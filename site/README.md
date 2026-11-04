# Site do Hub CMSYS

Site estatico (HTML + CSS + JS, sem build) com o download do `HubCMSYS.exe` e o guia passo a passo.

```
index.html          a pagina
assets/config.js    VERSAO, data, link do download e novidades  <- mexa aqui a cada versao
assets/style.css    visual (claro/escuro)
assets/app.js       download, tema, checklist, copiar, filtro do FAQ
download/           coloque aqui o HubCMSYS.exe
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
