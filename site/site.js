// Mentoria sitesi: üst çubuk, kaydırınca belirme, 3D sahnelerin fare ve
// kaydırmayla eğilmesi. "Hareketi azalt" açıksa yalnızca son halleri gösterir.
(function () {
  'use strict';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var nav = document.getElementById('nav');

  // Üst çubuk: koyu giriş bölümünün üstünde şeffaf, sonra beyaz.
  var hero = document.querySelector('.hero');
  function navState() {
    if (!nav) return;
    var limit = hero ? hero.offsetHeight - 80 : 0;
    nav.classList.toggle('solid', window.scrollY > limit);
  }
  if (!hero && nav) nav.classList.add('light');
  navState();
  window.addEventListener('scroll', navState, { passive: true });

  // Belirme: görünür olunca .in (bir kez).
  var targets = document.querySelectorAll('.reveal, .reveal-lessons, .reveal-bars, .consolidate');
  if (reduce || !('IntersectionObserver' in window)) {
    targets.forEach(function (el) { el.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      });
    }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });
    targets.forEach(function (el) { io.observe(el); });
  }
  if (reduce) return;

  // Giriş sahnesi: fareyle hafif dönme.
  var scene = document.querySelector('[data-parallax]');
  var inner = scene && scene.querySelector('.scene-inner');
  if (inner && window.matchMedia('(pointer: fine)').matches) {
    var raf = 0, px = 0, py = 0;
    document.querySelector('.hero').addEventListener('pointermove', function (ev) {
      var r = scene.getBoundingClientRect();
      px = ((ev.clientX - r.left) / r.width - 0.5) * 2;
      py = ((ev.clientY - r.top) / r.height - 0.5) * 2;
      if (!raf) raf = requestAnimationFrame(function () {
        raf = 0;
        inner.style.setProperty('--ry', (px * 8).toFixed(2) + 'deg');
        inner.style.setProperty('--rx', (-py * 6).toFixed(2) + 'deg');
      });
    });
    document.querySelector('.hero').addEventListener('pointerleave', function () {
      inner.style.setProperty('--ry', '0deg');
      inner.style.setProperty('--rx', '0deg');
    });
  }

  // Modül görselleri: kaydırdıkça eğik halden düze gelir (3D giriş).
  var tilts = Array.prototype.slice.call(document.querySelectorAll('[data-tilt]'));
  var ticking = false;
  function update() {
    ticking = false;
    var vh = window.innerHeight;
    tilts.forEach(function (el, i) {
      var r = el.getBoundingClientRect();
      if (r.bottom < -200 || r.top > vh + 200) return;
      // 0: ekranın altında, 1: ortada
      var p = 1 - Math.min(Math.max((r.top + r.height / 2 - vh / 2) / (vh * 0.75), -1), 1);
      var t = Math.min(p, 1);
      var dir = i % 2 ? -1 : 1;
      var rx = (1 - t) * 16;
      var ry = (1 - t) * 14 * dir;
      var y = (1 - t) * 40;
      el.style.transform = 'translateY(' + y.toFixed(1) + 'px) rotateX(' + rx.toFixed(2) + 'deg) rotateY(' + ry.toFixed(2) + 'deg)';
    });
  }
  function onScroll() {
    if (!ticking) { ticking = true; requestAnimationFrame(update); }
  }
  if (tilts.length) {
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
  }
})();
