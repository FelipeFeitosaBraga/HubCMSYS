@echo off
rem ======================================================================
rem  BOTAO 1 - REDE COMO PRIVADA
rem ----------------------------------------------------------------------
rem  O que faz : troca toda conexao de rede marcada como "Publica" para
rem              "Privada". Em rede Publica o Windows bloqueia o
rem              compartilhamento e a descoberta de rede; em Privada nao.
rem  Seguro    : redes de DOMINIO nao sao mexidas, e redes que ja estao
rem              Privadas ficam como estao (pode rodar varias vezes).
rem  Parametro : /auto  -> nao pede "pressione uma tecla" no final
rem                        (usado pelo botao EXECUTAR TUDO).
rem  Obs.      : este arquivo nao tem acentos de proposito, para o CMD
rem              nao mostrar caracteres estranhos em nenhum Windows.
rem ======================================================================
title Preparar PC CMSYS - 1) Rede privada

rem  RC = "return code" (codigo de retorno). 0 = deu certo, 1 = deu erro.
set "RC=0"

echo.
echo ================================================================
echo  REDE: colocando as conexoes como PRIVADA
echo ================================================================

rem  PowerShell faz o trabalho pesado:
rem   - Get-NetConnectionProfile : lista as redes conectadas e a categoria.
rem   - Where-Object             : filtra so as que estao como "Public".
rem   - Set-NetConnectionProfile : muda a categoria para "Private".
rem   - -ErrorAction Stop        : se algo falhar, o PowerShell devolve
rem                                erro (codigo 1) em vez de ignorar.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'Public' } | ForEach-Object { Write-Host ('  Alterando para Privada: ' + $_.Name); Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop }"
if errorlevel 1 goto :falha

echo.
echo  Situacao atual das redes:
rem  Mostra uma tabelinha para conferir o resultado com os olhos.
powershell -NoProfile -Command "Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory -AutoSize"

echo [OK] Rede configurada.
goto :fim

:falha
echo.
echo [FALHA] Nao foi possivel mudar a rede para Privada.
echo         Confira se o PC esta conectado a uma rede e se o CMD esta como administrador.
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
