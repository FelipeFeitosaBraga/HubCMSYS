@echo off
rem ======================================================================
rem  CONFIGURACOES COMPARTILHADAS (lido pelos botoes 4, 5 e 6 e pelo Hub)
rem ----------------------------------------------------------------------
rem  Nao e um botao: e chamado com "call config_hub.bat" para carregar as
rem  variaveis abaixo. Mude aqui e vale para todos os scripts de SQL.
rem ======================================================================

rem  Senha do usuario "sa" do SQL Server (padrao do manual da Azure).
rem  Fica em UM so lugar. Quem tiver estes arquivos consegue le-la.
set "SA_PWD=Vector5**"

rem  Caminho da pasta do SQL DENTRO do disco onde o cmsys foi criado.
rem  O disco (C:, D:...) e descoberto sozinho: veja _achar_pasta_sql.bat.
set "PASTA_SQL_REL=cmsys\Suporte\SQLSERVER2025"

rem  Onde ficam os arquivos do banco restaurado (segue o manual:
rem  dados em ...\Dados\BACKUP e log em ...\Dados\SQL).
rem  Se o manual estiver com os nomes trocados, inverta as duas linhas.
set "REL_DADOS=cmsys\Dados\BACKUP"
set "REL_LOG=cmsys\Dados\SQL"

rem  Pasta temporaria onde a midia do SQL e baixada/extraida (~1,5 GB).
set "MIDIA_SQL=C:\SQL2025"

rem  Idioma da midia do SQL. O manual usou portugues (pt-BR). Se o download
rem  falhar por causa do idioma, deixe vazio (baixa em ingles; nao afeta o CMSYS).
set "IDIOMA_SQL=pt-BR"

rem  0 = instala o SQL mesmo sem o .bak (padrao: o .bak e baixado DEPOIS,
rem      quando o Hub pergunta se ja quer restaurar o banco).
rem  1 = o botao 4 so instala o SQL se o .bak ja estiver na pasta.
set "EXIGIR_BAK=0"

rem  0 = se o banco ja existir, NAO restaura por cima (protege dados do cliente).
rem  1 = restaura por cima (WITH REPLACE) sem perguntar.
set "SUBSTITUIR_SE_EXISTIR=0"

rem ---------------------------------------------------------------------
rem  PORTAL DA AZURE (botao 5: baixar o .bak do cliente)
rem ---------------------------------------------------------------------
rem  O Hub le estas linhas para montar a janela de login.
rem  Na senha, {EMPRESA} (ou {empresa}) vira o codigo da empresa digitado no Hub.
rem  Tambem da para usar {MES} (jan, feb, mar... em ingles) e {ANO} (26).
rem  Mesma regra da extensao "Auto Login Azure" 2.0: old* + empresa + /0.
rem  Se a regra mudar, troque aqui e nas opcoes da extensao.
rem  Nao use % nem ! nestas linhas.
set "PORTAL_URL=https://www.azuresistemas.com.br/restorebackup/RestoreBackupLocal"
set "PORTAL_USUARIO=Cmsys"
set "PORTAL_SENHA=old*{EMPRESA}/0"

rem ---------------------------------------------------------------------
rem  INSTALACAO DO CMSYS NA ESTACAO (botao 6)
rem ---------------------------------------------------------------------
rem  Pastas dentro de X:\cmsys\Suporte (o disco e descoberto sozinho).
set "REL_SUPORTE=cmsys\Suporte"
set "PASTA_REPORTVIEWER=Setup Report Viewer"
set "PASTA_CRYSTAL=Setup Crystal"
set "PASTA_RELATORIOS=Setup CMSYS 2010 - depois de 295"
set "PASTA_BOLETO=cmsysBoleto"
set "PASTA_CMSYS=Setup CMSYS\winGeral"
rem  Onde o CMSYS Boleto e instalado (obrigatorio pelo manual).
set "DESTINO_BOLETO=C:\CmsysBoleto"
