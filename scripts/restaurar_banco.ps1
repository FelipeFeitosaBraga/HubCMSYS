# ==========================================================================
#  RESTAURAR O BANCO DO CMSYS  (chamado pelo 5_restaurar_banco.bat)
# --------------------------------------------------------------------------
#  Parametros:
#    -Bak          caminho completo do arquivo .bak
#    -PastaDados   onde ficam os arquivos de dados (.mdf)
#    -PastaLog     onde ficam os arquivos de log (.ldf)
#    -Substituir   1 = restaura por cima se o banco ja existir; 0 = protege
#    -Auto         1 = nao faz perguntas
#  A senha do "sa" vem da variavel de ambiente SA_PWD.
#  Codigos de saida: 0 = ok (ou banco ja existia e foi preservado), 1 = erro.
# ==========================================================================
param(
  [Parameter(Mandatory = $true)][string]$Bak,
  [Parameter(Mandatory = $true)][string]$PastaDados,
  [Parameter(Mandatory = $true)][string]$PastaLog,
  [int]$Substituir = 0,
  [int]$Auto = 0
)
# 'Stop' = qualquer erro interrompe e cai no catch la embaixo.
$ErrorActionPreference = 'Stop'

# Dobra aspas simples para o texto poder entrar dentro de N'...' no T-SQL.
function Escapar([string]$texto) { return $texto.Replace("'", "''") }

# Conecta no SQL local como sa. Tenta por ate ~1 minuto porque, logo depois
# da instalacao, o servico pode ainda estar subindo.
function Conectar {
  $sb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $sb['Data Source']     = 'localhost'
  $sb['Initial Catalog'] = 'master'
  $sb['User ID']         = 'sa'
  $sb['Password']        = $env:SA_PWD
  $sb['Connect Timeout'] = 15
  for ($i = 1; $i -le 12; $i++) {
    try {
      $cn = New-Object System.Data.SqlClient.SqlConnection($sb.ConnectionString)
      $cn.Open()
      return $cn
    } catch {
      Write-Host ("  Aguardando o SQL ficar pronto ({0}/12)..." -f $i)
      Start-Sleep -Seconds 5
    }
  }
  throw 'Nao consegui conectar no SQL Server como sa. Confira a senha (SA_PWD) e se o servico esta no ar.'
}

# Cria um comando SQL sem limite de tempo (restauracao pode demorar).
function Novo-Comando($cn, [string]$sql) {
  $cmd = $cn.CreateCommand()
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 0
  return $cmd
}

# Executa um comando que nao devolve dados (RESTORE, ALTER...).
function Exec-Comando($cn, [string]$sql) { [void](Novo-Comando $cn $sql).ExecuteNonQuery() }

# Executa uma consulta e devolve o primeiro valor (ex.: um COUNT).
function Exec-Escalar($cn, [string]$sql) { return (Novo-Comando $cn $sql).ExecuteScalar() }

# Liga TCP/IP e Pipes nomeados (se estiverem desligados) e reinicia o servico.
function Garantir-Protocolos {
  Write-Host ''
  Write-Host '  Conferindo protocolos de rede do SQL...'
  # Descobre a pasta do registro da instancia (ex.: MSSQL17.MSSQLSERVER).
  $inst = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').MSSQLSERVER
  $base = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$inst\MSSQLServer\SuperSocketNetLib"
  $mudou = $false
  foreach ($par in @(@('Tcp', 'TCP/IP'), @('Np', 'Pipes nomeados'))) {
    $chave = Join-Path $base $par[0]
    if ((Get-ItemProperty $chave).Enabled -ne 1) {
      Set-ItemProperty -Path $chave -Name Enabled -Value 1
      $mudou = $true
      Write-Host ('   - ' + $par[1] + ': habilitado agora')
    } else {
      Write-Host ('   - ' + $par[1] + ': ja estava habilitado')
    }
  }
  if ($mudou) {
    Write-Host '  Reiniciando o servico do SQL Server...'
    Restart-Service -Name MSSQLSERVER -Force
  }
  # Browser em execucao (permite achar a instancia pela rede).
  try {
    if ((Get-Service SQLBrowser).Status -ne 'Running') { Start-Service SQLBrowser }
  } catch { Write-Host '  AVISO: nao consegui iniciar o SQL Server Browser.' -ForegroundColor Yellow }
  # Confere se algo esta escutando na porta 1433 (a mesma liberada no botao 2).
  Start-Sleep -Seconds 3
  $porta = Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue
  if ($porta) { Write-Host '  Porta 1433: SQL escutando (OK).' -ForegroundColor Green }
  else { Write-Host '  AVISO: nada escutando na porta 1433. Confira o SQL Server Configuration Manager.' -ForegroundColor Yellow }
}

try {
  Write-Host ''
  # ---- 1) Nome do banco, pelo numero da filial no nome do .bak ----------
  # Ex.: _cmsys09006_Filial_1_20261031.bak -> filial 1 -> banco "cmsys"
  #      ..._Filial_2_...                  -> filial 2 -> banco "cmsys_f2"
  $arquivo = [IO.Path]::GetFileName($Bak)
  $filial = 1
  if ($arquivo -match 'Filial[_\s-]*(\d+)') { $filial = [int]$Matches[1] }
  if ($filial -le 1) { $db = 'cmsys' } else { $db = "cmsys_f$filial" }
  Write-Host ("  Filial detectada: {0}  ->  banco: {1}" -f $filial, $db)

  # ---- 2) Pastas e permissoes --------------------------------------------
  # O servico do SQL (NT SERVICE\MSSQLSERVER) precisa ESCREVER nas pastas de
  # dados/log e LER o .bak; senao a restauracao falha com "acesso negado".
  foreach ($pasta in @($PastaDados, $PastaLog)) {
    New-Item -ItemType Directory -Force -Path $pasta | Out-Null
    & icacls.exe $pasta /grant 'NT SERVICE\MSSQLSERVER:(OI)(CI)M' | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "  AVISO: nao consegui ajustar permissao em $pasta" -ForegroundColor Yellow }
  }
  & icacls.exe (Split-Path $Bak -Parent) /grant 'NT SERVICE\MSSQLSERVER:(OI)(CI)R' | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host '  AVISO: nao consegui ajustar permissao na pasta do .bak' -ForegroundColor Yellow }
  # O .bak que veio da pasta Downloads chega com as permissoes do perfil do
  # usuario (so ele, Administradores e SYSTEM leem). Por isso a permissao vai
  # direto no ARQUIVO tambem: religa a heranca da pasta e libera a leitura
  # para o servico do SQL. Sem isso: "Erro do sistema operacional 5 (Acesso negado)".
  & icacls.exe $Bak /inheritance:e | Out-Null
  & icacls.exe $Bak /grant 'NT SERVICE\MSSQLSERVER:R' | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host '  AVISO: nao consegui liberar a leitura do .bak para o SQL' -ForegroundColor Yellow }

  # ---- 3) Conectar e ver se o banco ja existe -----------------------------
  $cn = Conectar
  # Mostra o andamento (STATS) da restauracao no CMD.
  $cn.add_InfoMessage([System.Data.SqlClient.SqlInfoMessageEventHandler]{ param($s, $e) Write-Host ('   ' + $e.Message) })

  $qtd = Exec-Escalar $cn "SELECT COUNT(*) FROM sys.databases WHERE name = N'$db'"
  $existe = ([int]$qtd -gt 0)
  $restaurar = $true
  if ($existe -and $Substituir -ne 1) {
    Write-Host ''
    Write-Host "  O banco '$db' JA EXISTE neste SQL Server." -ForegroundColor Yellow
    if ($Auto -eq 1) {
      Write-Host '  Modo automatico: mantendo o banco como esta (nada foi sobrescrito).' -ForegroundColor Yellow
      $restaurar = $false
    } else {
      $resp = Read-Host '  Para SUBSTITUIR pelo conteudo do .bak digite SUBSTITUIR (Enter = manter)'
      if ($resp -cne 'SUBSTITUIR') { $restaurar = $false; Write-Host '  Mantido como esta.' }
    }
  }

  if ($restaurar) {
    # ---- 4) Descobrir os arquivos logicos dentro do .bak -------------------
    $bakSql = Escapar $Bak
    $leitor = (Novo-Comando $cn "RESTORE FILELISTONLY FROM DISK = N'$bakSql'").ExecuteReader()
    $tabela = New-Object System.Data.DataTable
    $tabela.Load($leitor)
    if (-not $leitor.IsClosed) { $leitor.Close() }

    # Para cada arquivo logico, define o destino (MOVE): dados -> PastaDados,
    # log -> PastaLog. Nomes novos usam o nome do banco (evita colisao entre filiais).
    $moves = @(); $nd = 0; $nl = 0
    foreach ($linha in $tabela.Rows) {
      $logico = Escapar ([string]$linha['LogicalName'])
      $tipo = [string]$linha['Type']
      if ($tipo -eq 'D') {
        $nd++
        if ($nd -eq 1) { $nome = "$db.mdf" } else { $nome = "${db}_$nd.ndf" }
        $destino = Join-Path $PastaDados $nome
      } elseif ($tipo -eq 'L') {
        $nl++
        if ($nl -eq 1) { $nome = "${db}_log.ldf" } else { $nome = "${db}_log$nl.ldf" }
        $destino = Join-Path $PastaLog $nome
      } else {
        throw "Tipo de arquivo nao suportado dentro do .bak: $tipo ($logico)"
      }
      $moves += "MOVE N'$logico' TO N'$(Escapar $destino)'"
    }

    # ---- 5) Restaurar --------------------------------------------------------
    if ($existe) {
      # Banco existente: expulsa conexoes para poder substituir (equivale a
      # marcar "Substituir o banco existente" e "Fechar conexoes" no SSMS).
      Exec-Comando $cn "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
    }
    $sql = "RESTORE DATABASE [$db] FROM DISK = N'$bakSql' WITH " + ($moves -join ', ') + ', RECOVERY, STATS = 10'
    if ($existe) { $sql += ', REPLACE' }
    Write-Host ''
    Write-Host '  Restaurando (pode levar varios minutos)...'
    Exec-Comando $cn $sql
    if ($existe) { Exec-Comando $cn "ALTER DATABASE [$db] SET MULTI_USER" }

    # ---- 6) Conferir o resultado ----------------------------------------------
    $estado = [string](Exec-Escalar $cn "SELECT state_desc FROM sys.databases WHERE name = N'$db'")
    if ($estado -ne 'ONLINE') { throw "O banco '$db' ficou no estado $estado (esperado ONLINE)." }
    Write-Host ("  [OK] Banco '{0}' restaurado e ONLINE." -f $db) -ForegroundColor Green
  }
  $cn.Close()

  # ---- 7) Protocolos de rede + reinicio do servico ---------------------------
  Garantir-Protocolos
  exit 0
}
catch {
  Write-Host ''
  Write-Host ('  FALHA: ' + $_.Exception.Message) -ForegroundColor Red
  exit 1
}
