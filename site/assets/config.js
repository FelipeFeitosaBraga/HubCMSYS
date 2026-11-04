/* ==========================================================================
   CONFIGURACAO DO SITE  (o unico arquivo que voce precisa mexer a cada versao)
   --------------------------------------------------------------------------
   URL_DOWNLOAD:
     - "download/HubCMSYS.exe"  -> o .exe fica dentro do proprio site
       (copie o dist\HubCMSYS.exe do build.bat para a pasta "download").
     - ou o link de uma Release do GitHub, ex.:
       "https://github.com/SEU-USUARIO/HubCMSYS/releases/latest/download/HubCMSYS.exe"
   ========================================================================== */
window.HUB_CONFIG = {
  VERSAO: "1.0",
  DATA_VERSAO: "04/11/2026",
  URL_DOWNLOAD: "download/HubCMSYS.exe",
  NOVIDADES: [
    "Botao 8: migrar XML, notas, fotos e logos do servidor antigo (robocopy).",
    "Botao 5: ajuda a baixar o .bak no portal da Azure e restaura sozinho.",
    "Botao 6: instala ReportViewer, Crystal, Relatorios, Boleto e componentes do CMSYS.",
    "Correcao: 'Acesso negado' ao restaurar o .bak vindo da pasta Downloads."
  ]
};
