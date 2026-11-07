/* Comportamento da pagina: abas (Preparar PC / Atualizar Servidor), download,
   tema, checklists, copiar e filtro dos problemas. */
(function () {
  var cfg = window.HUB_CONFIG || {};
  var cfgAt = cfg.ATUALIZAR || {};

  // localStorage pode falhar (aba anonima, bloqueio): nunca quebra a pagina.
  function ler(chave, padrao) {
    try { var v = localStorage.getItem(chave); return v === null ? padrao : JSON.parse(v); }
    catch (e) { return padrao; }
  }
  function gravar(chave, valor) {
    try { localStorage.setItem(chave, JSON.stringify(valor)); } catch (e) { /* ignora */ }
  }
  function cada(seletor, fn, raiz) {
    Array.prototype.forEach.call((raiz || document).querySelectorAll(seletor), fn);
  }

  // ---- Downloads e versoes (vem do config.js) ----
  cada(".js-download", function (a) {
    a.href = cfg.URL_DOWNLOAD || "download/HubCMSYS.exe";
    a.setAttribute("download", "HubCMSYS.exe");
  });
  cada(".js-download-at", function (a) {
    a.href = cfgAt.URL_DOWNLOAD || "download/AtualizarCMSYS.exe";
    a.setAttribute("download", "AtualizarCMSYS.exe");
  });
  cada(".js-versao", function (el) { el.textContent = cfg.VERSAO || "1.0"; });
  cada(".js-data", function (el) { el.textContent = cfg.DATA_VERSAO || ""; });
  cada(".js-at-versao", function (el) { el.textContent = cfgAt.VERSAO || "1.0"; });
  cada(".js-at-data", function (el) { el.textContent = cfgAt.DATA_VERSAO || ""; });
  var lista = document.getElementById("novidades-lista");
  if (lista) (cfg.NOVIDADES || []).forEach(function (t) {
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

  // ---- Abas com transicao horizontal ----
  var trilho = document.querySelector(".trilho");
  var vistas = {};
  cada(".vista", function (v) { vistas[v.dataset.vista] = v; });
  var titulos = {
    preparar: "Hub CMSYS · Guia e download",
    atualizar: "Hub CMSYS · Atualizar servidor"
  };
  var reduzir = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var atual = null;

  function vistaDoHash(h) {
    h = (h || "").replace(/^#/, "");
    return (h === "atualizar" || h.indexOf("at-") === 0) ? "atualizar" : "preparar";
  }

  function esconderOutras() {
    Object.keys(vistas).forEach(function (n) {
      var outra = n !== atual;
      vistas[n].classList.toggle("oculta", outra);
      vistas[n].inert = outra;
      if (outra) vistas[n].setAttribute("aria-hidden", "true"); else vistas[n].removeAttribute("aria-hidden");
    });
  }

  function mostrar(nome, animar) {
    if (!vistas[nome] || nome === atual) return;
    var anterior = atual;
    atual = nome;
    animar = animar && anterior && !reduzir;

    // Durante a transicao as duas paginas ficam visiveis.
    vistas[nome].classList.remove("oculta");
    vistas[nome].inert = false;
    if (!animar) document.body.classList.add("sem-animacao");
    if (animar && window.scrollY > 0) window.scrollTo({ top: 0, behavior: "instant" });

    document.body.setAttribute("data-vista", nome);
    document.title = titulos[nome] || document.title;
    cada(".aba", function (b) { b.setAttribute("aria-selected", b.dataset.ir === nome ? "true" : "false"); });
    cada(".topo-nav", function (n) { n.hidden = n.dataset.nav !== nome; });

    if (!animar) {
      void trilho.offsetWidth;   // aplica sem transicao
      esconderOutras();
      requestAnimationFrame(function () { document.body.classList.remove("sem-animacao"); });
      return;
    }
    var feito = false;
    function fim(e) {
      if (feito || (e && e.target !== trilho)) return;
      feito = true;
      trilho.removeEventListener("transitionend", fim);
      if (atual === nome) esconderOutras();
    }
    trilho.addEventListener("transitionend", fim);
    setTimeout(fim, 900);
  }

  function irPara(nome) {
    if (nome === atual) { window.scrollTo({ top: 0, behavior: "smooth" }); return; }
    var url = nome === "atualizar" ? "#atualizar" : location.pathname + location.search;
    try { history.pushState({ vista: nome }, "", url); } catch (e) { /* ignora */ }
    mostrar(nome, true);
  }

  cada(".aba", function (b) {
    b.addEventListener("click", function () { irPara(b.dataset.ir); });
    b.addEventListener("keydown", function (e) {
      if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
      var outra = b.dataset.ir === "preparar" ? "atualizar" : "preparar";
      irPara(outra);
      document.getElementById("aba-" + outra).focus();
    });
  });
  window.addEventListener("popstate", function () { mostrar(vistaDoHash(location.hash), true); });
  window.addEventListener("hashchange", function () { mostrar(vistaDoHash(location.hash), true); });

  // A marca leva ao topo da pagina que estiver aberta.
  var marca = document.querySelector(".marca");
  if (marca) marca.addEventListener("click", function (e) {
    e.preventDefault();
    window.scrollTo({ top: 0, behavior: "smooth" });
  });

  // Abre direto na aba certa (ex.: link .../#atualizar ou .../#at-problemas).
  mostrar(vistaDoHash(location.hash), false);
  if (location.hash.indexOf("#at-") === 0) {
    var alvo = document.getElementById(location.hash.slice(1));
    if (alvo) setTimeout(function () { alvo.scrollIntoView(); }, 0);
  }

  // ---- Checklists (um por pagina, cada um salvo com a sua chave) ----
  cada(".etapas[data-chave]", function (grupo) {
    var chave = grupo.dataset.chave;
    var painel = document.querySelector('.progresso[data-chave="' + chave + '"]');
    var feitas = ler(chave, {});
    var etapas = Array.prototype.slice.call(grupo.querySelectorAll(".etapa"));
    function atualizar() {
      var n = 0;
      etapas.forEach(function (e) {
        var ok = !!feitas[e.dataset.id];
        e.classList.toggle("feita", ok);
        e.querySelector("input").checked = ok;
        if (ok) n++;
      });
      if (!painel) return;
      painel.querySelector(".js-barra").style.width = (n / etapas.length * 100) + "%";
      painel.querySelector(".js-progresso-txt").textContent = n + " de " + etapas.length + " etapas";
    }
    etapas.forEach(function (e) {
      e.querySelector("input").addEventListener("change", function (ev) {
        feitas[e.dataset.id] = ev.target.checked;
        gravar(chave, feitas);
        atualizar();
      });
    });
    if (painel) painel.querySelector(".js-zerar").addEventListener("click", function () {
      feitas = {}; gravar(chave, feitas); atualizar();
    });
    atualizar();
  });

  // ---- Botoes Copiar ----
  cada(".copiar", function (b) {
    b.addEventListener("click", function () {
      var texto = b.parentElement.querySelector("code").innerText;
      var ok = function () { b.textContent = "Copiado!"; setTimeout(function () { b.textContent = "Copiar"; }, 1600); };
      if (navigator.clipboard) navigator.clipboard.writeText(texto).then(ok, function () {});
    });
  });

  // ---- Filtro dos problemas (cada pagina tem o seu) ----
  function semAcento(t) { return t.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
  cada(".busca[data-faq]", function (busca) {
    var faq = document.getElementById(busca.dataset.faq);
    if (!faq) return;
    var itens = faq.querySelectorAll(".q");
    var vazio = faq.querySelector(".vazio");
    busca.addEventListener("input", function () {
      var termo = semAcento(busca.value.trim());
      var visiveis = 0;
      Array.prototype.forEach.call(itens, function (q) {
        var mostra = !termo || semAcento(q.textContent).indexOf(termo) !== -1;
        q.hidden = !mostra;
        if (mostra) visiveis++;
      });
      if (vazio) vazio.hidden = visiveis > 0;
    });
  });
})();
