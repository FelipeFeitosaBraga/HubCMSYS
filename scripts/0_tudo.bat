@echo off
rem ======================================================================
rem  BOTAO EXECUTAR TUDO  (1 + 2 + 3 + 4, nessa ordem)
rem ----------------------------------------------------------------------
rem  Chama cada etapa com o parametro /auto, que faz a etapa NAO pausar no
rem  final (senao o tecnico teria que apertar uma tecla 4 vezes).
rem  Se uma etapa falhar, as outras continuam e o resumo final mostra
rem  quais deram erro.
rem ======================================================================
title Preparar PC CMSYS - EXECUTAR TUDO
set "RC=0"
rem  AQUI = pasta onde este .bat esta (com a barra no final).
set "AQUI=%~dp0"

call "%AQUI%1_rede_privada.bat" /auto
set "R1=%errorlevel%"
call "%AQUI%2_firewall.bat" /auto
set "R2=%errorlevel%"
call "%AQUI%3_baixar_estrutura.bat" /auto
set "R3=%errorlevel%"
call "%AQUI%4_windows_update.bat" /auto
set "R4=%errorlevel%"

echo.
echo ================================================================
echo  RESUMO  (0 = OK, outro numero = falhou)
echo ================================================================
echo  1) Rede privada ........ %R1%
echo  2) Firewall e portas ... %R2%
echo  3) Estrutura CMSYS ..... %R3%
echo  4) Windows Update ...... %R4%

if not "%R1%"=="0" set "RC=1"
if not "%R2%"=="0" set "RC=1"
if not "%R3%"=="0" set "RC=1"
if not "%R4%"=="0" set "RC=1"

echo.
pause
exit /b %RC%
