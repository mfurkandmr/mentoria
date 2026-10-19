# Yayın öncesi kontrol listesi

> 19 Ekim 2026. Geliştirici hesapları (Google Play, App Store) henüz yok;
> bu liste onlar açılmadan yapılabilecekleri ve açılınca yapılacakları ayırır.
> KVKK'ya özel işler: `docs/kvkk/00_README.md`.

## 1. Senin yapman gerekenler (panelde / elde)

### İmza anahtarını yedekle (bugün)
- Android mağaza imza anahtarı oluşturuldu: `C:\anahtarlar\mentoria.jks`.
- Parolası `android/key.properties` dosyasında. Bu dosya git'e girmez,
  OneDrive klasöründe durur.
- **İkisini birlikte güvenli bir yere yedekle:** şifre yöneticisi, şifreli
  USB ya da bulut kasası. Anahtar kaybolursa Play'de güncelleme yayınlamak
  için Google destek süreci gerekir.
- Bu anahtarla imzalanan ilk APK'yı kurmadan önce telefonlardaki eski sürüm
  **bir kez kaldırılmalı** (eskiler geçici anahtarla imzalıydı).

### Supabase paneli (Authentication)
- [ ] **Sign In / Providers → Email → "Confirm email" açık mı?** Kapalıysa
      kayıtta doğrulama kodu adımı atlanır.
- [ ] **Özel SMTP:** Supabase'in kendi e-postası saatte birkaç adrese
      gider; gerçek öğrenciler kayıt kodunu alamaz. Bir alan adı gerekir.
      Resend önerildi (ayda 3.000 e-posta ücretsiz). Ayrıntı: NOTLAR.md §17
      "Panelde yapılacaklar".
- [ ] **Sızdırılmış şifre koruması** (Password security → "Leaked password
      protection"): tek tıkla açılır. Supabase güvenlik uyarısı veriyor.
- [ ] **E-posta şablonu** ("Confirm signup"): `supabase/templates/confirm_signup.html`.

### Firebase konsolu
- [ ] Crashlytics: ilk çökme raporu gelince sekme açılır; açılmazsa
      Crashlytics → "Enable". Test için yeni APK'da bilerek hata
      oluşturmaya gerek yok; ilk gerçek hata yeterli.

### GitHub
- [ ] **Depo şu an herkese açık (public).** Kod, NOTLAR.md ve KVKK taslakları
      herkes tarafından görülebiliyor. Önerilen: Settings → General → Danger
      Zone → "Change repository visibility" → Private. (CI özel depoda da
      çalışır; ayda 2.000 dakika ücretsiz.) `promo-assets` dalındaki videolar
      bir yerden bağlantıyla kullanılıyorsa önce onları başka yere taşı.

### Alan adı
- [ ] Bir alan adı al (ör. `mentoria.app`). Gerekenler:
  - SMTP (yukarıda)
  - Gizlilik politikasının ve web'den hesap silme sayfasının herkese açık
    adresi (Play zorunlu tutuyor)
  - İleride `https://` davet linklerinin uygulamada açılması (App Links /
    Universal Links)

## 2. Telefonda deneme turu (yeni APK ile)

Her madde bugüne kadar testlerde geçti ama gerçek telefonda denenmedi.

- [ ] **Kurulum:** eski sürümü kaldır, yeni APK'yı kur, giriş yap.
- [ ] **Pomodoro zili:** zamanlayıcı kartında kırmızı izin uyarısı çıkarsa
      "İzni aç"a bas. 15 dk başlat, telefonu kilitle,
      süre bitince zil çalmalı (kilit ekranında saat simgesi görünür).
      Uygulamayı son kullanılanlardan kaydırıp kapatınca da denenmeli.
- [ ] **Push:** koç hesabından ödev gönder; öğrenci telefonu kilitliyken
      bildirim gelmeli, uygulama açıkken yukarıdan kart kaymalı.
- [ ] **Ana sayfa:** uygulamayı kapat, internetini kes, aç: son görülen ana
      sayfa gelmeli. İnterneti aç, aşağı çek: güncellenmeli.
- [ ] **Kayıt (KVKK):** yeni bir öğrenci davet koduyla kayıt ol. Doğum yılı
      ve aydınlatma kutusu zorunlu, sıralama kutusu isteğe bağlı olmalı;
      "Aydınlatma Metni'ni oku" metni açmalı.
- [ ] **Veli onayı:** 18 yaş altı öğrenci velisini davet etsin; veli kaydında
      zorunlu onay kutusu çıkmalı. Kurum beyanlı davetle gelen öğrencide
      "Veli onayın kurumun tarafından alındı" yazmalı.
- [ ] **Gizlilik ve izinler:** sıralama izni aç/kapa; "Verilerimi indir" bir
      JSON dosyası paylaşmalı.
- [ ] **Sıralama:** izni açan öğrenciler başarı sıralamasında görünmeli,
      kapatan görünmemeli.
- [ ] **Hata defteri:** fotoğraflı kart ekle, sil; 10 dk içinde fotoğraf
      depodan silinmeli (Supabase → Storage → mistake-photos).
- [ ] **Koç:** öğrenci listesinde silme talebi rozeti, öğrenci detayında
      gökyüzü üst çubuğu.
- [ ] **Zorunlu güncelleme:** (isteğe bağlı) SQL Editor'da
      `update app_config set min_build = 99;` → uygulama "Yeni sürüm
      gerekli" ekranında durmalı. Sonra `min_build = 1` yap.

## 3. Zorunlu güncelleme nasıl kullanılır

- Uygulamanın sürümü `pubspec.yaml`'da (`version: 0.2.0+2`; `+2` derleme
  numarası) ve `lib/core/config/app_version.dart`'ta. İkisi birlikte artırılır;
  test eşleşmeyi denetler.
- Sunucuda eski sürümleri bozacak bir değişiklik yapıldığında, yeni sürüm
  dağıtıldıktan sonra:
  ```sql
  update public.app_config
  set min_build = 3,
      update_url = 'https://...',   -- mağaza ya da APK indirme adresi
      message = null;               -- boşsa varsayılan metin
  ```
- Kontrol açılışta bir kez yapılır; sunucuya ulaşılamazsa uygulama açılır
  (kimse kilitlenmez).

## 4. Geliştirici hesapları açılınca

### Google Play (tek seferlik 25 $)
- [ ] Uygulama oluştur (`com.mentoria.mentoria`); **Play App Signing** açık.
      Yükleme anahtarı olarak `C:\anahtarlar\mentoria.jks` kullanılır.
- [ ] Derleme:
      `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json`
      (`M:` sürücüsünden; NOTLAR.md "Proje yolu").
- [ ] Mağaza sayfası, ekran görüntüleri (demo modundan alınabilir), simge.
- [ ] Gizlilik politikası adresi, **Veri güvenliği** formu
      (`docs/kvkk/05_gizlilik_politikasi.md` sonundaki tablo).
- [ ] İçerik derecelendirmesi; hedef kitle (13–18 ve üstü; "Families"
      politikasına dikkat).
- [ ] Hesap silme: uygulama içinden başlatılabiliyor ✔; web'den talep sayfası
      adresi gerekli.
- [ ] `app_config.update_url` = Play mağaza adresi.

### App Store (yıllık 99 $)
- [ ] Mac ve Xcode gerekli; iOS hiç derlenmedi.
- [ ] APNs anahtarı (.p8) Firebase'e yüklenir (push için).
- [ ] Özel zil sesleri iOS paketine eklenir (NOTLAR §13).
- [ ] App Privacy formu; çocuklar için "Kids" kategorisi seçilmemeli (hedef
      13+), ama veli onayı akışı incelemede anlatılmalı.
