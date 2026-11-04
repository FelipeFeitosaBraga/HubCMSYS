/* Comportamento da pagina: download, tema, checklist, copiar e filtro do FAQ. */
(function () {
  var cfg = window.HUB_CONFIG || {};

  // localStorage pode falhar (aba anonima, bloqueio): nunca quebra a pagina.
  function ler(chave, padrao) {
    try { var v = localStorage.getItem(chave); return v === null ? padrao : JSON.parse(v); }
    catch (e) { return padrao; }
  }
  function gravar(chave, valor) {
    try { localStorage.setItem(chave, JSON.stringify(valor)); } catch (e) { /* ignora */ }
  }

  // ---- Download e versao (vem do config.js) ----
  document.querySelectorAll(".js-download").forEach(function (a) {
    a.href = cfg.URL_DOWNLOAD || "download/HubCMSYS.exe";
    a.setAttribute("download", "HubCMSYS.exe");
  });
  document.querySelectorAll(".js-versao").forEach(function (el) { el.textContent = cfg.VERSAO || "1.0"; });
  document.querySelectorAll(".js-data").forEach(function (el) { el.textContent = cfg.DATA_VERSAO || ""; });
  var lista = document.getElementById("novidades-lista");
  (cfg.NOVIDADES || []).forEach(function (t) {
    var li = document.createElement("li"); li.textContent = t; lista.appendChild(li);
  });

  // ---- Tema claro/escuro ----
  var raiz = document.documentElement;
  var temaSalvo = ler("hub-tema", null);
  if (temaSalvo) raiz.setAttribute("data-theme", temaSalvo);
  document.getElementById("tema").addEventListener("click", function () {
    var escuroAgora = raiz.getAttribute("data-theme") === "dark" ||
      (!raiz.getAttribute("data-theme") && matchMedia("(prefers-color-scheme: dark)").matches);
    var novo = escuroAgora ? "light" : "dark";
    raiz.setAttribute("data-theme", novo);
    gravar("hub-tema", novo);
  });

  // ---- Checklist das etapas ----
  var feitas = ler("hub-etapas", {});
  var etapas = Array.prototype.slice.call(document.querySelectorAll(".etapa"));
  function atualizar() {
    var n = 0;
    etapas.forEach(function (e) {
      var ok = !!feitas[e.dataset.id];
      e.classList.toggle("feita", ok);
      e.querySelector("input").checked = ok;
      if (ok) n++;
    });
    document.getElementById("barra").style.width = (n / etapas.length * 100) + "%";
    document.getElementById("progresso-txt").textContent = n + " de " + etapas.length + " etapas";
  }
  etapas.forEach(function (e) {
    e.querySelector("input").addEventListener("change", function (ev) {
      feitas[e.dataset.id] = ev.target.checked;
      gravar("hub-etapas", feitas);
      atualizar();
    });
  });
  document.getElementById("zerar").addEventListener("click", function () {
    feitas = {}; gravar("hub-etapas", feitas); atualizar();
  });
  atualizar();

  // ---- Botoes Copiar ----
  document.querySelectorAll(".copiar").forEach(function (b) {
    b.addEventListener("click", function () {
      var texto = b.parentElement.querySelector("code").innerText;
      var ok = function () { b.textContent = "Copiado!"; setTimeout(function () { b.textContent = "Copiar"; }, 1600); };
      if (navigator.clipboard) navigator.clipboard.writeText(texto).then(ok, function () {});
    });
  });

  // ---- Filtro do FAQ ----
  var busca = document.getElementById("busca");
  var itens = document.querySelectorAll("#faq .q");
  busca.addEventListener("input", function () {
    var termo = busca.value.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    var visiveis = 0;
    itens.forEach(function (q) {
      var txt = q.textContent.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
      var mostra = !termo || txt.indexOf(termo) !== -1;
      q.hidden = !mostra;
      if (mostra) visiveis++;
    });
    document.getElementById("faq-vazio").hidden = visiveis > 0;
  });
})();
