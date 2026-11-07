{{flutter_js}}
{{flutter_build_config}}

// Motor hazır olunca açılış ekranını kaldır (web/index.html, #splash).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const splash = document.getElementById('splash');
    if (splash) {
      splash.style.opacity = '0';
      setTimeout(function () { splash.remove(); }, 300);
    }
  },
});
