// Tanıtım sayfasının <head> içinde eşzamanlı çalışır (CSP satır içi script'e izin vermez).
document.documentElement.classList.remove('no-js');
// Panelde oturumu açık olan kullanıcı siteyi açınca doğrudan paneline
// gider (oturum tarayıcıda, çıkış yapana kadar kalır). Tanıtımı görmek
// için: mentoria.com.tr/?tanitim
try {
  if (!/[?&]tanitim\b/.test(location.search)) {
    for (var i = 0; i < localStorage.length; i++) {
      if (/^sb-.+-auth-token$/.test(localStorage.key(i))) {
        location.replace('/app/');
        break;
      }
    }
  }
} catch (e) {}
