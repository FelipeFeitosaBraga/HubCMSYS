@echo off
rem ======================================================================
rem  AJUDANTE (nao e botao): descobre onde esta a pasta do SQL e o .bak
rem ----------------------------------------------------------------------
rem  Procura  X:\cmsys\Suporte\SQLSERVER2025  em todos os discos (o cmsys
rem  pode estar em C:, D:, E:...). Comeca pelo disco que o botao 3 gravou.
rem  Devolve (variaveis para quem chamou):
rem     CMSYS_DISCO  letra do disco, ex.: C
rem     PASTA_SQL    pasta completa, ex.: C:\cmsys\Suporte\SQLSERVER2025
rem     SSEI         instalador SQL2025-SSEI-Expr.exe
rem     SSMS_EXE     instalador vs_SSMS.exe
rem     BAK          .bak mais recente da pasta (vazio se nao houver)
rem  Codigo de saida: 0 = pasta encontrada, 1 = nao encontrada.
rem  Requer que config_hub.bat ja tenha sido chamado (usa PASTA_SQL_REL).
rem ======================================================================
set "CMSYS_DISCO="
set "PASTA_SQL="
set "SSEI="
set "SSMS_EXE="
set "BAK="

rem  Disco gravado pelo botao 3 (se existir) vai na frente da fila.
set "LISTA=C"
if exist "%ProgramData%\CMSYS_Preparacao\disco_cmsys.txt" set /p LISTA=<"%ProgramData%\CMSYS_Preparacao\disco_cmsys.txt"
set "LISTA=%LISTA:~0,1% C D E F G H I J K L M N O P Q R S T U V W X Y Z"

rem  Testa cada letra; o primeiro disco que tiver a pasta vence.
for %%D in (%LISTA%) do if not defined PASTA_SQL if exist "%%D:\%PASTA_SQL_REL%\" (set "CMSYS_DISCO=%%D" & set "PASTA_SQL=%%D:\%PASTA_SQL_REL%")

if not defined PASTA_SQL exit /b 1

set "SSEI=%PASTA_SQL%\SQL2025-SSEI-Expr.exe"
set "SSMS_EXE=%PASTA_SQL%\vs_SSMS.exe"

rem  "dir /o-d" lista do mais NOVO para o mais antigo; o primeiro .bak vence.
for /f "delims=" %%F in ('dir /b /a-d /o-d "%PASTA_SQL%\*.bak" 2^>nul') do if not defined BAK set "BAK=%PASTA_SQL%\%%F"
exit /b 0
