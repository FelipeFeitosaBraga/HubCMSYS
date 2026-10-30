@echo off
rem ======================================================================
rem  BOTAO 4 - WINDOWS UPDATE
rem ----------------------------------------------------------------------
rem  O que faz : chama o windows_update.ps1 (na mesma pasta), que procura,
rem              baixa e instala as atualizacoes do Windows.
rem  Se o Windows pedir reinicio, o .ps1 devolve o codigo 3010 (codigo
rem  padrao do Windows para "reinicio necessario") e aqui perguntamos se
rem  o tecnico quer reiniciar agora.
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final.
rem ======================================================================
title Preparar PC CMSYS - 4) Windows Update
set "RC=0"

rem  -File executa o script .ps1. %~dp0 = pasta onde ESTE .bat esta.
rem  -ExecutionPolicy Bypass libera a execucao so nesta chamada.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_update.ps1"
set "PS_RC=%errorlevel%"

if "%PS_RC%"=="3010" goto :reiniciar
if not "%PS_RC%"=="0" set "RC=1"
goto :fim

:reiniciar
echo.
echo  O Windows precisa REINICIAR para concluir as atualizacoes.
echo  Depois do reinicio, rode este botao de novo ate nao restar nada.
set "R="
set /p "R=Reiniciar agora? (S/N) - a conexao do TeamViewer sera interrompida: "
if /i "%R%"=="S" shutdown /r /t 15 /c "Reinicio para concluir as atualizacoes do Windows (CMSYS)"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
