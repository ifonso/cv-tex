-- core/linebreak.lua
--
-- Quebra de linha "gulosa" (first-fit), igual à do Google Docs.
--
-- O algoritmo padrão do TeX (Knuth-Plass) otimiza o parágrafo inteiro e pode
-- escolher quebras diferentes das do Google Docs. Aqui cada linha recebe o
-- máximo de palavras que cabem na largura natural (sem comprimir espaços), e
-- a linha é então justificada esticando os espaços — exatamente como o Docs.
--
-- Cada linha gerada recebe altura/profundidade fixas (\cvLineAbove e
-- \cvLineBelow), o que reproduz o modelo de entrelinha do Docs:
--   altura da linha = line-height × (ascendente + descendente) × tamanho
--   o espaço extra do line-height fica *abaixo* da linha.
--
-- O algoritmo só é usado quando \cvGreedy = 1 (definido por \cvParagraph).

cvlayout = cvlayout or {}

local GLUE    = node.id("glue")
local PENALTY = node.id("penalty")
local KERN    = node.id("kern")
local MATH    = node.id("math")

local glue_subtype = {}
for k, v in pairs(node.subtypes("glue")) do glue_subtype[v] = k end
local LEFTSKIP    = glue_subtype.leftskip
local RIGHTSKIP   = glue_subtype.rightskip
local PARFILLSKIP = glue_subtype.parfillskip

local EPS = 2 -- tolerância em sp para erros de arredondamento

local function discardable(n)
  local id = n.id
  return id == GLUE or id == PENALTY or id == KERN or id == MATH
end

local function is_parfill(n)
  return n.id == GLUE and n.subtype == PARFILLSKIP
end

local function new_skip(subtype, name)
  local g = node.new(GLUE, subtype)
  node.setglue(g, tex.getglue(name))
  return g
end

local function width(a, b)
  if a == b then return 0 end
  return (node.dimensions(a, b))
end

-- Remove os itens descartáveis que vêm logo após uma quebra (como o TeX).
local function skip_discardables(n)
  while n and discardable(n) and not is_parfill(n) do
    local nx = n.next
    if nx then nx.prev = nil end
    n.next = nil
    node.flush_node(n)
    n = nx
  end
  return n
end

-- Justificação do Docs: o espaço que sobra na linha é convertido em pixels
-- inteiros (1px = 0.75bp, tela a 96 dpi) e distribuído entre os espaços entre
-- palavras — todos recebem a parte inteira e os primeiros recebem +1px. A
-- fração de pixel que sobra fica à direita (a linha não encosta exatamente
-- na margem). Linhas com cola infinita (última linha, quebra manual, texto
-- alinhado à esquerda) ficam com os espaços naturais.
local PX = tex.sp("0.75bp")
-- Calibração: medindo todas as linhas justificadas do PDF original, a
-- borda direita efetiva do Docs fica em [margem - 0.02bp, margem).
local JUSTIFY_SLACK = tex.sp("0.01bp")

local function justify(head, rs, hsize)
  local gaps = {}
  for g in node.traverse_id(GLUE, head) do
    local _, stretch, _, order = node.getglue(g)
    if order > 0 and stretch ~= 0 then return end
    if g.subtype ~= LEFTSKIP and g.subtype ~= RIGHTSKIP and stretch > 0 then
      gaps[#gaps + 1] = g
    end
  end
  if #gaps == 0 then return end
  local extra = hsize - node.dimensions(head) - JUSTIFY_SLACK
  if extra <= 0 then return end
  local px = math.floor(extra / PX)
  local base, rest = px // #gaps, px % #gaps
  for i, g in ipairs(gaps) do
    local add = base * PX
    if i <= rest then add = add + PX end
    node.setglue(g, g.width + add, 0, 0, 0, 0)
  end
  node.setglue(rs, 0, 65536, 0, 2, 0) -- 0pt plus 1fil
end

function cvlayout.linebreak(head, is_display)
  if tex.count["cvGreedy"] ~= 1 then
    return true -- usa o algoritmo padrão do TeX
  end

  local hsize = tex.hsize
  local lw = tex.getglue("leftskip")
  local rw = tex.getglue("rightskip")
  local avail = hsize - lw - rw
  local above = tex.dimen["cvLineAbove"]
  local below = tex.dimen["cvLineBelow"]

  local lines = {}

  local function pack(first)
    local ls = new_skip(LEFTSKIP, "leftskip")
    local rs = new_skip(RIGHTSKIP, "rightskip")
    ls.next = first
    first.prev = ls
    local t = node.tail(first)
    t.next = rs
    rs.prev = t
    justify(ls, rs, hsize)
    local box = node.hpack(ls, hsize, "exactly")
    box.subtype = 1 -- line
    box.height = above
    box.depth = below
    lines[#lines + 1] = box
  end

  -- Fecha a linha [start, brk) e devolve o início da próxima.
  local function emit(start, brk)
    local last = brk.prev
    last.next = nil
    brk.prev = nil
    start.prev = nil
    pack(start)
    return skip_discardables(brk)
  end

  local start = head
  local candidate = nil
  local n = start

  while n do
    if is_parfill(n) then
      -- Fim do parágrafo: a última linha precisa caber.
      if width(start, n) > avail + EPS and candidate then
        start = emit(start, candidate)
        candidate, n = nil, start
      else
        start.prev = nil
        pack(start)
        break
      end
    elseif n.id == PENALTY and n.penalty <= -10000 then
      -- Quebra forçada (\cvBreak). Se o trecho não couber, quebra antes.
      if width(start, n) > avail + EPS and candidate then
        start = emit(start, candidate)
      else
        start = emit(start, n)
      end
      candidate, n = nil, start
    elseif n.id == GLUE and n.prev and not discardable(n.prev)
        and width(start, n) > 0 then
      if width(start, n) <= avail + EPS then
        candidate = n
        n = n.next
      elseif candidate then
        start = emit(start, candidate)
        candidate, n = nil, start
      else
        -- Palavra maior que a linha: quebra aqui mesmo (overfull).
        start = emit(start, n)
        candidate, n = nil, start
      end
    else
      n = n.next
    end
  end

  -- Monta a lista vertical: linhas + penalidades (viúvas/órfãs).
  local count = #lines
  local result, tail = nil, nil
  local function append(x)
    if tail then tail.next = x; x.prev = tail else result = x end
    tail = x
  end
  for i, box in ipairs(lines) do
    append(box)
    if i < count then
      local p = tex.interlinepenalty
      if i == 1 then p = p + tex.clubpenalty end
      if i == count - 1 then p = p + tex.widowpenalty end
      if p > 10000 then p = 10000 end
      if p ~= 0 then
        local pen = node.new(PENALTY)
        pen.penalty = p
        append(pen)
      end
    end
  end
  return result
end

luatexbase.add_to_callback("linebreak_filter", cvlayout.linebreak,
  "cvlayout.linebreak")
