# Garopaba Algodoeira — app

App interno (cotações do algodão, notícias e calculadoras) com login por departamento.

## Arquivos
- `index.html` — o app (GitHub Pages).
- `config.js` — URL e chave pública (publishable/anon) do Supabase.
- `schema.sql` — tabelas e regras de acesso (rodar 1 vez).
- `seed.sql` — cotações e notícias iniciais (26/11/2026).
- `manifest.json`, `icon*.png`, `icon.svg` — instalar como aplicativo no celular.

## Montagem
1. Supabase (conta pessoal, organização "Augusto Pessoal"): criar projeto `garopaba-algodoeira` (região São Paulo, sa-east-1).
2. Rodar `schema.sql` e depois `seed.sql` no SQL Editor.
3. Authentication → URL Configuration: Site URL = https://cantuariadesouza-arch.github.io/garopaba-algodoeira/
4. Preencher `config.js` com Project URL e a chave publishable/anon.
5. GitHub: repositório `cantuariadesouza-arch/garopaba-algodoeira` com estes arquivos; Pages → branch main, pasta raiz.
6. O primeiro cadastro feito no app vira administrador liberado (fazer com o e-mail do Augusto).

## Regras de acesso
- Cadastro: nome, departamento (Comercial, Financeiro, Contábil, Faturamento, Logística, Jurídico), e-mail e senha → fica "aguardando".
- Administrador libera/bloqueia, muda departamento e define outros administradores na aba Equipe.
- Histórico das calculadoras: cada departamento vê só o seu; o departamento é gravado pelo banco (não dá para falsificar). Admin vê todos.
- Cotações e notícias (tabela `docs`): todos os liberados leem; só administradores gravam. As tarefas automáticas devem gravar em `docs` (paths `mercado/atual`, `noticias/atual`, `noticiasDia/AAAA-MM-DD`).
