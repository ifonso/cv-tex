# Currículo em LaTeX

Repositório para gerar o meu currículo em PDF a partir de LaTeX. O conteúdo fica em `content/`, os componentes reutilizáveis em `components/` e o motor de layout em `core/`. Um exemplo do resultado está em `preview.pdf`.

Para compilar é preciso de uma distribuição TeX com LuaLaTeX e latexmk, como o MacTeX ou o TeX Live, já que o layout depende de callbacks em Lua. O `make` é opcional e só serve de atalho: `make` gera o PDF em `build/main.pdf`, `make watch` recompila a cada alteração e `make clean` apaga o build. Sem o `make`, basta rodar `latexmk` na raiz.

As fontes necessárias (Carlito, Noto Serif Bengali e Arimo) já estão em `fonts/`. A Calibri é proprietária e não é versionada; se estiver instalada no sistema ou copiada para `fonts/`, ela é usada no lugar da Carlito, que tem as mesmas métricas.

O telefone não é versionado. Para incluí-lo no PDF, copie `content/phone.example.tex` para `content/phone.tex` (que é ignorado pelo git) e coloque o número; sem esse arquivo o currículo sai sem telefone.
