# ==========================================================================
#  MIGRAR ARQUIVOS DO SERVIDOR ANTIGO  (chamado pelo 8_migrar_arquivos.bat)
# --------------------------------------------------------------------------
#  Copia com ROBOCOPY, da pasta cmsys do servidor antigo para a da maquina
#  nova (mesma rede):
#    XML de cupom ... cmsys\Aplicativo\CFe\RETORNO\XML
#    Notas .......... cmsys\NFe\<CNPJ>\XML  e  cmsys\NFe\<CNPJ>\PDF
#                     (todas as pastas de CNPJ que existirem)
#    Fotos .......... cmsys\Fotos (se tiver arquivos)
#    Logos .......... cmsys\Aplicativo\Logo.jpg/.jpeg/.png e Logo.gif.
#                     O que o cliente nao tiver vem de cmsys\Aplicativo\Logo
#                     (logos nativos do CMSYS).
#
#  Tudo vem das variaveis de ambiente (o Hub preenche):
#    MIG_ORIGEM, MIG_DESTINO   pastas cmsys de origem e destino
#    MIG_CUPOM, MIG_NOTAS, MIG_FOTOS, MIG_LOGOS   1 = copiar, 0 = pular
#    MIG_SIMULAR               1 = so mostra o que copiaria (robocopy /L)
#    MIG_USUARIO, MIG_SENHA    opcionais: login do servidor antigo
#
#  Seguro para rodar de novo: NUNCA apaga nada no destino (sem /MIR) e nao
#  troca arquivo do destino por um mais antigo (/XO). Arquivo igual e pulado.
#  Codigos de saida: 0 = ok, 1 = algo falhou.
# ==========================================================================
$ErrorActionPreference = 'Stop'

$origem  = $env:MIG_ORIGEM.TrimEnd('\')
$destino = $env:MIG_DESTINO.TrimEnd('\')
$simular = ($env:MIG_SIMULAR -eq '1')

$pastaLog = Join-Path $env:ProgramData 'CMSYS_Preparacao'
New-Item -ItemType Directory -Force -Path $pastaLog | Out-Null
$log = Join-Path $pastaLog 'migrar_arquivos.log'
if (Test-Path -LiteralPath $log) { Move-Item -LiteralPath $log -Destination "$log.anterior.log" -Force }

$script:erros = 0
function Diga([string]$t, [string]$cor = 'Gray') {
  Write-Host $t -ForegroundColor $cor
  Add-Content -LiteralPath $log -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $t) -Encoding UTF8
}
function Erro([string]$t) { $script:erros++; Diga "  [ERRO] $t" 'Red' }

Diga 'MIGRAR ARQUIVOS DO SERVIDOR ANTIGO' 'Cyan'
Diga "Origem : $origem"
Diga "Destino: $destino"
if ($simular) { Diga 'MODO SIMULACAO: nada sera copiado, so listado.' 'Yellow' }

# ---- 1) ACESSO AO SERVIDOR ANTIGO -----------------------------------------
# O Hub roda como administrador; unidades mapeadas (Z:, Y:...) do usuario nao
# aparecem nessa sessao. Por isso o caminho deve ser de rede: \\SERVIDOR\...
if (-not (Test-Path -LiteralPath $origem)) {
  if ($origem -match '^(\\\\[^\\]+\\[^\\]+)') {
    $compartilhamento = $Matches[1]
    if ($env:MIG_USUARIO) {
      Diga "  Conectando em $compartilhamento com o usuario $env:MIG_USUARIO..."
      # A senha vai pelo ambiente, nunca aparece na tela nem no log.
      & net.exe use $compartilhamento $env:MIG_SENHA "/user:$env:MIG_USUARIO" /persistent:no 2>&1 | Out-Null
    }
  }
}
if (-not (Test-Path -LiteralPath $origem)) {
  Erro "Nao consegui abrir a origem: $origem"
  Diga '  Confira o nome do servidor, se a pasta esta compartilhada e o usuario/senha.' 'Yellow'
  Diga '  Use caminho de rede (\\SERVIDOR\c$\cmsys), nao letra de unidade mapeada.' 'Yellow'
  exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $origem 'Aplicativo'))) {
  Diga '  AVISO: a origem nao tem a pasta Aplicativo. Ela e mesmo a pasta cmsys?' 'Yellow'
}
New-Item -ItemType Directory -Force -Path $destino | Out-Null

# ---- ROBOCOPY ---------------------------------------------------------------
#  /E        inclui subpastas (inclusive vazias)
#  /XO       nao troca arquivo do destino por um MAIS ANTIGO da origem
#  /COPY:DAT dados, atributos e datas   /DCOPY:T datas das pastas
#  /R:2 /W:5 tenta 2 vezes, esperando 5 s (rede instavel)
#  /MT:16    16 copias ao mesmo tempo (bem mais rapido com milhares de XML)
#  /NP /NFL /NDL  sem porcentagem e sem listar cada arquivo na tela
#  /L        (simulacao) so lista
#  /LOG+     acrescenta no log desta execucao   /TEE  tambem mostra na tela
#  Codigo do robocopy: 0 a 7 = ok (1 = copiou, 2/3 = havia extras/diferencas);
#  8 ou mais = falhou algum arquivo.
function Copiar([string]$rotulo, [string]$de, [string]$para, [string[]]$extra = @()) {
  if (-not (Test-Path -LiteralPath $de)) { Diga "  $rotulo : nao existe na origem, pulando." 'DarkGray'; return }
  $parametros = @($de, $para, '/E', '/XO', '/COPY:DAT', '/DCOPY:T', '/R:2', '/W:5', '/MT:16',
            '/NP', '/NFL', '/NDL', "/LOG+:$log", '/TEE') + $extra
  if ($simular) { $parametros += '/L' }
  Diga "  $rotulo" 'White'
  Diga "    $de  ->  $para" 'DarkGray'
  # /TEE mostra o resumo do robocopy nesta janela e grava no log.
  & robocopy.exe @parametros
  $rc = $LASTEXITCODE
  if ($rc -ge 8) { Erro "$rotulo : robocopy terminou com codigo $rc (veja o log)" }
  elseif ($rc -eq 0) { Diga '    nada novo para copiar.' 'Green' }
  else { Diga "    ok (codigo $rc)." 'Green' }
}

# ---- 2) XML DE CUPOM -------------------------------------------------------
if ($env:MIG_CUPOM -eq '1') {
  Diga ''; Diga 'XML de cupom (CFe)' 'Cyan'
  Copiar 'CFe\RETORNO\XML' (Join-Path $origem 'Aplicativo\CFe\RETORNO\XML') (Join-Path $destino 'Aplicativo\CFe\RETORNO\XML')
}

# ---- 3) NOTAS: XML e PDF de cada CNPJ ------------------------------------------
if ($env:MIG_NOTAS -eq '1') {
  Diga ''; Diga 'Notas (NFe): XML e PDF de cada CNPJ' 'Cyan'
  $nfe = Join-Path $origem 'NFe'
  $cnpjs = @(Get-ChildItem -LiteralPath $nfe -Directory -ErrorAction SilentlyContinue)
  if ($cnpjs.Count -eq 0) { Diga '  Nenhuma pasta de CNPJ em NFe na origem.' 'DarkGray' }
  foreach ($c in $cnpjs) {
    foreach ($sub in 'XML', 'PDF') {
      Copiar "NFe\$($c.Name)\$sub" (Join-Path $c.FullName $sub) (Join-Path $destino "NFe\$($c.Name)\$sub")
    }
  }
}

# ---- 4) FOTOS -----------------------------------------------------------------------
if ($env:MIG_FOTOS -eq '1') {
  Diga ''; Diga 'Fotos' 'Cyan'
  $fotos = Join-Path $origem 'Fotos'
  $tem = Test-Path -LiteralPath $fotos
  if ($tem) { $tem = [bool](Get-ChildItem -LiteralPath $fotos -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) }
  if ($tem) { Copiar 'Fotos' $fotos (Join-Path $destino 'Fotos') }
  else { Diga '  Sem fotos na origem, pulando.' 'DarkGray' }
}

# ---- 5) LOGOS --------------------------------------------------------------------------
# Dois logos em cmsys\Aplicativo: a imagem (Logo.jpg, .jpeg ou .png) e o Logo.gif.
# Para cada um: usa o do cliente (origem); se ele nao tiver, usa o nativo da
# pasta Aplicativo\Logo (da maquina nova; se nao houver, da antiga).
# O logo do cliente substitui o do destino. Se o destino tiver o logo em outra
# extensao (ex.: Logo.jpg e o cliente usa Logo.png), o antigo e renomeado para
# ".anterior", nunca apagado, para o CMSYS nao achar dois logos.
function AcharLogo([string]$pasta, [string[]]$extensoes, [bool]$soNomeLogo) {
  if (-not (Test-Path -LiteralPath $pasta)) { return $null }
  $arqs = Get-ChildItem -LiteralPath $pasta -File -ErrorAction SilentlyContinue |
          Where-Object { $extensoes -contains $_.Extension.ToLower() }
  if ($soNomeLogo) { $arqs = $arqs | Where-Object { $_.BaseName -ieq 'Logo' } }
  # Preferencia: arquivo chamado Logo; depois a ordem das extensoes.
  return $arqs | Sort-Object @{ e = { if ($_.BaseName -ieq 'Logo') { 0 } else { 1 } } },
                             @{ e = { [array]::IndexOf($extensoes, $_.Extension.ToLower()) } } |
                 Select-Object -First 1
}

function ColocarLogo([string]$tipo, [string[]]$extensoes) {
  $aplicDestino = Join-Path $destino 'Aplicativo'
  $fonte = AcharLogo (Join-Path $origem 'Aplicativo') $extensoes $true
  $deOnde = 'do cliente'
  if (-not $fonte) {
    $fonte = AcharLogo (Join-Path $aplicDestino 'Logo') $extensoes $false
    $deOnde = 'nativo (Aplicativo\Logo da maquina nova)'
  }
  if (-not $fonte) {
    $fonte = AcharLogo (Join-Path $origem 'Aplicativo\Logo') $extensoes $false
    $deOnde = 'nativo (Aplicativo\Logo do servidor antigo)'
  }
  if (-not $fonte) { Erro "Logo $tipo nao encontrado no cliente nem em Aplicativo\Logo"; return }

  $alvo = Join-Path $aplicDestino ('Logo' + $fonte.Extension.ToLower())
  Diga "  Logo $tipo $deOnde : $($fonte.Name) -> Aplicativo\$(Split-Path $alvo -Leaf)"
  if ($simular) { return }
  New-Item -ItemType Directory -Force -Path $aplicDestino | Out-Null
  # Outras extensoes do mesmo logo no destino viram ".anterior".
  foreach ($ext in $extensoes) {
    $outro = Join-Path $aplicDestino "Logo$ext"
    if ($ext -ne $fonte.Extension.ToLower() -and (Test-Path -LiteralPath $outro)) {
      Move-Item -LiteralPath $outro -Destination "$outro.anterior" -Force
      Diga "    Aplicativo\Logo$ext renomeado para Logo$ext.anterior" 'Yellow'
    }
  }
  Copy-Item -LiteralPath $fonte.FullName -Destination $alvo -Force
}

if ($env:MIG_LOGOS -eq '1') {
  Diga ''; Diga 'Logos (Aplicativo)' 'Cyan'
  try { ColocarLogo 'imagem' @('.jpg', '.jpeg', '.png') } catch { Erro $_.Exception.Message }
  try { ColocarLogo 'gif' @('.gif') } catch { Erro $_.Exception.Message }
}

# ---- FIM ---------------------------------------------------------------------------
Diga ''
if ($script:erros -gt 0) { Diga "Terminou com $($script:erros) erro(s). Log: $log" 'Red'; exit 1 }
if ($simular) { Diga 'Simulacao concluida. Rode de novo sem simular para copiar.' 'Green' }
else { Diga "Migracao concluida. Log: $log" 'Green' }
exit 0
