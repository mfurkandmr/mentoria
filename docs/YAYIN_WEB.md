# Web yayını: yapılacaklar (mentoria.com.tr)

Kod hazır (NOTLAR §65). Aşağıdakiler hesap gerektirdiği için senin
yapman gerekenler; her adımın sonunda bana ne vereceğin yazıyor. Benim
yapacaklarım en altta.

GitHub'da hazır olan değişkenler: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
`CLOUDFLARE_PROJECT = mentoria` (7 Kasım 2026'da ayarlandı).

## Senin yapacakların

### 1. Alan adı
- [ ] `mentoria.com.tr`'yi bir kayıt firmasından al (belge gerekmiyor).

### 2. Cloudflare (ücretsiz)
- [ ] Hesap aç: <https://dash.cloudflare.com/sign-up>
- [ ] **Add a domain** → `mentoria.com.tr` → **Free** planı seç.
- [ ] Cloudflare'in verdiği iki **nameserver** adresini, alan adını aldığın
      firmanın panelinde alan adının DNS / nameserver ayarına yaz. Etkinleşmesi
      birkaç saat sürebilir; Cloudflare e-postayla haber verir.
- [ ] **Workers & Pages → Create → Pages → Upload assets**: proje adı
      `mentoria`. İstediği dosya için herhangi bir küçük dosya yükleyebilirsin;
      sonra GitHub üzerine yazar.
- [ ] **API token**: sağ üstte profil → **My Profile → API Tokens → Create
      Token → Custom token**. İzin: *Account → Cloudflare Pages → Edit*.
      Oluşan token'ı kopyala (bir kez gösterilir).
- [ ] **Account ID**: Workers & Pages sayfasının sağ tarafında yazar.

### 3. GitHub gizli değerleri
Token gizlidir; bana yazma, doğrudan GitHub'a gir:
<https://github.com/mfurkandmr/mentoria/settings/secrets/actions> →
**New repository secret**
- [ ] `CLOUDFLARE_API_TOKEN` = 2. adımdaki token
- [ ] `CLOUDFLARE_ACCOUNT_ID` = 2. adımdaki Account ID

Bana "secret'lar girildi" demen yeter.

### 4. Firebase web uygulaması (web bildirimi için)
- [ ] <https://console.firebase.google.com> → **mentoria-4939f** → dişli →
      **Project settings → Your apps → Add app → Web (</>)**. Takma ad:
      `Mentoria Web`; "Firebase Hosting" kutusunu **işaretleme**.
- [ ] Çıkan kodda `apiKey` ve `appId` değerlerini bana yaz. Bunlar gizli
      değildir (tarayıcıya zaten gider).

### 5. Supabase giriş adresleri
<https://supabase.com/dashboard/project/lmbykdvvxormfiaomysn/auth/url-configuration>
- [ ] **Site URL**: `https://mentoria.com.tr/app`
- [ ] **Redirect URLs**'e ekle: `https://mentoria.com.tr/app/**`
      (`mentoria://reset-password` kalsın, telefon için).
- [ ] Bu arada: **Authentication → Attack Protection → Leaked password
      protection** aç (eski açık iş).

### 6. İletişim e-postası
Cloudflare'de alan adı etkinleşince:
- [ ] **Email → Email Routing → Get started** → `iletisim@mentoria.com.tr`
      adresini kendi Gmail'ine yönlendir (Gmail'e gelen onay bağlantısına
      tıkla).

### 7. KVKK metinleri
Sitede ve uygulamada şu alanlar hâlâ boş görünüyor; bana yaz, tek seferde
doldurup sürümü artırayım:
- [ ] Ad soyad (`[AD SOYAD]`)
- [ ] Yazışma adresi (`[ADRES]`)
- [ ] KVKK başvuru e-postası (öneri: `iletisim@mentoria.com.tr` ya da ayrı
      `kvkk@mentoria.com.tr`)
- [ ] Kullanım koşulları için yetkili mahkeme ili

Web adresi (`mentoria.com.tr/app/hesap-sil`) ve aydınlatma metni bağlantısı
(`mentoria.com.tr/aydinlatma/`) belli; onları ben yazarım.

## Benim yapacaklarım (sen yukarıdakileri bitirince)

1. GitHub'da `WEB_DEPLOY = true` (ve Firebase değerleri) değişkenlerini
   ayarlamak, kodu göndermek; ilk yayın otomatik başlar.
2. Cloudflare Pages'e `mentoria.com.tr` ve `www` alan adlarını bağlamak.
3. Canlıda denemek: sayfa yenilenince `/app/login` açılıyor mu, şifre
   sıfırlama bağlantısı `/app`'e dönüyor mu, davet linki, gizli `/demo`,
   web bildirimi.
4. KVKK metinlerini doldurup `legalVersion`'ı artırmak.
