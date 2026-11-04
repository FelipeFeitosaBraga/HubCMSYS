@echo off
setlocal enableextensions
rem ======================================================================
rem  BOTAO 4 - INSTALAR SQL SERVER 2025 EXPRESS + SSMS
rem ----------------------------------------------------------------------
rem  Rode depois dos botoes 1, 2 e 3 (rede, firewall e estrutura).
rem  O que faz:
rem    1) acha a pasta X:\cmsys\Suporte\SQLSERVER2025 (em qualquer disco);
rem    2) avisa se ainda nao ha .bak (normal: o Hub baixa depois, veja EXIGIR_BAK);
rem    3) se o SQL ja estiver instalado, pula a instalacao (pode rodar de novo);
rem    4) baixa a midia do Express (Core), extrai e instala em silencio usando
rem       o sql_config.ini (mesmas escolhas do manual da Azure);
rem    5) instala o SSMS (vs_SSMS.exe) em silencio.
rem  Precisa de INTERNET (o instalador do SQL e o do SSMS baixam da Microsoft).
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final.
rem ======================================================================
title Preparar PC CMSYS - 4) Instalar SQL Server 2025 Express + SSMS
set "RC=0"
call "%~dp0config_hub.bat"

echo.
echo ================================================================
echo  SQL SERVER 2025 EXPRESS + SSMS
echo ================================================================

rem ---- 1) PASTA DO SQL -------------------------------------------------
call "%~dp0_achar_pasta_sql.bat"
if errorlevel 1 goto :sem_pasta
echo  Pasta do SQL: %PASTA_SQL%

rem ---- 2) CONFERIR O .BAK ANTES DE INSTALAR -------------------------------
if defined BAK goto :bak_ok
if "%EXIGIR_BAK%"=="1" goto :sem_bak
echo  Ainda nao ha .bak na pasta (tudo bem: o Hub pergunta depois da instalacao).
goto :checar_instaladores
:bak_ok
for %%B in ("%BAK%") do echo  Backup encontrado: %%~nxB

:checar_instaladores
if not exist "%SSEI%" goto :sem_ssei

rem ---- 3) JA ESTA INSTALADO? ------------------------------------------------
rem  "sc query" consulta o servico do Windows. Se existe, o SQL ja esta la.
sc query MSSQLSERVER >nul 2>&1
if not errorlevel 1 goto :ja_instalado

rem ---- 4) REINICIO PENDENTE? (o setup do SQL recusa instalar assim) -----------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if not errorlevel 1 goto :reinicio_pendente
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if not errorlevel 1 goto :reinicio_pendente

rem ---- 5) BAIXAR E EXTRAIR A MIDIA -------------------------------------------
rem  No SQL 2025 a Microsoft acabou com o "Express Advanced": o Full-text e os
rem  demais recursos vem no Express normal. Por isso a midia agora e "Core"
rem  (o valor antigo "Advanced" da erro: Invalid value 'Advanced' for MediaType).
set "EXTRAIDO=%MIDIA_SQL%\Express"
if not exist "%MIDIA_SQL%" mkdir "%MIDIA_SQL%"
rem  Ja extraida antes, ou copiada a mao? Procura um setup.exe em qualquer
rem  subpasta da midia (ex.: copiar C:\SQL2025\ExpressAdv_PTB para ca funciona).
if exist "%EXTRAIDO%\setup.exe" goto :instalar
for /d %%D in ("%MIDIA_SQL%\*") do if exist "%%~fD\setup.exe" set "EXTRAIDO=%%~fD"
if exist "%EXTRAIDO%\setup.exe" goto :instalar

rem  Ja baixada (SQLEXPR_x64_*.exe ou SQLEXPRADV_x64_*.exe)? Entao so extrai.
set "PACOTE="
for %%F in ("%MIDIA_SQL%\SQLEXPR*_x64_*.exe") do set "PACOTE=%%~fF"
if defined PACOTE goto :extrair

echo.
echo  Baixando a midia do SQL Server 2025 Express (pode demorar, sem barra de progresso)...
set "ARG_IDIOMA="
if defined IDIOMA_SQL set "ARG_IDIOMA=/LANGUAGE=%IDIOMA_SQL%"
rem  "start /wait" faz o CMD esperar o instalador terminar. "/b" = mesma janela.
rem    /ACTION=Download  so baixa, nao instala
rem    MEDIAPATH         pasta de destino
rem    /MEDIATYPE=Core   Express completo (no 2025 ja inclui Full-text etc.)
rem    /QUIET            sem janela
start "" /b /wait "%SSEI%" /ACTION=Download MEDIAPATH="%MIDIA_SQL%" /MEDIATYPE=Core %ARG_IDIOMA% /QUIET
for %%F in ("%MIDIA_SQL%\SQLEXPR*_x64_*.exe") do set "PACOTE=%%~fF"
if defined PACOTE goto :extrair
rem  Ainda nada? Tenta sem idioma (o SSEI as vezes recusa o codigo de idioma).
if not defined ARG_IDIOMA goto :falha_download
echo  Tentando de novo sem fixar o idioma...
start "" /b /wait "%SSEI%" /ACTION=Download MEDIAPATH="%MIDIA_SQL%" /MEDIATYPE=Core /QUIET
for %%F in ("%MIDIA_SQL%\SQLEXPR*_x64_*.exe") do set "PACOTE=%%~fF"
if not defined PACOTE goto :falha_download

:extrair

echo.
echo  Baixando a midia do SQL Server 2025 Express (pode demorar, sem barra de progresso)...
set "ARG_IDIOMA="
if defined IDIOMA_SQL set "ARG_IDIOMA=/LANGUAGE=%IDIOMA_SQL%"
rem  "start /wait" faz o CMD esperar o instalador terminar (ele e um programa
rem  de janela; sem isso o CMD seguiria em frente na hora). "/b" = mesma janela.
rem    /ACTION=Download  so baixa, nao instala
rem    MEDIAPATH         pasta de destino
rem    /MEDIATYPE=Advanced  Express com Advanced Services (inclui IA/Full-text)
rem    /QUIET            sem janela
start "" /b /wait "%SSEI%" /ACTION=Download MEDIAPATH="%MIDIA_SQL%" /MEDIATYPE=Advanced %ARG_IDIOMA% /QUIET
for %%F in ("%MIDIA_SQL%\SQLEXPRADV_x64_*.exe") do set "PACOTE=%%~fF"
if not defined PACOTE goto :falha_download

:extrair
echo.
echo  Extraindo a midia...
rem  /q = silencioso   /x:PASTA = so extrai os arquivos (nao instala)
start "" /b /wait "%PACOTE%" /q /x:"%EXTRAIDO%"
if not exist "%EXTRAIDO%\setup.exe" goto :falha_extrair

rem ---- 6) INSTALAR O SQL ------------------------------------------------------
:instalar
echo.
echo  Instalando o SQL Server 2025 Express (alguns minutos)...
rem  /ConfigurationFile = nossas escolhas (sql_config.ini ao lado deste .bat)
rem  /SAPWD             = senha do sa, vinda do config_hub.bat
start "" /b /wait "%EXTRAIDO%\setup.exe" /ConfigurationFile="%~dp0sql_config.ini" /SAPWD="%SA_PWD%"
set "SETUP_RC=%errorlevel%"
if "%SETUP_RC%"=="0" goto :sql_ok
if "%SETUP_RC%"=="3010" goto :sql_ok_reiniciar
goto :falha_setup

:sql_ok_reiniciar
echo  AVISO: o instalador pediu reinicio do Windows (codigo 3010). Reinicie antes do botao 5.
:sql_ok
echo  SQL Server instalado.
goto :garantir_servico

:ja_instalado
echo.
echo  O SQL Server ja esta instalado neste PC. Pulando a instalacao do banco.

rem ---- 7) SERVICO NO AR -----------------------------------------------------------
:garantir_servico
sc query MSSQLSERVER | find /i "RUNNING" >nul
if errorlevel 1 net start MSSQLSERVER

rem ---- 8) SSMS ----------------------------------------------------------------------
if not exist "%SSMS_EXE%" goto :sem_ssms_exe
if not defined ProgramW6432 set "ProgramW6432=%ProgramFiles%"
if exist "%ProgramW6432%\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Ssms.exe" goto :ssms_ja
echo.
echo  Instalando o SSMS (precisa de internet, pode demorar)...
rem  --quiet sem janela   --norestart nao reinicia sozinho   --wait espera terminar
start "" /b /wait "%SSMS_EXE%" --quiet --norestart --wait
set "SSMS_RC=%errorlevel%"
if "%SSMS_RC%"=="0" goto :fim_ok
if "%SSMS_RC%"=="3010" goto :fim_ok
goto :falha_ssms

:ssms_ja
echo.
echo  O SSMS ja esta instalado. Pulando.
goto :fim_ok

:sem_ssms_exe
echo.
echo  AVISO: vs_SSMS.exe nao encontrado em %PASTA_SQL%. SSMS nao instalado.
goto :fim_ok

:fim_ok
echo.
echo [OK] Etapa concluida. Ao fechar esta janela, o Hub pergunta se ja quer restaurar o banco.
goto :fim

rem ------------------------- TRATAMENTO DE ERROS ------------------------
:sem_pasta
echo.
echo [FALHA] Nao achei a pasta %PASTA_SQL_REL% em nenhum disco.
echo         Rode antes o botao 3 (Baixar estrutura).
set "RC=1"
goto :fim

:sem_bak
echo.
echo [FALHA] Nenhum arquivo .bak em %PASTA_SQL%
echo         Copie o backup do cliente para essa pasta e rode de novo.
echo         O SQL NAO foi instalado.
set "RC=1"
goto :fim

:sem_ssei
echo.
echo [FALHA] Nao achei o SQL2025-SSEI-Expr.exe em %PASTA_SQL%
set "RC=1"
goto :fim

:reinicio_pendente
echo.
echo [FALHA] Ha um reinicio do Windows pendente. Reinicie o PC e rode de novo.
set "RC=1"
goto :fim

:falha_download
echo.
echo [FALHA] Nao foi possivel baixar a midia do SQL. Confira a internet.
echo         Plano B: no PC onde voce instalou a mao, copie a pasta C:\SQL2025\ExpressAdv_PTB
echo         (a que tem o setup.exe) para %MIDIA_SQL% deste PC e rode o botao de novo.
set "RC=1"
goto :fim

:falha_extrair
echo.
echo [FALHA] Nao foi possivel extrair a midia em %EXTRAIDO%
set "RC=1"
goto :fim

:falha_setup
echo.
echo [FALHA] O instalador do SQL terminou com erro (codigo %SETUP_RC%).
echo         Veja o resumo em: %ProgramFiles%\Microsoft SQL Server\170\Setup Bootstrap\Log\Summary.txt
set "RC=1"
goto :fim

:falha_ssms
echo.
echo [FALHA] O instalador do SSMS terminou com erro (codigo %SSMS_RC%). Confira a internet.
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
