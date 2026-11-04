@echo off
setlocal enableextensions
rem ======================================================================
rem  BOTAO 6 - INSTALAR O CMSYS NESTA ESTACAO
rem ----------------------------------------------------------------------
rem  Rode depois do botao 3 (precisa da pasta X:\cmsys\Suporte).
rem  O que faz (tudo no instalar_cmsys.ps1, ao lado deste arquivo):
rem    1) Microsoft ReportViewer 2010 ............ pula se ja instalado
rem    2) Crystal Reports Runtime 2008 ........... pula se ja instalado
rem    3) CMSYS Relatorios (depois de 295) ....... DESINSTALA versoes
rem       antigas e instala a nova
rem    4) CMSYS Boleto ........................... cria C:\CmsysBoleto e
rem       instala nela (pula se a mesma versao ja esta instalada)
rem    5) Componentes do CMSYS (CMSYS.CAB) ....... copia so o que falta ou
rem       esta mais antigo, registra, e nunca troca arquivo do Windows
rem  Pode rodar quantas vezes quiser: nao duplica nada. Um unico log,
rem  sobrescrito a cada execucao: C:\ProgramData\CMSYS_Preparacao\instalar_cmsys.log
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final.
rem ======================================================================
title Preparar PC CMSYS - 6) Instalar CMSYS na estacao
set "RC=0"
call "%~dp0config_hub.bat"

echo.
echo ================================================================
echo  INSTALAR CMSYS NA ESTACAO
echo ================================================================

rem  Descobre o disco do cmsys (o mesmo ajudante do SQL).
call "%~dp0_achar_pasta_sql.bat"
if errorlevel 1 goto :sem_pasta
set "SUPORTE=%CMSYS_DISCO%:\%REL_SUPORTE%"
echo  Pasta Suporte: %SUPORTE%

rem  Os componentes do CMSYS sao de 32 bits (VB6 + Crystal 9). Por isso o
rem  PowerShell de 32 bits (SysWOW64): grava nos mesmos lugares que o
rem  instalador original. Num Windows de 32 bits usa o PowerShell normal.
set "PS32=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS32%" set "PS32=powershell"

rem  As pastas (PASTA_REPORTVIEWER etc.) seguem pelo ambiente, do config_hub.bat.
"%PS32%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_cmsys.ps1" -Suporte "%SUPORTE%"
set "PS_RC=%errorlevel%"
if "%PS_RC%"=="0" goto :ok
if "%PS_RC%"=="3010" goto :ok_reiniciar
goto :falha

:ok_reiniciar
echo.
echo  AVISO: algum instalador pediu reinicio do Windows. Reinicie antes de abrir o CMSYS.
:ok
echo.
echo [OK] CMSYS instalado nesta estacao.
goto :fim

:sem_pasta
echo.
echo [FALHA] Nao achei a pasta cmsys\Suporte em nenhum disco. Rode o botao 3.
set "RC=1"
goto :fim

:falha
echo.
echo [FALHA] Alguma parte nao foi instalada (veja as mensagens acima e o log).
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
