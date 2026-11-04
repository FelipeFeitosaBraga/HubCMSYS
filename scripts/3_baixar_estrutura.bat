@echo off
setlocal EnableExtensions
rem ======================================================================
rem BOTAO 3 - BAIXAR E INSTALAR A ESTRUTURA DO CMSYS
rem
rem ETAPAS:
rem 1. Pergunta a unidade de destino (Enter usa C:).
rem 2. Procura cmsys.zip ao lado do Hub ou deste BAT (modo offline).
rem    Se nao encontrar, baixa o arquivo da Release v1.0 do GitHub.
rem 3. Confere o SHA-256 do arquivo para impedir pacote incorreto.
rem 4. Testa e extrai o ZIP em uma pasta temporaria.
rem 5. Copia o conteudo para \cmsys usando ROBOCOPY.
rem
rem SEGURANCA:
rem - Nao usa /MIR nem /PURGE: nao apaga arquivos do destino.
rem - Por padrao, nao substitui arquivos que ja existem.
rem - O ZIP local tambem precisa ter o mesmo SHA-256 da Release.
rem - Se publicar outro ZIP, atualize URL_ZIP e SHA256_ESPERADO.
rem ======================================================================

title Preparar PC CMSYS - 3) Baixar estrutura
set "RC=0"

rem ------------------------- CONFIGURACOES ------------------------------
rem Link direto do arquivo cmsys.zip anexado a Release v1.0.
set "URL_ZIP=https://github.com/FelipeFeitosaBraga/download-cmsys/releases/download/v1.0/cmsys.zip"

rem SHA-256 exibido pelo GitHub para o arquivo cmsys.zip da Release.
set "SHA256_ESPERADO=7a3cd359f18e4c9dd0df31a41c9738b62feb1b10d0288162b4452113212ab30c"

rem Espaco livre minimo recomendado. Ajuste se o pacote exigir mais.
set "ESPACO_MIN_GB=8"

rem 0 = nao sobrescreve arquivos existentes (recomendado).
rem 1 = permite sobrescrever arquivos existentes.
set "SOBRESCREVER=0"
rem ----------------------------------------------------------------------

echo.
echo ================================================================
echo ESTRUTURA CMSYS: pastas + arquivos
echo ================================================================

rem 1. Perguntar a unidade de destino.
set "DISCO=C"
set /p "DISCO=Em qual disco criar a pasta cmsys? [Enter = C]: "
if not defined DISCO set "DISCO=C"
set "DISCO=%DISCO:~0,1%"

rem Confirmar se a unidade informada existe.
if not exist "%DISCO%:\" goto :disco_invalido

set "DESTINO=%DISCO%:\cmsys"
set "TEMPDIR=%DISCO%:\_cmsys_download"
set "ZIP=%TEMPDIR%\cmsys.zip"
set "EXTRAIDO=%TEMPDIR%\extraido"

echo.
echo Destino: %DESTINO%

rem 2. Consultar espaco livre com PowerShell.
set "LIVRE_GB="
for /f %%G in ('powershell -NoProfile -Command "(Get-PSDrive -Name '%DISCO%').Free / 1GB -as [int]" 2^>nul') do set "LIVRE_GB=%%G"

if defined LIVRE_GB (
    echo Espaco livre em %DISCO%: %LIVRE_GB% GB
    if %LIVRE_GB% LSS %ESPACO_MIN_GB% (
        echo.
        echo ATENCAO: recomendado ter pelo menos %ESPACO_MIN_GB% GB livres.
        choice /c SN /n /m "Continuar mesmo assim? [S/N]: "
        if errorlevel 2 goto :cancelado
    )
) else (
    echo Nao foi possivel consultar o espaco livre. Continuando com cautela.
)

rem 3. Procurar ZIP local. HUB_DIR pode ser definida pelo hub.py.
set "ZIP_LOCAL="
if defined HUB_DIR if exist "%HUB_DIR%\cmsys.zip" set "ZIP_LOCAL=%HUB_DIR%\cmsys.zip"
if not defined ZIP_LOCAL if exist "%~dp0cmsys.zip" set "ZIP_LOCAL=%~dp0cmsys.zip"

if not exist "%TEMPDIR%" mkdir "%TEMPDIR%"

if defined ZIP_LOCAL goto :usar_local

rem 4. Baixar o arquivo do GitHub. -C - tenta retomar download parcial.
echo.
echo Baixando cmsys.zip da Release do GitHub...
echo Tamanho aproximado: 1,48 GB. O download pode demorar.
echo Se a conexao cair, execute novamente para tentar continuar.
echo.

"%SystemRoot%\System32\curl.exe" -L --fail --retry 10 --retry-delay 5 -C - -o "%ZIP%" "%URL_ZIP%"
set "CURL_RC=%ERRORLEVEL%"
if not "%CURL_RC%"=="0" (
    echo.
    echo [FALHA] O download terminou com codigo %CURL_RC%.
    echo Confira a internet e o endereco da Release.
    set "RC=1"
    goto :fim
)
goto :validar_hash

:usar_local
echo.
echo Usando o cmsys.zip local:
echo %ZIP_LOCAL%
set "ZIP=%ZIP_LOCAL%"

:validar_hash
rem 5. Calcular SHA-256 e comparar com o valor da Release.
echo.
echo Conferindo SHA-256 do arquivo...
set "HASH_ATUAL="
for /f %%H in ('powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%ZIP%' -Algorithm SHA256).Hash.ToLower()" 2^>nul') do set "HASH_ATUAL=%%H"

if not defined HASH_ATUAL goto :hash_falhou
if /i not "%HASH_ATUAL%"=="%SHA256_ESPERADO%" goto :hash_diferente
echo SHA-256 correto.

rem 6. Testar se o ZIP pode ser lido antes de extrair.
echo.
echo Verificando a integridade do ZIP...
"%SystemRoot%\System32\tar.exe" -tf "%ZIP%" >nul 2>&1
if errorlevel 1 goto :zip_invalido
echo Arquivo ZIP integro.

rem 7. Extrair para uma pasta temporaria.
echo.
echo Extraindo o pacote. Aguarde...
if exist "%EXTRAIDO%" rd /s /q "%EXTRAIDO%"
mkdir "%EXTRAIDO%"
"%SystemRoot%\System32\tar.exe" -xf "%ZIP%" -C "%EXTRAIDO%"
if errorlevel 1 goto :falha_extrair

rem 8. Descobrir se os arquivos estao dentro de uma unica pasta raiz.
set "ORIGEM=%EXTRAIDO%"
set "N_PASTAS=0"
set "UNICA="
set "TEM_ARQUIVO="

for /d %%D in ("%EXTRAIDO%\*") do (
    set /a N_PASTAS+=1
    set "UNICA=%%~fD"
)
for %%F in ("%EXTRAIDO%\*") do (
    if not exist "%%~fF\" set "TEM_ARQUIVO=1"
)

if "%N_PASTAS%"=="1" if not defined TEM_ARQUIVO set "ORIGEM=%UNICA%"

rem 9. Conferir se existe pelo menos uma pasta esperada do CMSYS.
rem Ajuste os nomes abaixo se o ZIP usar outra organizacao.
set "ACHOU="
for %%E in (Aplicativo Dados NFe Suporte) do (
    if exist "%ORIGEM%\%%E" set "ACHOU=1"
)

if not defined ACHOU goto :falha_estrutura

rem 10. Copiar para o destino. Nao apagar nem espelhar pastas.
echo.
echo Copiando arquivos para %DESTINO%...
echo Arquivos existentes nao serao sobrescritos.

set "OPC_COPIA=/E /R:1 /W:2 /NP /MT:8"
if "%SOBRESCREVER%"=="0" set "OPC_COPIA=%OPC_COPIA% /XC /XN /XO"

robocopy "%ORIGEM%" "%DESTINO%" %OPC_COPIA%
if errorlevel 8 goto :falha_copia

rem 11. Limpar temporarios. O ZIP local nunca e apagado.
echo.
echo Limpando arquivos temporarios...
if exist "%EXTRAIDO%" rd /s /q "%EXTRAIDO%"
if not defined ZIP_LOCAL if exist "%ZIP%" del /q "%ZIP%"
rd "%TEMPDIR%" 2>nul

rem Guarda o disco escolhido para os botoes 4, 5 e 6 acharem a pasta cmsys
rem mesmo fora do C:. O ">" vem antes do echo para nao gravar espaco extra.
if not exist "%ProgramData%\CMSYS_Preparacao" mkdir "%ProgramData%\CMSYS_Preparacao"
>"%ProgramData%\CMSYS_Preparacao\disco_cmsys.txt" echo %DISCO%

echo.
echo [OK] Estrutura do CMSYS pronta em %DESTINO%.
goto :fim

:disco_invalido
echo.
echo [FALHA] A unidade informada nao existe: %DISCO%:
set "RC=1"
goto :fim

:hash_falhou
echo.
echo [FALHA] Nao foi possivel calcular o SHA-256 do arquivo.
echo Verifique o ZIP e se o PowerShell esta disponivel.
set "RC=1"
goto :fim

:hash_diferente
echo.
echo [FALHA] O arquivo nao corresponde ao cmsys.zip da Release.
echo SHA-256 esperado: %SHA256_ESPERADO%
echo SHA-256 recebido: %HASH_ATUAL%
echo O arquivo nao sera extraido.
if not defined ZIP_LOCAL del /q "%ZIP%" 2>nul
set "RC=1"
goto :fim

:zip_invalido
echo.
echo [FALHA] O arquivo ZIP nao pode ser lido.
if not defined ZIP_LOCAL del /q "%ZIP%" 2>nul
set "RC=1"
goto :fim

:falha_extrair
echo.
echo [FALHA] Nao foi possivel extrair o ZIP.
echo Verifique o espaco livre e tente novamente.
set "RC=1"
goto :fim

:falha_estrutura
echo.
echo [FALHA] Nao encontrei Aplicativo, Dados, NFe ou Suporte na raiz extraida.
echo O ZIP pode ter outra organizacao. Nenhum arquivo foi copiado.
if exist "%EXTRAIDO%" rd /s /q "%EXTRAIDO%"
set "RC=1"
goto :fim

:falha_copia
echo.
echo [FALHA] O ROBOCOPY informou erro durante a copia.
echo Verifique permissoes e espaco livre no destino.
set "RC=1"
goto :fim

:cancelado
echo.
echo Operacao cancelada pelo tecnico.
set "RC=1"

:fim
echo.
if /i not "%~1"=="/auto" pause
exit /b %RC%
