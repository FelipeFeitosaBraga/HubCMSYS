@echo off
setlocal enableextensions
rem ======================================================================
rem  BOTAO 8 - MIGRAR ARQUIVOS DO SERVIDOR ANTIGO (robocopy)
rem ----------------------------------------------------------------------
rem  Para cliente que ja tem servidor: depois de preparar a maquina nova,
rem  traz os documentos locais do cmsys antigo pela rede.
rem  Origem, destino e o que copiar vem do Hub (variaveis MIG_*).
rem  Tudo no migrar_arquivos.ps1, ao lado deste arquivo.
rem  Nao apaga nada no destino e pode rodar de novo (so copia o que falta
rem  ou mudou). Log: C:\ProgramData\CMSYS_Preparacao\migrar_arquivos.log
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final.
rem ======================================================================
title Preparar PC CMSYS - 8) Migrar arquivos do servidor antigo
set "RC=0"

if not defined MIG_ORIGEM goto :sem_dados
if not defined MIG_DESTINO goto :sem_dados

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0migrar_arquivos.ps1"
if errorlevel 1 set "RC=1"
goto :fim

:sem_dados
echo.
echo [FALHA] Origem e destino nao informados. Use o botao 8 pelo Hub.
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
