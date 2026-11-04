@echo off
rem ======================================================================
rem  EXECUTAR TUDO PELA LINHA DE COMANDO  (1 a 7, sem perguntas)
rem ----------------------------------------------------------------------
rem  ATENCAO: o botao "EXECUTAR TUDO" do Hub NAO usa este arquivo. O Hub
rem  roda as etapas uma a uma e, depois do SQL, pergunta se ja quer
rem  restaurar o banco (e ajuda a baixar o .bak). Este .bat e para quem
rem  quiser rodar tudo direto no CMD: a etapa 5 so restaura se o .bak ja
rem  estiver em cmsys\Suporte\SQLSERVER2025.
rem
rem  1 Rede  2 Firewall  3 Estrutura  4 SQL+SSMS  5 Restaurar banco
rem  6 Instalar CMSYS  7 Windows Update (por ultimo: pode exigir reinicio).
rem  Se a 3 falhar, 4, 5 e 6 sao puladas; se a 4 falhar, a 5 e pulada.
rem ======================================================================
title Preparar PC CMSYS - EXECUTAR TUDO
set "RC=0"
set "AQUI=%~dp0"

call "%AQUI%1_rede_privada.bat" /auto
set "R1=%errorlevel%"
call "%AQUI%2_firewall.bat" /auto
set "R2=%errorlevel%"
call "%AQUI%3_baixar_estrutura.bat" /auto
set "R3=%errorlevel%"

set "R4=pulado"
set "R5=pulado"
set "R6=pulado"
if not "%R3%"=="0" goto :janela_update
call "%AQUI%4_instalar_sql.bat" /auto
set "R4=%errorlevel%"
if not "%R4%"=="0" goto :cmsys
call "%AQUI%5_restaurar_banco.bat" /auto
set "R5=%errorlevel%"
:cmsys
call "%AQUI%6_instalar_cmsys.bat" /auto
set "R6=%errorlevel%"

:janela_update
call "%AQUI%7_windows_update.bat" /auto
set "R7=%errorlevel%"

echo.
echo ================================================================
echo  RESUMO  (0 = OK, outro valor = falhou, pulado = nao executou)
echo ================================================================
echo  1) Rede privada ........... %R1%
echo  2) Firewall e portas ...... %R2%
echo  3) Estrutura CMSYS ........ %R3%
echo  4) SQL Server + SSMS ...... %R4%
echo  5) Restaurar banco ........ %R5%
echo  6) Instalar CMSYS ......... %R6%
echo  7) Windows Update ......... %R7%

for %%R in ("%R1%" "%R2%" "%R3%" "%R4%" "%R5%" "%R6%" "%R7%") do if not "%%~R"=="0" set "RC=1"

echo.
pause
exit /b %RC%
