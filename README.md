# Hub CMSYS - Preparar PC (cliente novo)

Este repositorio tem duas partes:
- **raiz**: o programa (hub.py + scripts) que vira o `HubCMSYS.exe`;
- **`site/`**: o site de download e guia, publicado no Vercel (Root Directory = `site`). Veja `site/README.md`.

Janela com botoes; cada botao executa um `.bat` da pasta `scripts`. A numeracao segue a ordem de execucao.

| Botao | Arquivo | O que faz |
|---|---|---|
| 1 | `1_rede_privada.bat` | Redes Publicas -> Privadas |
| 2 | `2_firewall.bat` | Firewall off + regras TS 3389 e SQL 1433 |
| 3 | `3_baixar_estrutura.bat` | Baixa `cmsys.zip`, confere, extrai e copia para `X:\cmsys` |
| 4 | `4_instalar_sql.bat` | Instala SQL Server 2025 Express + SSMS (config em `sql_config.ini`). No fim o Hub pergunta se ja quer restaurar o banco |
| 5 | `5_restaurar_banco.bat` (+ `restaurar_banco.ps1`) | O Hub pergunta se o `.bak` ja foi baixado; se nao, abre o portal da Azure com login para copiar, espera o download e move o `.bak` para `cmsys\Suporte\SQLSERVER2025`. Depois restaura (cmsys / cmsys_fN), liga TCP/IP e Pipes, reinicia o servico |
| 6 | `6_instalar_cmsys.bat` (+ `instalar_cmsys.ps1`) | ReportViewer 2010, Crystal Runtime 2008, CMSYS Relatorios (desinstala versoes antigas antes), CMSYS Boleto em `C:\CmsysBoleto`, componentes do CMSYS (CMSYS.CAB). Nao duplica nada |
| 7 | `7_windows_update.bat` (+ `windows_update.ps1`) | Windows Update (por ultimo: pode pedir reinicio) |
| 8 | `8_migrar_arquivos.bat` (+ `migrar_arquivos.ps1`) | Troca de servidor: robocopy do cmsys antigo (rede) para o novo. XML de cupom, XML/PDF das notas de cada CNPJ, Fotos e Logos. Nao apaga nada; fora do Executar tudo |
| Tudo | (feito pelo Hub) | 1 a 7 em sequencia, pergunta do banco depois do SQL, resumo no final. `0_tudo.bat` e a versao sem perguntas para rodar no CMD |

Arquivos de apoio (nao sao botoes): `config_hub.bat` (senha do sa, pastas, opcoes), `_achar_pasta_sql.bat` (acha `X:\cmsys\Suporte\SQLSERVER2025` em qualquer disco), `sql_config.ini` (escolhas do manual do SQL).

## Testar
`python hub.py` (pede administrador sozinho). Teste numa VM antes de usar em cliente.

## Gerar o .exe
`build.bat` -> `dist\HubCMSYS.exe`

## Onde colocar o cmsys.zip
- **Teste/offline:** `cmsys.zip` ao lado do `hub.py` (ou do `.exe`). O botao 3 usa ele e nao baixa nada.
- **Online:** NAO faca commit do zip (GitHub bloqueia arquivo > 100 MB). Crie uma *Release* e anexe o `cmsys.zip` (ate 2 GiB por arquivo). O botao 3 baixa de `.../releases/latest/download/cmsys.zip` (variavel `URL_ZIP` no `3_baixar_estrutura.bat`). O repositorio precisa ser publico.

## SQL: o que ja vem no zip
O botao 4 espera encontrar em `X:\cmsys\Suporte\SQLSERVER2025`: `SQL2025-SSEI-Expr.exe`, `vs_SSMS.exe` e o `.bak` do cliente. O `.bak` pode chegar depois: o botao 5 ajuda a baixar (`EXIGIR_BAK=0` no `config_hub.bat`).

## Portal da Azure (botao 5)
URL, usuario e regra da senha ficam no `config_hub.bat` (`PORTAL_URL`, `PORTAL_USUARIO`, `PORTAL_SENHA`). Na senha, `{EMPRESA}` vira o codigo digitado (padrao `old*{EMPRESA}/0`, igual a extensao Auto Login 2.0); tambem aceita `{MES}` e `{ANO}`.

## Instalar CMSYS (botao 6)
Le os instaladores de `X:\cmsys\Suporte` (pastas configuradas no `config_hub.bat`). Log unico, sobrescrito a cada execucao: `C:\ProgramData\CMSYS_Preparacao\instalar_cmsys.log` (a execucao anterior fica em `instalar_cmsys.log.anterior.log`).

## Migrar arquivos (botao 8)
Origem pelo caminho de rede (`\\SERVIDOR\c$\cmsys`): o Hub roda como administrador e nao enxerga unidades mapeadas. Robocopy com `/E /XO` (nunca apaga no destino, nao troca arquivo por um mais antigo). Logos: usa `Aplicativo\Logo.jpg/.jpeg/.png` e `Logo.gif` do cliente; o que faltar vem de `Aplicativo\Logo`. Log: `C:\ProgramData\CMSYS_Preparacao\migrar_arquivos.log`.
