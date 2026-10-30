@echo off
rem ======================================================================
rem  GERAR O .EXE  (rode no seu PC de desenvolvimento, com Python instalado)
rem ----------------------------------------------------------------------
rem  Resultado: dist\HubCMSYS.exe  (arquivo unico, nao precisa de Python
rem  no PC do cliente).
rem    --onefile    junta tudo em um unico .exe
rem    --noconsole  nao abre janela preta junto com a janela do hub
rem    --name       nome do .exe
rem    --add-data   embute a pasta "scripts" dentro do .exe
rem  Dica: se existir uma pasta "scripts" AO LADO do .exe, ela tem
rem  prioridade sobre a embutida (da para ajustar um .bat sem recompilar).
rem ======================================================================
cd /d "%~dp0"
python -m pip install --upgrade pyinstaller
python -m PyInstaller --noconfirm --onefile --noconsole --name HubCMSYS --add-data "scripts;scripts" hub.py
echo.
echo Pronto: dist\HubCMSYS.exe
pause
