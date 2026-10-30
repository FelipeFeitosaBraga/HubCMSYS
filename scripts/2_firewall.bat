@echo off
rem ======================================================================
rem  BOTAO 2 - FIREWALL DESATIVADO + REGRAS TS (3389) E SQL (1433)
rem ----------------------------------------------------------------------
rem  O que faz :
rem    a) desativa o Firewall do Windows nos 3 perfis (Dominio, Privado
rem       e Publico);
rem    b) cria a regra "TS"  = porta TCP 3389 (Terminal Services / Area
rem       de Trabalho Remota), entrada e saida;
rem    c) cria a regra "SQL" = porta TCP 1433 (SQL Server), entrada e saida.
rem  Pode rodar varias vezes: antes de criar cada regra, a antiga com o
rem  mesmo nome e apagada, entao nunca fica regra duplicada.
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final.
rem ======================================================================
title Preparar PC CMSYS - 2) Firewall e portas
set "RC=0"

echo.
echo ================================================================
echo  FIREWALL: desativando perfis e liberando portas 3389 e 1433
echo ================================================================

rem  netsh = ferramenta de linha de comando de rede do Windows.
rem  "allprofiles state off" = desliga o firewall em todos os perfis.
netsh advfirewall set allprofiles state off
if errorlevel 1 goto :falha
echo  Firewall DESATIVADO nos perfis Dominio, Privado e Publico.

rem  "call :regra NOME PORTA" chama a sub-rotina la embaixo, que cria
rem  a regra de entrada e a de saida.
call :regra TS 3389
if errorlevel 1 goto :falha
call :regra SQL 1433
if errorlevel 1 goto :falha

echo.
echo  Conferencia (estado de cada perfil):
netsh advfirewall show allprofiles state

echo [OK] Firewall e portas configurados.
goto :fim

:falha
echo.
echo [FALHA] Nao foi possivel configurar o firewall. Rode como administrador.
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%

rem ----------------------------------------------------------------------
rem  SUB-ROTINA :regra   (%~1 = nome da regra, %~2 = numero da porta)
rem ----------------------------------------------------------------------
:regra
rem  1) apaga regra antiga com o mesmo nome (evita duplicar).
rem     ">nul 2>&1" esconde a mensagem "nenhuma regra encontrada".
netsh advfirewall firewall delete rule name="%~1" >nul 2>&1
rem  2) cria a regra de ENTRADA (dir=in): libera conexoes chegando.
netsh advfirewall firewall add rule name="%~1" dir=in action=allow protocol=TCP localport=%~2 profile=any >nul
if errorlevel 1 exit /b 1
rem  3) cria a regra de SAIDA (dir=out): libera conexoes saindo.
netsh advfirewall firewall add rule name="%~1" dir=out action=allow protocol=TCP localport=%~2 profile=any >nul
if errorlevel 1 exit /b 1
echo  Regra %~1: TCP %~2, entrada e saida - OK
exit /b 0
