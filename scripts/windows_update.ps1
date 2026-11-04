# ==========================================================================
#  WINDOWS UPDATE  (chamado pelo 7_windows_update.bat)
# --------------------------------------------------------------------------
#  O que faz : procura, baixa e instala as atualizacoes do Windows usando a
#              API oficial do Windows Update (objetos COM), sem precisar de
#              nenhum modulo extra instalado.
#  Codigos de saida (lidos pelo .bat):
#     0    = tudo certo, nada pendente
#     1    = alguma atualizacao falhou ou deu erro (ex.: sem internet)
#     3010 = precisa REINICIAR o PC (codigo padrao do Windows)
# ==========================================================================

# 'Continue' = se um comando falhar, mostra o erro e segue em frente.
$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host ('=' * 64) -ForegroundColor Cyan
Write-Host ' WINDOWS UPDATE (nao feche esta janela, pode demorar bastante)' -ForegroundColor Cyan
Write-Host ('=' * 64) -ForegroundColor Cyan

$instaladas = 0      # quantas atualizacoes foram instaladas com sucesso
$falhas     = 0      # quantas falharam
$reiniciar  = $false # vira $true se o Windows pedir reinicio

try {
  # Session = "conversa" com o servico do Windows Update.
  $session = New-Object -ComObject Microsoft.Update.Session

  # Repete ate 5 vezes: depois de instalar um lote, podem aparecer novas
  # atualizacoes que dependiam das primeiras.
  for ($passo = 1; $passo -le 5; $passo++) {
    Write-Host ("  Passo {0}: procurando atualizacoes..." -f $passo)

    # Criterio: ainda nao instalada, nao oculta, e do tipo "Software"
    # (ignora drivers, que podem causar problemas em maquina de cliente).
    $busca = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

    if ($busca.Updates.Count -eq 0) {
      Write-Host '  Nenhuma atualizacao pendente.' -ForegroundColor Green
      break
    }
    Write-Host ("  Encontradas: {0}" -f $busca.Updates.Count)

    # Monta a lista (colecao) do que sera baixado.
    $baixar = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $busca.Updates) {
      Write-Host ('   - ' + $u.Title)
      if (-not $u.EulaAccepted) { $u.AcceptEula() }   # aceita o termo de licenca
      [void]$baixar.Add($u)
    }

    Write-Host '  Baixando...'
    $dl = $session.CreateUpdateDownloader()
    $dl.Updates = $baixar
    [void]$dl.Download()

    # So instala o que realmente terminou de baixar.
    $instalar = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $busca.Updates) { if ($u.IsDownloaded) { [void]$instalar.Add($u) } }
    if ($instalar.Count -eq 0) {
      Write-Host '  Nenhuma atualizacao foi baixada.' -ForegroundColor Red
      $falhas++
      break
    }

    Write-Host ("  Instalando {0} atualizacao(oes)..." -f $instalar.Count)
    $inst = $session.CreateUpdateInstaller()
    $inst.Updates = $instalar
    $resultado = $inst.Install()

    # ResultCode: 2 = sucesso, 3 = sucesso com avisos; qualquer outro = falha.
    for ($k = 0; $k -lt $instalar.Count; $k++) {
      $rc = $resultado.GetUpdateResult($k).ResultCode
      if ($rc -eq 2 -or $rc -eq 3) { $instaladas++ }
      else {
        $falhas++
        Write-Host ('   Falhou: ' + $instalar.Item($k).Title) -ForegroundColor Red
      }
    }

    # Se o Windows pede reinicio, para aqui: reinicia e roda de novo.
    if ($resultado.RebootRequired) { $reiniciar = $true; break }
  }
}
catch {
  Write-Host ('  FALHA: ' + $_.Exception.Message) -ForegroundColor Red
  Write-Host '  Verifique a conexao com a internet.' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host ("  Instaladas: {0} | Falhas: {1}" -f $instaladas, $falhas)

if ($reiniciar) { Write-Host '  REINICIO NECESSARIO.' -ForegroundColor Yellow; exit 3010 }
if ($falhas -gt 0) { exit 1 }
Write-Host '  [OK] Sem pendencias.' -ForegroundColor Green
exit 0
