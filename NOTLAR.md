# Geliştirme notları

Bu dosya, son iki büyük özelliğin (white label ve öğrenci avatarı) ne yaptığını,
nasıl çalıştığını ve nelere dikkat edilmesi gerektiğini anlatır.

> **Güncel durum (16 Ekim 2026, genel kontrol):** Depodaki 29 migration'ın
> hepsi canlı projede (`lmbykdvvxormfiaomysn`). `send-push` sürüm 3 canlı ve
> depodakiyle aynı; Vault'ta `push_function_url` / `push_webhook_secret` var.
> `meeting-reminders` cron işi çalışıyor (hatasız). **Telefon bildirimi gerçek
> cihazda doğrulandı:** 19:10'da bir görüşme hatırlatması FCM'e iletildi
> (`sent: 1`) ve geçersiz bir cihaz adresi otomatik silindi.
> Canlı ile depo birebir aynı: Mentoria'ya ait olmayan iki boş tablo
> (`cookie_consents`, `survey_responses`) silindi, bkz. §14.
> Aşağıdaki bölümlerde "canlıya alınmadı" yazan eski notlar bu durumla
> güncellendi.

---

## 1. White label (beyaz etiket): her dershane kendi markasıyla

### Veritabanı (4 ayrı migration + her biri için geri alma dosyası)

| Migration | Ne yapar | Geri alma |
|---|---|---|
| `20261017100000_tenants.sql` | `tenants` tablosu, `platform_admins` (süper admin), kurumları dershaneye bağlama, `create_tenant`, `tenant_branding`, `check_invite` artık markayı da döndürür | `supabase/rollbacks/20261017100000_tenants.down.sql` |
| `20261017110000_tenant_columns.sql` | Dershaneye ait 16 tabloya `tenant_id`, mevcut verilerin doldurulması, `set_tenant_id` tetikleyicisi, `my_tenant()` | `…_tenant_columns.down.sql` |
| `20261017120000_tenant_isolation.sql` | Her tabloya **RESTRICTIVE** izolasyon politikası | `…_tenant_isolation.down.sql` |
| `20261017130000_tenant_logo_storage.sql` | `tenant-logos` Storage kovası (herkese açık okuma, yalnızca süper admin yazar; PNG/JPEG/WebP, 1 MB) | `…_tenant_logo_storage.down.sql` |

Geri alma dosyaları **ters sırayla** çalıştırılır (13 → 12 → 11 → 10). Supabase CLI
bunları migration olarak görmesin diye `supabase/rollbacks/` klasöründeler.

**Kolon adları:** Mevcut şemayla aynı kalsın diye İngilizce:
`name` (ad), `slug`, `logo_url`, `primary_color` (ana_renk),
`secondary_color` (ikincil_renk), `is_active` (aktif_mi).

**Dershane ile kurum ilişkisi:** `tenants` markalama birimidir. Var olan
`organizations` (kurum/şube: koltuk sayısı, lisans) her biri bir dershaneye
bağlanır. Mevcut her kurum için otomatik bir dershane açıldı (varsayılan
Mentoria renkleriyle, slug kurum adından: "Bal Akademi" → `bal-akademi`).
`tenant_id` verilmeden kurum eklenirse dershane yine otomatik açılır, yani eski
SQL akışları bozulmaz.

**İzolasyon nasıl sağlanıyor?**
- `tenant_id` istemciden **alınmaz**. `set_tenant_id` tetikleyicisi her
  kayıtta onu öğrencinin/kurumun dershanesinden doldurur. Güncellemede
  değiştirilemez.
- Her tabloda RESTRICTIVE bir politika var: mevcut politikalarla **VE**'lenir.
  Mevcut bir kural fazla izin verse bile kullanıcı yalnızca kendi dershanesinin
  satırlarını görür ve yazar.
- Pasif dershane (`is_active = false`): kullanıcılar giriş yapabilir ama veri
  tablolarına erişemez (uygulama "erişim kapalı" ekranı gösterir). Davet
  kodları geçersiz olur, yeni kayıt yapılamaz, giriş ekranında marka görünmez.
- `SECURITY DEFINER` fonksiyonlar (`student_summaries` vb.) RLS'i atlar. Ama
  çağıranın koç/müdür/öğrenci ilişkisine göre süzerler ve bu ilişkiler tek
  dershane içindedir; testlerle doğrulandı.

**Süper admin yapmak** (yalnızca SQL ile; uygulamadan yapılamaz):
```sql
insert into public.platform_admins (user_id)
select id from auth.users where email = 'ornek@mail.com';
```
Süper admin, profil ekranında **"Dershane yönetimi"** kartını görür.

### Uygulama

- **Tema katmanı:** `lib/core/theme/brand_theme.dart` → `BrandTheme`
  (ThemeExtension). Widget'lar renkleri `context.brand.primary`,
  `.primaryDeep`, `.secondary`, `.ink`, `.success` vb. ile okur. Uygulama adı
  `context.brand.appName`, logo `context.brand.logoUrl`.
  `AppColors` artık yalnızca **varsayılan** paletin kaynağı; ekranlarda
  doğrudan kullanılmıyor.
- **Renk türetme:** Dershanenin iki renginden koyu ton, üstündeki yazı rengi
  (WCAG kontrastına göre koyu ya da beyaz), zemin ve koyu tema yüzeyleri
  türetilir. Renkler Mentoria'nınkiyle aynıysa tema **birebir** korunur.
- **Marka ne zaman değişir:** `lib/core/branding/branding_providers.dart`
  - Giriş yapılmışsa: kullanıcının dershanesi.
  - Giriş yoksa: cihazda kayıtlı dershane kodu (slug).
  - Davet linkiyle gelindiyse: davetin dershanesi.
  - **Yüklenirken ya da hata olursa Mentoria teması.**
- **Logo:** `BrandLogo` widget'ı. Varsayılanda "mentoria" yazı logosu,
  dershanede logo + ad gösterir. Logo yoksa ya da yüklenemezse ana renkte baş
  harf rozeti. Açılış animasyonunda dershanenin adı düşer.
- **Giriş:**
  - Giriş ekranında "Dershane kodun var mı?" seçeneği var. Kod girilince ekran
    o dershanenin rengi ve adıyla yeniden çizilir; kod cihazda hatırlanır.
  - Kodla girilen hesap başka bir dershaneye aitse oturum kapatılır ve uyarı
    gösterilir.
  - Kod girilmeden giriş de çalışır; mevcut kullanıcılar etkilenmez, marka
    hesaptan gelir.
- **Linkler** (`lib/core/branding/app_links.dart`):
  - Davet linki: `…/#/join/KOD`. Kayıt ekranı kodu doğrular ve dershanenin
    markasıyla açılır. Koç davet ekranında "Davet linkini kopyala" düğmesi var.
  - Dershane linki: `…/#/t/slug`. Giriş ekranı o dershaneyle açılır.
  - Mobilde: `mentoria://app/join/KOD` (Android intent filter eklendi; iOS
    `mentoria` şeması zaten kayıtlı).
  - Web/üretim adresi `--dart-define=APP_LINK_BASE=https://…` ile verilir.
- **Süper admin paneli:** `/platform`.
  - Dershane listesi; yeni dershane (ad, otomatik slug, iki renk, koltuk
    sayısı).
  - Hazır renkler + HEX girişi, logo yükleme (Storage) ve **canlı tema
    önizlemesi**.
  - Aktif/pasif anahtarı, müdür davet kodu ve dershane linki.
  - Yeni dershane açılınca ilk kurum müdürünün davet kodu ve linki gösterilir.

### Yeni metinler
Bütün yeni metinler `tr()` ile, İngilizceleri `strings_en.dart` içinde.
"Mentoria'ya yalnızca davetle…" metni artık dershane adını kullanıyor.

---

## 2. Öğrenci avatarı (Bitmoji tarzı)

### Veritabanı: `20261017140000_avatars.sql` (geri alma: `…_avatars.down.sql`)

- **`profiles.avatar`** (jsonb): ör. `{"hair": 4, "skin": 7, "outfit": 12, "accessory": 15}`.
  Değerler `avatar_items.id`. Görsel üretilmez, Storage'a resim yüklenmez.
- **`avatar_items`**: `id, category, asset_name, unlock_rule, sort, is_active`.
  Açılma koşulları (`unlock_rule`) **burada**, uygulamada değil:
  - `{"type":"free"}`
  - `{"type":"streak","days":7}`: en uzun çalışma serisi
  - `{"type":"net","exam_type":"TYT","value":60}`: bir denemede toplam net
  - `{"type":"badge","badge":"questions_1000"}`: uygulamadaki rozet
    anahtarları (`first_step`, `streak_3`, `questions_100`, `first_exam`,
    `streak_7`, `focus_master`, `topic_hunter`, `questions_1000`, `streak_30`,
    `question_machine`)
- **`user_unlocked_items`**: öğrencinin açtığı parçalar. Yalnızca sunucu yazar
  (`claim_avatar_unlocks()`); istemci ekleyemez.
- **Koruma** (`guard_avatar` tetikleyicisi):
  - Yalnızca öğrenci ve yalnızca kendi avatarını değiştirebilir.
  - Bilinmeyen alan, yanlış kategori ya da sayı olmayan değer reddedilir.
  - **Kilitli parça kuşanılamaz.**
- **Sıralama** (`avatar_leaderboard(limit, offset)`):
  - Aynı dershanedeki öğrenciler, son 7 günün soru sayısına göre.
  - Sayfalı (en fazla 50). Yalnızca **ad + soyadın baş harfi**, avatar JSON'u
    ve puan döner.
  - Realtime yok.
- **Başkasının avatarı:** yalnızca aynı dershane içinde (sıralama
  fonksiyonuyla); profiller tablosundan okunamaz.
- **Hesap silme:** profil silinince avatar ve açılan parçalar da silinir
  (cascade).
- **Başlangıç seti:** 5 saç, 4 ten (hepsi ücretsiz), 5 kıyafet, 3 aksesuar.

### Yeni parça eklemek
1. SVG'yi `assets/avatar/<kategori>/<asset_adı>.svg` olarak ekle (200×200,
   diğer katmanlarla hizalı).
2. Tabloya bir satır ekle:
   ```sql
   insert into public.avatar_items (id, category, asset_name, unlock_rule, sort)
   values (18, 'hair', 'hair_mohawk', '{"type":"streak","days":14}', 6);
   ```

Başka kod değişikliği gerekmez. `test/avatar_test.dart`, migration'daki her
parçanın asset dosyasının var olduğunu denetler.

### Görseller (geçici)
`assets/avatar/` altındaki 17 SVG **geçici placeholder**'dır: maskot stilinde
basit şekiller (kalın koyu kontur, canlı renkler). Gerçek çizimler geldiğinde
aynı adla değiştirilmesi yeterli. Yol ve uzantı tek yerde:
`AvatarAssets` (`lib/features/avatar/data/avatar_models.dart`). PNG'ye geçmek
için yalnızca `extension` ve `AvatarLayer` değişir.

### Uygulama
- **`StudentAvatar`**: tek yeniden kullanılabilir widget. Katmanlar
  `Stack` ile çizilir: ten → kıyafet → saç → aksesuar. Ana sayfa (üst çubuk ve
  "Haftanın arıları" kartı), profil, sıralama ve editör bunu kullanır.
- **Editör** (`/student/avatar`):
  - Saç / Ten / Kıyafet / Aksesuar sekmeleri ve anlık önizleme.
  - Kilitli parçada koşul metni (kural verisinden üretilir), "Kaydet" düğmesi.
  - Kaydedilmemiş değişiklikle çıkarken onay sorulur.
- **Sıralama** (`/student/leaderboard`): sayfa sayfa yüklenir, aşağı çekince
  yenilenir.
- **Kilit açma:** oturumda bir kez `claim_avatar_unlocks` çağrılır. Yeni
  parça açıldıysa ana sayfada "Gör" düğmeli bir bildirim ve editörde konfeti
  çıkar.
- **KVKK:** fotoğraf ya da yüz verisi alınmaz. Editörde bu açıkça yazıyor.

---

## 3. Testler ve kontroller

- `flutter analyze`: **sorun yok**.
  - `M:\` gibi bir sürücü kökünde Flutter aracı çöküyor (araçtaki bir JSON
    hatası). Kökü olmayan bir yoldan çalıştırın: `subst N: "…\Masaüstü"`,
    sonra `N:\Mentoria` içinde `flutter analyze`.
- `flutter test`: **64 test geçti**. Yeni dosyalar:
  - `test/branding_test.dart`: marka ayrıştırma, renk türetme, çalışma
    anında tema değişimi, yüklenirken/hatada Mentoria, slug ile giriş, süper
    admin akışı.
  - `test/avatar_test.dart`: avatar JSON, katman sırası, editör, kilitli
    parça, sıralama, asset denetimi.
- **SQL testleri** (`supabase/tests/`, PGlite ile; Supabase gerekmez):
  ```bash
  cd supabase/tests && npm install && npm test
  ```
  - `rls_test.mjs` (62): mevcut RLS kuralları.
  - `tenant_test.mjs` (46): geçiş, dershaneler arası izolasyon, çapraz yazma
    engeli, süper admin, pasif dershane, **geri alma ve yeniden uygulama**.
  - `avatar_test.mjs` (29): kilit kuralları, kuşanma koruması, sıralama
    izolasyonu ve sayfalama, hesap silme, geri alma.
- **Demo ile görsel kontrol:**
  - `--dart-define=DEMO=true --dart-define=DEMO_TENANT=yildiz`: öğrenci
    paneli "Yıldız Dershanesi" markasıyla açılır.
  - `DEMO_ROLE=admin`: dershane yönetim paneli (`/#/platform`).

## 4. Dikkat edilecekler / yapılmadı

- **Canlıya alma:** yapıldı (bkz. en üstteki durum). Uygulamadan önce kurumsuz
  kullanıcı ya da sahipsiz kayıt olmadığı kontrol edildi. Advisors'ta yeni bir
  RLS açığı yok; uyarılar, içinde yetki kontrolü yapan kasıtlı RPC
  fonksiyonlarına ait. Geri almak gerekirse rollback dosyaları ters sırayla
  (14 → 13 → 12 → 11 → 10) çalıştırılır.
- **Ana sayfa avatarı:** öğrencinin avatarı gökyüzü başlığının ortasında
  hafifçe süzülür; dokununca avatar editörü açılır. Katalog yüklenemezse boş
  daire yerine yüz simgesi görünür.
- **Kod biçimi:** `dart format` tüm projeye uygulandı. Birçok dosyada yalnızca
  satır düzeni değişti; Cursor'da açık değişiklik varsa birleştirirken dikkat.
- **Kasıtlı olarak sabit kalan renkler** (markadan bağımsız illüstrasyon):
  - Bızz maskotu
  - Gökyüzü başlığı (sabah/akşam/gece)
  - Seri alevi
  - Konfeti ve madalya (altın/gümüş/bronz) renkleri
- **Sıralamada gizlilik:** öğrenciler sıralamadan çıkma seçeneğine şu an sahip
  değil. Gerekirse `profiles` tablosuna bir tercih kolonu eklenebilir.
- **iOS evrensel link / Android App Links** (https ile açılan linkler) için
  alan adı doğrulaması yapılmadı; şimdilik `mentoria://app/...` ve web
  linkleri çalışıyor.
- Davet linkini başkasıyla paylaşmak, kodu paylaşmakla aynı güvenliktedir
  (kod tek kullanımlık ya da sınırlı kullanımlık).

---

## 5. Telefon bildirimleri (Firebase Cloud Messaging)

Koç ödev, görev ya da not gönderince veya deneme sonucu girilince, öğrencinin
telefonuna uygulama kapalıyken de bildirim gider. Uygulama açıkken zaten
uygulama içi kart (InAppNotifier) gösterildiği için ayrıca bildirim çıkmaz.

**Akış:**
1. `notifications` tablosuna kayıt düşer (mevcut tetikleyiciler).
2. `push_on_notification` tetikleyicisi `send-push` Edge Function'ını pg_net
   ile çağırır; yalnızca bildirim id'si gönderilir.
3. Fonksiyon bildirimi ve kullanıcının cihaz adreslerini (service role ile)
   okur, FCM HTTP v1 ile gönderir. Geçersiz adresleri siler.

**Firebase projesi:** `mentoria-4939f`
- Android `com.mentoria.mentoria` → `android/app/google-services.json`
- iOS `com.mentoria.mentoria` → `ios/Runner/GoogleService-Info.plist`

**Dosyalar**
- `supabase/migrations/20261017150000_push_tokens.sql`: `device_tokens`
  tablosu ile `register_device_token` / `unregister_device_token`.
  - Kullanıcı yalnızca kendi adreslerini görür; aynı cihazda başka hesapla
    giriş yapılınca adres yeni kullanıcıya geçer.
  - Kullanıcı başına en fazla 10 cihaz; hesap silinince adresler de silinir.
  - Dershane izolasyonu var.
- `supabase/migrations/20261017160000_push_webhook.sql`: tetikleyici.
  - Adres ve parola **Vault**'tan okunur: `push_function_url`,
    `push_webhook_secret`. Bunlar yoksa hiçbir şey yapmaz.
  - Gönderim hatası bildirim kaydını asla engellemez.
- Geri alma: `supabase/rollbacks/20261017160000_push_webhook.down.sql`, sonra
  `…150000_push_tokens.down.sql`.
- `supabase/functions/send-push/index.ts`: gönderen fonksiyon.
  - JWT doğrulaması kapalı deploy edilir; yetki `x-push-secret` başlığıyla.
- `lib/features/notifications/push/push_service.dart`: uygulama tarafı.
  - Firebase'i başlatır (web/demo'da atlanır; hata olursa uygulama
    bildirimsiz devam eder).
  - İzin ister, adresi kaydeder; çıkıştan önce siler
    (`AuthRepository.beforeSignOut`).
  - Bildirime dokununca ilgili ekranı açar: ödev, deneme ya da ana sayfa.
- iOS ayarları: `Runner.entitlements` (`aps-environment`), Info.plist'te
  `UIBackgroundModes: remote-notification`, plist Xcode projesine eklendi.

**Gizli değerler** (koda ya da sohbete yazılmaz)
- `FCM_SERVICE_ACCOUNT`:
  - Kaynak: Firebase → Project settings → Service accounts → "Generate new
    private key" ile inen JSON'un tamamı.
  - Nereye: Supabase → Edge Functions → Secrets.
- `PUSH_WEBHOOK_SECRET`:
  - Rastgele bir parola.
  - Aynı değer Vault'ta `push_webhook_secret` olarak da durur.

**Durum**
- Kod, migration'lar ve fonksiyon yazıldı.
- Testler:
  - `flutter test`: 64 test geçti.
  - SQL `push_test.mjs`: 18 test geçti.
  - Android debug APK Firebase ile derlendi.
- **Canlıda (16 Ekim 2026):** migration'lar, Edge Function, Vault ayarları ve
  `FCM_SERVICE_ACCOUNT` kurulu; gerçek cihaza gönderim doğrulandı.

**Kısıtlar ve notlar**
- **iOS:**
  - Apple Developer hesabı (yıllık 99$) ve APNs anahtarı (.p8) Firebase'e
    yüklenmeden iPhone'a bildirim gitmez.
  - iOS derlemesi Mac gerektirir. Kod hazır.
- **Web:** telefon bildirimi yok (VAPID anahtarı alınmadı); web'de uygulama içi
  bildirimler çalışır.
- **Bildirim dili:** Telefon bildirimlerinin metni şimdilik Türkçe; dil tercihi
  cihazda tutulduğu için sunucu bilmiyor.
- **firebase_messaging 17:** klasik `getToken` API'sini yeni FID tabanlı
  `register()/onRegistered` lehine kullanımdan kaldırılmış işaretliyor. FCM
  HTTP v1 hâlâ registration token'ı hedef aldığı için bilerek eski API
  kullanılıyor. Paket bu API'yi kaldırırsa ikisi birlikte güncellenmeli.
- **Proje yolu ve Android derleme:**
  - Proje yolundaki "ü" (Masaüstü) Android derlemesini `C:` yolundan
    engelliyor: AGP "non-ASCII path" hatası veriyor.
  - Android'i ya `M:` (subst) sürücüsünden çalıştırın ya da projeyi ASCII bir
    klasöre (ör. `C:\dev\mentoria`) taşıyın.
  - `M:`'den derlerken Kotlin artımlı önbelleği farklı sürücülerde bozulduğu
    için `android/gradle.properties` içinde `kotlin.incremental=false`
    ayarlandı.

---

## 6. Hesap silme ve veli kodu kuralları

**Migration:** `20261017170000_account_rules.sql`. Geri alma
`…_account_rules.down.sql` önceki fonksiyonları birebir geri yükler.

- **Öğrenci kendi hesabını silemez.** `delete_my_account` öğrenci için
  `STUDENT_DELETE_BY_COACH` hatası verir. Öğrenci silmeyi **talep eder**
  (aşağıda "Hesap silme talebi").
- **Koç öğrencinin hesabını siler:**
  - Fonksiyon: `delete_student_account(öğrenci)`.
  - Yetki: yalnızca o öğrencinin koçu ya da kurumunun müdürü
    (`can_manage_student`). Başka koç `NOT_ALLOWED`, öğrenci olmayan hesap
    `NOT_A_STUDENT` hatası alır.
  - Hesap ve tüm veriler cascade ile silinir.
  - Arayüz: öğrenci detayında sağ üst menü → "Öğrenci hesabını sil"; "SİL"
    yazmadan onaylanmaz.
- **Veli davet kodu 30 gün** geçerli; öğrenci, koç ve müdür kodları 14 gün.
- **Canlı (16 Ekim 2026):** `account_rules` migration'ı canlı projeye uygulandı ve
  doğrulandı: öğrencinin kendi hesabını silmesi engelleniyor, veli kodu 30 gün,
  `delete_student_account` giriş yapmayanlara kapalı. Bildirim (push)
  migration'ları ve fonksiyonu da sonradan canlıya alındı.
- **Testler:**
  - SQL `rls_test.mjs`: 67 test (kurallar için 5 yeni kontrol).
  - `flutter test`: 66 test (2 yeni widget testi).

**Mağaza uyumu (çözüldü, canlıda):** Apple (Guideline
5.1.1(v)) ve Google Play, kullanıcının hesap silmeyi uygulama içinden
**başlatabilmesini** istiyor. Öğrenci artık profilden "Hesabımın silinmesini
iste" ile talep açıyor; silme kararı yine koçta (bkz. bölüm 7). İnceleme
notuna şunu yazmak faydalı: "Öğrenci hesabı, öğrencinin talebiyle koçu
tarafından silinir; talep Profil → Güvenlik → Hesabımın silinmesini iste."
Google Play için ayrıca web'den silme talebi bağlantısı istenir; o kısım
yapılmadı.

**Diyalog hatası (düzeltildi):** Profildeki kendi hesabını silme ve şifre
değiştirme diyaloglarının metin denetleyicileri artık diyalog widget'larının
State'inde (`_DeleteAccountDialog`, `_ChangePasswordDialog`); kapanış
animasyonu bittikten sonra serbest bırakılıyor. Widget testi:
"hesap silme diyaloğu kapanırken denetleyici hatası yok".

---

## 7. Hesap silme talebi

**Migration:** `20261017180000_account_deletion_requests.sql`. Geri alma:
`supabase/rollbacks/20261017180000_account_deletion_requests.down.sql`
(önce bu türdeki bildirimleri siler, sonra eski bildirim türü kısıtını geri
koyar).

- **Tablo `account_deletion_requests`** (`student_id` birincil anahtar,
  `tenant_id`, `requested_at`).
  - Öğrencinin aynı anda tek talebi olur.
  - `tenant_id` `set_tenant_id` ile sunucuda dolar; RESTRICTIVE dershane
    izolasyonu var.
  - Öğrenci kendi talebini, koçu / kurum müdürü öğrencilerinin taleplerini
    görür (`can_manage_student`). Başka koç, öğrenci ya da dershane görmez.
  - Doğrudan ekleme/güncelleme yok. Öğrenci kendi talebini silerek **geri
    alabilir**; koç talebi silemez (kararı hesabı silmektir).
  - Öğrenci silinince talep cascade ile gider.
- **RPC `request_account_deletion()`** (security definer, yalnızca öğrenci):
  - Talep açar; tekrar çağrıda `ALREADY_REQUESTED` (uygulama bunu başarı
    sayar).
  - Öğrencinin koç(lar)ına `deletion_request` bildirimi düşer (öğrenci adı ve
    `/coach/students/<id>` rotası). Koçu yoksa kurum müdür(ler)ine
    (`/admin/students/<id>`).
  - Geri al / yeniden iste döngüsüyle bildirim yağmasın diye aynı öğrenci
    için 24 saatte en fazla bir bildirim.
- **Bildirim türü:** `notifications.kind` kısıtına `deletion_request`
  eklendi. `send-push` Edge Function'ı bu türün metnini ve rotasını
  biliyor (**yeniden deploy gerekir**). Koçların uygulama içi bildirim zili
  yok; koça bildirim telefon bildirimiyle gider, uygulamada rozet görünür.
  Uygulama tanımadığı bildirim türlerini artık atlıyor (çökmüyor).
- **Arayüz:**
  - Öğrenci: Profil → Güvenlik → "Hesabımın silinmesini iste" → onay →
    "Talebin koçuna iletildi". Bekleyen talepte tarih ve "Geri al".
  - Koç / müdür: öğrenci detayında sekmelerin üstünde kırmızı "Hesap silme
    talebi" şeridi ve "Hesabı sil" kısa yolu (mevcut "SİL" yazmalı diyalog);
    sağ üst menü simgesinde rozet.
- **Testler:**
  - SQL `deletion_request_test.mjs`: 29 test (talep, tekrar engeli, görünürlük,
    izolasyon, koçsuz öğrenci → müdür, 24 saat sınırı, cascade, geri alma ve
    yeniden uygulama). `npm test` artık bunu da çalıştırıyor.
  - `flutter test`: 69 test (talep + geri alma, diyalog kapanışı, koç
    şeridi, talep yoksa şerit yok).
- **Canlıda** (16 Ekim 2026).
- **Yapılmadı:** koç ana sayfasındaki öğrenci listesinde talep rozeti; Google
  Play'in istediği web üzerinden silme talebi sayfası.

---

## 7. Kurum müdürü: kurum görünümü (logo, renk, ad)

Kurum müdürü artık kendi kurumunun markasını yönetir. Süper admine gerek
yok.

- **Nereden:** Müdür paneli → kurum kartı → **"Kurum görünümü: logo ve
  renkler"** (`/admin/branding`). Kurum adı, iki renk ve logo değiştirilebilir;
  canlı önizleme vardır. Slug, aktiflik ve müdür davet kodu yalnızca süper
  admin ekranında.
- **Kurum adı eşitleme:** Müdür adı ister bu ekrandan ister kurum kartındaki
  kalemden değiştirsin, marka adı da değişir (dershanenin tek kurumu varsa;
  çok şubeli dershanede şube adı markayı değiştirmez).
- **Koç ve öğrenciler:**
  - Koç, veli ve müdür ekranlarının üst çubuğunda kurum logosu ve adı
    görünür.
  - Öğrenci ana sayfasında tarih satırında kurum adı yazar ("16 Ekim Cuma ·
    Bal Akademi").
  - Değişiklik uygulama yeniden açılınca ya da sayfa aşağı çekilip
    yenilenince gelir.
- **Güvenlik:**
  - `update_my_branding` yalnızca müdür için ve yalnızca kendi dershanesinde
    çalışır.
  - Logo adresi yalnızca kendi dershanesinin Storage klasöründen
    (`tenant-logos/<tenant_id>/…`) olabilir; dış adres reddedilir.
  - Storage'da müdür yalnızca kendi klasörüne yazabilir.
- **Migration:** `20261017190000_admin_branding.sql` (geri alma:
  `…_admin_branding.down.sql`).
  - Diğer oturumun `20261017180000_account_deletion_requests.sql` dosyasıyla
    aynı zaman damgasını almasın diye 19 olarak adlandırıldı.
- **Testler:**
  - SQL `branding_test.mjs`: 18 test.
  - `flutter test`: 70 test (müdür akışı için yeni widget testi).
- **Canlıda** (16 Ekim 2026).

---

## 6. Başarı sıralaması (kurum içi, deneme netine göre)

Müdür **Genel** sekmesindeki anahtarla açar (`set_success_ranking`). Kapalıyken
öğrenci ve koç sıralamayı göremez; müdür önizleyebilir.

- **Puan:** öğrencinin o türdeki **son 5 denemesinin ortalama toplam neti**
  (en az 1 deneme). TYT ve AYT ayrı sıralanır; AYT alan alan (SAY/EA/SÖZ/DİL).
- **Ödüller** yalnızca **TYT** sırasından gelir (kurumda tek "1." olsun diye)
  ve **kalıcı değildir**: öğrenci sırasını kaybedince ödül de gider,
  sıralama kapatılınca hepsi kalkar. Beraberlikte iki öğrenci de aynı ödülü alır.
  - 1.: kral tacı (+ altın kanatlar)
  - 1–3.: altın arı kanatları
  - 4–5.: gümüş arı kanatları
- **Görünüm:** Öğrenci ana sayfasında kart yok; sıralama açıksa üst çubukta
  profilin yanında kupa düğmesi çıkar (ödülü varsa altın renkte).
- **Gizlilik:** Sıralamada yalnızca adın ilk iki harfi döner ("El***";
  `ranking_short_name`, `…_success_ranking_short_names.sql`). Haftalık soru
  sıralaması "Elif Y." olarak kalır.
- Ödül avatar JSON'unda tutulmaz. Sunucu `reward_rank` döndürür
  (`my_success_status`, `success_leaderboard`, `avatar_leaderboard`);
  `StudentAvatar(reward: …)` kanatları en alta, tacı en üste çizer.
  Görseller: `assets/avatar/reward/`.
- **Dosyalar:** `supabase/migrations/20261017200000_success_ranking.sql`
  (geri alma: `rollbacks/…_success_ranking.down.sql`; haftalık sıralama eski
  haline döner), `lib/features/ranking/`, SQL testi
  `supabase/tests/success_ranking_test.mjs`, widget testi `test/ranking_test.dart`.
- **Canlıya uygulandı (16 Ekim 2026).** Kurumlarda varsayılan olarak kapalı;
  müdür açana kadar öğrenciler görmez.
- Aynı gün canlıda eksik olan `push_tokens`, `push_webhook`,
  `account_deletion_requests` ve `admin_branding` de uygulandı; `pg_net`
  `extensions` şemasına alındı (`…_pg_net_extensions_schema.sql`). Canlıda
  artık depodaki 18 migration'ın hepsi var.
- **Telefon bildirimleri kuruldu (16 Ekim 2026):** `send-push` deploy edildi
  (`verify_jwt = false`); Vault'ta `push_function_url` ve
  `push_webhook_secret`, Edge Function Secrets'ta `PUSH_WEBHOOK_SECRET` ve
  `FCM_SERVICE_ACCOUNT` var. pg_net ile sahte bildirim kimliği → 200
  ("bildirim yok"); yanlış parola → 401. Gerçek telefona gönderim de
  doğrulandı (görüşme hatırlatması, `sent: 1`).

### Avatar çizimleri
17 parça yeniden çizildi (gölgeli yüz, gözlerde parlama, saçta ışık, desenli
kıyafetler). Hepsi aynı 200×200 hizada; adlar değişmedi. Görsel kontrol:
`flutter test test/tool/avatar_preview_test.dart` → `build/avatar_preview.png`.

---

## 7. Koç ve müdür panelleri, deneme yüklemeleri

### Görünüm
Koç ana sayfası ve müdürün Genel sekmesi öğrenci paneliyle aynı dilde:
gökyüzü başlığı ve konuşan Bızz (`ManagerSkyAppBar`), renkli özet kutuları
(`GlowStat`), hızlı işlemler ve öğrenci kartları (`StudentCard`: renkli baş
harf rozeti, bu hafta aktif noktası, haftalık ilerleme çubuğu). Ortak parçalar:
`lib/features/coach/presentation/manager_widgets.dart`.

### Denemeler ekranı (`/coach/exams`, `/admin/exams`)
- Migration: `20261017230000_exam_batches.sql` (geri alma: `…_exam_batches.down.sql`).
- `exams.batch_id`: bir Excel yüklemesindeki tüm öğrencilerin denemeleri tek
  paket. Elle girilen deneme kendi paketi. Eski yüklemeler aynı giren + ad +
  tür + alan + tarih + giriş saatine göre pakete toplandı.
- **7 günlük düzeltme süresi:** deneme girildikten 7 gün sonra kimse silemez
  ya da değiştiremez (RLS + `delete_exam_batch`). Uygulamada deneme detayında
  da kilit görünür.
- `delete_exam_batch`: kendi yüklediğin paketi içindeki tüm öğrencilerden
  siler; "Deneme sonucun geldi" bildirimleri de gider. Ekranın üstündeki
  "Son denemeyi herkesten sil" bunu en son yüklemeye uygular.
- Yalnızca kendi yüklediklerin listelenir; müdür koçun yüklemesini bu yolla
  silemez.
- SQL testi: `supabase/tests/exam_batches_test.mjs`; widget testi:
  `test/exams/exam_batches_test.dart`.
- **Canlıya uygulandı (16 Ekim 2026).** O an canlıdaki 3 deneme elle
  girilmişti ve hepsi 7 günden yeniydi; her biri kendi paketi oldu.
- Telefondaki eski APK: Excel yüklemesi paket kimliği göndermez, her öğrencinin
  denemesi ayrı satır olarak görünür; deneme detayındaki "Sil" 7 günden eski
  denemede hiçbir şey silmeden kapanır. Yeni APK ile ikisi de düzelir.

---

## 8. Öğrenci sekmeleri ve veli paneli: yeni tasarım dili

Koç/müdür panelleriyle aynı görsel dil artık her yerde.

- **Ortak parçalar** `lib/shared/widgets/panel.dart`'a taşındı: `GlowStat`,
  `PanelSectionTitle`, `PanelNotice`, `InfoPill`, `InitialsAvatar`,
  `ProfileInitialsButton`, `QuickActionTile`, `staggered`.
  `manager_widgets.dart` bunları yeniden dışa aktarır (eski importlar çalışır).
- **`SkyAppBar`** (`home_sky.dart`): alt sayfalar için ince, canlı gökyüzü üst
  çubuğu (Bızz'sız). İsteğe bağlı sekme çubuğu gökyüzü üzerinde okunur renkte.
- **Ortak sekmeler** (`ExamsView`, `QuestionsView`, `TopicsView`,
  `StudyStatsSection`): eski `StatTile` yerine `GlowStat`, bölüm başlıkları
  `PanelSectionTitle`, kartlar sırayla süzülerek gelir. Öğrenci, veli ve
  koçun öğrenci detayı aynı parçaları kullandığı için üçü birden değişti.
  Öğrencinin Denemeler/Soru/Konular/Süre ekranlarında `SkyAppBar` var.
- **Veli ana sayfası**: koç ana sayfasıyla aynı düzen. Gökyüzü başlığında
  konuşan Bızz (çocuğun haftası), 5 renkli özet kutusu, "Ayrıntılar" hızlı
  geçişleri, hedefler, görevler, ödevler. Birden çok çocukta üstte seçim
  çipleri.
- **Yeni rota** `/parent/child/:id?tab=0..3`: `ParentChildScreen`
  (Denemeler · Sorular · Konular · Süre sekmeleri, salt okunur).
- **Yapılmadı:** koçun öğrenci detay ekranının üst çubuğu hâlâ düz `AppBar`
  (içerik yeni tasarımda).

---

## 9. Koç–öğrenci görüşmeleri

Koç her öğrencisi için görüşme planlar: **haftalık rutin** ("Ahmet ile her
salı 11:00") ya da **tek seferlik**. Öğrenci, velisi ve kurum müdürü görür.

- **Migration:** `20261018100000_meetings.sql` (geri alma:
  `rollbacks/20261018100000_meetings.down.sql`). SQL testi:
  `supabase/tests/meetings_test.mjs` (46 kontrol; `npm test` çalıştırır).
- **Tablolar:**
  - `meeting_schedules`: plan (ilk tarih, saat, süre, haftalık mı, bitiş
    tarihi, not). Yalnızca öğrencinin koçu ekler/değiştirir/siler; görme
    `can_view_student` (öğrenci, veli, koç, müdür). Dershane izolasyonu var.
  - `meeting_occurrences`: tek bir günün görüşmesi: durum (`held`/`missed`/
    `cancelled`) ve `reminded_at`. Doğrudan yazma yok; koç
    `set_meeting_status(plan, gün, durum)` ile işaretler. Gelecekteki görüşme
    yalnızca iptal edilebilir.
- **Saatler Türkiye saatidir** (`Europe/Istanbul`). Uygulama cihaz saatinin
  aynı olduğunu varsayar.
- **24 saat önce bildirim:** `send_meeting_reminders()` görüşmesine 24 saatten
  az kalan öğrenciye `meeting` bildirimi ekler (aynı görüşme için bir kez,
  iptal edilene hiç). Bildirim mevcut push tetikleyicisiyle telefona gider.
  Zamanlayıcı **pg_cron** (`meeting-reminders`, 10 dakikada bir); migration
  pg_cron'u kurar. `send-push` bu türün metnini biliyor (**yeniden deploy
  gerekir**).
- **Rutini bitirme:** hiç işaretlenmemiş ve başlamamış görüşme silinir; yoksa
  `until_date = bugün` olur, geçmiş kayıtlar müdür raporunda kalır.
- **Arayüz:**
  - Koç: öğrenci detayı → Özet → "Görüşmeler" kartı ("Görüşme ekle", rutini
    bitir, bu haftanın görüşmesini işaretle). Ana sayfada "Bu haftaki
    görüşmeler" (dokununca yapıldı / yapılmadı / iptal).
  - Öğrenci: ana sayfada sayacın altında "Koçunla görüşme" kartı (sıradaki
    görüşme). Bildirim: "Yarın 11:00 · Ayşe Koç ile görüşmen var".
  - Veli: ana sayfada salt okunur "Görüşmeler" kartı.
  - Müdür: Genel sekmesinde "Koç görüşmeleri": her koç için haftanın
    görüşmeleri, "x / y yapıldı", önceki haftalara geçiş.
- **Canlı (16 Ekim 2026):** migration uygulandı (`meetings`). pg_cron kuruldu,
  `meeting-reminders` işi 10 dakikada bir çalışıyor; `send_meeting_reminders()`
  canlıda hatasız döndü (henüz plan yok, 0 bildirim). Advisors'ta yeni RLS
  açığı yok; `set_meeting_status` uyarısı kasıtlı (yetkiyi kendisi denetler).
  `send-push` sürüm 2 deploy edildi (`verify_jwt = false`); sahte bildirim
  kimliğiyle 200 "bildirim yok". İlk gerçek hatırlatma 19:10'da cron ile
  gönderildi ve FCM kabul etti.

---

## 10. Bal kavanozu zamanlayıcı ve yeni alt menü

- **`HoneyDial`** (`lib/features/tracking/presentation/honey_dial.dart`):
  Pomodoro / kronometre halkasının içi bal dolu bir kavanoz. Pomodoroda süre
  azaldıkça bal azalır, molada kavanoz yeniden dolar, kronometrede süre
  arttıkça bal yükselir (saatte bir başa döner). Yüzey dalgalanır, kabarcıklar
  yükselir; dışta ince ilerleme halkası. Bal rengi sabit (markadan bağımsız
  illüstrasyon). Görsel kontrol:
  `flutter test test/tool/honey_dial_preview_test.dart` →
  `build/honey_dial_preview.png`.
- **`HoneyNavBar`** (`lib/shared/widgets/honey_nav_bar.dart`): öğrenci, koç ve
  müdür (dar ekran) alt menüsü. Yüzen yuvarlak bar, silik petek dokusu,
  seçili sekmede bal rengi petek gözü. Ekran okuyucu için her düğme
  `button + selected` ve dokunma eylemi taşır (`test/honey_nav_bar_test.dart`).
  Müdürün geniş ekrandaki `NavigationRail`'i değişmedi.

---

## 11. Kurum yazı tipi

Kurum müdürü "Kurum görünümü: logo, renk ve yazı tipi" ekranında 10 yazı
tipinden birini seçer; dershanedeki herkes uygulamayı o yazı tipiyle görür
(giriş ve davetle kayıt ekranı dahil). Süper admin de dershane düzenleme
ekranından değiştirebilir.

- **Yazı tipleri** (`lib/core/theme/app_fonts.dart`, Google Fonts), her biri
  ayrı tarzda: Nunito (yuvarlak, varsayılan), Poppins (geometrik),
  Merriweather (klasik tırnaklı), Playfair Display (zarif), Roboto Slab (kalın
  tırnaklı), Oswald (dar), Baloo 2 (tombul), Patrick Hand (el yazısı), Space
  Mono (daktilo), Exo 2 (fütüristik). Hepsi Türkçe karakterleri destekler.
  İlk liste (Montserrat, Inter, Roboto…) birbirine çok benzediği için
  `20261018120000_tenant_fonts_v2.sql` ile değiştirildi; listeden çıkan
  yazı tipini seçmiş dershane Nunito'ya döner.
- **APK boyutu:** yazı tipleri `GoogleFonts.getFont(ad)` ile değil, her biri
  kendi fonksiyonuyla (`AppFont.style` / `AppFont.textTheme`) çağrılır.
  Adla çağırmak Google Fonts'un tüm kataloğunu derlemeye ekliyordu: APK
  64 → 95,5 MB, web `main.dart.js` 13,1 MB. Düzeltmeden sonra web 5,0 MB.
- **Migration:** `20261018110000_tenant_fonts.sql` (geri alma:
  `rollbacks/…_tenant_fonts.down.sql`). `tenants.font_family` (kısıtlı
  liste, varsayılan `nunito`: mevcut görünüm değişmez). `tenant_branding` ve
  `check_invite` yazı tipini döndürür; `update_my_branding`'e
  `p_font_family` eklendi (null: değiştirme; listede yoksa `INVALID_FONT`).
  SQL testi: `supabase/tests/tenant_fonts_test.mjs` (19 kontrol).
- **Uygulama:** `Branding.font` → `BrandTheme.font` → `AppTheme` metinleri
  `GoogleFonts.getTextTheme` ile kurulur. Seçici: `FontPicker`
  (`lib/features/tenants/presentation/font_picker.dart`), her kutu kendi
  yazı tipiyle çizilir; önizleme kartı seçimi anında gösterir.
- `branding_test.mjs` geri alma adımı artık `update_my_branding`'i değiştiren
  sonraki migration'ları da (ters sırayla) geri alıp yeniden uygular.
- Demo: Yıldız Dershanesi (`DEMO_TENANT=yildiz`) Poppins kullanır.
- **v2 canlıda (16 Ekim 2026).** Mevcut dershane Plus Jakarta Sans
  seçmişti; listede olmadığı için Nunito'ya döndü. Telefondaki eski APK
  (mentoria-3) eski listeden yazı tipi seçerse `INVALID_FONT` alır; yeni APK
  ile düzelir.
- **Canlı (16 Ekim 2026):** migration uygulandı (`tenant_fonts`). Mevcut
  dershane `nunito` ile başladı; `tenant_branding` yazı tipini döndürüyor,
  `update_my_branding` 5 parametreli (anon çağıramaz). Eski APK 4 parametreyle
  çağırdığı için çalışmaya devam eder (yazı tipi değişmez). Advisors'ta yeni
  sorun yok.

---

## 12. Uygulama sesleri

- **Sesler uygulamaya özel ve telifsiz:** `tool/make_sounds.py` ile sentezlenir
  (`python tool/make_sounds.py assets/sounds`).
  - `assets/sounds/bizz_tap.wav`: Bızz'a dokununca kısa "bızzt" + iki tını.
  - `assets/sounds/intro.wav`: açılışta Bızz uçarak gelirken vızıltı, konunca
    çan arpeji (animasyonla eş zamanlı).
- **Çalar:** `lib/core/sound/app_sounds.dart` (`audioplayers`). Telefon
  sessiz/titreşimdeyse çalmaz (`respectSilence`), müzik çalarken onu
  durdurmaz. Hata olursa sessiz devam eder. Testlerde oynatıcı oluşturulmaz;
  `AppSounds.debugOnPlay` ile yakalanır (`test/sound_test.dart`).
- **Nerede çalar:** Bızz'a dokununca (öğrenci/koç/müdür gökyüzü başlığı ve
  etkileşimli tüm Bızz'lar) ve açılış animasyonunda ("hareketi azalt" açıksa
  açılış atlanır, ses de çalmaz).
- **Ses seviyesi:** ilk sürüm yüksek bulundu; çalma seviyesi dokunuşta 0,7 →
  0,35, açılışta 0,6 → 0,3 (yaklaşık −6 dB). `AppSound` içinde ayarlanır.
- **Ayar:** Profil → "Görünüm, dil ve ses" → **Sesler** anahtarı (cihazda
  saklanır, varsayılan açık). Açınca örnek ses bir kez çalar.
- **Web:** tarayıcılar kullanıcı dokunmadan ses çalmayı engelleyebilir; ilk
  açılışta açılış sesi web'de duyulmayabilir (telefonda sorun yok).
- **Derleme notu:** eklenti eklendikten sonra web derlemesi eski eklenti
  listesini önbellekten kullandı (`MissingPluginException`). Çözüm:
  `.dart_tool/flutter_build/*` içindeki web önbellek klasörlerini silip
  yeniden derlemek (`flutter clean` build/ içindeki APK'ları da sildiği için
  kullanılmadı).

---

## 13. Müdüre tam ad, pomodoro zili ve arka planda zamanlayıcı

### Başarı sıralamasında müdür tam adı görür
- Migration `20261018130000_ranking_admin_full_names.sql` (geri alma:
  `rollbacks/…_ranking_admin_full_names.down.sql`): `success_leaderboard`
  çağıran kurum müdürüyse tam adı, öğrenci ve koçsa "El***" döndürür.
  SQL testi `success_ranking_test.mjs` içinde. Demo da aynı davranır.
- **Canlı (16 Ekim 2026):** uygulandı; eski APK da tam adı gösterir (ad
  sunucudan geliyor).

### Pomodoro bitiş zili
- **5 zil + titreşim:** Bal Kavanozu, Arı Vızıltısı, Kristal, Marimba, Gong,
  Yalnızca titreşim. `tool/make_sounds.py` üretir; hem `assets/sounds/`
  (önizleme, web) hem `android/app/src/main/res/raw/` (bildirim sesi).
  `res/raw/keep.xml` release'te silinmelerini engeller.
- **Seçim:** Süre sekmesi → "Bitiş sesi" (dokununca dinletir). Cihazda
  saklanır (`AppSettings.pomodoroTone`, `pomodoro_tone`).
- **Nasıl çalar:** `PomodoroAlarm` (`lib/features/tracking/data/pomodoro_alarm.dart`,
  `flutter_local_notifications` + `timezone`). Başlatınca bitiş anına
  **zamanlanmış bildirim** kurulur → uygulama arka planda ya da kapalıyken de
  çalar. Molanın sonu için de kurulur. Android'de her zil ayrı bildirim
  kanalı (ses kanala bağlı), alarm ses seviyesinde çalar. Duraklat/bitir/molayı
  atla alarmı iptal eder. Bildirim kurulamazsa (web, izin yok) süre dolunca
  zili uygulama kendisi çalar.
- **Bildirim çubuğunda sayaç:** çalışırken geri sayan (kronometrede ileri
  sayan) sessiz "Odak · Ders" bildirimi.
- **Arka plan / kapanma:** zamanlayıcı durumu `pomodoro_state` anahtarıyla
  cihazda saklanır; uygulama açılınca geri yüklenir. Süre kapalıyken dolduysa
  oturum kaydedilir, mola odağın bittiği andan sayılır.
- **Android izinleri:** `SCHEDULE_EXACT_ALARM` (Android 14+'ta kullanıcı
  açmalı; açılmamışsa uygulama bir kez "Alarmlar ve hatırlatıcılar" iznini
  ister, yoksa zil birkaç dakika gecikebilir), `RECEIVE_BOOT_COMPLETED`,
  `VIBRATE`; manifest'te plugin alıcıları; Gradle'da core library desugaring.
- **iOS:** özel zil sesleri uygulama paketine eklenmedi (Mac/Xcode gerekir);
  iOS'ta varsayılan bildirim sesi çalar.
- **Test edilmeyen:** gerçek bir Android telefonda zamanlanmış bildirimin
  çalması ve Android derlemesi (yeni eklenti + desugaring). İlk APK
  derlemesinde doğrulanacak.

### Öğrenci sekmelerindeki alt sayfalar
- Süre/Soru/Konular/Denemeler sekmelerindeki alt sayfalar (`showModalBottomSheet`)
  alt menünün altında kalıyordu; artık `useRootNavigator: true` ile menünün
  üstünde açılıyor.

---

## 14. Genel kontrol (16 Ekim 2026)

- **Repo ↔ canlı:** depodaki tüm migration'lar canlıda. Ek olarak
  `20261018140000_meeting_marked_by_index.sql` (performans önerisi:
  `meeting_occurrences.marked_by` indeksi) eklendi ve canlıya alındı.
- **Mentoria'ya ait olmayan tablolar:** canlıda `create_consent_and_survey_tables`
  migration'ı var (`cookie_consents`, `survey_responses`: web sitesi çerez
  onayı ve anket; IP, şehir, tarayıcı bilgisi). Depoda yok, uygulama
  kullanmıyor, tablolar boş. Muhtemelen başka bir projeden yanlışlıkla bu
  projeye uygulanmış. Sorunlar: giriş yapmış **her kullanıcı** (öğrenciler
  dahil) satırları okuyabilir; giriş yapmayan herkes sınırsız satır ekleyebilir.
  **Silindi (16 Ekim 2026):** `20261018150000_drop_foreign_consent_survey_tables.sql`
  yalnızca tablolar boşsa siler (doluysa durur); tabloların olmadığı yeni
  kurulumlarda etkisizdir. Geri alma dosyası tabloları ilk halleriyle yeniden
  oluşturur. Canlıdaki migration geçmişinde `create_consent_and_survey_tables`
  kaydı durur (silinemez), ama tablolar artık yok.
- **"Kullanılmayan indeks" uyarıları** (35 adet): veri az olduğu için normal;
  yabancı anahtar ve dershane izolasyonu için gerekli, silinmedi.
- **Panelden açılması gereken ayar:** Authentication → "Leaked password
  protection" kapalı (sızmış şifreleri engeller). MCP ile açılamıyor.

---

## 15. Deneme sonucu yükleme: dosya okuma yeniden yazıldı

**Sorun:** Telefonda "Dosya okunamadı. Excel 97-2003 (.xls)…" hatası. Bu mesaj
her okuma hatasında çıkıyordu. Asıl sebep: `excel` paketi sıradan `.xlsx`
dosyalarında bile çöküyordu (kalın / renkli başlık + sayı biçimi →
"Null check operator used on a null value"); `.xls`, CSV, TXT hiç
desteklenmiyordu.

**Çözüm:** `lib/features/import/data/spreadsheet_reader.dart`
(`readSpreadsheet`). Biçim uzantıdan değil içerikten anlaşılır:
- `.xlsx`: XML doğrudan okunur (`archive` + `xml`); yalnızca değerler, stil ne
  olursa olsun. Beklenmedik yapıda `excel` paketi yedek olarak denenir.
- `.xls`: Excel 97-2003 (BIFF8) ve Excel 95 (BIFF5); OLE2 dosyası, paylaşılan
  metin tablosu (CONTINUE'ya bölünse de), sayı / RK / formül sonuçları.
- "XML Elektronik Tablo 2003" ve uzantısı .xls olan HTML tablolar.
- CSV / TXT: `;`, sekme, `,`, `|` kendiliğinden seçilir; UTF-8, UTF-16 ya da
  Windows-1254 (Türkçe) kodlama.
- Okunamazsa sebep ayrı söylenir: şifreli, boş, tablo değil, bozuk, dosya
  açılamadı (izin / bulut).

**Ekran:** her dosya seçilebilir (Android'de uzantı süzgeci bazı geçerli
dosyaları gri gösteriyordu). Ders sütunları en çok eşleşen sayfa ve sınav
türü kendiliğinden seçilir; Fizik / Kimya gibi iki türde de olan derslerde
soru sayısını aşmayan tür seçilir. Optik okuyucu kısaltmaları ("TRK D",
"FİZ Y", "KİM D"…) ve "Türkçe Doğru Sayısı" başlıkları tanınır.

**Testler:** `test/import/spreadsheet_reader_test.dart` (her biçim, Türkçe
karakter, hatalar), `test/import/import_screen_test.dart`. Örnek dosyalar
`test/fixtures/import/` (üretici: `make_fixtures.py`, xlwt + openpyxl).

**Doğrulanmayan:** kullanıcının telefonda hata aldığı asıl dosya elimizde
yok; o dosya `docs/ornek-sonuclar/` klasörüne konursa teste eklenebilir.
Düzeltme telefonda yeni APK ile gelir.

---

## 16. Uygulama simgesi: arı %25 büyütüldü

Android uyarlanabilir simgesinin ön katmanındaki arı küçük kalıyordu (katman
genişliğinin ~%40'ı). `assets/brand/icon/adaptive_foreground.png` arı 1,25
kat büyütülüp dikeyde ortalanarak yeniden üretildi; en uzak nokta (anten)
merkeze 322 px, launcher'ın gösterdiği alan 341 px yarıçap → yuvarlak ve
yuvarlatılmış kare maskelerde kesilmez. Sonra `dart run flutter_launcher_icons`
çalıştırıldı (Android mipmap / drawable dosyaları). `app_icon.png` (iOS, web,
Android 7 ve öncesi) değişmedi. Telefonda yeni APK ile görünür.

---

## 17. Kayıt: şifre tekrarı + e-posta doğrulama kodu

Davetle kayıt artık üç adım: **davet kodu → bilgiler → doğrulama**.

- Bilgiler adımı: şifre iki kez girilir ve eşleşmeli; e-posta biçimi
  denetlenir (`lib/features/auth/data/email_check.dart`), `gmial.com` gibi
  yazım hatalarında "Bunu mu demek istedin?" sorulur.
- Doğrulama adımı: Supabase Auth e-postaya 6 haneli kod yollar
  (`signUp`), uygulama `verifyOTP(type: signup)` ile doğrular; 60 sn sonra
  "Kodu yeniden gönder" (`resend`), "E-posta adresini değiştir" ile forma
  dönülür. Oturum kod doğrulanınca açılır.
- Veritabanı (`20261018160000_signup_after_email_confirm`): kayıt anında
  davet yalnızca **denetlenir**; profil, koç/veli ilişkisi ve davet
  kullanımı adres **doğrulanınca** yazılır. Olmayan bir adresle kaydolan
  biri daveti ve öğrenci koltuğunu harcayamaz. Test:
  `supabase/tests/signup_confirm_test.mjs`.
  **Canlıda** (16 Ekim 2026); panel adımları aşağıda, onlar yapılana kadar
  kayıt eskisi gibi anında tamamlanır.

### Panelde yapılacaklar (kod tarafı hazır)
1. **Authentication → Sign In / Providers → Email → "Confirm email" AÇIK.**
   (Şu an kapalı; kapalıyken kod adımı atlanır, kayıt eskisi gibi anında olur.)
2. **Authentication → Emails → Templates → "Confirm signup"**: konu ve gövde
   `supabase/templates/confirm_signup.html` içinden. Gövdede bağlantı değil
   `{{ .Token }}` olmalı.
3. **Özel SMTP (zorunlu):** Supabase'in yerleşik e-postası yalnızca proje
   ekibindeki adreslere ve saatte birkaç e-posta gönderir; gerçek
   kullanıcılar kodu alamaz. Seçim: **Resend** (ayda 3.000 / günde 100
   e-posta ücretsiz, Supabase ile resmi entegrasyonu var). Kendi alan adın
   (ör. `mentoria.app`) Resend'de doğrulanır (DNS'e SPF/DKIM kayıtları),
   sonra Authentication → Emails → SMTP Settings: host `smtp.resend.com`,
   port `465`, kullanıcı `resend`, şifre = Resend API anahtarı, gönderen
   `no-reply@<alan-adın>`. Alternatif: Brevo (günde 300 ücretsiz).
4. İsteğe bağlı: Authentication → Rate Limits'te e-posta sınırını SMTP
   planına göre yükselt.

---

## 18. Özel bildirim sesi + kulaklık düzeltmesi

- **Ses:** `mentoria_bildirim.wav` (kısa "bızt" + iki bal damlası tınısı,
  ~0,9 sn), `tool/make_sounds.py` üretir → `assets/sounds/` (uygulama içi
  kart) ve `android/app/src/main/res/raw/` (telefon bildirimi).
- **Android kanalı** `mentoria_bildirim`: `PushService.start` oluşturur,
  manifestte FCM'in varsayılan kanalı, `send-push` de `channel_id` olarak
  yollar. Android kanal sesini sonradan değiştirmeye izin vermez: ses
  değişirse kanal kimliği de değişmeli (ör. `mentoria_bildirim_2`; üç yerde,
  `test/sound_test.dart` eşleşmeyi denetler).
- Uygulama açıkken düşen bildirim kartı da aynı sesi çalar (Ayarlar → Sesler
  kapalıysa çalmaz).
- **iOS:** `apns.sound = mentoria_bildirim.wav`; dosya Xcode'da Runner
  paketine eklenene kadar iOS varsayılan sesi çalar.
- **Kulaklık sorunu:** `respectSilence: true` Android'de "zil sesi" yolunu
  seçiyordu; Android bu yolu kulaklık takılıyken hoparlörden de çalar.
  Sesler artık medya yolundan (`usageType: game`) çalar → yalnızca
  kulaklıktan. Sessiz/titreşim modu `MainActivity.kt` içindeki
  `mentoria/sound` kanalından okunur; o modda uygulama sesleri çalmaz.
- `send-push` v3 canlıda (16 Ekim 2026): özel kanal + ses ile gönderir.

---

## 19. Telefonu salla: Bızz değişimi

Öğrenci ana sayfasında telefon sallanınca yeni bir Bızz sol üstten dalarak
gelir, yerdeki Bızz'a çarpar (bal damlası + yıldız patlaması, güçlü titreşim,
"bonk" sesi), eski arı üzgün yüzle dönerek savrulur, yenisi yerine konar,
zıplayıp güler ve balonda bir cümle söyler ("Nöbet değişimi!…").

- **Sınır:** saatte en fazla 2 (`BizzSwapLimit`, SharedPreferences
  `bizz_swap_times`; uygulama kapanıp açılsa da geçerli). Hak dolunca arı
  başını sallar: "Arılar dinleniyor 😴 N dk sonra yine salla."
- **Algılama:** `ShakeDetector` (`lib/features/student/data/bizz_shake.dart`),
  `sensors_plus` yerçekimsiz ivme, ~15 Hz. 0,9 sn içinde 3 güçlü (≥14 m/s²)
  sarsıntı = sallama; yürüme, cebe koyma sayılmaz. Başlık kapalıyken, başka
  sekmedeyken, uygulama arka plandayken sayılmaz.
- **Animasyon:** `lib/shared/widgets/bizz_swap.dart` (1,7 sn, çarpma
  %32'de). İki arı aynı çizim; rolleri değişir, yerine konan arı sıçramaz.
  "Hareketi azalt" açıksa animasyonsuz: yeni arı doğrudan güler.
- **Ses:** `assets/sounds/bizz_bump.wav` (make_sounds.py `bump()`; çarpma
  sesi animasyondaki çarpma anına denk).
- Koç / müdür panelindeki gökyüzünde kapalı (`SkyHeader.swapLimit` yok).
- Önizleme: `flutter test test/tool/bizz_swap_preview_test.dart` →
  `build/bizz_swap_preview.png` (9 kare).

---

## 20. Avatar: 26 yeni parça ve başarım ödülleri

`20261018170000_avatars_more` (geri alma: `…_avatars_more.down.sql`):
17 → 43 parça. Ten 6, saç 14 (başörtüsü dahil), kıyafet 11, aksesuar 12.

**Yeni açılma kuralları** (`avatar_rule_met`, metinler `avatar_rule_text.dart`):
`questions {count}` toplam soru, `study_minutes {minutes}` toplam odak,
`topics {count}` bitirilen konu, `exams {count}` girilen deneme.

| Ödül | Koşul |
|---|---|
| Kalem (kulakta) | 250 soru |
| Örgü saç | 500 soru |
| Arı anteni | 2.000 soru |
| Altın saç | "Soru makinesi" rozeti (5.000 soru) |
| Güneş gözlüğü | 5 gün seri |
| İbikli saç | 14 gün seri |
| Galaksi saç | AYT'de 50 net |
| Forma (1 numara) | 5 deneme |
| Mezuniyet kepi | 10 deneme |
| Cübbe | 20 deneme |
| Laboratuvar önlüğü | 25 konu bitir |
| Astronot | 50 saat odaklan |
| Hale | 100 saat odaklan |

Ücretsiz yeniler: 2 ten, uzun / at kuyruğu / başörtüsü / afro / dalgalı saç,
okul forması, kazak, şapka, bere, çiçek, fiyonk.
Önizleme: `flutter test test/tool/avatar_parts_preview_test.dart` →
`build/avatar_parts_preview.png`. SQL testi: `avatars_more_test.mjs`.

---

## 21. Güvenlik denetimi (17 Ekim 2026)

**Denetlenen ve sorunsuz bulunan:** tüm tablolarda RLS açık; anon'a hiçbir
politika satır göstermiyor; e-postalar hiçbir RPC'den dönmüyor; öğrenci
profilde yalnızca güvenli kolonları (ad, avatar, alan, sınav yılı) yazabilir,
rolünü / kurumunu değiştiremez; müdür kurumda yalnızca adı değiştirebilir
(koltuk / lisans değil); Realtime yalnızca kişinin kendi bildirimleri;
logo deposunda listeleme kapalı, SVG yüklenemez (XSS yok), 1 MB sınırı;
anahtar dosyaları depoda yok (`env.json` .gitignore'da).

**Kapatılanlar** (`20261018180000_security_hardening`, test: `security_test.mjs`):
1. anon (giriş yapmamış) hiçbir tabloya doğrudan erişemez; yalnızca
   `check_invite` ve `tenant_branding` RPC'leri. Yeni tablolar da varsayılan
   olarak anon'a kapalı.
2. TRUNCATE / TRIGGER / REFERENCES istemci rollerinden kaldırıldı (TRUNCATE
   RLS'e takılmaz).
3. Dershane logosu yalnızca **bu projenin** Storage'ında, kendi klasöründen
   (eski denetim başka sunucudaki benzer bir yolu kabul ediyordu → öğrencilerin
   IP'si o sunucuya gidebilirdi). Tabloda da biçim denetimi var.
4. `handle_user_email_confirmed` dışarıdan çağrılamaz.
5. `profiles.avatar_url` (kullanılmıyor) istemciden yazılamaz.
6. Soru kaydı başına en fazla 1.500 soru (sıralama şişirilemez).

**Uygulama (Android):**
- Yedekleme kapalı (`allowBackup=false`, `data_extraction_rules.xml`): oturum
  anahtarı Google Drive / cihaz aktarımına girmez.
- Mağaza sürümünde `debugPrint` susturuldu (logcat'e hata ayrıntısı yazmaz).
- PKCE açıkça seçili: e-posta bağlantısını başka uygulama yakalasa da işe
  yaramaz.
- Mağaza imzası hazır: `android/key.properties` varsa onunla imzalanır
  (yoksa hata ayıklama anahtarı). Anahtar oluşturma:
  ```
  keytool -genkey -v -keystore C:nahtarlar\mentoria.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mentoria
  ```
  `android/key.properties`:
  ```
  storeFile=C:\anahtarlar\mentoria.jks
  storePassword=...
  keyAlias=mentoria
  keyPassword=...
  ```
  Anahtarı ve parolaları kaybetme (mağazada güncelleme yayınlanamaz); depoya
  koyma (.gitignore'da).
- Mağaza derlemesi kodu karıştırarak:
  `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json`

**Panelde yapılacaklar (Supabase → Authentication):**
1. *Leaked password protection* AÇ (sızdırılmış şifreler reddedilir).
2. Şifre: en az 8 karakter, harf + rakam zorunlu (uygulama zaten 8 istiyor).
3. *Confirm email* AÇ + özel SMTP (§17).
4. Canlı için ayrı bir Supabase projesi önerilir (geliştirme verisi
   karışmasın); orada Point-in-Time Recovery yedeği ve *SSL enforcement*
   açık olsun. Müdür / süper-admin hesapları için MFA düşünülebilir.

---

## 22. Haftanın Bal Raporu (Instagram hikayesi tarzı haftalık özet)

Öğrenci ana sayfasında parıldayan bir kart → tam ekran, kendiliğinden ilerleyen
hikaye (sağa dokun: sonraki, sola: önceki, basılı tut: durdur, üstte
ilerleme çubukları). Son 7 gün, ana sayfanın zaten yüklediği verilerden
hesaplanır (`WeekRecap.compute`, `lib/features/recap/`), ek sorgu yok.

Sayfalar (veri yoksa o sayfa atlanır):
1. Giriş: gece moru, Bızz, tarih aralığı.
2. Soru avı: dev sayaç, yağan bal damlaları, geçen haftaya göre %,
   "N doğru = X kavanoz bal".
3. Odak zamanı: dolan halka, saat/dk, pomodoro karşılığı.
4. Haftanın ritmi: 7 gün sütunu sırayla yükselir, en iyi güne taç.
5. Favori ders: ders adı + isabet halkası.
6. Deneme cephesi: deneme sayısı, en iyi net.
7. Arı tipi: dönen ışık huzmeleri önünde 3B dönerek gelen rozet + ses ve
   titreşim. Tipler: İstikrar (7/7 gün), Keskin Nişancı (%85+ isabet),
   Gece Kuşu (oturumların çoğu 21:00 sonrası), Sabahçı (09:00 öncesi),
   Maratoncu (ortalama 45+ dk), Soru Avcısı (varsayılan).
8. Özet kartı + konfeti: "Paylaş" kartı resim olarak paylaşır (share_plus),
   "Yeniden izle".

Boş haftada tek, cesaretlendiren sayfa. "Hareketi azalt" açıksa sayfalar
kendiliğinden geçmez. Önizleme: `flutter test test/tool/recap_preview_test.dart`
→ `build/recap_preview.png` (Windows yazı tipleriyle). Test: `test/recap_test.dart`.

---

## 23. Hata Defteri, Odak Bahçesi, veli haftalık raporu

**Hata Defteri** (`lib/features/mistakes/`, migration
`20261018190000_mistakes_and_parent_report`, test `mistakes_test.mjs`):
- Öğrenci yanlış yaptığı sorunun fotoğrafını (kamera / galeri, image_picker)
  ders, konu ve notla ekler. Tekrar aralıkları 1 → 3 → 7 → 21 gün; dördüncü
  doğru tekrardan sonra "öğrenildi", yanlışta başa döner. Kural sunucuda
  (`review_mistake`), aynısı `MistakeCard.reviewed` (demo / test).
- Fotoğraflar özel `mistake-photos` kovasında (`<öğrenci id>/...`, 2 MB).
  Yalnızca öğrenci yükler/siler; koç, müdür, veli görür (can_view_student).
- Her sabah 10:00'da (pg_cron `review-reminders`) tekrarı gelen öğrenciye
  tek bildirim (`review`).
- Ekranlar: `/student/mistakes` (özet, "N soruyu şimdi tekrar et", tekrar
  oturumu), ana sayfa kısayolu, koçun öğrenci ayrıntısında ve veli ekranında
  salt okunur "Hata Defteri" sekmesi + "En çok takıldığı yerler".
- Not: hesap silinince kartlar silinir ama kovadaki fotoğraflar kalır
  (Storage SQL ile silinmez); gerekirse dönemsel temizlik.

**Odak Bahçesi** (`lib/features/garden/`, yalnızca uygulama):
- Her çalışma oturumu bir çiçek: ders → cins (matematik papatya, Türkçe/
  edebiyat/dil lale, fen çan çiçeği, sosyal ayçiçeği, derssiz kozmos), süre
  → büyüklük (filiz / tomurcuk / çiçek / 50 dk+ parıltılı dev çiçek);
  20 dk'dan kısa pomodoro soluk. Rüzgârda sallanır, Bızz aralarında uçar,
  çiçeğe dokununca ayrıntı. Bu hafta / bu ay / tümü, paylaş.
- `/student/garden`; ana sayfa ve çalışma süresi ekranından; oturum
  kaydedilince "bahçende bir çiçek açtı" bildirimi.

**Veli haftalık raporu:** her pazar 19:00 (pg_cron `parent-weekly-reports`)
veliye çocuğunun son 7 günü (soru, dakika, aktif gün; `weekly_report`).
Veli ekranında yeni "Bal Raporu" sekmesi (tab=4): paylaşılabilir özet kartı.

Önizleme: `flutter test test/tool/new_features_preview_test.dart` →
`build/new_features_preview.png`. Testler: `test/mistakes_garden_test.dart`.
