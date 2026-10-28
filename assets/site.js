// TDash Protheus - tema, menu, índice e telas
(function () {
  var root = document.documentElement;

  function store(key, value) {
    try { if (value === undefined) return localStorage.getItem(key); localStorage.setItem(key, value); } catch (e) { return null; }
  }

  function isDark() {
    if (root.dataset.theme) return root.dataset.theme === 'dark';
    return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches;
  }

  // As telas do app têm versão clara e escura: segue o tema do site
  function syncShots() {
    var mode = isDark() ? 'dark' : 'light';
    document.querySelectorAll('img[data-shot]').forEach(function (img) {
      img.src = 'assets/img/' + img.dataset.shot + '-' + mode + '.webp';
    });
  }

  var saved = store('tdash-theme');
  if (saved === 'dark' || saved === 'light') root.dataset.theme = saved;

  document.addEventListener('DOMContentLoaded', function () {
    syncShots();
    if (window.matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener('change', syncShots);

    var themeBtn = document.getElementById('themeBtn');
    if (themeBtn) themeBtn.addEventListener('click', function () {
      root.dataset.theme = isDark() ? 'light' : 'dark';
      store('tdash-theme', root.dataset.theme);
      syncShots();
    });

    var menuBtn = document.getElementById('menuBtn');
    var nav = document.getElementById('nav');
    if (menuBtn && nav) {
      menuBtn.addEventListener('click', function () {
        var open = nav.classList.toggle('open');
        menuBtn.setAttribute('aria-expanded', String(open));
      });
      nav.addEventListener('click', function (e) { if (e.target.closest('a')) nav.classList.remove('open'); });
    }

    // Índice lateral: marca a seção visível
    var links = document.querySelectorAll('.toc a[href^="#"]');
    if (links.length && 'IntersectionObserver' in window) {
      var map = {};
      links.forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          links.forEach(function (a) { a.classList.remove('active'); });
          var link = map[entry.target.id];
          if (link) link.classList.add('active');
        });
      }, { rootMargin: '-80px 0px -70% 0px' });
      Object.keys(map).forEach(function (id) {
        var el = document.getElementById(id);
        if (el) observer.observe(el);
      });
    }

    // Catálogo de indicadores: busca e filtro por módulo
    var search = document.getElementById('kpiSearch');
    var chips = document.querySelectorAll('.filter .chip');
    if (search) {
      var active = 'all';
      var apply = function () {
        var q = search.value.trim().toLowerCase();
        document.querySelectorAll('[data-module]').forEach(function (block) {
          var showBlock = active === 'all' || block.dataset.module === active;
          var visible = 0;
          block.querySelectorAll('tbody tr').forEach(function (tr) {
            var hit = !q || tr.textContent.toLowerCase().indexOf(q) >= 0;
            tr.hidden = !hit;
            if (hit) visible++;
          });
          block.hidden = !showBlock || visible === 0;
        });
      };
      search.addEventListener('input', apply);
      chips.forEach(function (chip) {
        chip.addEventListener('click', function () {
          active = chip.dataset.filter;
          chips.forEach(function (c) { c.setAttribute('aria-pressed', String(c === chip)); });
          apply();
        });
      });
    }
  });
})();
