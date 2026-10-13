-- core/snap.lua
--
-- Encaixe dos sublinhados na grade de pontos, como o Google Docs faz:
-- as extremidades e o topo do traço de 1bp são arredondados para o ponto
-- inteiro mais próximo da página (ex.: texto começando em 70.20bp tem o
-- sublinhado começando em 70bp).
--
-- Funciona no momento do \shipout: percorre a página calculando a posição
-- absoluta de cada régua marcada com o atributo \cvSnapAttr e a ajusta.

cvlayout = cvlayout or {}

local HLIST = node.id("hlist")
local VLIST = node.id("vlist")
local RULE  = node.id("rule")
local GLUE  = node.id("glue")
local KERN  = node.id("kern")
local GLYPH = node.id("glyph")
local DISC  = node.id("disc")
local MATH  = node.id("math")

local ATTR = luatexbase.attributes.cvSnapAttr
local BP = tex.sp("1bp")

local function round_bp(v)
  return math.floor(v / BP + 0.5) * BP
end

local function snap_rule(rule, parent, x, y, ox, oy)
  local x0 = ox + x
  local x1 = x0 + rule.width
  local top = oy + y - rule.height
  local thickness = rule.height + rule.depth
  local nx0, nx1, ntop = round_bp(x0), round_bp(x1), round_bp(top)
  local shift = math.floor(nx0 - x0 + 0.5)
  local width = math.floor(nx1 - nx0 + 0.5)
  local before = node.new(KERN)
  before.kern = shift
  local after = node.new(KERN)
  after.kern = -(shift + width - rule.width)
  rule.height = math.floor(-(ntop - oy - y) + 0.5)
  rule.depth = thickness - rule.height
  rule.width = width
  parent.head = node.insert_before(parent.head, rule, before)
  node.insert_after(parent.head, rule, after)
end

local walk_h, walk_v

-- x: borda esquerda da caixa; y: linha de base (crescendo para baixo)
walk_h = function(box, x, y, ox, oy)
  local cx = x
  local n = box.head
  while n do
    local nx = n.next
    local id = n.id
    if id == HLIST then
      walk_h(n, cx, y + n.shift, ox, oy)
      cx = cx + n.width
    elseif id == VLIST then
      walk_v(n, cx, y + n.shift, ox, oy)
      cx = cx + n.width
    elseif id == RULE then
      local w = n.width
      if node.has_attribute(n, ATTR) then
        snap_rule(n, box, cx, y, ox, oy)
      end
      cx = cx + w
    elseif id == GLUE then
      cx = cx + node.effective_glue(n, box)
    elseif id == KERN then
      cx = cx + n.kern
    elseif id == GLYPH then
      cx = cx + n.width
    elseif id == DISC then
      if n.replace then cx = cx + (node.dimensions(n.replace)) end
    elseif id == MATH then
      cx = cx + n.surround
    end
    n = nx
  end
end

walk_v = function(box, x, y, ox, oy)
  local cy = y - box.height
  for n in node.traverse(box.head) do
    local id = n.id
    if id == HLIST or id == VLIST then
      cy = cy + n.height
      if id == HLIST then
        walk_h(n, x + n.shift, cy, ox, oy)
      else
        walk_v(n, x + n.shift, cy, ox, oy)
      end
      cy = cy + n.depth
    elseif id == GLUE then
      cy = cy + node.effective_glue(n, box)
    elseif id == KERN then
      cy = cy + n.kern
    elseif id == RULE then
      cy = cy + n.height + n.depth
    end
  end
end

function cvlayout.snap(box)
  local h, v = pdf.getorigin()
  local ox, oy = h + tex.hoffset, v + tex.voffset
  if box.id == VLIST then
    walk_v(box, 0, box.height, ox, oy)
  else
    walk_h(box, 0, box.height, ox, oy)
  end
  return true
end

luatexbase.add_to_callback("pre_shipout_filter", cvlayout.snap, "cvlayout.snap")
