# Site do Hub CMSYS

Site estatico (HTML + CSS + JS, sem build) com duas abas, na mesma pagina:
- **Preparar PC**: download do `HubCMSYS.exe` e o guia (cliente novo / troca de servidor);
- **Atualizar Servidor**: download do `AtualizarCMSYS.exe` e o guia da atualizacao do cliente.

A aba troca com uma transicao horizontal. Link direto para a aba: `https://hubcmsys-site.vercel.app/#atualizar`.

```
index.html          a pagina
assets/config.js    VERSAO, data, links dos downloads e novidades  <- mexa aqui a cada versao
assets/style.css    visual (claro/escuro)
assets/app.js       download, tema, checklist, copiar, filtro do FAQ
download/           HubCMSYS.exe e AtualizarCMSYS.exe
vercel.json         forca o download do .exe e evita cache do config.js
```

## Publicar no Vercel (primeira vez)
1. Rode `build.bat` na raiz do repositorio e copie `dist\HubCMSYS.exe` para `site\download`.
2. Faca commit e push do repositorio HubCMSYS (com o .exe em `site/download`).
3. Em vercel.com: **Add New > Project**, importe `FelipeFeitosaBraga/HubCMSYS`.
   **Root Directory: `site`**. Framework Preset: **Other**. Build Command e Output Directory: em branco.
4. Clique em **Deploy**. O site fica em `https://<nome>.vercel.app`.

Sem GitHub: instale o Node, abra o terminal nesta pasta e rode `npx vercel` (depois `npx vercel --prod`).

## Nova versao do Hub
1. Troque o `download/HubCMSYS.exe` pelo novo.
2. Em `assets/config.js`, atualize `VERSAO`, `DATA_VERSAO` e `NOVIDADES`.
3. `git push` (o Vercel publica sozinho).

## Exe fora do site (opcional)
Se preferir hospedar o .exe numa Release do GitHub, troque `URL_DOWNLOAD` no `config.js`
pelo link da Release e deixe a pasta `download` vazia.

## Quem pode acessar
O site e publico para quem tiver o link (nao aparece no Google por causa do `noindex`).
O .exe leva dentro a senha do `sa` e a regra da senha do portal. Para restringir:
Vercel > Project > Settings > **Deployment Protection** (protecao por senha exige plano Pro).

## Aba Atualizar Servidor
- O conteudo fica em `index.html`, dentro de `<div class="vista" id="vista-atualizar">` (secoes com id `at-...`).
- Nova versao do AtualizarCMSYS: troque `download/AtualizarCMSYS.exe` e atualize `ATUALIZAR.VERSAO`
  e `ATUALIZAR.DATA_VERSAO` no `config.js`.
- O `AtualizarCMSYS.exe` do site vai **sem token** (este repositorio e publico). Ele ja sabe o
  repositorio (`FelipeFeitosaBraga/UpdateCmsys`, ref `main`) e pede o token ao abrir.
  Para gerar: na pasta `ferramentas\AtualizarCMSYS` do UpdateCmsys, deixe um `AtualizarCMSYS.cfg`
  so com `repositorio=` e `ref=` (sem a linha `token=`) e rode o `compilar.bat`.
  NUNCA publique aqui um .exe com o token embutido.
