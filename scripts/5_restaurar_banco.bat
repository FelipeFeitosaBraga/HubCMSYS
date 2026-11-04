@echo off
setlocal enableextensions
rem ======================================================================
rem  BOTAO 5 - RESTAURAR O BANCO DO CMSYS A PARTIR DO .BAK
rem ----------------------------------------------------------------------
rem  Rode depois do botao 4.
rem  O que faz (tudo no restaurar_banco.ps1, ao lado deste arquivo):
rem    1) usa o .bak que o Hub escolheu/baixou (variavel BAK_ESCOLHIDO) ou,
rem       sem ela, o .bak mais recente em X:\cmsys\Suporte\SQLSERVER2025;
rem    2) restaura como "cmsys" (filial 1) ou "cmsys_fN" (filial N), lendo
rem       o numero da filial do nome do arquivo (ex.: ..._Filial_1_...);
rem    3) coloca os arquivos de dados e de log nas pastas do config_hub.bat;
rem    4) garante TCP/IP e Pipes nomeados ligados e reinicia o servico;
rem    5) confere se o SQL esta escutando na porta 1433.
rem  Se o banco ja existir, NAO sobrescreve (protege dados do cliente), a
rem  menos que SUBSTITUIR_SE_EXISTIR=1 ou o tecnico digite SUBSTITUIR.
rem  Parametro : /auto  -> sem perguntas e sem "pressione uma tecla".
rem ======================================================================
title Preparar PC CMSYS - 5) Restaurar banco do CMSYS
set "RC=0"
call "%~dp0config_hub.bat"
set "AUTO=0"
if /i "%~1"=="/auto" set "AUTO=1"

echo.
echo ================================================================
echo  RESTAURAR BANCO DO CMSYS
echo ================================================================

call "%~dp0_achar_pasta_sql.bat"
if errorlevel 1 goto :sem_pasta
rem  O Hub informa qual .bak usar (o que acabou de ser baixado/escolhido).
if defined BAK_ESCOLHIDO if exist "%BAK_ESCOLHIDO%" set "BAK=%BAK_ESCOLHIDO%"
if not defined BAK goto :sem_bak
for %%B in ("%BAK%") do echo  Backup: %%~nxB

rem  O SQL precisa estar instalado e no ar.
sc query MSSQLSERVER >nul 2>&1
if errorlevel 1 goto :sem_sql
sc query MSSQLSERVER | find /i "RUNNING" >nul
if errorlevel 1 net start MSSQLSERVER

set "DADOS=%CMSYS_DISCO%:\%REL_DADOS%"
set "LOGDIR=%CMSYS_DISCO%:\%REL_LOG%"
echo  Dados : %DADOS%
echo  Log   : %LOGDIR%
echo.

rem  A senha do sa segue para o PowerShell pela variavel de ambiente SA_PWD
rem  (definida no config_hub.bat), sem aparecer na linha de comando.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restaurar_banco.ps1" -Bak "%BAK%" -PastaDados "%DADOS%" -PastaLog "%LOGDIR%" -Substituir %SUBSTITUIR_SE_EXISTIR% -Auto %AUTO%
if errorlevel 1 goto :falha
goto :fim

:sem_pasta
echo.
echo [FALHA] Nao achei a pasta %PASTA_SQL_REL% em nenhum disco. Rode o botao 3.
set "RC=1"
goto :fim

:sem_bak
echo.
echo [FALHA] Nenhum arquivo .bak em %PASTA_SQL%
set "RC=1"
goto :fim

:sem_sql
echo.
echo [FALHA] O SQL Server nao esta instalado. Rode o botao 4 primeiro.
set "RC=1"
goto :fim

:falha
echo.
echo [FALHA] A restauracao nao foi concluida (veja as mensagens acima).
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
