# ==========================================================================
#  INSTALAR O CMSYS NA ESTACAO  (chamado pelo 6_instalar_cmsys.bat)
# --------------------------------------------------------------------------
#  Parametro:
#    -Suporte   pasta X:\cmsys\Suporte (onde estao as pastas dos instaladores)
#  As subpastas vem do config_hub.bat pelas variaveis de ambiente:
#    PASTA_REPORTVIEWER, PASTA_CRYSTAL, PASTA_RELATORIOS, PASTA_BOLETO,
#    PASTA_CMSYS e DESTINO_BOLETO.
#  Codigos de saida: 0 = ok, 3010 = ok mas pede reinicio, 1 = algo falhou.
#
#  Regra para NAO duplicar nada (pode rodar quantas vezes quiser):
#    - programas ja instalados sao pulados (exceto o CMSYS Relatorios,
#      que e sempre desinstalado e instalado de novo, como pede o manual);
#    - componentes: copia so se o arquivo nao existe ou se o do pacote e
#      mais NOVO; o mesmo nome e sobrescrito no mesmo lugar, nunca copiado
#      com outro nome;
#    - arquivos do proprio Windows (OLEAUT32, MSVCRT...) nunca sao trocados;
#    - um unico log e uma unica pasta temporaria, limpos a cada execucao.
# ==========================================================================
param(
  [Parameter(Mandatory = $true)][string]$Suporte
)
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------ LOG
$pastaLog = Join-Path $env:ProgramData 'CMSYS_Preparacao'
New-Item -ItemType Directory -Force -Path $pastaLog | Out-Null
$log = Join-Path $pastaLog 'instalar_cmsys.log'
# Guarda so a execucao anterior (.anterior.log) e comeca um log novo.
if (Test-Path -LiteralPath $log) { Move-Item -LiteralPath $log -Destination "$log.anterior.log" -Force }

function Log([string]$texto, [string]$cor = 'Gray') {
  Write-Host $texto -ForegroundColor $cor
  Add-Content -LiteralPath $log -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $texto) -Encoding UTF8
}

$script:erros = 0
$script:reiniciar = $false
function Erro([string]$texto) { $script:erros++; Log "  [ERRO] $texto" 'Red' }

# Pasta de cada instalador (valor do config_hub.bat, ou o padrao).
function Pasta([string]$variavel, [string]$padrao) {
  $v = [Environment]::GetEnvironmentVariable($variavel)
  if (-not $v) { $v = $padrao }
  return Join-Path $Suporte $v
}

# Primeiro arquivo que bate com um dos filtros (o mais recente).
function Achar([string]$pasta, [string[]]$filtros) {
  if (-not (Test-Path -LiteralPath $pasta)) { return $null }
  foreach ($f in $filtros) {
    $a = Get-ChildItem -LiteralPath $pasta -Filter $f -File -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($a) { return $a.FullName }
  }
  return $null
}

# Programas instalados (Painel de Controle), nas visoes 64 e 32 bits.
function Instalados([string]$padrao) {
  $lista = @()
  foreach ($visao in 'Registry64', 'Registry32') {
    try { $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $visao) } catch { continue }
    $k = $base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
    if (-not $k) { continue }
    foreach ($n in $k.GetSubKeyNames()) {
      $s = $k.OpenSubKey($n)
      if (-not $s) { continue }
      $nome = $s.GetValue('DisplayName')
      if ($nome -and $nome -like $padrao) {
        $lista += [pscustomobject]@{ Nome = $nome; Versao = $s.GetValue('DisplayVersion'); Codigo = $n }
      }
    }
  }
  return @($lista | Sort-Object Codigo -Unique)
}

# Le uma propriedade de dentro do .msi (ex.: ProductCode, ProductVersion).
function PropMsi([string]$msi, [string]$prop) {
  $wi = New-Object -ComObject WindowsInstaller.Installer
  $db = $wi.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $wi, @($msi, 0))
  $vw = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT Value FROM Property WHERE Property='$prop'"))
  $vw.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $vw, $null) | Out-Null
  $rec = $vw.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $vw, $null)
  $valor = $null
  if ($rec) { $valor = $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, 1) }
  $vw.GetType().InvokeMember('Close', 'InvokeMethod', $null, $vw, $null) | Out-Null
  [Runtime.InteropServices.Marshal]::ReleaseComObject($db) | Out-Null
  return $valor
}

# Roda um programa, espera terminar e devolve o codigo de saida.
function Rodar([string]$exe, [string]$argumentos) {
  $p = Start-Process -FilePath $exe -ArgumentList $argumentos -Wait -PassThru
  return $p.ExitCode
}

# 0 = ok; 3010/1641 = ok, pede reinicio. Qualquer outro = erro.
function ConferirCodigo([int]$codigo, [string]$oque) {
  if ($codigo -eq 0) { Log "  $oque : OK" 'Green'; return $true }
  if ($codigo -eq 3010 -or $codigo -eq 1641) { $script:reiniciar = $true; Log "  $oque : OK (pede reinicio)" 'Yellow'; return $true }
  Erro "$oque terminou com codigo $codigo"
  return $false
}

function InstalarMsi([string]$msi, [string]$etapa, [string]$extra = '') {
  $logMsi = Join-Path $pastaLog "msi_$etapa.log"   # um por etapa, sobrescrito
  $c = Rodar 'msiexec.exe' "/i `"$msi`" $extra /qn /norestart /l*v `"$logMsi`""
  return (ConferirCodigo $c "Instalacao ($([IO.Path]::GetFileName($msi)))")
}

function Desinstalar($programa) {
  if ($programa.Codigo -notmatch '^\{[0-9A-Fa-f-]{36}\}$') {
    Erro "Nao sei desinstalar '$($programa.Nome)' sozinho (nao e MSI). Desinstale pelo Painel de Controle."
    return
  }
  Log "  Desinstalando $($programa.Nome) $($programa.Versao)..."
  $c = Rodar 'msiexec.exe' "/x $($programa.Codigo) /qn /norestart"
  # 1605 = ja nao estava instalado: tudo bem.
  if ($c -eq 1605) { $c = 0 }
  ConferirCodigo $c "Desinstalacao de $($programa.Nome)" | Out-Null
}

Log "Instalar CMSYS na estacao - $env:COMPUTERNAME" 'Cyan'
Log "Pasta Suporte: $Suporte"

# ==========================================================================
#  1) MICROSOFT REPORTVIEWER 2010
# ==========================================================================
Log ''
Log '1) Microsoft ReportViewer 2010' 'Cyan'
try {
  $ja = Instalados 'Microsoft Report Viewer*2010*'
  if ($ja.Count -gt 0) {
    Log "  Ja instalado ($($ja[0].Nome)). Pulando." 'Green'
  } else {
    $exe = Achar (Pasta 'PASTA_REPORTVIEWER' 'Setup Report Viewer') @('ReportViewer*.exe', '*.exe')
    if (-not $exe) { Erro 'ReportViewer.exe nao encontrado.' }
    else {
      # /q = silencioso   /norestart = nao reinicia sozinho
      ConferirCodigo (Rodar $exe '/q /norestart') 'ReportViewer 2010' | Out-Null
    }
  }
} catch { Erro $_.Exception.Message }

# ==========================================================================
#  2) CRYSTAL REPORTS RUNTIME (VS 2008)
# ==========================================================================
Log ''
Log '2) Crystal Reports Runtime 2008' 'Cyan'
try {
  $msi = Achar (Pasta 'PASTA_CRYSTAL' 'Setup Crystal') @('CRRedist*x86*.msi', 'CRRedist*.msi', '*.msi')
  if (-not $msi) { Erro 'Instalador do Crystal (.msi) nao encontrado.' }
  else {
    $codigo = PropMsi $msi 'ProductCode'
    $ja = @(Instalados '*' | Where-Object { $_.Codigo -eq $codigo })
    if ($ja.Count -gt 0) { Log "  Ja instalado ($($ja[0].Nome)). Pulando." 'Green' }
    else { InstalarMsi $msi 'crystal' | Out-Null }
  }
} catch { Erro $_.Exception.Message }

# ==========================================================================
#  3) CMSYS RELATORIOS  (remove TODAS as versoes antigas antes)
# ==========================================================================
Log ''
Log '3) CMSYS Relatorios (Setup CMSYS 2010 - depois de 295)' 'Cyan'
try {
  $msi = Achar (Pasta 'PASTA_RELATORIOS' 'Setup CMSYS 2010 - depois de 295') @('cmsysRelatorios*.msi', '*.msi')
  if (-not $msi) { Erro 'cmsysRelatoriosSetup.msi nao encontrado.' }
  else {
    Log "  Instalador: $([IO.Path]::GetFileName($msi)) (versao $(PropMsi $msi 'ProductVersion'))"
    $antigos = @(Instalados '*CMSYS*Relat*')
    if ($antigos.Count -eq 0) { Log '  Nenhuma versao anterior instalada.' }
    foreach ($a in $antigos) { Desinstalar $a }
    InstalarMsi $msi 'relatorios' | Out-Null
  }
} catch { Erro $_.Exception.Message }

# ==========================================================================
#  4) CMSYS BOLETO  (sempre em C:\CmsysBoleto)
# ==========================================================================
Log ''
Log '4) CMSYS Boleto' 'Cyan'
try {
  $destino = $env:DESTINO_BOLETO
  if (-not $destino) { $destino = 'C:\CmsysBoleto' }
  New-Item -ItemType Directory -Force -Path $destino | Out-Null
  Log "  Pasta: $destino"
  $msi = Achar (Pasta 'PASTA_BOLETO' 'cmsysBoleto') @('cmsysBoleto*.msi', '*.msi')
  if (-not $msi) { Erro 'cmsysBoleto.msi nao encontrado.' }
  else {
    $codigo = PropMsi $msi 'ProductCode'
    $instalados = @(Instalados '*CMSYS*Boleto*')
    $mesma = @($instalados | Where-Object { $_.Codigo -eq $codigo })
    $naPasta = Test-Path -LiteralPath (Join-Path $destino 'cmsysBoleto.dll')
    if ($mesma.Count -gt 0 -and $naPasta) {
      Log "  Mesma versao ja instalada em $destino. Pulando." 'Green'
    } else {
      # Outra versao, ou instalada fora de C:\CmsysBoleto: remove e instala de novo.
      foreach ($a in $instalados) { Desinstalar $a }
      InstalarMsi $msi 'boleto' "TARGETDIR=`"$destino`"" | Out-Null
    }
  }
} catch { Erro $_.Exception.Message }

# ==========================================================================
#  5) COMPONENTES DO CMSYS  (mesma lista do PrepararEstacaoCmsys)
# ==========================================================================
#  NOME | DESTINO | ACAO
#    SYS     = pasta de sistema 32 bits (SysWOW64 no Windows 64 bits)
#    CRYSTAL = Common Files\Crystal Decisions\2.0\bin
#    COPIA   = so copia;  REG = copia e registra (regsvr32);  TLB = registra type library
$manifesto = @'
VB6STKIT.DLL|SYS|COPIA
COMCAT.DLL|SYS|REG
OLEPRO32.DLL|SYS|REG
STDOLE2.TLB|SYS|TLB
ASYCFILT.DLL|SYS|COPIA
OLEAUT32.DLL|SYS|REG
MSCOMM32.OCX|SYS|REG
comdlg32.ocx|SYS|REG
TABCTL32.OCX|SYS|REG
MSCOMCT2.OCX|SYS|REG
MSCOMCTL.OCX|SYS|REG
mfc42.dll|SYS|REG
MSVCRT.DLL|SYS|COPIA
SPR32X60.ocx|SYS|REG
MSFLXGRD.OCX|SYS|REG
comBoleto.tlb|SYS|TLB
msstdfmt.dll|SYS|REG
scrrun.dll|SYS|REG
keycode.dll|CRYSTAL|REG
u2dapp.dll|CRYSTAL|COPIA
u2dpost.dll|CRYSTAL|COPIA
u2ddisk.dll|CRYSTAL|COPIA
u2fxml.dll|CRYSTAL|COPIA
u2ftext.dll|CRYSTAL|COPIA
u2fsepv.dll|CRYSTAL|COPIA
u2fcr.dll|CRYSTAL|COPIA
crtslv.dll|CRYSTAL|REG
ExportModeller.dll|CRYSTAL|REG
crxf_xls.dll|CRYSTAL|COPIA
crxf_wordw.dll|CRYSTAL|COPIA
crxf_rtf.dll|CRYSTAL|COPIA
crxf_pdf.dll|CRYSTAL|COPIA
sacommoncontrols.dll|CRYSTAL|REG
filedialog.dll|CRYSTAL|REG
crdb_dictionary.dll|CRYSTAL|COPIA
p2ixbse.dll|CRYSTAL|COPIA
CRAnalyzer.dll|CRYSTAL|REG
sscdlg.dll|CRYSTAL|COPIA
sscrc.dll|CRYSTAL|COPIA
sscsdk80.dll|CRYSTAL|COPIA
exlate32.dll|CRYSTAL|COPIA
querybuilder.dll|CRYSTAL|COPIA
crdb_odbc.dll|CRYSTAL|COPIA
crdb_dao.dll|CRYSTAL|COPIA
crdb_ado.dll|CRYSTAL|COPIA
crqe.dll|CRYSTAL|REG
Implode.dll|CRYSTAL|COPIA
u25samp1.dll|CRYSTAL|COPIA
u25dts.dll|CRYSTAL|COPIA
u252000.dll|CRYSTAL|COPIA
u2lfinra.dll|CRYSTAL|COPIA
u2lexch.dll|CRYSTAL|COPIA
u2ldts.dll|CRYSTAL|COPIA
u2lcom.dll|CRYSTAL|COPIA
u2l2000.dll|CRYSTAL|COPIA
ufmanager.dll|CRYSTAL|COPIA
crtowords_en.dll|CRYSTAL|COPIA
UNICOWS.DLL|CRYSTAL|COPIA
craxddrt9.dll|CRYSTAL|REG
craxdrt9.dll|CRYSTAL|REG
crviewer9.dll|CRYSTAL|REG
SWECF.DLL|SYS|COPIA
'@

# Arquivos do proprio Windows: se ja existem, nao copia nem registra.
# O Windows 10/11 traz versoes mais novas e protegidas; trocar quebra o sistema.
$doWindows = @('COMCAT.DLL', 'OLEPRO32.DLL', 'STDOLE2.TLB', 'ASYCFILT.DLL', 'OLEAUT32.DLL',
               'MSVCRT.DLL', 'MFC42.DLL', 'SCRRUN.DLL')

function Versao([string]$arquivo) {
  try {
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($arquivo)
    if ($v.FileVersion) { return New-Object Version($v.FileMajorPart, $v.FileMinorPart, $v.FileBuildPart, $v.FilePrivatePart) }
  } catch {}
  return $null
}

# Devolve o motivo para copiar, ou $null se o arquivo atual ja serve.
function MotivoCopia([string]$origem, [string]$destino) {
  if (-not (Test-Path -LiteralPath $destino)) { return 'nao existia' }
  $vo = Versao $origem; $vd = Versao $destino
  if ($vo -and $vd) {
    if ($vo -gt $vd) { return "versao $vd -> $vo" }
    return $null
  }
  # Sem numero de versao (ex.: .tlb): compara a data do arquivo.
  if ((Get-Item -LiteralPath $origem).LastWriteTimeUtc -gt (Get-Item -LiteralPath $destino).LastWriteTimeUtc) { return 'arquivo mais novo' }
  return $null
}

Log ''
Log '5) Componentes do CMSYS (CMSYS.CAB)' 'Cyan'
$temp = Join-Path $env:TEMP 'cmsys-componentes'   # sempre a MESMA pasta
try {
  $cab = Achar (Pasta 'PASTA_CMSYS' 'Setup CMSYS\winGeral') @('CMSYS.CAB')
  if (-not $cab) { throw 'CMSYS.CAB nao encontrado.' }
  Log "  Pacote: $cab"

  # Pastas de destino (32 bits). SystemX86 = SysWOW64 no Windows 64 bits.
  $sys = [Environment]::GetFolderPath('SystemX86')
  $cf = ${env:CommonProgramFiles(x86)}
  if (-not $cf) { $cf = $env:CommonProgramFiles }
  $crystal = Join-Path $cf 'Crystal Decisions\2.0\bin'
  New-Item -ItemType Directory -Force -Path $crystal | Out-Null
  $regsvr = Join-Path $sys 'regsvr32.exe'

  # Extrai o CAB numa pasta temporaria limpa.
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  & (Join-Path $env:SystemRoot 'System32\expand.exe') -F:* "$cab" "$temp" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "expand.exe falhou (codigo $LASTEXITCODE)." }

  # Registro de type library (.tlb) pela API do Windows.
  Add-Type -Namespace CmsysHub -Name Ole -MemberDefinition @'
[DllImport("oleaut32.dll", CharSet = CharSet.Unicode)]
public static extern int LoadTypeLibEx(string arquivo, int regkind, out IntPtr tlib);
'@

  $copiados = 0; $iguais = 0; $registrados = 0
  foreach ($linha in ($manifesto -split "`r?`n")) {
    if (-not $linha.Trim()) { continue }
    $nome, $onde, $acao = $linha.Split('|')
    $origem = Join-Path $temp $nome
    $pastaDestino = if ($onde -eq 'CRYSTAL') { $crystal } else { $sys }
    $destino = Join-Path $pastaDestino $nome

    if (-not (Test-Path -LiteralPath $origem)) { Erro "$nome ausente no CMSYS.CAB"; continue }

    $existe = Test-Path -LiteralPath $destino
    if ($existe -and ($doWindows -contains $nome.ToUpper())) { $iguais++; continue }   # do Windows: nao mexe

    # ---- copiar (sobrescreve no mesmo lugar, so se for mais novo) ----
    $motivo = MotivoCopia $origem $destino
    if ($motivo) {
      try {
        Copy-Item -LiteralPath $origem -Destination $destino -Force
        $copiados++
        Log "  copiado: $nome ($motivo)"
      } catch {
        if ($existe) { Log "  mantido: $nome (em uso ou protegido; fica o atual)" 'Yellow' }
        else { Erro "nao consegui copiar $nome : $($_.Exception.Message)"; continue }
      }
    } else { $iguais++ }

    # ---- registrar (registrar de novo nao duplica nada) ----
    if ($acao -eq 'REG') {
      $c = Rodar $regsvr "/s `"$destino`""
      if ($c -eq 0) { $registrados++ } else { Erro "regsvr32 $nome devolveu $c" }
    } elseif ($acao -eq 'TLB') {
      $p = [IntPtr]::Zero
      $hr = [CmsysHub.Ole]::LoadTypeLibEx($destino, 1, [ref]$p)   # 1 = REGKIND_REGISTER
      if ($p -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::Release($p) | Out-Null }
      if ($hr -eq 0) { $registrados++ } else { Erro ("registro de {0} devolveu 0x{1:X8}" -f $nome, $hr) }
    }
  }

  # Aponta o Crystal 9 para a pasta dos componentes (o que o 1.REG faz).
  $base32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry32')
  $chave = $base32.CreateSubKey('SOFTWARE\Crystal Decisions\9.0\Crystal Reports')
  $chave.SetValue('CommonFiles', $crystal)
  $chave.Close()

  Log "  $copiados copiado(s), $iguais ja estavam em versao igual ou mais nova, $registrados registrado(s)." 'Green'
} catch {
  Erro $_.Exception.Message
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

# ------------------------------------------------------------------ FIM
Log ''
if ($script:erros -gt 0) {
  Log "Terminou com $($script:erros) erro(s). Log: $log" 'Red'
  exit 1
}
if ($script:reiniciar) { Log 'Tudo instalado. O Windows pede reinicio.' 'Yellow'; exit 3010 }
Log 'Tudo instalado.' 'Green'
exit 0
