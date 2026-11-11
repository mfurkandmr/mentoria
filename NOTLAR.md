# Geliştirme notları

Bu dosya, son iki büyük özelliğin (white label ve öğrenci avatarı) ne yaptığını,
nasıl çalıştığını ve nelere dikkat edilmesi gerektiğini anlatır.

> **Güncel durum (19 Ekim 2026):** Depodaki 37 migration'ın hepsi canlı
> projede (`lmbykdvvxormfiaomysn`; Günün Sorusu, AYT, düello, plan, deneme eğilimi ve toplu duyuru dahil). `send-push` sürüm 8 canlı ve
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
- **Yapıldı (19 Ekim, §37):** koç ve müdür öğrenci listelerinde talep rozeti.
- **Yapılmadı:** Google Play'in istediği web üzerinden silme talebi sayfası.

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
- **Yapıldı (19 Ekim, §37):** koçun öğrenci detay ekranında da `SkyAppBar`.

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
- **R8 kuralları (`android/app/proguard-rules.pro`):** sürüm derlemesinde
  R8, eklentinin zamanlanmış bildirimleri saklamak için kullandığı Gson
  sınıflarını siliyordu. `zonedSchedule` hata veriyor, alarm kurulamıyor ve
  zil ancak uygulama açılınca çalıyordu (kullanıcı şikâyeti). Dosyada
  `com.dexterous.**` ve Gson `TypeToken` kuralları var; dosya `build.gradle.kts`
  release'te bağlı. Debug derlemesi küçültme yapmadığı için sorun orada
  görünmez.
- **Zil uygulamaya girmeden çalmıyordu (19 Ekim, ikinci düzeltme):**
  - Odak ve mola alarmı aynı bildirim kimliğini (7001) kullanıyordu. Sistem
    odak alarmını ertelediğinde (tam alarm izni yok, Doze) uygulama telefon
    uyanınca odağı bitirip mola alarmını kuruyor, bu da bekleyen odak alarmını
    siliyordu. Artık odak 7001, mola 7003.
  - İzin varsa alarm `AndroidScheduleMode.alarmClock` ile kuruluyor (saat
    uygulamaları gibi; Doze ve üretici pil tasarrufu ertelemez, kilit
    ekranında saat simgesi görünür). İzin yoksa `inexactAllowWhileIdle`.
  - Uygulama süre dolduğunu fark edince `PomodoroAlarm.fireIfLate` alarmın
    hâlâ bekleyip beklemediğine bakıyor (`pendingNotificationRequests`).
    Bekliyorsa iptal edip zili hemen çalıyor.
  - Tek seferlik 8 saniyelik uyarı kaldırıldı. Yerine, izin kapalı olduğu
    sürece zamanlayıcı kartında uyarı ve "İzni aç" düğmesi var
    (`AlarmHealth`: bildirim kapalı / tam alarm izni yok). Kart, ayarlardan
    dönünce kendini yeniliyor.
  - Henüz gerçek telefonda denenmedi; yeni APK gerekiyor.
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
  keytool -genkeypair -keystore C:\anahtarlar\mentoria.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias mentoria
  ```
  `android/key.properties` (yolda `/` kullan; `\` properties dosyasında kaçış
  karakteri sayılır ve yol bozulur):
  ```
  storeFile=C:/anahtarlar/mentoria.jks
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

---

## 24. Deneme analizi (ders ders matematiksel gelişim)

Denemeler ekranında (öğrenci, koç, müdür, veli) TYT / AYT / YDT seçiminin
altında yeni **Sonuçlar | Analiz** seçimi. Analiz yalnızca uygulamada, var olan
denemelerden hesaplanır (`lib/features/exams/data/exam_analysis.dart`, test
`test/exams/exam_analysis_test.dart`):

- **Pencere:** son 5 / son 10 / tüm denemeler.
- **Toplam net eğilimi:** en küçük kareler doğrusu (net / deneme) ve
  "bu gidişle 5 deneme sonra ≈ X net" tahmini.
- **Öne çıkanlar:** en hızlı yükselen ders (deneme başına en çok net
  kazandıran), dikkat isteyen (en çok düşen; düşen yoksa ustalığı en düşük),
  en istikrarlı (soru sayısına göre en küçük sapma, en az 3 deneme).
- **Isı haritası:** ders × deneme, hücrede net, renk netin soru sayısına
  oranı (kırmızı → sarı → yeşil).
- **Her ders için kart:** gidişat rozeti (yükselişte / düşüşte / dalgalı /
  istikrarlı; eşik: soru sayısı / 80 net/deneme ve uyum ≥ %25), net grafiği
  üstünde kesikli eğilim çizgisi, eğim ve uyum (R²), son / ortalama / en iyi,
  isabet (doğru / (doğru+yanlış)), boş oranı, ustalık (ortalama / soru sayısı)
  ve soru sayısıyla sınırlı 5 deneme sonrası tahmini.

Önizleme: `flutter test test/tool/exam_analysis_preview_test.dart` →
`build/exam_analysis_preview.png`.

---

## 25. Eğitim sekmesi: bilgi kartları ve telifsiz soru havuzu

Öğrenci alt menüsünde yeni **Eğitim** sekmesi (Ana Sayfa'dan sonra). 9 TYT
dersi (Türkçe, Matematik, Fizik, Kimya, Biyoloji, Tarih, Coğrafya, Felsefe,
Din Kültürü):

- **Bilgi kartları** (`lib/features/learn/data/learn_cards.dart`): ders başına
  10-15 kart; dokununca dönen kart, arkada formül + kısa bilgi.
- **Soru çöz:** 5 şıklı (A-E) sorular, anında doğru/yanlış ve kısa çözüm,
  üst üste doğrularda alev rozeti, her 5 doğruda konfeti.
- **Günlük hak:** Türkçe ve Matematik 20, diğerleri 10 (günde toplam 110).
  Sınır sunucuda (`20261018200000_practice`, `guard_practice_answer`
  tetikleyicisi, Türkiye günü); istemci aşamaz. Test: `practice_test.mjs`.
- **Havuz = hak × 30:** Türkçe ve Matematik 600, diğerleri 300 → **3.300
  soru** (`assets/learn/questions/<ders>.json`, ~830 KB). Her öğrenci için
  sabit karışık sıra; havuz bitene kadar hiçbir soru tekrar gelmez (30 gün),
  sonra en uzun süredir görülmeyenler döner.
- **Telif:** sorular bu depoda özgün üretilir: `python tool/questions/make_questions.py`
  (sabit tohum; aynı komut aynı soruları üretir). Sayısal sorular (matematik,
  fizik, kimya hesapları, genetik çaprazlama, DNA, harita ölçeği, saat farkı)
  parametreli şablonlardan hesaplanır, cevap her zaman doğrudur. Sözel dersler
  (Türkçe ses bilgisi kurala göre hesaplanır; eş/zıt anlam, tarih, coğrafya,
  felsefe, din) bilgi tablolarından üretilir; tabloları düzeltmek / büyütmek
  için `tool/questions/<ders>.py` dosyaları. Üretici her soruyu denetler
  (5 farklı şık, geçerli cevap); `test/learn_test.dart` havuzu doğrular.
- Cevaplar `practice_answers` tablosunda; koç, müdür ve veli görebilir
  (koç ekranında "Eğitim" sekmesi, bkz. §26).
- Bilinen sınırlar: sözel derslerde soru kökleri çeşitli ama kalıplar az
  (ör. Tarih'te kronoloji ağırlıklı); havuz büyütüldükçe yeni şablonlar
  eklenmeli. Sorular bir öğretmen tarafından gözden geçirilmeli.

Önizleme: `flutter test test/tool/learn_preview_test.dart` → `build/learn_preview.png`.

## 26. Yanlışı deftere at, Günün Sorusu, koçun Eğitim karnesi

- **Yanlışı tek dokunuşla Hata Defteri'ne at:** Eğitim'de (ve Günün
  Sorusu'nda) yanlış cevaptan sonra "Hata Defteri'ne ekle" düğmesi; kart
  soru metni + doğru şık + kısa çözümle oluşur (en çok 500 karakter,
  `notebook_button.dart`), 1-3-7-21 gün tekrarına girer.
- **Günün Sorusu** (`20261018210000_daily_question`, canlıda):
  - Her öğrenciye her gün tek soru; ders güne göre döner (9 günde 9 ders,
    öğrenciler farklı dersten başlar), soru öğrenci + güne göre seçilir
    (`daily_question_id`, havuzla aynı kimlikler). Günlük hakkı harcamaz.
  - `daily_answers`: günde bir cevap, yalnızca o günün sorusu kabul edilir
    (`NOT_TODAYS_QUESTION`), değiştirilemez / silinemez.
  - `my_daily_question()`: bugünkü soru, cevap durumu ve **seri** (art arda
    doğru cevaplanan günler; yanlış cevap seriyi sıfırlar, cevapsız bugün
    seriyi bozmaz).
  - pg_cron `daily-question` (`0 6 * * *` = 09.00 TR) →
    `send_daily_questions()`: o gün cevaplamamış öğrencilere
    `daily_question` bildirimi (günde bir kez). send-push'a da eklendi →
    send-push sürüm 5 canlıda.
  - Uygulama: ana sayfada turuncu "Günün Sorusu" kartı (alev serisiyle),
    `/student/daily` ekranı; bildirim oraya açılır.
  - Test: `supabase/tests/daily_question_test.mjs`.
- **Koçun Eğitim karnesi:** öğrenci detayında yeni "Eğitim" sekmesi
  (`learn_report_view.dart`, hesap `practice_report.dart`): toplam soru,
  isabet, son 7 gün grafiği, ders ders isabet çubuğu ve en çok yanlış
  yapılan konu; en zayıf ders %70 altındaysa öneri notu.
- Testler: `test/learn_daily_test.dart`. Önizleme:
  `flutter test test/tool/daily_question_preview_test.dart` →
  `build/daily_question_preview.png`.

## 27. Eğitim: AYT dersleri

- Eğitim sekmesinin üstünde **TYT | AYT** seçimi. AYT'de 11 ders: Matematik,
  Fizik, Kimya, Biyoloji, Türk Dili ve Edebiyatı, Tarih-1, Coğrafya-1,
  Tarih-2, Coğrafya-2, Felsefe Grubu, Din Kültürü.
- **Günlük hak:** AYT Matematik ve AYT Edebiyat 20, diğerleri 10 (AYT'de
  günde 130). Sunucu: `20261018220000_practice_ayt` (ders kodu ve soru
  kimliği kısıtları genişledi, `practice_daily_limit` güncellendi).
- **Havuz = hak × 30:** 2 × 600 + 9 × 300 = **3.900 AYT sorusu**; toplam
  7.200 (`assets/learn/questions/AYT_*.json`). Üretici:
  `tool/questions/ayt_*.py`. TYT modüllerinden sonra çalışır, TYT
  kimlikleri değişmedi.
  - Sayısal derslerde (logaritma, polinom, türev, integral, karmaşık sayı,
    olasılık; Newton, atışlar, kondansatör, indüksiyon, fotoelektrik; gaz,
    molarite, pH, Kc, Hess, Faraday; genetik olasılıklar, Hardy-Weinberg,
    mRNA) cevaplar hesaplanır.
  - Mantıkta doğruluk değeri soruları ifade ağacıyla hesaplanır.
  - Edebiyattaki hece sayısı soruları özgün dizelerden sayılır.
  - Sözel dersler yazar-eser, dönem, kavram ve kronoloji tablolarından
    üretilir. Ortak yardımcılar `common.py` içinde: `relation_gens`,
    `define_gens`, `chrono_gens`, `fact_gen`.
- 116 yeni AYT bilgi kartı (`learn_cards.dart`).
- Ders adları karışmasın diye `practiceSubjectLabel()` kullanılıyor: koç
  karnesi ve başlıklarda "AYT Matematik" yazılır.
- Günün Sorusu yalnızca TYT derslerinden gelir (9 günlük döngü).
- Sorular bir öğretmen tarafından gözden geçirilmeli; özellikle sözel
  tabloların sınıflandırmaları.

## 28. Arkadaş düellosu

`20261018230000_duels` (geri alma: `…_duels.down.sql`, test: `duels_test.mjs`).
**Canlıda** (send-push sürüm 6: `duel`, `duel_result`). Canlıdaki cevap
anahtarı ders başına bir rakam dizisiyle yüklendi; 7.200 satır, md5 yerel
havuzla aynı. Havuz değişirse canlıdaki anahtar da yenilenmeli.

- **Akış:**
  - Eğitim sekmesinin başındaki turuncu karttan ya da `/student/duels`
    adresinden açılır.
  - "Düello başlat" ile ders (TYT ya da AYT) ve aynı dershaneden bir arkadaş
    seçilir; arkadaşa bildirim gider.
  - İkisi de aynı 10 soruyu çözer; sorular sunucuda rastgele seçilir.
- **Kurallar** test başlamadan önce kurallar ekranında gösterilir:
  - En çok doğru yapan kazanır.
  - **Doğrular eşitse testi daha kısa sürede bitiren kazanır.**
  - Süre "Başla"ya basınca başlar; başlayan oyuncu 30 dakika içinde
    bitirmelidir.
  - Soruyu cevaplayınca sonrakine geçilir, geri dönülmez ("Boş geç" var).
  - Davet 48 saat geçerlidir. Süresi dolan ve iki taraf bitirmemiş düello
    sonuçsuz kalır.
- **Hile koruması:**
  - Puan ve süre istemciden alınmaz. Doğrular sunucudaki cevap anahtarından
    (`practice_keys`, 7.200 satır) sayılır; süre `start_duel` ile
    `finish_duel` arası sunucu saatidir.
  - Sorular "Başla"dan önce görünmez.
  - Rakibin puanı sen bitirene kadar gizlidir.
  - Tablolara doğrudan erişim yok; her şey fonksiyonlarla.
  - Aynı ikili arasında tek açık düello olur; günde en çok 10 davet.
- **Ödül:**
  - Yeni kural `{"type": "duel_wins", "count": n}`.
  - 1 galibiyet: madalya (`acc_duel_medal`), 5: defne tacı (`acc_laurel`),
    10: şampiyon pelerini (`outfit_champion`).
  - Parça, kazanan uygulamayı açınca `claim_avatar_unlocks` ile açılır;
    "yeni parça" bildirimi de böylece çıkar.
- **Cevap anahtarı havuzla aynı olmalı.** Havuz yeniden üretilirse şu komut
  da çalıştırılmalı; `duels_test.mjs` farkı yakalar:
  `python tool/questions/make_keys_sql.py`.
- **Demo:** Can'dan bekleyen bir davet ve Zeynep'le kazanılmış bir düello
  var. Demoda rakip, sen bitirince hemen "oynar".
- **Testler:** `test/duel_test.dart`. Önizleme:
  `flutter test test/tool/duel_preview_test.dart` → `build/duel_preview.png`.

## 29. Sıkça sorulan sorular (her panel için)

- Profil ekranında "Sıkça sorulan sorular" kartı (tüm roller aynı
  `ProfileScreen`'i kullanır); kart, giriş yapan rolün sorularını açar.
- **İçerik:**
  - Öğrenci 15 soru, koç 11, kurum müdürü 8, veli 6 soru içerir.
  - Hepsine ortak 4 "Uygulama" sorusu eklenir.
  - Süper admine ayrıca "Platform yönetimi" bölümü görünür.
- **Ekran:** arama kutusu var (Türkçe karakterleri yok sayar). Aramada
  cevaplar açık gelir. En altta "cevabı bulamadın mı?" satırında kime
  ulaşılacağı yazar.
- **Tek kaynak:** `tool/faq/faq_content.py` (Türkçe + İngilizce).
  - `python tool/faq/make_faq.py` çalıştırılınca
    `lib/features/help/data/faq.dart` ile `strings_en.dart` içindeki SSS
    bloğu üretilir.
  - Bu iki dosyayı elle düzenleme. Yeni özellik eklenince ilgili soruyu da
    buraya ekle.
- **Test:** `test/faq_test.dart`. Önizleme:
  `flutter test test/tool/faq_preview_test.dart` → `build/faq_preview.png`.

## 30. YKS puan hesaplayıcı, haftalık plan, yükselen / düşen öğrenciler

`20261018240000_plan_and_trends` (geri alma `…_plan_and_trends.down.sql`, test
`plan_test.mjs`). **Canlıda.**

- **Puan hesaplayıcı** (`/student/score`; Denemeler ekranının sağ üstündeki
  hesap makinesi):
  - Netler her sınav türünün en son denemesinden dolar; değiştirilebilir.
  - TYT, SAY, EA, SÖZ ve DİL puanı hesaplanır; diploma notuyla OBP katkısı
    eklenir (×5 ×0,12; geçen yıl yerleştiyse ×0,06).
  - Hedef puan girilirse "hedefe X puan kaldı" ve tek başına açığı kapatan
    dersler gösterilir (1 net en çok puan getiren önce).
  - Katsayılar **yaklaşık** (`yks_score.dart`); ekranda tahmin olduğu yazar.
    Sıralama tahmini yok (ÖSYM tabloları her yıl değişir).
  - Hedef ve diploma notu cihazda tutulur (SharedPreferences).
- **Haftalık plan** (`plan_items`):
  - Koç ya da müdür öğrenci detayındaki **Plan** sekmesinden gün gün madde
    ekler (ders, konu, soru / dakika hedefi, not); "Geçen haftayı kopyala"
    var.
  - Öğrenci ana sayfadaki "Bugünün planı" kartından `/student/plan`
    ekranına gider ve yalnızca işaretler.
  - Veli, çocuğunun ekranındaki Plan sekmesinde salt okunur görür.
  - Sunucu kuralları: günde en çok 12 madde, geçmiş haftaya ekleme yok,
    öğrenci maddeyi değiştiremez ve silemez.
  - **Bildirim** (`20261018250000_plan_notifications`): koç ya da müdür bir
    haftaya madde ekleyince öğrenciye "Haftalık planın hazır 📅" gider.
    Aynı hafta için 30 dakikada bir kez gönderilir (kopyalama da tek
    bildirim); geçmiş hafta için gönderilmez. Test: `plan_notify_test.mjs`.
- **Son 5 denemede değişim** (`exam_trends`):
  - Koç ve müdür ana sayfasında TYT / AYT seçmeli kart; en çok yükselen ve
    en çok düşen 5 öğrenciyi gösterir.
  - Her öğrencinin son 5 denemesinin ilk ve son toplam neti karşılaştırılır
    (en az 2 deneme gerekir).
  - Yalnızca yönetilen öğrenciler (`can_manage_student`) görünür; isme
    dokununca öğrenci detayı açılır.
- **Testler:** `test/score_plan_trends_test.dart`.

## 31. Tanıtım videoları (koç-müdür, öğrenci-veli)

Araçlar `tool/promo/`:

1. **Ekran görüntüleri:** `flutter test tool/promo/promo_shots_test.dart` →
   `build/promo/shots/*.png` (1170×2532, demo verisi, gerçek widget'lar).
   - Normal `flutter test` bu dosyayı çalıştırmaz.
   - Gerçek Nunito dosyaları `build/promo/fonts/nunito_<ağırlık>.ttf` olmalı.
     `google_fonts`'un kullandığı fonts.gstatic.com dosyalarıdır (karma
     değerleri `google_fonts` paketindeki `part_n.dart` içinde).
   - Emoji için Windows'un Segoe UI Symbol yazı tipi yedek olarak eklenir.
   - Maskot görselleri de buradan üretilir.
2. **Kurgu:** `python tool/promo/make_promo.py coach|student`
   (`--preview` ile sahne başına iki kare).
   - Telefon çerçevesi, durum çubuğu, kelime kelime gelen başlıklar,
     yakınlaşma, sayaç sahnesi ve geçişlerle 1080×1920, 30 fps MP4 üretir.
   - ffmpeg için `pip install imageio-ffmpeg`.
   - **Özelleştirme bölümü (koç-müdür videosu):** giriş kartı (üç marka
     rozeti, 1 Logo · 2 Renk · 3 Yazı tipi), kurum görünümü ekranı adım adım,
     üç markanın giriş ekranı yan yana ve iki markanın ana sayfası.
     Görüntüler `l_*`: örnek kurum logoları `build/promo/logos/*.png`
     dosyalarından, harness içindeki yerel bir HTTP sunucusuyla yüklenir.
     Harness tüm marka yazı tiplerini `build/promo/fonts/all/manifest.txt`
     listesinden yükler.
   - Kafede telefonlu adam girişi denendi, beğenilmedi ve kaldırıldı.
3. **Müzik:** sentezlenmiş müzikler beğenilmedi. Videolarda hazır parça var:
   "Spark of Inspiration", Shane Ivers, CC BY 4.0 (silvermansound.com).
   - MP3 `build/promo/music_dl/` altında.
   - Künye şart; son 4,6 sn'de alt kenarda yazılır.
   - `make_promo.py` render'dan sonra `mix_track.py` ile müziği ve künyeyi
     ekler. Elle: `python tool/promo/mix_track.py <görüntü.mp4> <mp3> <çıktı.mp4> "<künye>"`.
4. **VideoDB:** son MP4'ler VideoDB'ye yüklenir. Dosyalar herkese açık
   depoda yalnızca bu dosyaları içeren `promo-assets` dalından okunur.

Uygulamaya yansıyan düzeltmeler:
- Düellodaki "Başla" düğmesinin yazısı artık markanın yazı tipinde (önceden
  sistem yazı tipine düşüyordu).
- Öğrenci ve koç/müdür ana sayfasında başlık kayınca görünen kurum adı ve
  "mento" yazısı koyu gökyüzünde koyu renkteydi, okunmuyordu. Artık beyaz
  (`BrandLogo(onDark: true)`).

## 32. Toplu duyuru

- **Kim kime:** kurum müdürü herkese, öğrencilere, velilere ya da koçlara;
  koç kendi öğrencilerine ya da onların velilerine. Öğrenci ve veli
  gönderemez.
- **Veritabanı** (`20261019100000_announcements`):
  - `announcements` tablosu; istemci doğrudan yazamaz.
  - `send_announcement(kitle, başlık, metin)` alıcıları sunucuda bulur, her
    alıcıya `announcement` bildirimi yazar (rota alıcının paneline göre) ve
    alıcı sayısını döner.
  - Hatalar: `ANNOUNCE_INVALID` (başlık 2-80, metin 1-600 karakter),
    `ANNOUNCE_LIMIT` (gönderen başına 24 saatte 10), `ANNOUNCE_NO_RECIPIENTS`,
    `NOT_ALLOWED`.
  - `my_announcements()`: bana gelenler (bildirim satırları üzerinden) ve
    gönderdiklerim; müdür kurumdaki tüm gönderilenleri görür. Alıcı sayısı
    yalnızca gönderene ve müdüre.
- **Telefon bildirimi:** mevcut push tetikleyicisi; `send-push` v8'de
  `announcement` türü (başlık "📣 …", metin 180 karakterde kısaltılır).
- **Uygulama** (`lib/features/announcements/`):
  - "Duyurular" ekranı: `/student|coach|admin|parent/announcements`.
  - Ana sayfa kartı (`AnnouncementsHomeCard`): koç ve müdürde her zaman
    "Yeni duyuru" düğmesiyle; öğrenci ve velide yalnızca son 14 günde
    duyuru geldiyse.
  - Gönderme penceresi kitle seçer ve gönderim öncesi onay ister.
- Veli ve koç panelinde bildirim listesi olmadığı için duyurular bu kart ve
  ekranla görünür.
- **Testler:** `supabase/tests/announcements_test.mjs` ve
  `test/announcements_test.dart`; SSS'ye dört soru eklendi.

## 33. Yük azaltma (aynı anda binlerce öğrenci)

Senaryo: deneme sonucu açıklanınca binlerce öğrenci aynı anda uygulamayı açar.
Migration `20261019120000_scale_load` (rollback'i var), `send-push` v9.

- **Bildirimler Realtime'dan çıktı.** Önceden her açık uygulama kalıcı bir
  Realtime bağlantısı tutuyordu (planlarda eş zamanlı bağlantı sınırı var).
  `SupabaseNotificationRepository.watch` artık tek sorguyla çekiyor ve
  `NotificationRefresh.ping()` gelince yeniden çekiyor. Ping'i tetikleyenler:
  FCM ön plan mesajı (`push_service`), uygulamanın öne gelmesi
  (`AppLifecycleListener`) ve okundu işaretleme. Push gelmeyen durumlar (web,
  izin yok) için uygulama öndeyken 5 dakikada bir de yokluyor.
  `notifications` tablosu `supabase_realtime` yayınından çıkarıldı.
- **Öğrenci ana sayfası tek istekte.** `student_home(p_student, p_since,
  p_since_ts)` (SECURITY INVOKER, RLS aynen geçerli) soru kayıtlarını,
  oturumları, hedefleri, konu ilerlemesini, denemeleri ve ödevleri PostgREST
  sorgularıyla aynı JSON biçiminde döndürüyor.
  - Uygulamada `HomeSeed` (`lib/features/student/data/home_seed.dart`) var.
    Ana sayfa `studentHomePrimeProvider`'ı izleyince RPC başlıyor. Supabase
    repository'leri (tracking, exams, assignments) ilk okumada kendi
    parçalarını `HomeSeed.take` ile alıyor. Her parça bir kez kullanılır ve
    30 saniyeden eski paket kullanılmaz; sonraki yenilemeler normal sorguyla
    gelir.
  - Paket gelmezse sessizce eski sorgulara dönülür. Provider'lar
    değişmediği için demo ve testler etkilenmez.
- **Toplu push'lar zamana yayılır.** Son 10 saniyede 30'dan az bildirim
  varsa push eskisi gibi anında gider. Fazlaysa `push_queue`'ya saniyede 40
  olacak şekilde sıra zamanı yazılır (5.000 bildirim yaklaşık 2 dakika).
  pg_cron `drain-push-queue` 15 saniyede bir vadesi gelenleri 100'lük
  paketlerle `send-push`'a yollar. `send-push` hem `notification_id` hem
  `notification_ids` (en çok 200) kabul ediyor ve FCM'e aynı anda en fazla 25
  istek atıyor. Böylece duyuru, deneme paketi ve Günün Sorusu ani yük
  yaratmıyor.
- **Koç/müdür panelleri.** `student_summaries()` ve `exam_trends()` önceden
  platformdaki tüm öğrencileri tek tek `can_manage_student()`'tan
  geçiriyordu. Artık önce `my_managed_students()` ile yönetilen öğrenciler
  bulunuyor (koç: `coach_students`, müdür: kurum); sonuç aynı. Hazır özet
  tablosu bu ölçekte gerekmedi.
- **Cihaz önbelleği.** `StaticCache` (`lib/core/cache/static_cache.dart`)
  ders listesini (4 repository ortak kullanıyor), konuları ve avatar
  parçalarını SharedPreferences'ta tutuyor. Konular ve dersler 3 gün, avatar
  parçaları 1 gün saklanıyor. Seed değişirse `StaticCache.version`'ı artır.
- **Yük testi:** `tool/loadtest/` (k6, README'de). Canlıda değil, test
  projesinde çalıştırılmalı.
  - 19 Ekim 2026 sonucu. Test projesi `Mentoria-Test`
    (`iruiyvfndxhkuiwbekuf`): ücretsiz plan, Frankfurt, 1000 öğrenci, 20.000
    soru kaydı, 3.000 deneme. 30 hesap oturum açtı; k6 Türkiye'deki
    bilgisayardan çalıştı.

    | Senaryo | Yöntem | Açılış | İstek | Ort. açılış | p95 | Hata |
    |---|---|---|---|---|---|---|
    | ~2,5 dk'ya yayılmış | yeni | 1074 | 5.370 | 126 ms | 184 ms | 0 |
    | ~2,5 dk'ya yayılmış | eski | 1074 | 10.740 | 218 ms | 308 ms | 0 |
    | ~35 sn'ye sıkışmış | yeni | 1256 | 6.280 | 122 ms | 180 ms | 0 |
    | ~35 sn'ye sıkışmış | eski | 1256 | 12.560 | 241 ms | 398 ms | 0 |

  - İsteklerin büyük kısmı ağ gecikmesi (~65 ms). 1000 kişide iki yöntem de
    sorunsuz; yenisi istek sayısını yarıya, açılış süresini yaklaşık yarıya
    indiriyor.
  - Realtime bağlantı sınırı bu testte ölçülmedi.
- **Testler:** `supabase/tests/scale_test.mjs`, `test/scale_cache_test.dart`.

## 34. Zamanla büyüyen yükler ve anında açılan ana sayfa

Migration: `20261019130000_home_counts_cleanup_import` (rollback'i var).

- **Kısayol sayıları:** ana sayfadaki Odak Bahçesi ve Hata Defteri
  kısayolları önceden öğrencinin bütün oturumlarını ve bütün hata kartlarını
  indiriyordu. Artık yalnızca sayılar geliyor:
  - Sunucuda `student_shortcut_counts(p_student, p_today)`, ayrıca
    `student_home` paketinde `shortcuts` anahtarı.
  - Uygulamada `shortcutCountsProvider` (`lib/features/student/data/home_providers.dart`).
  - Kurallar uygulamadakiyle aynı: 20 dakikadan kısa pomodoro solmuş sayılır;
    tekrar zamanı = ustalaşılmamış ve `due_on` bugün ya da önce.
  - Pomodoro kaydı ve hata defteri değişikliklerinden sonra bu provider da
    yenileniyor (`study_view`, `mistake_widgets`, `notebook_button`).
  - `student_home` artık 4 parametreli (`p_today` eklendi). Eski 3
    parametreli sürüm kaldırıldı.
- **Bildirim temizliği:** pg_cron `cleanup-notifications` her gece 03.30'da
  (TR) 90 günden eski bildirimleri siliyor.
  - Duyurular silinmez, çünkü `my_announcements()` bildirim satırlarından
    okuyor.
  - `cleanup_old_notifications(p_days)` en az 30 gün tutar.
- **Toplu deneme yükleme:** `import_exam_batch(p_batch, p_exam, p_rows)`
  (SECURITY INVOKER, RLS aynen geçerli).
  - Öğrenci başına ayrı alt işlem açılır; yetkisiz öğrenci ya da hatalı
    ders kodu yalnız o satırı düşürür ve `failed` listesinde döner.
  - En çok 500 satır kabul edilir; içe aktarma ekranı 200'lük parçalar
    yollar. 300 öğrenci için yaklaşık 900 istek yerine 2 istek gidiyor.
  - `ExamRepository.createExamBatch` (InMemory karşılığı tek tek ekler).
- **Anında açılan ana sayfa:**
  - `HomeSeed`, son gelen ana sayfa paketini cihazda saklıyor
    (`home_bundle.<öğrenci>`, en çok 7 gün).
  - Sonraki açılışta ekran önce bu paketle hemen çiziliyor. Taze paket gelince
    `studentHomePrimeProvider`'daki `onFresh` ilgili provider'ları yeniliyor;
    eski değer yenilenirken ekranda kalıyor, yani titreme yok.
  - İnternet yoksa son görülen ana sayfa açılıyor.
  - Aşağı çekip yenilemede cihazdaki paket atlanıyor (`HomeSeed.skipDiskOnce`).
  - Çıkışta `HomeSeed.clearDisk()` cihazdaki paketleri siliyor.
- **Testler:** `supabase/tests/home_counts_test.mjs`,
  `test/scale_cache_test.dart` (cihaz önbelleği ve toplu yükleme).
- **Test projesi (`Mentoria-Test`):** bu migration oraya da uygulandı.
- **Ekranlar arası kısa önbellek:**
  - Provider'ların neredeyse hepsi zaten oturum boyunca bellekte
    (autoDispose değil), yani sekme geçişinde yeniden indirmiyor.
  - Her açılışta baştan indiren üç yer vardı: başarı sıralaması, avatar
    liderlik tablosu ve duyurular.
  - İlk ikisi `TimedCache` (`lib/core/cache/timed_cache.dart`) ile sayfaları
    2 dakika tutuyor. Önbellek kullanıcıya bağlı:
    `successRankingCacheProvider`, `leaderboardCacheProvider`. Aşağı çekince
    temizleniyor.
  - Duyurular `ref.cacheFor(2 dk)` ile ekrandan çıkınca 2 dakika daha
    tutuluyor.

## 35. KVKK: rızalar, yaş, veli onayı, verilerimi indir

Metinler `docs/kvkk/` klasöründe; açık işler `docs/kvkk/00_README.md`
dosyasında. Migration `20261019150000_kvkk_consents` (rollback'i var),
Edge Function `storage-cleanup` v1.

- **Metinler uygulamada:**
  - `tool/legal/build_legal.py`, `docs/kvkk` taslaklarından avukat notlarını
    (`>` satırları) ve iç bölümleri ayıklayıp `assets/legal/*.md` üretir.
  - `LegalTextScreen` bunları küçük bir Markdown çözücüyle gösterir.
  - Metin değişince betiği çalıştır ve `legalVersion`'ı artır.
- **Rızalar (`consents`):**
  - Her onay ve geri çekme ayrı satır olarak tutulur; güncel durum türe göre
    son satırdır.
  - Türler: `privacy_notice` (aydınlatma teyidi), `ranking`, `parent_view`
    (18+), `guardian_approval` (18-).
  - Kaynak `self` / `parent` / `institution`; metin sürümü de saklanır.
  - Yazma yalnızca `set_consent` ve kayıt tetikleyicisiyle. Okuma:
    `consent_status()`.
  - Eski birleşik kutuyu işaretlemiş hesaplar sürüm `0` olarak aktarıldı.
- **Yaş:**
  - `profiles.birth_year`; `is_minor()` doğum yılından hesaplar. O yıl 18'ini
    dolduranlar yıl sonuna kadar küçük sayılır; yıl yoksa küçük sayılır.
  - Öğrenci yılı bir kez girer (`set_birth_year`); sonra yalnızca koç veya
    müdür değiştirir.
  - Mevcut öğrencilere ana sayfada "Doğum yılını gir" kartı (`KvkkHomeCard`)
    çıkar.
- **Veli onayı, iki yol:**
  - Kurum, öğrenci davetinde "veli onayını kurumumuz aldı" kutusunu işaretler
    (`create_invite(..., p_guardian_statement)`,
    `invite_codes.guardian_statement_at`). Bu davetle gelen öğrenciye
    `institution` kaynaklı onay yazılır.
  - Ya da veli, kayıtta "yasal temsilci olarak onay veriyorum" kutusunu
    işaretler; kutu `check_invite`'ın `student_minor` alanına göre görünür.
  - Veli onayı geri çekerse çocuğun hesabı için silme talebi açılır.
- **Sıralamalar:** `success_scores` ve `avatar_leaderboard` artık yalnızca
  `ranking_visible()` olanları gösterir: rıza var ve 18 altındaysa ayrıca veli
  onayı var. **Canlıda şu an sıralamalar boş görünebilir**; öğrenciler yeni
  APK'dan izin verince dolar.
- **Yetişkin öğrencinin velisi:** veli davetinden önce `parent_view` rızası
  istenir (yoksa `PARENT_VIEW_CONSENT_REQUIRED`). Rıza geri çekilince
  `parent_students` bağı silinir.
- **Verilerimi indir:** `export_my_data()` (SECURITY INVOKER, yalnızca
  kişinin kendi satırları). E-posta uygulamada oturumdan eklenir; dosya
  `share_plus` ile paylaşılır.
- **Silme talepleri:** `process_overdue_deletion_requests()`, 29 günde
  sonuçlanmayan talepleri her gece siler (KVKK 30 gün).
- **Hata defteri fotoğrafları:** kart ya da hesap silinince
  `storage_cleanup` kuyruğuna girer. pg_cron `storage-cleanup` 10 dakikada bir
  `storage-cleanup` Edge Function'ını çağırır (Supabase depoyu SQL ile
  sildirmiyor). Adres `push_function_url`'den türetilir; parola
  `push_webhook_secret`. Canlıda uçtan uca denendi.
- **Uygulama:**
  - Kayıt ekranı: aydınlatma teyidi, doğum yılı, isteğe bağlı sıralama rızası;
    18 altı çocuğun velisine zorunlu veli onayı.
  - Profil → "Gizlilik ve izinler" (`PrivacyScreen`): metinler, izin
    anahtarları, veli onayı durumu, verilerimi indir. Velide her çocuk için
    onay ve sıralama.
  - Koç ve müdürün öğrenci davetinde kurum beyanı kutusu
    (`GuardianStatementTile`).
  - Koç notu ve görev açıklamasında "özel bilgi yazma" uyarısı.
  - `kvkkContactEmail` boş: veri sorumlusu bilgileri gelince doldurulacak.
- **Testler:** `supabase/tests/kvkk_test.mjs`, `test/privacy_test.dart`,
  `test/auth/invite_signup_test.dart` (güncellendi). Sıralama testleri artık
  rıza veriyor.
- **Test projesi (`Mentoria-Test`):** bu migration oraya uygulanmadı.

## 36. Yazı tipleri uygulamada (KVKK)

- Önceden `google_fonts` yazı tiplerini çalışırken fonts.gstatic.com'dan
  indiriyordu; bu da kullanıcının IP adresinin Google'a gitmesi demekti.
- Artık 10 yazı tipinin uygulamada kullanılan kalınlıkları (400–900) ve
  Nunito'nun eğik sürümleri `assets/google_fonts/` klasöründe: 54 dosya,
  yaklaşık 10 MB (APK'da sıkıştırılmış hâli daha küçük).
- `main()` içinde `GoogleFonts.config.allowRuntimeFetching = false`.
- `tool/fonts/fetch_fonts.py`, dosyaların adresini ve SHA-256 özetini
  google_fonts paketinin kendi listesinden okur, indirir ve doğrular.
  google_fonts sürümü değişirse ya da `AppFont`'a yazı tipi eklenirse yeniden
  çalıştırılır.
- Test: `test/bundled_fonts_test.dart`, her yazı tipi ve kalınlığın
  internetsiz yüklendiğini denetler. Dosya eksikse test başarısız olur; paket
  hata yolunda takıldığı için bu zaman aşımıyla olur.
- Yan etki: testlerdeki "google_fonts was unable to load font" uyarıları
  kalktı.
- KVKK metinlerinden ve veri envanterinden Google Fonts aktarımı çıkarıldı.
- Yazı tipleri SIL Open Font License ya da Apache 2.0 lisanslı; lisans
  bilgisi dosyaların içinde (metadata).

## 37. Yayın hazırlığı (19 Ekim 2026)

Kontrol listesi: `docs/YAYIN_ONCESI.md` (panel adımları, telefonda deneme
turu, mağaza hesapları açılınca yapılacaklar).

- **Kod GitHub'da:** 13 commit gönderildi; bundan sonra commit'ler düzenli
  gönderilecek.
- **İmza anahtarı:** `C:\anahtarlar\mentoria.jks` (PKCS12, alias `mentoria`,
  SHA-256 `ED:2D:E8:F4:…:21:F5`). Parola `android/key.properties`'te (git'e
  girmez). Yedeklenmeli. Bu anahtarla imzalanan ilk APK için telefonlardaki
  eski sürüm bir kez kaldırılmalı.
- **Zorunlu güncelleme:**
  - Migration `20261019160000_app_config` (rollback'i var).
  - Tek satırlık `app_config` tablosu (`min_build`, `update_url`,
    `message`). Girişten önce de okunur; uygulamadan yazılamaz.
  - Uygulama açılışta `updateGateProvider` ile bakar; `appBuild < min_build`
    ise `UpdateRequiredScreen` dışında hiçbir ekran açılmaz.
  - Sunucuya ulaşılamazsa uygulama açılır.
  - Sürüm `0.2.0+2` (`pubspec.yaml` ve `lib/core/config/app_version.dart`;
    `test/app_version_test.dart` eşleşmeyi denetler). `url_launcher`
    doğrudan bağımlılık oldu (zaten dolaylı olarak vardı).
  - Testte yakalandı: güvenlik sıkılaştırması yeni tablolarda varsayılan
    yetkiyi kapattığı için `grant select ... to anon, authenticated` açıkça
    yazıldı.
- **Koç listesinde silme talebi rozeti:** `StudentCard(deletionRequested:)`.
  Koç ana sayfasında ve müdürün iki öğrenci listesinde
  (`deletionRequestsProvider`). Test: `test/coach_deletion_badge_test.dart`.
- **Koçun öğrenci detayı:** düz `AppBar` yerine `SkyAppBar` (öğrenci ve veli
  ekranlarıyla aynı). Demo web'de (`build/web_coach`) görsel olarak bakıldı.

## 38. CI ve çökme raporlama

- **CI (GitHub Actions)** `.github/workflows/ci.yml`: her push ve pull
  request'te iki iş çalışır.
  - `flutter`: Flutter 3.44.6, `dart format` denetimi, `dart analyze`,
    `flutter test`.
  - `sql`: Node 22, `supabase/tests` içinde `npm test` (PGlite).
  - Gizli anahtar gerekmez. Sonuçlar GitHub → Actions sekmesinde.
  - Yerelde Flutter sürümü değişirse iş akışındaki `flutter-version` de
    güncellenmeli.
- **Çökme raporlama (Firebase Crashlytics):**
  - `firebase_crashlytics` paketi ve Android Gradle eklentisi
    `com.google.firebase.crashlytics` 3.0.6. Eklenti olmadan SDK açılışta
    "build ID eksik" hatası verir.
  - `lib/core/crash/crash_reporting.dart`: yalnızca telefonda ve sürüm
    derlemesinde açık. `FlutterError.onError` ve `PlatformDispatcher.onError`
    hataları Crashlytics'e gider.
  - Kullanıcı kimliği gönderilmez; yalnızca `build` anahtarı eklenir.
  - KVKK metinlerine (envanter, aydınlatma, gizlilik politikası ve mağaza
    formu) eklendi.
  - Firebase konsolunda Crashlytics sekmesi ilk raporla açılır; gerekirse
    "Enable" denir.
  - Mağaza derlemesi `--obfuscate` ile yapılırsa Dart yığınlarını okumak
    için sembol yüklenmeli:
    `firebase crashlytics:symbols:upload --app=<Android app id> build/symbols`.
  - iOS'ta Xcode'da dSYM yükleme betiği eklenecek (Mac gerekiyor).
- Release derlemesi Crashlytics eklentisi ve yeni imza anahtarıyla denendi:
  APK 76,8 MB; imza parmak izi `ED:2D:E8:…`.

## 39. Kullanım koşulları ve gizlilik politikası uygulamada (20 Ekim 2026)

- Yeni taslak: `docs/kvkk/08_kullanim_kosullari.md` (kullanım kuralları,
  kullanıcı içeriği, fikrî mülkiyet ve "tüm hakları saklıdır", koç/kurum
  sorumluluğu, sorumluluk sınırı, uygulanacak hukuk). Avukat incelemesi ve
  `[İL]`, ücretlendirme gibi boşluklar bekliyor.
- `05_gizlilik_politikasi.md` de uygulamada gösteriliyor; "Mağaza formları
  için özet" bölümü `build_legal.py` ile çıkarılıyor. Çıktılar:
  `assets/legal/kullanim_kosullari.md`, `assets/legal/gizlilik.md`.
- `LegalDoc.terms` ve `LegalDoc.privacyPolicy`: "Gizlilik ve izinler"
  ekranındaki Metinler kartında listelenir. Ekranın altında
  `CopyrightNote` ("© 2026 Mentoria. Tüm hakları saklıdır." ve sürüm).
- Kayıt ekranındaki zorunlu kutu artık "Kullanım Koşulları'nı kabul
  ediyorum; Aydınlatma Metni'ni okudum." Kayıt `privacy_notice` rızası
  olarak saklanır; `legalVersion` 1.1 oldu (hangi metnin kabul edildiği
  sürümden anlaşılır, migration gerekmedi).
- `learn_daily_test`: uzun günün sorularında sonuç kutusu ekranın altında
  kaldığı için test kaydırıp bakıyor (20 Ekim sorusu bunu ortaya çıkardı).

## 40. Kurum kredisi ve kurum kodu (20 Ekim 2026)

Migration `20261020100000_org_credits` (canlıda; geri alma dosyası var).
`schools` tablosu yok; karşılığı `organizations`. Bitiş tarihi için ayrı
`plan_expires_at` açılmadı, mevcut `license_expires_at` kullanılıyor.

- **Alanlar:** `credit_balance` (öğrenci kredisi), `invite_code`
  (`MENTORIA-` + 6 karakter, `generate_org_invite_code()`; 0/O, 1/I yok),
  `is_active`.
- **Kredi harcanır:** öğrenci profili eklenince `consume_student_credit`
  tetikleyicisi 1 düşer; 0'da `NO_CREDITS`. Öğrenci silinse de geri gelmez.
  Koltuk sayımı (`SEAT_LIMIT_REACHED`) kalktı; `seat_limit` yalnızca yeni
  kurumun başlangıç kredisi. Mevcut kurum: kalan koltuk kadar kredi (47).
- **Kredi yükleme:** yalnızca platform yöneticisi:
  `select public.add_org_credits('<org id>', 100);` ya da SQL ile
  `update organizations set credit_balance = ...`. Uygulamada fiyat, satın
  alma, ödeme bağlantısı yok (`test/org_credits_test.dart` bunu tarar).
- **Kurum kodu:** öğrenci kayıt ekranındaki "Davet kodu" alanına yazar
  (`check_invite` ve `apply_signup_invite` iki türü de tanır). Öğrenci,
  kurumda en az öğrencisi olan koça bağlanır (koç yoksa `NO_COACH`).
  Kodu yalnızca müdür görür (`my_org_invite_code`; tablo sütununun okuma
  izni kaldırıldı) ve yenileyebilir (`regenerate_org_invite_code`).
  **organizations'a yeni sütun eklenirse `grant select (sütun)` gerekir.**
- **Uygulama:** `lib/features/credits/`. `LowCreditBanner` (50'nin altında,
  yalnızca "Yöneticinizle iletişime geçin"), müdür panelinde kredi ve
  `OrgCodeCard`, koç ve müdür davet ekranlarında kredi 0 iken "Kod oluştur"
  kapalı. Kayıtta kredisi biten kurumun kodu form açmadan reddedilir.

## 41. Güvenlik taraması (22 Ekim 2026)

- **SQL/RLS testleri:** 25 dosyanın hepsi geçiyor (`cd supabase/tests && npm test`).
- **Supabase advisor (güvenlik):**
  - `SECURITY DEFINER` RPC'lerin giriş yapanlara açık olması bilerek yapıldı:
    her biri çağıranın yetkisine kendisi bakıyor.
  - `check_invite` ve `tenant_branding` girişsiz de çağrılabiliyor (kayıt ve
    marka ekranı girişten önce açıldığı için).
  - `duels`, `push_queue`, `storage_cleanup` ve `practice_keys` tablolarında
    politika yok: bu tablolara yalnızca sunucu fonksiyonları erişiyor.
  - Sızdırılmış parola koruması (HaveIBeenPwned) kapalı; Pro plana geçince
    panelden açılacak.
- **Düzeltilen sızıntı** (`20261022100000_revoke_consent_helpers`, canlıda):
  `is_minor`, `has_consent` ve `ranking_visible` çağıranın kim olduğuna
  bakmıyordu. Giriş yapan herkes, UUID'sini bildiği birinin 18 yaş altı olup
  olmadığını ve rızalarını öğrenebiliyordu. Artık doğrudan çağrılamıyorlar;
  yalnızca DEFINER fonksiyonların içinden çalışıyorlar. Test:
  `supabase/tests/consent_helpers_test.mjs`.
  **Kural:** başkasının kimliğini (`p_user`) alan yeni bir yardımcı fonksiyon,
  ya çağıranın yetkisine bakmalı ya da izni `authenticated`'dan kaldırılmalı.
- **İkinci tur kontroller (aynı gün):**
  - Git geçmişinde sır yok. Firebase API anahtarları zaten gizli değil;
    Google Cloud Console'da Android/iOS uygulamasıyla sınırlanmalı (kullanıcıda).
  - `send-push` ve `storage-cleanup` parolasız isteğe 401 dönüyor.
  - `net` ve `vault` şemaları API'ye açık değil.
  - `notifications` tablosuna kullanıcı satır ekleyemiyor.
  - Depolama: `mistake-photos` gizli, `tenant-logos` bilerek açık.
- **Davet kodu tahmini** (`20261022110000_invite_rate_limit`, canlıda):
  - `random_code()`: kodlar `random()` yerine `gen_random_uuid()` baytlarından
    üretiliyor (güvenli kaynak, pgcrypto gerekmez). Biçim aynı.
  - `check_invite` artık plpgsql ve volatile. Hatalı denemeler
    `invite_check_failures`'a yazılıyor. IP başına (x-forwarded-for'un ilk
    değeri) 10 dakikada 20, toplamda 10 dakikada 1000 hatalı denemeden sonra
    `TOO_MANY_ATTEMPTS` dönüyor. Uygulama bunu "çok fazla deneme" mesajına
    çeviriyor (`auth_error.dart`).
  - **IP düzeltmesi** (`20261022120000_invite_rate_limit_ip`, canlıda).
    Canlıda ölçüldü: `x-forwarded-for`'un ilk değeri istemcinin yazdığı değer
    çıktı, yani ilk sürümdeki IP başına sınır aşılabiliyordu.
    `cf-connecting-ip` ve `sb-forwarded-for` ise taklit edilemiyor (sahte
    `CF-Connecting-IP` gönderen isteği Cloudflare reddediyor). IP artık bu
    sırayla alınıyor: `cf-connecting-ip` → `sb-forwarded-for` →
    `x-forwarded-for`'un son değeri. Sınırlar: IP başına 10 dakikada 30
    (NAT arkasındaki sınıflar takılmasın), toplamda 5000 (acil fren).
    Gerçek API'den sahte başlıkla yapılan denemeler gerçek IP'ye yazıldı.
  - Mevcut kurumun kodu eski `random()` ile üretilmişti, değiştirilmedi
    (müdürün dağıttığı kod bozulmasın). Müdür panelden yenileyebilir.
  - Test: `supabase/tests/invite_rate_limit_test.mjs`.

## 42. KVKK saklama görevleri ve web'den hesap silme (29 Ekim 2026)

Migration `20261029100000_retention_jobs` (rollback'i var). **Canlıya
uygulandı 30 Ekim 2026** (2 Kasım'da `list_migrations` ile doğrulandı); test
projesine uygulanmadı.

- **Veri sorumlusu:** şirket yok, bireysel geliştirici. Metinlerdeki unvan
  yerleri `[AD SOYAD]` oldu; MERSİS ve KEP satırları kalktı. Ad, adres,
  e-posta ve web adresi hâlâ boş (`docs/kvkk/00_README.md`).
- **Saklama görevleri** (gece 03.30, pg_cron `retention-jobs` →
  `run_retention_jobs()`):
  - `purge_old_announcements()`: 1 yıldan eski duyurular ve onların
    bildirimleri.
  - `purge_expired_organizations()`: lisansı 1 yıldan önce bitmiş kurumdaki
    tüm hesaplar. Lisans yenilenirse tarih ilerlediği için bir şey silinmez.
  - `process_inactive_accounts()`: son etkinlikten 2 yıl − 30 gün sonra
    `inactivity_warning` bildirimi (telefon bildirimi de gider), uyarıdan en
    az 30 gün sonra hâlâ etkinlik yoksa silme. Son etkinlik = kayıt, son
    giriş ve `auth.refresh_tokens.updated_at`'in en yenisi (uygulama açık
    kaldıkça oturum yenilenir; "hiç çıkış yapmayan" kişi silinmez).
    Silinmeyenler: platform yöneticileri, öğrencisi olan koç, öğrencisi olan
    kurumun tek müdürü.
  - Süreler `retention_settings` tablosunda (tek satır, yalnızca SQL).
    Elle çalıştırma: `select public.run_retention_jobs();`
- **Web'den hesap silme** (`/#/hesap-sil`, `AccountDeletionScreen`; Google
  Play'in "uygulamayı kurmadan silme" şartı):
  - E-posta → 6 haneli kod (`signInWithOtp(shouldCreateUser: false)` +
    `verifyOTP(type: email)`). Kayıtlı olmayan adreste de "kod gönderdik"
    denir (hesap tahmini olmasın).
  - Sonra uygulamadaki kural: öğrenci silme talebi açar (koç siler, 29 günde
    sistem siler), diğer roller hemen siler (`delete_my_account`).
  - Router bu adreste oturum açık da kapalı da yönlendirme yapmaz.
  - **Canlıda gerekli:** Supabase → Authentication → Emails → "Magic Link"
    şablonuna `supabase/templates/magic_link.html` yapıştırılmalı (kod
    gitmesi için `{{ .Token }}`). Edge Function gerekmedi.
- Metinler: süreler dolduruldu, web silme sayfası eklendi;
  `build_legal.py` çalıştırıldı, `legalVersion` 1.2.
- Test: `supabase/tests/retention_test.mjs`.

## 43. Optik okuma (30 Ekim 2026)

Migration `20261030100000_optic_reading` (rollback'i var; **canlıya
uygulandı 30 Ekim 2026**, RLS ve yetkiler SQL ile doğrulandı). Koç kazanım /
cevap anahtarı Excel'ini yükler, sonra optik formların fotoğrafını çeker;
okuma telefonda yapılır (internet ve ücret yok).

- **Veritabanı:**
  - `answer_keys` (deneme: ad, tür, yayınevi, tarih, `template_id`) ve
    `answer_key_items` (ders + soru no → doğru cevap, kazanım, isteğe bağlı
    konu). Kurumdaki koç ve müdürler okur; öğrenci anahtarı göremez.
    Yazma yalnızca `create_answer_key` / `delete_answer_key` ile.
  - `exam_answers`: öğrencinin her soruda işaretlediği şık + doğru cevap +
    kazanım. Denemeyi görebilen (öğrenci, veli, koç, müdür) görür.
  - `submit_optic(key, student, answers)`: sunucuda değerlendirir, deneme
    `source = 'optic'`, `batch_id = anahtar` (Denemeler ekranında tek paket,
    7 günlük silme kuralı aynen). Aynı öğrencinin optiği yeniden okunursa
    deneme yerinde güncellenir, bildirim tekrar gitmez; 7 günü geçmişse
    `EXAM_LOCKED`. Yanlış/boş sorular kazanımın bağlı olduğu konu varsa
    `exam_wrong_topics`'e yazılır. İptal soru (cevabı boş) sayılmaz; AYT'de
    hiç işaret konmayan test (alan dışı) sayılmaz, alan profilden ya da
    işaretli testlerden çıkar.
- **Okuma motoru** (`lib/features/optic/data/omr/`, saf Dart + `image`):
  EXIF yönü düzeltilir → en uzun kenar 1600 px → yerel ortalamaya göre
  eşikleme → dört köşedeki dolu kareler bulunur → perspektif dönüşümü
  (`Homography`) → her baloncuğun ortalama koyuluğu. Bir sıradaki boş
  baloncuklara (ortanca) göre belirgin koyu olan işaretli sayılır; eşik o
  kâğıttaki tipik işaret koyuluğuna göre kayar (açık basan kalem de okunur).
  İki işaret ya da silik iz → `UncertainMark`, koç kontrol ekranında seçer.
  Öğrenci numarası formdaki numara alanından okunur, `student_number` ile
  eşleşir.
- **Cevap kâğıdı: Mentoria YKS formu** (`mentoria_yks`; 30 Ekim 2026'da
  kullanıcıyla kararlaştırıldı: yayınevi formları optik makine için
  tasarlandığından kamerayla okumaya kendi formumuz kullanılır). A4; dört
  köşede siyah kare + sol üstte küçük yön işareti (kâğıt ters ya da yan
  çekilse de okunur), öğrenci no (8 hane), oturum (TYT / AYT), kitapçık
  (A / B), 4 sütun × 40 satır ortak ızgara (ÖSYM kâğıdındaki gibi TYT ve
  AYT aynı kutucukları farklı derslerle kullanır; `layouts`).
  - Uygulamadan PDF olarak indirilir (Optik okuma ekranı → yazıcı simgesi;
    `optic_form_print.dart`: Flutter ile çizilir, JPEG gömülü tek sayfa PDF).
  - Önizleme: `flutter test test/tool/optic_form_preview_test.dart` →
    her şablon için `build/optik_<id>.pdf` / `.png` / `_dolu.png`.
  - `test/optic/optic_print_test.dart`: yazdırılan form doldurulup telefon
    fotoğrafına çevrilir ve okunur (TYT ve AYT).
  - Başka bir form gerekirse `opticTemplates`'e yeni şablon eklenir.
- **Standart YKS optik formu** (`standart_yks`, varsayılan; 30 Ekim 2026
  kullanıcı kararı: "standardı kullan"): yayınevi tarzı, köşe karesi yok,
  sol kenarda 55 zamanlama çubuğu (soru satırları çubuklarla hizalı), 10
  haneli öğrenci no, oturum, kitapçık, 4 × 40 ızgara. Gerçek bir yayınevinin
  kâğıdı değil, o tarzda bir örnek. Kullanıcının gönderdiği iki "yayınevi
  formu" görüntüsü kullanılmadı: biri 320 px, öbürü yapay zekâyla
  üretilmiş görünüyordu (yazım hataları, bozuk baloncuk harfleri) ve
  hizalama işareti yoktu.
  - `opticTemplates` = [standart, Mentoria]; yeni denemede ilki seçili.
  - İndirme: Optik okuma ekranındaki yazıcı simgesi formu sordurur;
    deneme ekranında "Bu denemenin boş kâğıdını indir (PDF)".
  - Yazdırma çizimi (`paintOpticForm`) artık şablondan bağımsız: kutular
    alanların konumundan hesaplanır, zamanlama çubukları da çizilir.
  - `test/optic/optic_print_test.dart` her şablon için basılı formu
    doldurup fotoğraflayıp okur (TYT ve AYT).
- **Yayınevi / dershane formları (zamanlama çizgili)** (30 Ekim 2026):
  makine için basılan formlarda köşe karesi yok, kenarda siyah zamanlama
  çubukları var (`OpticTemplate.track`, `TimingTrack`). Okuma:
  1. Aynı doğru üzerinde, eşit aralıklı, benzer boyda en çok çubuk bulunur;
     sıra numarası ardışık aralıklardan sayılır (perspektifte aralık değişir).
     İçeriğin hangi yanda olduğuna göre (önce parlaklık: masa / kâğıt, sonra
     baskı yoğunluğu) kâğıdın ters çekildiği anlaşılır.
  2. Kaba eşleme: çubuklara oturtulan eğri + satırlar çubuk sırasına dik.
  3. Kesin eşleme: çizgiden dışa doğru 100'er birimlik şeritlerde her
     baloncuk kendi çerçevesine oturtulur (`snap`), o ana kadarki
     eşleşmelere tek perspektif dönüşümü oturtulur (`Homography.fit`,
     aykırılar atılır; çubuklar kesin nokta, hiç atılmaz) ve sonraki şerit
     bu dönüşümle aranır.
  - Testler (`test/optic/omr_track_test.dart`, pembe baskılı sahte form):
    düz, ~%7 ve ~%13 perspektif, 180°; hizalama hatası gerçek yerlere göre
    1,5 birimin altında.
  - Denenmiş ama bırakılmış yollar: blok / parça bazında kaydırma araması
    ve ölçek-eğiklik kalibrasyonu (tekrarlayan baloncuk deseninde bir şık
    ya da bir satır kayık yere oturabiliyordu).
- **Şablon çıkarma aracı:** `python tool/optic/extract_template.py
  bos_form.png` (numpy + opencv-python). Boş formun düz taramasından köşe
  karelerini ya da zamanlama çubuklarını ve baloncuk ızgaralarını bulur;
  `build/<ad>_sablon.json`, `.dart` (OpticTemplate iskeleti, dersler
  `TODO`) ve `.png` (numaralı kontrol resmi) yazar. İki baloncuklu seçim
  alanları (kitapçık, oturum) "tek tük baloncuk" diye listelenir, elle
  yazılır. Mentoria formu ve çizgili test formunda değerler birebir doğru
  (`flutter test test/tool/optic_form_preview_test.dart` iki formun da
  PNG'sini üretir). **Gerçek yayınevi formu henüz denenmedi.**
- **Kitapçık (A/B)** (`20261030110000_optic_booklets`, rollback'i var; canlıda):
  kazanım Excel'inde isteğe bağlı "B Soru No" sütunu
  (`answer_key_items.question_no_b`). `submit_optic(..., p_booklet)`; kayıtlar
  A numarasıyla, `exam_answers.booklet_no` öğrencinin kendi numarası,
  `exams.booklet`. Anahtarda B yoksa B okunamaz (`NO_B_KEY`; kontrol ekranı
  kaydetmeyi kapatır). Formdaki oturum denemeyle uyuşmazsa uyarı.
- **Kazanım Excel'i** (`answer_key.dart` `parseAnswerKey`): sütunlar Ders /
  Test, Soru No, Cevap, Kazanım / Konu (yazım serbest). Test içi numaralar
  (Sosyal 1–20, Fen 1–20, AYT Sosyal-1/-2) derslere bölünür. Kazanım,
  adını içerdiği müfredat konusuna bağlanır (`matchTopic`).
- **Ekranlar:** `/coach/optic`, `/admin/optic` (liste), `…/optic/new`
  (yeni deneme + Excel), `…/optic/:id` (Optik oku → kontrol → kaydet; kamera
  sıradaki optik için kendiliğinden açılır; okunanlar nete göre; en çok
  yanlış yapılan kazanımlar; Excel indir). Girişler: koç ana sayfasında
  "Optik oku", Denemeler ekranının üstünde tarayıcı simgesi.
  Öğrencinin deneme detayında "Yanlışların ve boşların" + kazanımlar
  (`ExamAnswersView`).
- **Excel** (`optic_excel.dart`): Sonuçlar (nete göre sıralı), Cevaplar
  (öğrenci × soru, "B ✗ A"), Kazanımlar (başarı yüzdesi, en düşük üstte).
- **Testler:** `test/optic/` (okuma motoru: düz tarama, eğik/gölgeli/
  gürültülü JPEG fotoğraf, açık kalem, çift/silik işaret, kadraj dışı köşe;
  Excel okuma; puanlama; Excel yazma; ekran akışı; yazdırılan form),
  `supabase/tests/optic_test.mjs`, `optic_booklet_test.mjs`.

## 44. Rehberlik paketi ve lisans erişimi (31 Ekim 2026)

Altı migration, hepsinin rollback'i var; **hepsi canlıya uygulandı 30 Ekim
2026 akşamı** (2 Kasım'da doğrulandı). `send-push` v11 (yeni haftalık rapor
metni, `inactivity_warning`, `risk_digest`) da canlıda. Test projesine
uygulanmadı.

- **Öğrencinin kendi programı** (`20261031100000_student_self_plan`):
  `plan_items.start_time` (isteğe bağlı, "09:00–09:45"). Öğrenci kendi
  haftasına madde ekler, yalnızca kendi eklediğini siler; koçun maddelerini
  yalnızca işaretler. Günde en çok 12 madde. Kendi maddeleri bildirim
  üretmez.
- **Lisans bitince erişim biter** (`20261031110000_license_access`):
  `my_license_active()`; `my_tenant_active()` artık lisansı da kontrol eder,
  yani lisansı biten kurumun öğrenci, koç ve velisi yalnızca kendi profilini
  okur. Müdür her zaman girer. Uygulamada `licenseActiveProvider`
  (`RoleGateScreen`) "lisans doldu" ekranını gösterir. Lisans uzatılınca
  erişim kendiliğinden döner.
- **Veli haftalık özeti** (`20261031120000_weekly_summary`):
  `weekly_summary_data()` (iç) / `weekly_summary(öğrenci)`: son 7 gün
  çalışılan gün, kaçırılan / yapılan görüşme, ödev tamamlama, son net ve
  değişim, soru ve odak dakikası. Veli ana sayfasında `WeeklySummaryCard`
  (WhatsApp metni de buradan). Pazar akşamı veli bildirimi aynı veriyi
  taşır. Sınıf yoklaması yok; "devamsızlık" = çalışılmayan gün + kaçırılan
  görüşme.
- **Rehberlik görüşme kaydı** (`20261031130000_guidance_logs`,
  `lib/features/guidance/`): tarih, tür (yüz yüze / telefon / online / veli),
  sabit konu etiketleri, not, sonraki adım, takip tarihi. Yazan koç ya da
  müdür; görenler şimdiki koç ve müdür (öğrenci ve veli görmez, eski koç
  görmez). Değiştirme yok; yazan 24 saat içinde, müdür her zaman siler.
  Sağlık vb. özel nitelikli veri etiketi bilinçli olarak yok.
- **Risk erken uyarısı** (`20261031140000_risk_alerts`, `risk_card.dart`):
  0–100 skor = devam (en çok 50) + net düşüşü (en çok 30) + yapılmayan ödev
  (en çok 20). 30 ve üstü, en riskli 7 öğrenci; 7 günden yeni kayıt girmez.
  `my_risk_list()`; pg_cron `risk-digests` pazartesi 08:00 (TR) her koça tek
  `risk_digest` bildirimi.
- **Otomatik konu reçetesi** (`20261031150000_topic_prescription`,
  `prescription_card.dart`): `topic_prescription(öğrenci, 3)` son
  denemelerin yanlış konularından ödev taslağı önerir (1 yanlış → 15 soru,
  2–3 → 25, 4+ → 40; en çok 8 konu; son 14 günde ödev verilmiş konular
  çıkar). Hiçbir şey yazmaz; koç seçip mevcut ödev akışıyla gönderir.
- **Testler:** `test/weekly_guidance_test.dart`,
  `test/risk_prescription_test.dart`; SQL: `self_plan_test.mjs`,
  `license_access_test.mjs`, `weekly_guidance_test.mjs`,
  `risk_prescription_test.mjs`.

## 45. KVKK onayı: sunucuda zorunlu, metin güncellenince yeniden (2 Kasım 2026)

Migration `20261102100000_signup_consent_required` (rollback'i var; **canlıya
uygulandı 2 Kasım 2026**, yetkiler SQL ile doğrulandı). Test projesine
uygulanmadı.

- **Kayıt:** `apply_signup_invite`, `kvkk_consent = true` gelmeyen kaydı
  `KVKK_REQUIRED` ile reddeder (e-posta doğrulamasını bekleyen kayıt da).
  Önceden yalnızca uygulamadaki zorunlu kutu vardı; API doğrudan
  çağrılırsa onaysız hesap açılabiliyordu. Uygulama her zaman `true`
  gönderdiği için kullanıcıya ayrı bir hata metni yok.
- **Yeniden onay:** `consent_status` artık `privacy_version` döndürür
  (onaylanan son Kullanım Koşulları / Aydınlatma Metni sürümü; geri
  çekildiyse null). Kişi kendi durumunu her rolde okur. `RoleGateScreen`
  bunu `legalVersion` ile karşılaştırır, farklıysa panele girmeden
  `LegalUpdatePrompt` (`privacy/presentation/legal_update_screen.dart`)
  açılır: iki metnin linki, onay kutusu, "Onayla ve devam et", çıkış.
  Durum okunamazsa kişi kilitlenmez, geçer.
- **set_consent:** aynı rıza yalnızca aynı sürümle tekrar yazılmaz (önceden
  Aydınlatma Metni bir kez onaylandıysa yeni sürümün onayı hiç
  kaydedilmiyordu).
- **Metin değişince:** `build_legal.py` + `legalVersion` artırılır; bütün
  kullanıcılar sonraki açılışta yeniden onaylar. 2 Kasım'da canlıdaki 6
  hesabın hepsi sürüm "0"daydı, yeni APK ile hepsine bir kez sorulacak.
- **Testler:** `supabase/tests/signup_consent_test.mjs`,
  `test/legal_update_test.dart`.

## 46. Kurum finansı (5 Kasım 2026)

Migration `20261105100000_finance` (rollback'i var; **canlıya uygulandı 5
Kasım 2026**). Kullanıcı kararları: dört kısım da var, yalnızca müdür görür,
uygulama ödeme almaz (kayıt defteri; ödeme elden / havaleyle).

- **Tablolar:** `finance_fees` (öğrenci başına ücret), `finance_installments`
  (taksit: vade, tutar, `paid_on`, ödeme şekli), `finance_expenses` (kira,
  maaş, prim, fatura, materyal, reklam, vergi/SGK, diğer; maaş/prim bir koça
  bağlanabilir), `coach_pay_rates` (aylık maaş + öğrenci başı prim).
- **Yetki:** tek politika `is_finance_admin(org_id)` (giriş yapan kurum
  müdürü). Koç, öğrenci, veli, başka kurumun müdürü hiçbir satırı görmez.
  `org_id`, `tenant_id`, öğrenci/koç adı `guard_finance_row` /
  `guard_coach_pay_rate` tetikleyicilerinde yazılır (genel `set_tenant_id`
  student_id beklediği için kullanılmadı). Kurum ve öğrenci sonradan
  değiştirilemez.
- **Silinen hesaplar:** öğrenci ya da koç silinince mali kayıt kalır
  (`on delete set null`, ad kayıtta). Tetikleyici bu boşaltmaya izin verir.
- **Uygulama:** `lib/features/finance/`, `/admin/finance` (yalnızca müdür
  rotası). Sekmeler: Özet (ay seçimi, tahsilat / beklenen / gider / net,
  geciken toplamı, son 6 ay çubukları, geciken taksit listesi), Ücretler
  (taksit planı: tam lira, kuruş farkı son taksitte; ödendi işaretle / geri
  al), Giderler (aylara göre), Koçlar (önerilen ödeme = maaş + öğrenci ×
  prim; "Ödemeyi kaydet" maaş gideri yazar). Müdür ana sayfasında
  `FinanceHomeCard`. Hesaplar istemcide (`monthSummary`,
  `splitInstallments`, `parseMoney`).
- **₺ kuralı:** `org_credits_test` uygulamada ₺/TL'yi yasaklıyordu (Mentoria
  satışı yok). `lib/features/finance/` yalnızca para birimi kuralından muaf;
  "satın al / ödeme yap / fiyat" orada da yasak.
- **Testler:** `test/finance_test.dart`, `supabase/tests/finance_test.mjs`.

## 47. Taksit günü bildirimi ve veliye SMS (5 Kasım 2026)

Migration `20261105110000_finance_reminders` (rollback'i var; **canlıda**),
Edge Function `send-sms` v1 (yeni), `send-push` v12. Kullanıcı kararı: SMS
sistemi bağlanacak; ücret kaydında veli telefonu alınır, hatırlatma o numaraya
SMS olarak gider (uygulama içi veli bildirimi yok).

- **Ücret kaydı:** "Ödeme günü: her ayın N. günü" (1-28) + "İlk taksit" ayı;
  veli adı ve cep telefonu (`+905XXXXXXXXX`, `normalizePhone`). Sonradan
  ücret sayfasındaki kalemle değiştirilir.
- **Günlük bildirim:** pg_cron `due-installments` 06:00 UTC (09:00 TR) →
  `notify_due_installments()`: vadesi bugün, ödenmemiş taksitler için kurum
  müdürlerine tek `installment_due` bildirimi (sayı, toplam, telefonsuz
  sayısı). Dokununca `/admin/finance?remind=YYYY-MM-DD` açılır ve "Taksit
  hatırlatması gönderilsin mi?" penceresi (telefonu olanlar seçili) çıkar.
  Aynı taksit için bir kez.
- **SMS:** `send_payment_reminders(uuid[])` (yalnızca müdür) → `sms_outbox`
  (aynı taksite 20 saatte bir; ödenmiş / telefonsuz atlanır). Metin: "Sayın
  {veli}, {kurum}: {öğrenci} için {gg.aa.yyyy} vadeli {tutar} TL taksit
  ödemesini hatırlatırız." Ücret sayfasında her ödenmemiş taksitte "Veliye
  hatırlat" düğmesi. `kick_sms()` + pg_cron `sms-outbox` 5 dakikada bir
  `send-sms`'i dürter. 90 günden eski SMS kayıtları her sabah silinir.
- **SMS sağlayıcısı henüz yok:** `send-sms` secrets'ta `SMS_PROVIDER=netgsm`
  ve `NETGSM_USERCODE`, `NETGSM_PASSWORD`, `NETGSM_HEADER` görene kadar
  mesajlar `queued` bekler; bağlanınca gider. Netgsm çağrısı (GET
  /sms/send/get) gerçek hesapla **denenmedi**; başka sağlayıcı seçilirse
  `send-sms`'e eklenir.
- **KVKK:** veli telefonu yeni kişisel veri; aydınlatma metnine eklenmeli
  (docs/kvkk/00_README.md).
- **Testler:** `supabase/tests/finance_reminders_test.mjs`,
  `test/finance_test.dart` (hatırlatma penceresi, telefon ekleyip SMS).

## 48. Günlük yoklama ve "gelmedi" SMS'i (5 Kasım 2026)

Migration `20261105120000_attendance` (rollback'i var; **canlıda**, yetkiler
SQL ile doğrulandı). Test projesine uygulanmadı. Kullanıcı kararı: koç ve
müdür her gün yoklama alır, seçtikleri gelmeyen öğrencilerin velisine SMS
gider. SMS sağlayıcısı henüz yok (§47): mesajlar `sms_outbox`'ta `queued`
bekler, sağlayıcı bağlanınca gider.

- **Kim:** koç kendi öğrencilerini, müdür kurumun bütün öğrencilerini
  (`my_managed_students`, yalnızca `role = 'student'`). Öğrenci ve veli
  yoklamayı görmez.
- **Tablolar:** `attendance` (öğrenci + gün tekil; `present` / `absent` /
  `late` / `excused`; `sms_at`), `student_guardian_phones` (yoklama SMS'i
  için veli adı + `+905XXXXXXXXX`). İkisine de doğrudan yazılamaz.
- **RPC'ler:** `attendance_day(gün)` (liste + durum + `has_phone`),
  `save_attendance(gün, {id: durum|null})` (son 30 gün, ileri tarih yok),
  `set_guardian_phone`, `send_absence_sms(gün, id[])` (yalnızca "gelmedi"
  olan, telefonu olan, aynı gün bir kez). `sms_outbox.attendance_id` eklendi.
- **Veli telefonu:** önce yoklama için girilen; yoksa kurum finansındaki
  ödeyen veli (`finance_fees.payer_phone`). Finanstaki numara koça
  gösterilmez, yalnızca "telefon var" bilgisi ve SMS'te kullanılır.
- **SMS metni:** "Sayın {veli}, {kurum}: öğrenciniz {öğrenci} {gg.aa.yyyy}
  tarihinde kuruma gelmedi. Bilgilerinize."
- **Saklama:** pg_cron `attendance-retention` (00:40 UTC) 1 yıldan eski
  yoklamayı siler (`purge_old_attendance`).
- **Uygulama:** `lib/features/attendance/`, rota `/coach/attendance` ve
  `/admin/attendance`. Gün seçimi (son 30 gün), durum çipleri, "İşaretsizlerin
  hepsi geldi", kaydedince gelmeyenler için SMS penceresi (telefonu olanlar
  seçili), satırdaki telefon simgesinden veli telefonu, üst çubukta SMS
  düğmesi. Koç ve müdür ana sayfasında `AttendanceHomeCard`. Demo:
  `lib/dev/demo_attendance.dart`.
- **Açık:** yoklama "verilerimi indir"e (`export_my_data`) eklenmedi.
- **Testler:** `supabase/tests/attendance_test.mjs`, `test/attendance_test.dart`.

## 49. Otomatik haftalık ders programı (5 Kasım 2026)

Migration `20261105130000_timetable` (rollback'i var; **canlıda**, RLS ve
yetkiler SQL ile doğrulandı). Test projesine uygulanmadı. Kullanıcının
verdiği şartnameden bilinçli sapmalar: tablo/sütun adları İngilizce (`org_id`
+ `tenant_id`), `class_subject_requirements` + `teacher_class_assignments`
tek tablo `class_lessons` (öğretmen doluysa kesin, boşsa branşı tutan biri
seçilir; bu yüzden "tercih edilen öğretmen" yumuşak kısıtı yok), müsaitlik
satırı olmayan öğretmen her saat müsait, branş serbest metin
(`commonBranches` listesi), uzun basma kilit yerine **dokun → kilitle /
taşı** menüsü, **basılı tut + sürükle** taşıma.

- **Tablolar:** `teachers` (`profile_id` doluysa o koç/müdür hesabı
  programını görür), `teacher_availability`, `classrooms` (+
  `classroom_students`, `home_room_id`), `rooms`, `time_slots`,
  `class_lessons`, `schedules` (draft/published, kurumda tek yayın:
  `schedules_one_published`), `schedule_entries` (`locked`).
- **Yetki:** hepsine yalnızca kurum müdürü (`is_org_admin`) doğrudan
  yazar/okur. `guard_timetable_row` kurumu sunucuda yazar, başka kurumun
  kaydına bağlantıyı `TIMETABLE_BAD_REF` ile reddeder. Sert kısıt 1-3
  (öğretmen/sınıf/derslik aynı saatte tek) tekil indekslerle DB'de de var.
- **RPC'ler:** `save_schedule_entries` (programı tek seferde yazar),
  `publish_schedule` (öteki yayın taslağa döner), `my_timetable()`
  (öğretmen: kendi dersleri, öğrenci: sınıfı, veli: çocuklarının sınıfları;
  yalnızca yayındaki program).
- **Algoritma** (`lib/features/schedule_generator/domain/`, saf Dart,
  JSON girdi/çıktı): kilitliler yerleşir ve denetlenir → boş derslere
  öğretmen seçilir → teşhis (talep > müsaitlik / üst sınır / şablon) → MRV +
  backtracking + forward checking (40 bin düğüm ya da sürenin %40'ı) →
  olmazsa açgözlü doldurma, yerleşemeyenler `noCommonSlot` ile raporlanır →
  simulated annealing (taşı / aynı sınıfta yer değiştir), süre sınırı 10 sn.
  Yumuşak puan cezadır (0 en iyi): pencere 3, günlük sınırı aşan saat 5,
  öğleden sonra Matematik/Geometri/Fizik 2, öğretmenin günlük ek sınıfı 1.
  Uygulamada `compute()` ile isolate'te (`scheduleGeneratorProvider`).
  Sunucuya taşımak için girdi/çıktı JSON hazır; ama Edge Function Deno
  olduğu için kod TS'e çevrilmeli ya da ayrı Dart sunucusunda çalışmalı.
  Ölçek testi: 20 öğretmen / 15 sınıf / 420 saat ≈ 1 sn, tam ve geçerli.
- **Uygulama:** `/admin/schedule` (programlar), `/admin/schedule/setup`
  (5 adımlı sihirbaz), `/admin/schedule/:id?generate=1` (sınıf / öğretmen /
  derslik sekmeleri, çakışma paneli, yeniden oluştur, kaydet, yayınla,
  dışa aktar). Müdür ana sayfasında `TimetableAdminCard`; koç, öğrenci ve
  veli ana sayfasında `MyTimetableCard` (yayında program yoksa görünmez).
- **Dışa aktarma:** Excel (`excel` paketi, sınıf/öğretmen başına sayfa) ve
  PDF (Canvas → JPEG → çok sayfalı A4 yatay, `jpegPagesToPdf`; yeni paket
  yok, Türkçe karakterler uygulama yazı tipiyle).
- **Açık:** program yayınlanınca bildirim yok; öğretmenin hiç saat
  seçmemesi 1 dakikalık "boş aralık" satırıyla tutuluyor; veli/öğrenci
  görünümü gün listesi (ızgara değil).
- **Testler:** `test/schedule_generator/` (algoritma 10, ekran 5, dışa
  aktarma 1), `supabase/tests/timetable_test.mjs`. Demo:
  `lib/dev/demo_timetable.dart`.

## 50. Finans: aylık / yıllık Excel (5 Kasım 2026)

Finans ekranının üst çubuğunda "Excel olarak indir" (`showFinanceExportDialog`):
Aylık (yıl + ay) ya da Yıllık (yıl) seçilir, dosya paylaşılır
(`finans-2026-11.xlsx` / `finans-2026.xlsx`). Oluşturucu
`lib/features/finance/data/finance_excel.dart` (`buildFinanceWorkbook`,
`FinancePeriod`), yalnızca istemcide; sunucu değişikliği yok.
Sayfalar: Özet (tahsilat, vadesi dönemde olan, gider, net, bugün geciken;
yıllıkta ay ay tablo + toplam; gider türü dağılımı), Tahsilatlar (dönemde
ödendi işaretlenenler), Taksitler (vadesi dönemde olanlar ve durumu), Giderler,
Öğrenci bakiyeleri (bugün itibarıyla toplam / ödenen / kalan / geciken).
Tutarlar sayı hücresi. Testler: `test/finance_excel_test.dart`.

## 51. Sınıf yönetimi, öğrenci kayıt modları, öğrencinin ders programı (5 Kasım 2026)

Migration `20261105140000_student_registry` (rollback'i var; önceki
fonksiyon sürümlerini geri yükler; **canlıda**, yetkiler SQL ile doğrulandı),
`send-push` v13 (`timetable` bildirimi). Test projesine uygulanmadı.
Şartnameden sapmalar: ayrı `students` tablosu yok (`profiles` + yeni
sütunlar), varsayılan kayıt modu **serbest** (mevcut kurumların kaydı
kapanmasın), `v_student_schedule` yerine `my_timetable()` + `my_classroom()`,
"yeni sürüm" tablosu yok (yayındaki program yerinde güncellenir, öğrenciye
"güncellendi" bildirimi kişi başı 30 dakikada bir), sınıf ekleme/düzenleme
yalnızca müdürde (koç kendi öğrencilerini atar).

- **Kayıt modu** (`organizations.student_registration_mode`, müdür
  `set_registration_mode`): `list` → öğrenci kayıtta numarasını girer,
  `expected_students`'ta yoksa `STUDENT_NUMBER_NOT_FOUND`, eşleşmişse
  `STUDENT_NUMBER_TAKEN`; eşleşirse ad soyad listeden, sınıf adı tutarsa
  sınıfa atanır, veli telefonu `student_guardian_phones`'a yazılır. `free`
  → kayıt engellenmez; rakam dışı numara `bad_format`, kullanımdaki numara
  numarasız kayıt + `duplicate` (`attempted_number`). Serbestten listeye
  geçince (ya da liste yüklenince, `reconcile_expected_students`) numarası
  listede olmayanlar `not_in_list`.
- **Kayıt ekranı:** öğrenci davetinde "Öğrenci numaran" (yalnızca rakam,
  zorunlu); göndermeden önce `match_student_number` (anon, yalnızca
  ok/not_found/taken/invalid döner, `invite_check_failures` hız sınırı).
  GoTrue tetikleyici hatasını "Database error" olarak döndürdüğü için asıl
  mesaj bu ön kontrolden gelir. `check_invite` → `number_mode`.
- **Liste içe aktarma** (`/admin/registration/import`): Excel/CSV
  (`readSpreadsheet`), sayfa + başlık satırı + sütun eşleştirme (tahmin:
  `guessColumns`), doğrulama raporu (mükerrer, hatalı/eksik numara, adsız,
  geçersiz telefon), hatalı satır düzelt ya da atla, "Listeyi yenile"
  (eşleşmemiş eskileri sil). 2000+ satırda `compute`. `import_expected_students`.
- **Sınıflar** (`/admin|coach/classes`): `capacity`, `active`; öğrenci tek
  sınıfta (`classroom_students_one_class`); dolu sınıf silinemez
  (`CLASSROOM_NOT_EMPTY`, ekranda önce toplu taşıma). Sınıf detayında
  öğrenci ekle / çıkar.
- **Öğrenciler** (`/admin|coach/roster`): sekmeler Sınıfı olmayanlar / Tüm
  öğrenciler / Şüpheli numaralar (serbest modda ya da işaretli varsa:
  işaret, numarasız, sınıfsız, adı çok benzeyen — `suspiciousStudents`) /
  Henüz kayıt olmayanlar (müdür, liste modu). Arama, sınıf ve koç süzgeci,
  toplu atama. Öğrenci detayı: numara (anlık `student_number_available`),
  sınıf, koç (müdür, `set_student_coach`), işareti kaldır.
- **Geçmiş:** `student_class_history`, `student_number_history`
  (tetikleyicilerle; kim, rolü, ne zaman). `set_student_number` artık yalnızca
  rakam (1-20).
- **Öğrencinin programı** (`/student/timetable`, `StudentScheduleScreen`):
  Bugün (süren ders "Şimdi", sıradaki) + Hafta ızgarası; boş durumlar
  (sınıf yok / yayınlanmadı); son başarılı yükleme cihazda
  (`studentScheduleProvider`, çevrimdışı gösterilir). Ana sayfada
  `StudentScheduleCard` (sınıfı da programı da yoksa görünmez).
- **Yayın:** `schedules.published_at`, rozet "Yayında · tarih"; yayın
  penceresi etkilenecek sınıf ve öğrenci sayısını gösterir (`schedule_reach`).
- **Testler:** `supabase/tests/student_registry_test.mjs`,
  `test/student_registry_test.dart`, `test/auth/invite_signup_test.dart`.
  `timetable_test.mjs` geri almayı artık sonraki migration'larla ters
  sırada yapıyor.

## 52. Velilere serbest metinli SMS (5 Kasım 2026)

Migration `20261105150000_bulk_sms` (rollback'i var; **canlıda**). Müdür
ana sayfasında "Velilere SMS" → `/admin/sms`: metni yazar (hazır şablonlar:
resmi tatil, deneme sınavı, veli toplantısı), kime: tüm veliler / seçili
sınıflar / seçili öğrenciler. Alıcı sayısı ve telefonu olmayan öğrenci
sayısı gönderimden önce görünür (`send_bulk_sms(..., p_dry_run => true)`).

- Velinin numarası `guardian_phone_of` (yoklamada girilen, yoksa finanstaki
  ödeyen veli). Aynı numara bir kez (kardeşler). Metnin başına "Kurum adı:"
  eklenir. En çok 600 karakter, 2000 numara; kurum başına 10 dakikada bir
  gönderim (`SMS_TOO_SOON`).
- `sms_broadcasts` (geçmiş; yalnızca müdür okur), `sms_outbox.broadcast_id`,
  `my_sms_broadcasts()` (sırada / gitti / başarısız sayıları).
- SMS sağlayıcısı yok (§47): mesajlar sırada bekler. Bilinen sınır:
  `send-sms` her çağrıda 50 mesaj, cron 5 dakikada bir → saatte ~600;
  büyük kurumda sağlayıcı bağlanınca toplu gönderim API'si ya da döngü
  eklenmeli.
- İYS: ekranda "yalnızca bilgilendirme" uyarısı; reklam/kampanya için ticari
  ileti izni gerekir.
- Testler: `supabase/tests/bulk_sms_test.mjs`, `test/bulk_sms_test.dart`.

## 53. Deneme karşılaştırma (5 Kasım 2026)

Sunucu değişikliği yok (sonuçlar mevcut `exams` / `exam_subject_results`'tan,
kazanımlar `exam_answers.outcome`'dan). Denemeler ekranında (öğrenci, koç
öğrenci detayı, veli) "Denemeleri karşılaştır" → `ExamComparisonScreen`.
Şartnameden sapmalar: `exams.publisher` zaten vardı (yeni sütun yok);
dersler `subjects` koduyla eşleştiği için `ders_adi_normalize` gerekmedi
(TYT_MAT ile AYT_MAT ayrı kalır); deneme satırı öğrenci girdiyse var olduğu
için "katıldı / yayında" süzgeci yok; view yerine saf Dart.

- `lib/features/exam_comparison/domain/exam_comparator.dart`:
  `ComparisonMode.forCount` (2-4 tablo, 5+ özet), `compare` (ders satırları,
  olmayan ders null → "—", en yüksek/düşük net, toplam ve sıra),
  `summarize` (ders ortalaması, doğrusal eğilimle en çok gelişen/gerileyen
  3 ders), `outcomes` (en az iki denemede ölçülen kazanımlar, yazım farkı
  `normalizeLabel` ile eşleşir), `mixed` (TYT/AYT ya da alan karışınca uyarı).
- Ekran: Denemeler (seçim, "3/4 seçildi", özet bildirimi), Karşılaştırma
  (tablo + ders bazında çubuk + toplam net çizgi; 5+'da özet), Kazanımlar
  (yüzde ve ok). PDF: tablo A4 yatay (`renderComparisonPdf`, Canvas → JPEG).
- Testler: `test/exam_comparison/`.

## 54. Kitap takibi (5 Kasım 2026)

Migration `20261105160000_student_books` (rollback'i var; **canlıda**),
`send-push` v14 (`book_request`). Test projesine uygulanmadı.

- **Tablolar:** `books` (kurum havuzu; ad + yayın tekil, `norm_key`),
  `student_books` (dönem sunucuda: Eylül-Ocak "YYYY-Güz", Şubat-Ağustos
  "YYYY-Bahar", `term_of`), `student_book_limits` (varsayılan 7),
  `book_progress` (konu `topic_id` ya da serbest, sayfa, soru/D/Y/B, not).
- **Kurallar (tetikleyicilerde):** öğrenci havuza yalnızca talep ekler
  (`guard_book` durumu 'pending' yapar); öğrencinin listesine yalnızca
  aktif havuz kitabı (`BOOK_NOT_IN_POOL`); dönemde eklenen TOPLAM kayıt
  sınırı (`BOOK_LIMIT`, bitti/bırakıldı da sayılır; koç silerse düşer);
  öğrenci `student_books`'u güncelleyemez/silemez (politika yok); çalışmayı
  kendisi 24 saat düzenler/siler; D+Y+B ≤ soru, bitiş ≥ başlangıç sayfası,
  ileri tarih yok.
- **RPC'ler:** `approve_book`, `merge_book_request`, `reject_book_request`
  (talep edene `book_request` bildirimi), `set_book_limit`,
  `student_books_overview`, `book_usage` (kitap → öğrenci sayısı, ortalama
  soru; sınıf süzgeci), `topic_gaps` (son 120 gün optik denemede ≥3 soru,
  başarı < %50, son 60 günde kitap/soru kaydı yok), `import_books`.
- **Entegrasyon:** D/Y/B girilen çalışma `question_logs`'a kitap adıyla
  yansır (`mirror_book_progress`; istatistik, konu görünümü, haftalık rapor
  kendiliğinden içerir). Ders kitaptan, kitap karmaysa seçilen konudan.
- **Uygulama:** Eğitim sekmesinde "Kitaplarım" (`/student/books`), koç/müdür
  öğrenci detayında "Kitaplar" sekmesi (konu boşluğu sinyali, limiti artır,
  durum, sil), veli çocuk ekranında "Kitaplar" (salt okunur + son 7 gün
  soru özeti), müdür/koç ana sayfasında "Kitap havuzu" (`/admin|coach/books`:
  havuz, onay bekleyenler + benzer kitap önerisi, Excel ile toplu ekleme;
  ders "TYT Matematik" biçiminde, tanınmazsa Karma).
- **Testler:** `supabase/tests/student_books_test.mjs`,
  `test/student_books_test.dart`.

## 55. Kurum sınavı: optik Excel içe aktarma ve kazanım analizi (6 Kasım 2026)

Migration `20261105170000_exam_import` (rollback'i var; **canlıya uygulandı**
iki parça hâlinde: `exam_import` + `exam_import_functions`; RLS 7 yeni
tabloda açık, anon görünümleri okuyamıyor, mevcut 1 optik deneme taşındı).
Mevcut optik okuma yapısı (§43) genişletildi; ikinci bir sınav yapısı yok.

- **Veri:** `answer_keys` = kurum sınavı (+ `kind` deneme/konu_tarama,
  `status` draft/published, `wrong_penalty`, `penalty_ratio`).
  `answer_key_subjects` (soru sayısı, sıra, katsayı), `answer_key_classrooms`,
  `answer_key_items` (+ `outcome_id`, `difficulty`, `cancelled`),
  `answer_key_booklets` (B/C/D: kitapçıktaki no → A'daki no, isteğe bağlı o
  kitapçığın cevabı; `question_no_b` kamera akışı için eşitleniyor).
  `learning_outcomes` (kurum havuzu: ders > konu > alt konu ağacı, MEB kodu,
  isteğe bağlı `topic_id`). `exam_sheets` (ham optik, öğrencinin kitapçık
  sırasıyla), `exam_imports`, `import_templates`.
  `exams` + `total_net` (katsayılı), `rank_org`, `rank_class`,
  `classroom_id`; `exam_subject_results` + `wrong_penalty`, `weight`, ders
  sıralamaları; **net artık `correct - wrong * wrong_penalty`** (elle girilen
  denemede 0,25 — `guard_exam_scoring` bu sütunları yalnızca puanlamaya
  bırakır). Uygulamada `SubjectResult.penalty` sunucudan okunur.
- **Akış:** `save_exam(key, def)` sınavın tamamını kaydeder (yeni sınav
  taslak). Taslakta optikler yalnızca `exam_sheets`'te durur; öğrenci, veli,
  istatistikler görmez. `publish_exam` hepsini puanlar (`_apply_sheet`,
  bildirim ilk eklemede gider) ve sıralar (`_rank_key`). Yayındaki sınavda
  her yükleme anında puanlanır; anahtar/iptal değişince `save_exam` tüm
  optikleri yeniden puanlar. Excel: `start_exam_import` → 25'lik
  `import_exam_sheets` parçaları (en çok 100) → `finish_exam_import`.
  Aynı öğrenci tekrar yüklenirse güncellenir (kopya yok). Kamera akışı
  (`submit_optic`) da ham optiği yazar; taslakta önizleme döner (exam_id boş).
- **Puanlama kuralı** (SQL ve Dart `ExamScorer` aynı, testli): iptal ya da
  cevapsız soru hiçbir sayıma girmez; TYT'de tüm dersler, AYT/YDT'de işaret
  konan dersler; net 2 basamak, toplam = Σ net × katsayı.
- **Analiz görünümleri** (security_invoker): `v_student_outcome_analysis`
  (net kaybı = yanlış × (1 + katsayı) + boş, ders katsayısıyla),
  `v_class_outcome_analysis`, `v_institution_outcome_analysis`,
  `v_question_difficulty` (doğru/boş %, en çok işaretlenen yanlış, ayırt
  edicilik = en iyi %27 − en zayıf %27). Koçun kurum geneli için
  `exam_report(key)` (sıralamada koç yalnızca kendi öğrencileri, müdür
  hepsi); karne için `exam_card_context(exam)`; numara eşleştirme için
  `exam_import_roster()` (kurumun tüm öğrencileri, personel).
- **Dart:** `lib/features/exam_import/` (domain: `ExamDefinition`,
  `OpticResultParser`, `ExamScorer`, `prepareImport` — 60 satırdan büyük
  dosya `compute` ile isolate'te; data: `ExamAdminRepository`;
  ekranlar: Kurum sınavları listesi, sınav düzenleme (Bilgiler / Cevap
  anahtarı / Kazanımlar / Sonuçlar), kazanım havuzu, içe aktarma sihirbazı),
  `lib/features/exam_analysis/` (`ExamReportRepository`, kazanım
  analizi: zayıf kazanım, net kaybı haritası, trend; karne ekranı + PDF;
  sınıf/kurum raporu + Excel). Bellekte: `lib/dev/demo_exam_center.dart`
  (iki arayüzü birden; demoda 2 yayında + 1 taslak sınav).
- **Girişler:** müdür/koç ana sayfasında "Kurum sınavları" kartı
  (`/admin|coach/org-exams`, `…/org-exams/new|:id`, `…/outcomes`);
  Denemeler ekranında "Kurum sınavı karneleri"; deneme detayında "Karneyi aç".
- **Şartnameden sapmalar:** tablolar yeni adlarla değil mevcut tablolar
  genişletilerek; LGS yok (ders listesi ve puan YKS); öğrenci anahtar
  tablosunu hiç okumaz (doğru cevap kendi `exam_answers` kaydında);
  puan yalnızca TYT için tahmini (`computeScore`), sunucuda saklanmaz;
  PDF `pdf`/`printing` yerine mevcut Canvas → JPEG → PDF; zorluk değerleri
  İngilizce kod (easy/medium/hard).
- **Testler:** `supabase/tests/exam_import_test.mjs` (taslak gizliliği,
  A/B kitapçık, iptal, katsayı, yeniden yükleme, %33,3, RLS, rapor, geri
  alma); eski `exam_batches`/`optic`/`optic_booklet` testleri artık önce bu
  migration'ı geri alıyor. `test/exam_import/` (parser, scorer, plan, analiz,
  bellek deposu, ekran akışları, PDF/Excel).
- **Denenmedi:** gerçek bir optik okuyucu Excel'i ve telefonda akış.

## 56. Finans eklentileri: hesaplar, indirim, kısmi ödeme, makbuz, iade, gelir, toplu ücret, veli (6 Kasım 2026)

Migration `20261106100000_finance_plus` (rollback'i var; **canlıya uygulandı**
iki parça: `finance_plus` + `finance_plus_functions`; yeni 7 tabloda RLS açık).
E-fatura / e-arşiv kullanıcı kararıyla yapılmadı.

- **Kısmi ödeme ve makbuz:** `finance_payments` (tahsilat / iade satırları).
  `record_payment(fee, tutar, …, installment?)` tutarı ödenmemiş taksitlere
  dağıtır (seçilen taksit önce, sonra en eski vade); kalan borçtan fazlası
  `FINANCE_OVERPAYMENT`. Makbuz no kurum + yıl başına sıralı
  (`2026-000001`, `finance_receipt_seq`). Taksidin `paid_amount` / `paid_on`
  / `method` alanlarını yalnızca tetikleyici yazar (`_sync_installment`,
  `mentoria.finance_sync`); istemci doğrudan değiştiremez. `void_receipt`
  makbuzu iptal eder (silinmez, numara tekrar kullanılmaz). Eski ödenmiş
  taksitler makbuzsuz tahsilat satırına çevrildi ("Önceki kayıt").
- **İndirim / burs / kardeş:** `finance_discounts`. Ücretin `total`'i
  indirimsiz ücret; taksit toplamı = total − indirimler (`create_fee`
  denetler). Sonradan `add_fee_discount`: son vadeli taksitten başlayarak
  düşer, sıfırlanan taksit silinir.
- **Kayıt iptali / iade:** `cancel_fee`: ödenmemiş taksitler silinir, kısmen
  ödenen taksit ödenen tutara iner, ücret `status = cancelled`; iade tahsil
  edilen netten fazla olamaz, iade makbuzu yazılır. Tahsilatı olan ücret
  silinemez (`FINANCE_HAS_PAYMENTS`; kurum silinirken basamaklı silme geçer).
- **Diğer gelirler:** `finance_incomes` + `record_income` (kitap, özel ders,
  materyal, etkinlik, diğer; makbuz no'lu).
- **Kasa / banka:** `finance_accounts` (açılış bakiyesi, IBAN, kullanılmıyor),
  `finance_transfers` (virman). Tahsilat, gelir, gider ve iade hesaba
  bağlanabilir; bakiye istemcide (`accountBalances`).
- **Toplu ücret:** `fee_plans` (şablon) + `create_fees_bulk(öğrenciler, …)`:
  aynı başlıkta (Türkçe harf duyarsız) aktif ücreti olan atlanır; veli adı /
  telefonu yoklamadaki `student_guardian_phones` kaydından gelir.
- **Veli:** `my_child_finance(student)` (yalnızca `parent_students` bağı):
  ücretler, taksitler, indirim toplamı, makbuzlar. Veli panelinde
  çocuk ekranında "Ödemeler" sekmesi, makbuz PDF'i paylaşılabilir.
- **Hatırlatma SMS'i** kısmi ödemede kalan tutarı yazar.
- **Uygulama:** Finans ekranı 6 sekme (Özet, Ücretler, Gelirler, Giderler,
  Hesaplar, Koçlar). Ücret penceresinde "Ödeme al", "İndirim / burs",
  makbuz listesi (PDF / iptal), "Kaydı iptal et / iade"; taksite dokununca o
  taksidin kalanıyla ödeme. Ücret eklemede indirim; "Toplu ücret" (şablon,
  sınıfa göre seçim, şablon kaydet). Makbuz PDF'i (`receipt_pdf.dart`): A4'te
  veli ve kurum nüshası, "fatura yerine geçmez" notu. Excel'e makbuzlu
  tahsilatlar, iadeler, Diğer gelirler ve Hesaplar sayfaları eklendi.
- **Kelime kuralı:** "fiyat" uygulamada yasak (`org_credits_test`):
  "indirimsiz ücret" kullanıldı.
- **Testler:** `supabase/tests/finance_plus_test.mjs`; eski `finance_test` ve
  `finance_reminders_test` artık tahsilatı `record_payment` ile yazıyor ve
  önce bu migration'ı geri alıyor. `test/finance_plus_test.dart`.
  Ayrıca `weekly_guidance_test.mjs` gece 00:00-03:00 arası (UTC / TR farkı)
  kırılıyordu; tarih Türkiye saatine bağlandı.

## 57. Sınırlı kalanlar: AYT puanı, zorunlu hesap, toplu ücrette aynı başlık (6 Kasım 2026)

- **AYT/YDT tahmini puanı (karne):** AYT puanında TYT'nin %40 payı olduğu için
  öğrencinin aynı gün ya da önceki en yakın TYT denemesinin netleri alınır
  (`ReportCard.tytNets`, Supabase'de `_tytNets` tek sorguda 100'er öğrenci).
  Puan türü öğrencinin alanından (SAY/EA/SÖZ); alan yoksa AYT'de girilen
  derslere en çok uyan tür seçilir. YDT → DİL. TYT denemesi yoksa kutu
  görünmez. `estimatedScore` artık `(type, score)` döner, başlık
  "Tahmini SAY puanı" gibi (`scoreLabel`). Test: `test/exam_import/estimated_score_test.dart`.
- **Hesap seçimi:** kurumun açık kasa/banka hesabı varsa `AccountPicker`
  boş bırakılamaz; ödeme şekline göre kendiliğinden seçer (nakit → kasa,
  kart → POS/banka, havale → banka; `defaultAccountFor`). Kullanıcı elle
  değiştirmediyse ödeme şekli değişince güncellenir. Hiç hesap yoksa seçici
  gösterilmez. Sunucu hesapsız kayda yine izin verir (eski kayıtlar, hesap
  tanımlamamış kurum).
- **Toplu ücret, aynı başlık:** listede aynı başlıkta aktif ücreti olan
  öğrenci işaretlenir; seçildiyse "Aynı başlıkta ücreti olanlara da aç"
  anahtarı çıkar (varsayılan kapalı = atla). Migration
  `20261106150000_bulk_fee_duplicates` (`create_fees_bulk(..., p_allow_duplicate
  boolean default false)`, eski 7 parametreli imza kaldırıldı; eski APK'lar
  varsayılanla çalışır). Rollback var; `finance_test`/`finance_reminders_test`
  geri almada bunu da önce geri alıyor. Canlıya uygulandı.
- **E-fatura** yapılmadı: GİB'e bağlı bir özel entegratör (sözleşme + API
  anahtarı) olmadan kurulamaz; makbuz "fatura yerine geçmez" yazmaya devam eder.

## 58. Öğrenci düzenleme: veli telefonu ve kısayol (6 Kasım 2026)

- Veli adı / cep telefonu yalnızca Yoklama ekranında satır altında
  bulunuyordu. Artık "Sınıflar ve öğrenciler" → öğrenci penceresinde de var
  (sınıf, numara, koç ile birlikte). Kayıt `set_guardian_phone` ile; okuma
  `student_guardian_phones` tablosundan (`AttendanceRepository.fetchGuardian`,
  `guardianProvider`). Yeni migration yok.
- Öğrenci detay ekranının üst çubuğuna "Sınıf, numara ve veli" düğmesi
  (müdür ve koç) eklendi; aynı pencereyi açar.

## 59. Kurum müdürü kokpiti (6 Kasım 2026)

Müdür paneli "Genel" sekmesi öğrenci-odaklı/oyunsu görünümden işletme
kokpitine çevrildi. Hiçbir özellik kaldırılmadı; eski → yeni yer listesi ve
kontrol: `docs/admin_panel_envanter.md` (testi: `test/admin_cockpit_test.dart`).

- **Tema:** müdür panelinin tamamı tek, açık tema (`cockpit/cockpit_theme.dart`):
  nötr gri zemin, beyaz kartlar. Renk yalnızca anlam: `Tone.risk/warn/good`.
  Vurgu kurum markasının koyu tonu (`BrandTheme.ink`); kurum logosu, adı ve
  yazı tipi korunur (white label ayarları aynen çalışır). Uygulamanın koyu
  mod ayarı müdür panelini etkilemez. Bal peteği alt çubuğu yerine standart
  `NavigationBar`; liste sonunda `cockpitNavHeight + 16` boşluk.
- **Bölümler** (`lib/features/admin/presentation/cockpit/`): üst çubuk (logo,
  kurum adı, tarih; maskot/selamlama yok) · eşik bantları · özet şeridi
  (kayıtlı öğrenci, bu hafta aktif "312 / 410", bu hafta soru, yaklaşan
  deneme; geçen haftaya göre ok) · dikkat gerektirenler (7+ gün girmeyen,
  son iki denemede 3+ net düşen, taksiti geciken; satırdan koça bildirim /
  koçu ara) · koç performansı · kurum araçları (eski modül kartlarının
  hepsi) · kurum ayarları. Her bölümün yükleniyor (iskelet), boş (eylem
  düğmeli) ve hata (Tekrar dene) hali ayrı (`section_states.dart`).
- **Eşik bantları:** kurum kapalı; lisans bitti / 14 gün kaldı; kredi bitti /
  kayıtlı öğrencinin %10'unun altında (`orgAlerts`). Müdüre "yöneticinizle"
  denmez, "destek ekibiyle görüşün" denir (`LowCreditBanner` da müdürde bu
  metni gösterir; koçta eskisi gibi).
- **Alt sayfalar** (`/admin/...`): `exam-plans` (deneme takvimi), `activity`
  (bu hafta çalışmayanlar / soru sırası; eski "hareketsiz öğrenciler"),
  `risk` (eski risk kartı), `trends` (son 5 deneme), `meetings` (koç
  görüşmeleri haftalık raporu).
- **Sunucu:** migration `20261106160000_admin_cockpit` (canlıya uygulandı):
  `profiles.last_seen_at` + `touch_last_seen()` (uygulama açılış/öne
  gelişte, saatte en çok bir yazım; `presenceBootstrapProvider`),
  `org_exam_plans` + `add_exam_plan`/`delete_exam_plan`, `coach_phones` +
  `set_coach_phone` (müdür girer, Koçlar sekmesinden de), bildirim türü
  `coach_alert` + `notify_coach_about_student` (aynı öğrenci için 6 saatte
  bir), `admin_cockpit()` (tek çağrı; yalnızca müdür). "Bu hafta" son 7 gün,
  görüşmeler pazartesiden beri. Son görülme birikene kadar son çalışma kaydı
  kullanılır. Rollback ve `supabase/tests/admin_cockpit_test.mjs` var.
  `send-push` v15 (koça bildirim metni) deploy edildi.
- Android: "Koçu ara" için manifest `<queries>`'e `DIAL tel:` eklendi.

## 60. Kokpit ikinci tur ve koç paneli (6 Kasım 2026)

Kullanıcı kendi puanlamamdan (7/10) sonra açılış animasyonu hariç önerilerin
hepsini istedi. Envanter: `docs/admin_panel_envanter.md` (ikinci tur ve koç
paneli tabloları).

- **Kompakt araçlar:** modül kısayolları `lib/shared/widgets/tool_tile.dart`
  (`ToolInfo`, `ToolListCard`, `ToolGrid`). Her modülün durum satırı tek
  fonksiyonda (`attendanceTool`, `financeTool`, `studentsTool`,
  `bookPoolTool`, `orgExamsTool`, `timetableAdminTool`, `myTimetableTool`,
  `bulkSmsTool`, `trendsTool`); eski `*HomeCard`'lar bunu liste kartı olarak
  çizer (öğrenci/veli ekranları değişmedi). İş bekleyen kutu (yoklama
  alınmadı, onay bekleyen kitap, yayın bekleyen sınav, geciken taksit,
  sınıfsız öğrenci) dikkat renginde nokta + metin.
- **Başarı sıralaması anahtarı** kurum ayarları kartında (`SuccessRankingRow`).
- **Emojisiz:** risk/trend boş metinleri, görüşme planlandı, duyuru
  gönderildi, şüpheli numara yok. **Nötr kart:** `inCockpit(context)`
  (`CockpitThemed` içinde) → `StudentCard` ve `InitialsAvatar(plain: true)`
  dekoratif renksiz; risk/dikkat renkleri anlamlı kalır.
- **Eğilim:** migration `20261106170000_activity_weeks` (canlıda):
  `activity_weeks(p_weeks)` son N haftanın aktif öğrenci / soru / kayıtlı
  öğrenci sayısı; müdür kurumunu, koç kendi öğrencilerini görür
  (`my_managed_students`). Arayüz `cockpit/activity_trend_card.dart`
  (çubuklar, bu hafta vurgulu, değerler yazılı, ekran okuyucuya özet).
  Rollback ve SQL testi (`admin_cockpit_test.mjs`) var.
- **Koç paneli** (`coach_home_screen.dart`) kokpit diline geçti: aynı tema,
  üst çubuk (kurum logosu/adı/tarih), özet şeridi (değişim oku eğilim
  verisinden), risk kartı, görüşmeler, eğilim, kısayollar, duyurular,
  öğrenciler. Alt çubuk standart `NavigationBar` (eylemler aynı). Yeni
  rotalar koçta da: `/coach/activity`, `/coach/trends`. Davet sayfası
  `openInviteSheet`.
- Açılış animasyonu (Bızz intro) kullanıcı isteğiyle değişmedi.

## 61. Kokpit: hareket ve derinlik (6 Kasım 2026)

Kullanıcı ikinci turu "fazla düz" buldu; iPhone tasarımlarındaki gibi sade
ama akıcı ve şık istedi (motion-and-haptics becerisine göre).

- **Hareket dili** `cockpit/cockpit_motion.dart`: süre rolleri
  (`CockpitMotion.short/medium/long`, iOS'a yakın eğri), `Reveal` (bölümler
  sırayla aşağıdan süzülerek belirir), `Pressable` (basınca %97), 
  `AnimatedCount` (sayılar sayarak gelir), `SlidingSegments` (iOS kayan
  seçim kontrolü, ad + sayı iki satır), `SmoothSwitch` (grup değişince
  çapraz geçiş + boy). Titreşim haritası `CockpitHaptics`: seçim →
  selectionClick, kaydedildi (koça bildirim, telefon, deneme planı) →
  lightImpact; tek anahtar `CockpitHaptics.enabled`. Hepsi `Motion.of`
  ile "hareketi azalt"ta anında son hale geçer (sıfır süreli AnimatedSize
  kullanılmaz: düzen sırasında hata veriyordu).
- **Derinlik:** kartlar çizgisiz, yumuşak gölgeli, 18 px köşe; zemin üstte
  kurum renginin çok hafif tonundan griye iner (`CockpitBackground`);
  esnek (bouncing) kaydırma; Navigator geçişleri Cupertino.
- **Üst çubuk:** iOS büyük başlığı; açıkken logo + büyük kurum adı + tarih,
  kaydırınca küçük başlığa dönüşür ve buzlu cam (blur) çubuk belirir.
- **Bu hafta kartı** (`week_hero_card.dart`): koyu kurum renginde, dolan
  katılım halkası (iOS Fitness gibi), aktif sayısı sayarak gelir; yarıdan
  azı çalıştıysa halka sıcak sarı. Müdür ve koçta aynı. Altında üç kompakt
  kart (`HeroStrip`).
- Eğilim çubukları sırayla yükselir, seri değişince yeni yüksekliğe kayar;
  koç aktiflik çubukları dolarak gelir; araç kutuları basınca küçülür.
- Test: `admin_cockpit_test` "hareket açıkken" (animasyonlu yollar hatasız).

## 62. Kurum iç ekranları ve koyu kokpit (6 Kasım 2026)

Kullanıcı 10/10 için iç ekranların (Finans, Yoklama, SMS...) eski düz
görünümden çıkmasını ve hissin gelişmesini istedi.

- **Rota seviyesi:** `_managerRoutes` altındaki bütün sayfalar (koç ve
  müdür: finans, yoklama, SMS, kitap havuzu, kurum sınavları, ders
  programı, sınıflar, öğrenci detayı, profil, markalama...) `_cockpitPage`
  ile açılır: `CupertinoPage` (sağdan kayar, kenardan kaydırınca geri) +
  `CockpitThemed`. Ekran kodu değişmeden kokpit temasını alır.
- **Tema (`cockpitTheme`)** artık iç ekran bileşenlerini de kapsar: üst
  çubuk zeminle bir, içerik altına kayınca beyaza döner (scrolledUnder) ve
  başlık büyük/kalın; sekmeler kayan yumuşak hap; dalga (ripple) yok,
  dokununca hafif vurgu; iOS anahtarı; yuvarlak onay kutusu; pencere ve
  alt sayfalar 22–24 px köşe; yüzen SnackBar; tarih seçici, menü, çip,
  ilerleme çubuğu. Kurumun başarı/hata renkleri kokpitte anlam renklerine
  eşitlenir (`brand.copyWith(success, danger)`). Kaydırma her yerde esnek.
- **Koyu tema:** `CockpitColors` artık `ThemeExtension` (açık + koyu takım,
  `context.cockpit.x`); `Tone.of(context)` / `tintOf(context)`. Uygulama
  koyu temadaysa kokpit de koyu; vurgu kurum renginin açık tonu
  (`cockpitAccent`).
- **Kurumsal işaret** `shared/widgets/corporate_look.dart`
  (`CorporateLook` tema uzantısı, `isCorporate`): pencerelere de geçer.
  Kurum panelinde `BizzLoader` sade dönen gösterge, `EmptyState` maskot
  yerine simge gösterir. `inCockpit` bunu kullanır.
- **Titreşim:** yoklamada işaretleme (seçim), "hepsi geldi" ve kaydetme
  (kaydedildi); SMS sıraya alındı; tahsilat kaydedildi. Haftalık çalışma
  sayfasında kayan seçim kontrolü.
- **Yoklama kartı:** baş harf avatarı, dört eşit seçenek kutusu (simge +
  ad; seçilince durum renginde dolar). **SMS:** bölüm başlıkları, kayan
  "Kime" seçimi. Liste ekranlarında (kitap, sınıf, öğrenci, finans
  listeleri, ders programı) kartlar arası 8 px.
- **Hata düzeltmesi:** temadaki metin stillerinde boyut yoktu (`Theme.of`
  çalışırken eklenir); üst çubuk başlığı, pencere başlığı gibi tema içi
  stiller 14 px'e düşüyordu. `cockpitTheme` boyutları
  `Typography.material2021().englishLike` ile birleştirir. `SlidingSegments`
  yazısı tek satır (bölünen yazı taşıyordu).
- Test: 501 test geçti; `admin_cockpit_test` koyu tema, maskotsuz
  yükleniyor, alt sayfa rotaları.

## 63. Bekleyen işler ekranı (6 Kasım 2026)

Tek soru: "Benden ne bekleniyor?" Koç kendi öğrencilerini, müdür bütün
kurumu görür. Giriş: kokpit üst çubuğunda rozetli simge
(`PendingWorkButton`; acil iş varsa rozet risk renginde, yoksa vurgu
renginde, iş yoksa rozet yok). Rota `/coach/pending`, `/admin/pending`.

- **Veri:** yeni tablo / repository yok; mevcut sağlayıcılar birleştirilir
  (`pendingWorkProvider`, `pending_work/presentation`). Saf fonksiyon
  `pendingItems()` (`pending_work/domain`): yoklama alınmadı/işaretsiz,
  kitap talebi onayı, yayın bekleyen kurum sınavı, hesap silme talebi
  (öğrenci başına satır, geçen gün + KVKK 30 gün), sınıfsız / şüpheli
  numaralı / numarası eksik öğrenci; müdürde ayrıca geciken taksit ve
  kurum hesabı uyarıları (`orgAlerts`). Sayısı sıfır olan iş girmez.
- **Seviye:** en fazla iki (risk: para, hesap, silme talebi; dikkat:
  diğerleri). Önce riskler. Satır: sol kenarda 3 px şerit, rakam (+ birim),
  ne olduğu ve sebep cümlesi; ilk 5 satır, sonra "Tümünü gör (N)".
- **Görünüm:** mevcut kokpit kartı (kullanıcı yeni gölge token'ı yerine
  bunu seçti), içinde sık satırlar, kart içinde kart yok; özet kutuları
  (Acil / Bekleyen) gölgesiz ince çerçeve. Filtre: kayan seçim Tümü / Acil.
- **Haller:** yükleniyor (iskelet), boş ("Bekleyen işin yok, her şey
  güncel."), filtre boş ("Acil iş yok." + Tümü sekmesine dönüş), hata
  ("Bekleyen işler yüklenemedi…" + Tekrar dene), kısmi hata (gelmeyen
  kaynak ayrı satır, gerisi görünür), kısmi yükleme (ince ilerleme çubuğu).
- **Kırılım:** 720 px altında özet kutuları üstte, filtre altında; 720 ve
  üstünde özet + filtre tek satır; içerik en fazla 840 px, ortalanır.
- Test: `test/pending_work_test.dart` (14 test); toplam 515 test geçti.

## 64. Alt çubuk yeniden düzenlendi; APK'da ikonlar (6 Kasım 2026)

- **İkon hatası (kod değil, derleme):** APK sürücü kökünden (`subst M:` →
  `M:\`) derlenince "başarılı" görünüyor ama `flutter_assets` pakete
  girmiyor; telefonda bütün ikonlar kutucuk çıktı. Doğrusu:
  `subst N: "…\Masaüstü"` ve `N:\Mentoria` içinden derlemek (gerekirse önce
  `flutter clean`). Kontrol: `unzip -l app-release.apk | grep -c flutter_assets`.
- **Müdür alt çubuğu (6):** Genel · Öğrenciler · Koçlar · Sınavlar · Finans ·
  İletişim. Öğrenciler: üstte yatay araç şeridi (`ToolStrip`: sınıflar ve
  öğrenciler, yoklama, ders programı, kitap havuzu) + liste + "Öğrenci
  daveti". Koçlar: şerit (Davetler → yeni `/admin/invites` sayfası, koç
  görüşmeleri) + liste. Sınavlar (`ToolGroupTab`): deneme yükle, yüklenen
  denemeler, kurum sınavları, optik oku, deneme trendleri, deneme planı.
  Finans: finans ekranının kendisi. İletişim: velilere SMS, duyurular.
  Ana sayfadaki "Kurum araçları" aynen duruyor. Gruplar
  `cockpit/nav_groups.dart` (`examTools`, `messageTools`).
- **Koç alt çubuğu (4):** Genel · Öğrenciler (şerit: sınıflar, yoklama, ders
  programım, kitap havuzu, ödev ver; liste; "Davet et") · Sınavlar · İletişim
  (duyurular, öğrenci daveti). Eski eylem düğmeleri (davet, ödev, yükle,
  denemeler) bu sekmelerin içinde. Geniş ekranda yan menü.
- Gruplanmış sekmelerin üst çubuğunda bekleyen işler rozeti ve profil.
- Test: `admin_cockpit_test` "6 sekme", `coach_cockpit_test` "sekmeleri";
  516 test geçti.

## 65. Web yayını: tanıtım sayfası, panel ve gizli demo (7 Kasım 2026)

- **Adresler (tek alan adı, `mentoria.com.tr`):** `/` tanıtım sayfası
  (`site/`, düz HTML/CSS, Nunito siteyle birlikte gelir; Google'a istek
  yok), `/app/` panel (Flutter web, gerçek Supabase), `/demo/` rol seçimi ve
  `/demo/panel/` örnek verili panel (DEMO=true). Demo **gizli**: sitede
  bağlantısı yok, `noindex`, robots.txt'de kapalı; toplantıda göstermek için.
  Yasal metinler `/gizlilik/`, `/aydinlatma/`, `/kullanim-kosullari/`
  (`assets/legal`'den üretilir, uygulamadakiyle aynı metin), hesap silme
  `/app/hesap-sil`.
- **Derleme:** `python tool/web/build_web.py` (ASCII yoldan; `C:\dev\Mentoria`
  bağlantısı ya da `N:`). İki Flutter derlemesi (`--base-href /app/` ve
  `/demo/panel/`) + site → `build/site`. `--no-flutter` yalnızca toplar,
  `--serve` Cloudflare gibi davranan yerel sunucu (http://localhost:8790).
  `_redirects` panel yollarını (`APP_ROUTES`) index.html'e çevirir;
  `test/web_test.dart` router'daki her üst düzey yolun listede olduğunu
  denetler (yeni üst düzey rota = listeye ekle). `_headers` güvenlik
  başlıkları; `/app` ve `/demo` arama motorlarına kapalı.
- **Web'e özel davranış:**
  - Adreslerde `#` yok (`usePathUrlStrategy`): davet linki
    `https://mentoria.com.tr/app/join/KOD` (`APP_LINK_BASE` web derlemesinde
    verilir). Şifre sıfırlama bağlantısı da `/app`'e döner (`webAppRoot`).
  - Açılış animasyonu web'de yok; girişli kullanıcı doğrudan paneline.
    Oturum tarayıcıda (localStorage) çıkış yapana kadar kalır. Tanıtım
    sayfası oturumu görürse `/app/`'e yönlendirir (`/?tanitim` ile görülür).
  - Bütün roller web'de tam ekran (kullanıcı kararı: ortada telefon
    genişliğinde sütun istenmedi). Öğrenci: 900 px ve üstünde alt menü
    yerine solda yan menü (`StudentShell`, `student-rail`); veli ve giriş
    ekranı tam genişlik; koç/müdür zaten yan menülü.
  - Demo rolü adresten: `?rol=admin|coach|student|parent`, yenilenince
    yoldaki rol (`Env.activeDemoRole`).
  - Yükleme ekranı (`web/index.html` + `web/flutter_bootstrap.js`), PWA
    manifest (Türkçe, yön kilidi yok): Chrome/Edge'de "Yükle", iPhone'da
    "Ana Ekrana Ekle".
  - `cupertino_icons` eklendi: çatının iOS tarzı bileşenleri bu yazı tipini
    kullanıyor, yoksa web/iOS'ta kutucuk çıkıyordu (derleme uyarısı).
- **Yayın:** `.github/workflows/deploy-web.yml` → Cloudflare Pages. Repo
  değişkeni `WEB_DEPLOY=true` olana kadar atlanır. Gerekenler: Variables
  `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `CLOUDFLARE_PROJECT`; Secrets
  `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
- **Yayın günü yapılacaklar:** alan adını Cloudflare'e bağla; Pages projesine
  `mentoria.com.tr` (ve `www` → yönlendirme); Supabase → Authentication →
  URL Configuration: Site URL `https://mentoria.com.tr/app`, Redirect URLs'e
  `https://mentoria.com.tr/app/**`; `iletisim@mentoria.com.tr` için
  Cloudflare Email Routing (Gmail'e yönlendirme); `_redirects`'in 200
  yönlendirmesini canlıda dene (`/app/login` sayfası yenilenince açılmalı).
- **Açık:** yasal metinlerde `[AD SOYAD]`, `[ADRES]`, `[WEB ADRESİ]`
  (`docs/kvkk/00_README.md`) hâlâ boş; web sitesinde de görünür. Doldurulunca
  `build_legal.py` + `legalVersion` artır.
- **Web bildirimi (FCM):** VAPID (herkese açık) anahtarı `Env.firebaseVapidKey`
  varsayılanında. Etkinleşmesi için Firebase konsolunda bir **web uygulaması**
  kaydı gerekiyor (Project settings → Your apps → Web): `apiKey` ve `appId`
  env.json'a / GitHub Variables'a `FIREBASE_WEB_API_KEY`,
  `FIREBASE_WEB_APP_ID` olarak girilir; yoksa web bildirimsiz derlenir.
  - İzin kendiliğinden sorulmaz: izin henüz sorulmadıysa sağ üstte
    "Bildirimleri aç" kartı (`WebPushPrompt`, app.dart); "Aç" dokunuşla
    tarayıcı iznini ister, "Şimdi değil" 14 gün gizler. Token
    `device_tokens`'a `platform = 'web'` ile yazılır, çıkışta silinir.
  - Arka plan bildirimini sitenin kökündeki `firebase-messaging-sw.js`
    gösterir (build_web.py aynı ayarlarla üretir; Firebase JS 13.0.0,
    firebase_core_web ile aynı sürüm).
  - `send-push` v16 (canlıda): yalnızca web adreslerine `webpush` bloğu
    (ikon + dokununca `https://mentoria.com.tr/app<rota>`; `WEB_APP_URL`
    gizli değeriyle değiştirilebilir). Telefon bildirimleri aynı.
  - iPhone'da web bildirimi yalnızca site ana ekrana eklenmişse (iOS 16.4+).
- **Ekran görüntüleri:** `node tool/web/screenshots.mjs` (site `--serve` ile
  açıkken), demodan `site/img/*.png`.

## 66. Web hata kaydı (7 Kasım 2026)

- Crashlytics web'de çalışmıyor; web panelinde yakalanmayan hatalar kendi
  tablomuza yazılıyor (üçüncü taraf yok, veri Frankfurt'ta).
- **Migration** `20261107100000_client_errors` (canlıda; rollback +
  `supabase/tests/client_errors_test.mjs`): `client_errors` tablosu,
  `report_client_error()` (anon + authenticated çağırabilir; giriş ekranı
  hataları da gelsin). Aynı sürümde aynı hata tek satır, sayaç artar;
  parmak izi = sayıları atılmış mesaj + yığının ilk satırı. Saatte 500 yeni
  satır sınırı, 90 günden eskiler yazarken ara ara silinir. Yalnızca süper
  admin okur/siler. Advisor'ın "anon SECURITY DEFINER çağırabilir" uyarısı
  bilinçli (check_invite gibi).
- **KVKK:** kimliksiz. Kullanıcı kimliği, e-posta, IP yok; adres yalnızca
  yol (sorgu/# atılır, sunucuda da kesilir); tarayıcı yerine yalnızca
  işletim sistemi türü (`web/windows`). Veri envanterine satır eklendi.
- **Uygulama:** `lib/core/crash/web_error_reporter.dart`; `initCrashReporting`
  web'de sürüm derlemesinde `FlutterError.onError` ve
  `PlatformDispatcher.onError`'a bağlar (demo/ayarsız kapalı). Oturumda aynı
  hata bir kez, en fazla 20 hata; gönderim hatası yutulur.
- **Görme:** platform paneli (süper admin) → sağ üstte böcek simgesi →
  `/platform/errors` (`ClientErrorsScreen`): son görülen üstte, dokununca
  yığın, "Kopyala", "Çözüldü, kaldır". Demo/testte
  `InMemoryClientErrorRepository`.
- **Okunaksız yığın:** web derlemesi `--source-maps` ile; harita dosyaları
  yayına girmez, `build/web_sourcemaps/`'e (CI'da 90 gün saklanan
  `web-sourcemaps-<sha>` artifact'ı). Çözmek için:
  `node tool/web/symbolize.mjs build/web_sourcemaps/main.dart.js.map yigin.txt`.

## 67. Tanıtım sitesi kurumsal tasarım (7 Kasım 2026)

- Kullanıcı isteği: samimi değil kurumsal, satış odaklı; dershanelerin
  kullandığı araçları tek yerde topladığımız öne çıksın; 3D görseller.
- `site/` yeniden yazıldı: koyu lacivert giriş bölümü (3D eğik panel +
  telefon + yüzen kartlar, fareyle döner), 8 modül şeridi, "dağınık araçlar
  yerine tek sistem" (SMS paneli, optik yazılımı, Excel, mesaj grupları...
  → Mentoria), modül bölümleri (veli iletişimi/SMS, ders programı sihirbazı,
  deneme ve optik analizi, yoklama, finans, koçluk), kendi markanız, roller,
  kurulum adımları, güvenlik/KVKK (koyu), demo talebi.
- 3D: saf CSS (perspective/preserve-3d) + `site/site.js` (kaydırınca
  belirme, kaydırdıkça eğikten düze gelen görseller, ders bloklarının ve
  sütunların yerine oturması). "Hareketi azalt" açıksa hepsi son halinde.
- Ders programı ve finans görselleri CSS ile çizildi (demo verisinde
  programda çakışma uyarısı, finansta eksi net görünüyordu); diğerleri
  demodan gerçek ekran (WebP, `node tool/web/screenshots.mjs`).
- Yazı tipi Poppins (sitenin içinde). Fiyat yok; çağrı "Demo talep edin"
  (`iletisim@mentoria.com.tr`).

## 68. Veli paneli kurumsal kokpit (7 Kasım 2026)

- Kullanıcı isteği: veli tarafı da koç ve müdür gibi kurumsal olsun.
- `ParentHomeScreen` kokpit temasında (`CockpitThemed`, `CockpitBackground`):
  gökyüzü başlığı ve Bızz konuşma balonu kaldırıldı; üstte `CockpitHeader`
  (markanın adı ve logosu, `title` + `showPending: false`; veli kurum
  kaydını okuyamadığı için ad markadan). Özet: `WeekHeroCard` ("Elif bu
  hafta", 7 günün kaçında çalıştı, halka "devam") + üç `MetricCard` (çözülen
  soru, son TYT neti ve değişimi, TYT ortalaması). Ardından haftalık özet,
  ders programı, duyurular, "Ayrıntılar" araç ızgarası (denemeler, sorular,
  konular, süre → ayrıntı sekmeleri), hedefler, görüşmeler, görevler ve
  ödevler (`CockpitSection`). Birden çok çocukta kayan seçim.
- `WeekHeroCard` (`caption`, `ringLabel`, ekran okuyucu metinleri) ve
  `CockpitHeader` (`title`, `showPending`) genelleştirildi; koç/müdürde
  varsayılanlar aynı.
- Veli iç sayfaları (`/parent/profile`, `announcements`, `child/:id`)
  `_cockpitPage` ile açılıyor. `SkyAppBar` kurum panelinde (`isCorporate`)
  düz çubuğa dönüyor: veli ayrıntı ekranı ve koçun öğrenci detayı da
  gökyüzüsüz.
- Test: `features_flow_test` "veli çocuğunun panelini salt okunur görür"
  kokpit parçalarını ve maskotun olmadığını denetliyor; 526 test geçti.

## 69. Eğitim ekranı web'de (7 Kasım 2026)

- Ders kartları geniş ekranda dev görünüyordu (sabit 2 sütun): artık
  `GridView.extent` (kart en fazla 240 px; telefonda yine 2 sütun).
- Bilgi kartları: en fazla 560 × 620 px ortada; fareyle de sürüklenebilir
  (`dragDevices`); altta ileri/geri düğmeleri (`card-prev`, `card-next`,
  uçlarda kapalı). Test: `learn_test` ekran senaryosu.


## 70. Web'de kaydırma akıcılığı (7 Kasım 2026)

- Derleme `--wasm`: Chrome/Edge/Firefox ve yeni Safari skwasm motoruyla
  çizer (CanvasKit'ten belirgin akıcı); desteklemeyen tarayıcıya flutter.js
  kendiliğinden JS + CanvasKit sürümünü yükler. Çapraz köken yalıtımı
  (COOP/COEP) açılmadı: tek iş parçacıklı skwasm; COEP Supabase görsellerini
  ve Firebase betiğini bozardı. Hata kaydında wasm satırları
  `main.dart.wasm.map` ile çözülür (sourcemaps artifact'ında).
- Kokpit başlığındaki buzlu cam (`BackdropFilter`) web'de kapalı: her
  karede bulanıklaştırma kaydırmayı takıltıyordu; yerine %96 opak zemin.
- Web'de kokpit kaydırması düz (`cockpitScrollPhysics()`): fare tekerleğiyle
  iOS esnemesi takılma gibi hissettiriyordu; telefonda esnek kalır.
- `LoopBuilder` (sürekli dönen çizimler) `RepaintBoundary` içinde: kaydırılan
  liste her karede yeniden boyanmıyor.
- Yerel sunucu (`--serve`) `.mjs`/`.wasm` türlerini açıkça veriyor (Windows
  `.mjs`'i text/plain veriyordu, wasm sürümü açılmıyordu).

## 71. Yeni logo (7 Kasım 2026)

- Logo: lacivert (#122B4B) yuvarlak kare, beyaz M, turuncu (#F5A623) çizgi.
  Kullanıcının görselinden ölçülüp vektöre çevrildi: `tool/brand/make_logo.py`
  → `assets/brand/logo.svg`, uygulama ikonları (`assets/brand/icon/*`),
  `web/favicon.png`, `web/icons/*` (yuvarlak + maskable). Ardından
  `dart run flutter_launcher_icons` (web üretimi kapalı: `web.generate: false`,
  yoksa web ikonlarını ve manifest renklerini ezer). Uyarlanır ikon zemini
  #122B4B.
- Uygulamada `MentoriaMark`; varsayılan markada `BrandLogo` = M + "Mentoria",
  kokpit başlığında da M. **Öğrenci panelinde yalnızca arı**:
  `BrandLogo(student: true)` → Bızz başı + "mentoria" yazısı. Dershanenin
  kendi logosu/baş harfi her yerde aynen kalır (beyaz etiket).
- Site üst çubuğu/alt bilgi/demo/404 `img/icon.png` (= Icon-192) kullanır;
  web açılış ekranı ve manifest renkleri laciverte çekildi. Giriş ekranındaki
  Bızz çizimi ve telefondaki tanıtım animasyonu (intro) maskot olarak kaldı.
- Test: `test/brand_logo_test.dart`.
- Açılış animasyonu (`intro_screen.dart`, telefonda): Bızz yerine logo
  (`BrandLogo(showName: false)`: varsayılanda M, dershanede kendi logosu);
  yukarıdan inip yaylanarak büyür, hafif dönüşle oturur, bal damlaları
  saçılır, harfler düşer.

## 72. Kurum sınavı sonucu velilere SMS (7 Kasım 2026)

- Migration `20261107120000_exam_result_sms` (rollback + `exam_result_sms_test.mjs`,
  canlıda uygulandı). Kurum sınavı (answer_keys) yayınlanınca ve yayındaki
  sınava yeni optik gelince (Excel, kamera) `_rank_key` sonunda
  `_queue_exam_result_sms`: her öğrencinin velisine (`guardian_phone_of`)
  "<Kurum>: <Öğrenci> - <Sınav> sonucu: 72,25 net, kurum sırası 12/240.
  Ayrıntılar uygulamada." `sms_outbox.exam_id` tekil: her deneme bir kez;
  anahtar düzeltme/yeniden yükleme tekrar göndermez (sonuç değişse de).
  Yalnızca son 3 günde oluşan denemeler (ayar sonradan açılınca eski
  sınavlar toplu gitmez). Telefonu olmayan atlanır.
- `organizations.exam_result_sms` (varsayılan açık); müdür "Velilere SMS"
  ekranındaki "Otomatik SMS" anahtarıyla kapatır (`exam_result_sms_enabled`,
  `set_exam_result_sms`; InMemory'de `examResultSms`).
- Koçun kendi Excel deneme yüklemesi (eski `import`, kurum sınavı değil) SMS
  göndermez. Sağlayıcı bağlanana kadar mesajlar sırada bekler.
- KVKK envanterine "Veliye giden SMS'ler" satırı eklendi.
- `20261109100000_exam_result_sms_subjects`: mesaja ders ders satırlar eklendi
  ("Matematik 22 doğru 3 yanlış 21,25 net"; `subjects.sort` sırasıyla, üst sınır
  800 karakter). TYT'de 9 ders olduğundan mesaj yaklaşık 3 SMS tutuyordu.
- `20261109110000_exam_result_sms_short`: ders satırları kısaldı ("Mat 22D 3Y
  21,25"; kısaltmalar ders koduna göre SQL'de). TYT mesajı yaklaşık 260 karakter,
  yani 2 SMS; çok uzun kurum, öğrenci veya sınav adı 3'e çıkarabilir.

## 73. Performans geçişi (9 Kasım 2026)

- Migration `20261109120000_performance_pass` (rollback +
  `performance_pass_test.mjs`, canlıda). Sonuçlar aynı kalır:
  - Index: `exams (batch_id, source)`, `exams (student_id, exam_type, taken_on,
    created_at)`, `notifications (kind, ref_id)` ve index'siz 13 yabancı anahtar.
    Kapsanan `exam_answers (subject_id)` ve `exams (created_by)` kalktı.
  - `student_summaries` artık DEFINER (satır başına RLS yok). RLS'in verdiği
    kurallar sorguda açık: dershane, lisans ve koç bağı. Sonuncusu olmazsa iki
    koçlu öğrenci koçun listesinde iki kez çıkar.
  - `weekly_summary_data` tarih süzgeci index'i kullanır; `activity_weeks` tek
    geçiş (test eski ve yeni çıktıyı birebir karşılaştırır).
  - `cron.job_run_details` hiç temizlenmiyordu (127 bin satır, veritabanının
    yarısı). `purge-cron-history` her gece 7 günden eskisini siler.
- Advisor'daki "kullanılmayan 133 index" bilerek silinmedi: canlıda 6 profil var,
  kullanım istatistiği henüz bir şey göstermez.
- İstemci:
  - Tema yalnızca marka değişince kurulur (`_appThemesProvider`, `Branding ==`).
    Önceden kök her yenilendiğinde 400 ms'lik tema geçişi baştan başlıyordu.
  - Profil yalnızca kullanıcı değişince ya da `userUpdated` olayında çekilir;
    saatlik token yenilemesi artık profil, marka ve avatar isteği tetiklemez.
    Sonuç: başka cihazdan yapılan profil değişikliği yeniden girişe ya da
    `invalidate`'e kadar görünmez.
  - Ana sayfa başlığı: gökyüzü, avatar ve Bızz ayrı `RepaintBoundary`; başlık
    kapanınca `TickerMode` animasyonları durdurur. `FadeSlideIn.stagger` üst
    sınırlı (6. sıradan sonrası aynı gecikme).
  - Hata defteri: `cacheHeight` ve `mistakePhotoProvider` autoDispose (5 dakika).
  - Excel okuma arka planda (`readSpreadsheetInBackground`, 6 ekran).
- Hata düzeltmeleri:
  - `fetchCardsForExam` ve `fetchOutcomeHistory` sayfalı (`_outcomeRows`). Sunucu
    tek cevapta 1000 satır verdiği için büyük sınavda karneler sessizce eksik
    kazanımla gelirdi. Canlıdaki `max_rows` ayarı SQL'den okunamıyor; varsayılan
    1000 varsayıldı.
  - `schedule_screen_test` her pazartesi kalıyordu ("Pazartesi (bugün)").
- 1000 satır sınırı: ortak `fetchAllPages` (`lib/core/data/paged_fetch.dart`).
  Sayfalı olanlar: ücretler, gelirler, giderler, virmanlar, kurum üyeleri,
  `student_summaries`, `managed_students_list`, `attendance_day`. Son sıra ölçütü
  benzersiz olmalı (toplu ücretlerin `created_at`'i aynıdır). Yeni büyüyebilen
  liste eklerken bunu kullan. `save_attendance` 1000'lik parçalarla gönderilir.
  Dikkat: postgrest-dart'ta `.order()` varsayılanı azalan; RPC'ler bu yüzden
  `ascending: true` ile çağrılır. Gerçek hesapla denenmedi (demo in-memory).
- Yapılmadı: `my_risk_list` N+1 yeniden yazımı, sıralama önbelleği, bahçe ekranı
  çizimi, yazı tipi küçültme (ölçüm gerekir). Kitap havuzu ve silme talepleri
  sayfasız (1000'i aşması beklenmiyor); yoklama SMS'inin 1000 öğrenci sınırı duruyor.

## 74. Kaydırma ve dokunma hissi düzeltmeleri (9 Kasım 2026)

- `Reveal`: tembel listede bölüm kaydırınca yeniden kurulup gecikmeyle beliriyor,
  hızlı kaydırmada boşluk görünüyordu. Artık sayfa kaydırılmışsa anında görünür.
- `Pressable`: `Listener` kaydırma başlayınca iptal almadığından kart parmak
  kalkana kadar küçük kalıyordu. `kTouchSlop` aşılınca eski boyuna döner.
- `CockpitHeader`: başlık tam açıkken `BackdropFilter` çizilmez (görünmeyen blur).
- Test: `test/cockpit_motion_test.dart`. Web demoda kaydırma denendi; telefonda
  denenmedi, FPS ölçülmedi. Commit yok, APK yok.

## 75. Güvenlik kontrolü (9 Kasım 2026)

- SQL/RLS: 48 test dosyası, 72 migration üzerinde geçti. Depoda ve git geçmişinde
  sır kalıbı çıkmadı. Edge Function'lar parolasız isteğe 401 döndü.
- Advisor: kritik yok. Girişsiz çağrılabilen 4 DEFINER: `check_invite`,
  `tenant_branding`, `report_client_error`, `match_student_number`.
- Düşük bulgular, düzeltilmedi: `outcome_label`/`outcome_topic` UUID bilen her
  girişli kullanıcıya RLS'i aşarak kazanım adı/konusu döner (uygulama çağırmıyor,
  izin kaldırılabilir); `match_student_number` yalnızca bulunamayan numarayı
  sayar, `ok`/`taken` sınırsız; `report_client_error` saatlik 500 sınırı girişsiz
  doldurulabilir. Sızdırılmış parola koruması hâlâ kapalı.
- `save_schedule_entries` kurum dışı kimliği `guard_timetable_row` ile reddediyor.
- Sızma testi değil: canlıda katalog okundu, veri yazılmadı. DEFINER'ların hepsi
  tek tek okunmadı.

## 76. Güvenlik sıkılaştırması (9 Kasım 2026)

- Migration `20261109130000_security_tighten` canlıda (rollback ve
  `supabase/tests/security_tighten_test.mjs` ile).
- `outcome_label`/`outcome_topic` doğrudan çağrılamaz; `save_exam` kullanmaya
  devam eder. §75'teki iki bulgu kapandı.
- `match_student_number`: `taken` de `invite_check_failures`'a sayılır (IP başına
  10 dakikada 30). `ok` bilerek sayılmaz: okul ağında aynı IP'den toplu kayıt
  engellenmesin. Bu yüzden boş numaraları denemek hâlâ sınırsız; yalnızca dolu
  numarayı bulmak sınırlı.
- `report_client_error` saatlik sınırı ve kapalı parola koruması duruyor.

## 77. Veli SMS izni kararı ve hesapsız tarama (9 Kasım 2026)

- **Bilinçli karar, düzeltilmedi:** `_queue_exam_result_sms`, 18 yaş üstü öğrencinin
  `parent_view` iznine bakmıyor; sonuç veli/ödeyen numarasına sıraya girebilir.
  Kullanıcı "sorun değil" dedi. Canlıda bu türden SMS yok, sağlayıcı bağlı değil.
- 42Crunch hesap açılamadığı için kullanılmadı, `42c-ast` kaldırıldı.
- Hesapsız tarama (canlı şema, OSV, npm audit, web başlıkları): yeni açık yok.
  CSP eklenmedi; Flutter web'i bozabileceği için denenmeden eklenmemeli.

## 78. Öğretmen ödemeleri (9 Kasım 2026)

Migration `20261109140000_teacher_pay` (rollback + `teacher_pay_test.mjs`).
Finans → "Koç ve öğretmen" sekmesinde koçların altına öğretmen bölümü eklendi
(`lib/features/finance/presentation/teacher_pay_ui.dart`). Uygulama para
göndermez: kayıt defteridir.

- **Öğretmen ≠ koç:** öğretmenler `teachers` tablosunda, hesabı olmayabilir; bu
  yüzden `coach_pay_rates` kullanılmadı. Yeni `teacher_pay_rates`: ödeme şekli
  (`hourly` / `fixed`), tutar, not. Ödeme `finance_expenses` satırı (`salary`),
  `teacher_id` + `teacher_name`; öğretmen silinse de kayıt adıyla kalır. Bir gider
  aynı anda koça ve öğretmene bağlanamaz.
- **Saat:** yayındaki programda öğretmenin her satırı 1 ders saati (süresi 60
  dakika olmak zorunda değil). Yayında program yoksa saat elle yazılır.
- **Ödeme formu:** saat başına: hafta (varsayılan 4) × haftalık saat × ücret önerilir,
  her alan değişir (tatil, ek ders). Saat ve ücret ödeme notuna otomatik yazılır.
- `fetchEntries` artık `fetchAllPages` ile (1000 satır sınırı).
- Koç hesabına bağlı öğretmen iki yerde de görünür; kart "Koç hesabına bağlı" der.
- `finance_test.mjs` rollback listesine yeni migration eklendi. KVKK maddesi:
  `docs/kvkk/00_README.md`.
- Web önizleme: `-o` ile mutlak `C:/dev/...` verilince `assets/fonts` boş kaldı,
  ikonlar kutucuk çıktı (kod sorunu değil). Telefonda denenmedi.

## 79. Gelirlerde tahsilat özeti ve kalabalık demo (9 Kasım 2026)

- Gelirler sekmesinin başında "Bu ay öğrenci tahsilatı" kartı (`_MonthCollectionCard`);
  liste ücret dışı gelirlerle sınırlı kaldı.
- **Hata düzeltmesi:** `InMemoryFinanceRepository.demo` `teachers` almıyordu; §78'in
  demosunda öğretmene ücret/ödeme kaydetmek `FINANCE_BAD_TEACHER` veriyordu.
- **`DEMO_RICH`** (`lib/dev/demo_rich.dart`): 24 öğrenci, 4 koç; deneme, çalışma, görev,
  görüşme, yoklama (21 gün), kitap, SMS geçmişi, duyuru, risk, finans (ücret, maaş,
  öğretmen ödemesi, gider, gelir). Web `/demo` bu bayrakla derlenir
  (`tool/web/build_web.py`). Testler küçük demoya bağlı; varsayılan kapalı,
  `test/demo_rich_test.dart` `demoRichEnabled` ile açar.
- Kokpit sayıları elle yazılmadı, `richCockpitData` öteki demo verisinden hesaplar.
- Kalabalık demoda koç yalnızca kendi öğrencilerini görür (küçük demoda hepsi).
- Bütün adlar ve telefonlar uydurma. Commit yok.

## 80. Personel yönetimi ve çek / senet (9 Kasım 2026)

Migration `20261109150000_staff_cheques` (rollback + `staff_cheques_test.mjs`), canlıda.
Yalnızca müdür. Uygulama para hareketi yapmaz.

- **Personel** (`lib/features/staff/`, `/admin/staff`; Kurum araçları ve Koçlar sekmesi):
  `staff_members` kart, `staff_leaves` izin. Liste kart + koç + ders programı öğretmenini
  birleştirir (`mergePersonnel`); kartı olmayan koç / öğretmene izin ya da düzenleme girilince
  kart açılır. Ayrılan kişi `end_on` ile "Ayrılanlar"a düşer, kayıt kalır. Ödeme:
  `finance_expenses.staff_id`; kart silinse de ad kalır. Bir gider en çok bir kişiye bağlanır.
- **Bilerek yok:** TC kimlik, IBAN, sağlık ayrıntısı, belge yükleme, bordro (KVKK ve kapsam).
- **Çek / senet** (Finans son sekme, `cheques_ui.dart`; Özet'te vade uyarısı, Excel'de sayfa):
  `finance_cheques`; ekleme ve ilk durumda silme doğrudan, durum yalnızca `set_cheque_status`.
  Tahsil: ücret seçiliyse `record_payment`, değilse `record_income` (`method = other`). Ödendi:
  `finance_expenses` (`other`). Geri alma / karşılıksız: makbuz iptal ya da gider silinir.
  Kayıt düzenleme yok (sil, yeniden ekle). Vade bildirimi yok, uygulama içi uyarı var.
- SQL'de `select (f()).*` fonksiyonu sütun başına çağırır; `select * from f()` kullan.
- `org_credits_test` ₺ iznine `lib/features/staff/` eklendi (kurumun kendi defteri).
- Web'de yeni ikon boş görünürse tarayıcı eski `MaterialIcons` dosyasını önbellekten
  veriyordur: Ctrl+F5. Telefonda ve gerçek hesapla denenmedi. Commit yok.

## 81. Sınav yükleme akışı ve öğrenci analizi (9 Kasım 2026)

Kullanıcı kararı: her deneme cevap anahtarı ve kazanımla, optik okuyucu çıktısından
yüklenir; öğrenci hangi konuda ne yanlış yaptığını doğrudan görür.

- Migration `20261109160000_exam_key_required` (canlıda): `publish_exam`, iptal edilmemiş
  her sorunun cevabı ve kazanımı yoksa `EXAM_KEY_INCOMPLETE` verir. Serbest metin kazanım
  (`outcome`) da sayılır. Eski yayınlar değişmez. Yayındaki sınavda sonradan kazanım
  silmek engellenmedi (`save_exam`); yalnızca yayın anı denetleniyor.
- Sınavın Sonuçlar sekmesinde "Yayın kontrolü" (`ExamDefinition.keyGaps`); eksikse düğme kapalı.
- Menüden kaldırıldı: Deneme yükle, Yüklenen denemeler, Optik oku (kısa yol). Rotalar duruyor;
  kamera okuma sınavın içinden açılır. Koç ve öğrencinin elle deneme girmesi duruyor.
- Öğrenci: ana sayfa ve Denemeler'de `LastExamAnalysisCard`; karne Soru soru sekmesi önce
  yanlış ve boşları gösterir, satır başlığı konu. Düğme adı "Sınav analizleri".
- **Açık:** sabit genişlikli .txt optik çıktısı okunmaz (yalnızca Excel, CSV, ayraçlı TXT).
  Kurumun gerçek makine dosyasıyla denenmedi; örnek dosya gerekli.

## 82. Kitap raporu (9 Kasım 2026)

Migration `20261109170000_book_report` (canlıda), `book_question_report(term)`; müdür kurumu,
koç kendi öğrencilerini görür. Ekran `/admin|coach/book-report`: öğrenciye ya da kitaba göre,
arama, ders ve sınıf süzgeci. Sayılar yalnızca Kitaplarım'a girilen çalışmalardan gelir;
Soru sekmesinde serbest kaynak yazılan kayıt kitaba bağlanmaz. Dönem seçici ve Excel yok.

## 83. Optik paketi: sabit sütunlu .txt, anahtar ve kazanım tablosu (9 Kasım 2026)

Kullanıcının örnek dosyaları `test/fixtures/optic/` (TYT07): optik çıktısı (40 satır, 159
karakter, UTF-8, sondaki 120 karakter cevap, öncesi kitapçık), anahtar metni (A ve B),
`soru_kazanim` CSV'si (`;`, A cevabı, B'deki yeri, zorluk). `lib/features/exam_import/domain/exam_package.dart`.

- Kurum sınavları > "Dosyalardan sınav kur": üç dosya birlikte seçilir, içerikten tanınır.
  Anahtar + tablo çapraz denetlenir (A cevabı, B anahtarı, B yerleri); çelişki hepsiyle
  bildirilir. Kazanımlar havuza eklenip sorulara bağlanır, sınav taslak kaydedilir, optik
  seçildiyse doğrulama raporu açılır (sütun eşleştirme atlanır).
- B kitapçığında Sosyal ve Fen bölümünde soru dersler arasında karışabiliyor; sistem
  kitapçığı ders içinde tuttuğu için cevaplar ders sırasına yeniden dizilir (`bookletOrders`).
  Bu sıra sınavda saklanmaz: kayıtlı çok kitapçıklı sınava .txt'yi sonradan yüklemek için
  sihirbaz "Dosyalardan sınav kur"u önerir. Tek kitapçıkta .txt sihirbazda doğrudan okunur.
- Kitapçığı boş satır: iki anahtarla puanlanır, fark ≥10 doğruysa o kitapçık seçilir ve raporda
  not düşülür (örnekte 2026040 B: 65'e 23); değilse A kalır.
- TYT, AYT ve YDT dosyadan kurulur (10 Kasım): tür sınav adından, yoksa anahtar uzunluğundan
  (120 / 160 / 80). AYT'de genel soru numarası kitapçık sırasını izler (`bookletSubjects`:
  Edebiyat-Sosyal-1, Sosyal-2, Matematik, Fen); .txt her zaman bu sırayla bölünür, sınavdaki
  ders sırası farklı olsa da (`subjectsInBookletOrder`). Excel başlık tahmini AYT'yi tanır
  ("Sosyal-1/2", "Tarih-1/2", "TDE"). AYT / YDT gerçek makine dosyasıyla denenmedi; testler
  TYT07 biçiminde üretilen dosyalarla (`exam_package_ayt_ydt_test.dart`,
  `exam_import_ayt_ydt_test.mjs`). `*` boş sayılır.
- Örnekte: Elif 72 D / 38 Y / 10 B = 62,5 net; en yüksek Vildan 104,75; Can Öztürk boş;
  Gökhan'ın numarası 0045127 (kurum kaydında 45127 ise eşleşir). Canlı kurumda denenmedi;
  numaralar kurum listesinde yoksa raporda "eşleşmedi" çıkar.

## 84. Ortak hareket ve geri bildirim dili (10 Kasım 2026)

His: kurumsal, sakin. Bütün süre / eğri / mesafe `lib/core/design/motion.dart`
(`AppMotion`): instant 100, fast 180, base 240, slow 320 ms; enter easeOutCubic, exit
easeInCubic, move easeInOutCubic; kayma 8–24 px. Hareketi azalt ve testler tek yerden
(`Motion.of`, `AppMotion.of`). Titreşim `core/design/haptics.dart` (`AppHaptics.select /
confirm / warn`); `CockpitMotion` ve `CockpitHaptics` kalktı.

- **Giriş:** `FadeSlideIn` tek uygulama (12 px, 240 ms, öğe başına 30 ms, ilk 8 öğe);
  yalnızca ilk kurulduğunda oynar, sayfa kaydırılmışsa anında. `Reveal` ve `staggered`
  bunu sarar. `Pressable` = `PressScale` (0,97, kaydırınca bırakır).
- **Sayfa geçişi:** `core/design/page_transitions.dart` `AppPageTransitionsBuilder`
  (iOS Cupertino + kenardan geri; ötekilerde belirme + 16 px). `_cockpitPage` artık
  `MaterialPage`; Android'de kokpit sağdan kaymaz. Alt sayfa ve pencereler
  `AppMotion.overlayStyle(context)` ile açılır (yeni çağrıya da eklenmeli).
- **Yükleniyor:** `shared/widgets/skeleton.dart` `LoadSwitcher` (iskelet en az 300 ms,
  240 ms çapraz geçiş, üstten hizalı) ve `SkeletonList`. `AsyncView` bunu kullanır.
  Kurum panelinde `BizzLoader` iskelet çizer; öğrenci tarafında maskot kalır.
- **Grafik:** fl_chart'lara `duration: AppMotion.base, curve: AppMotion.enter`; ilk
  görünüşte `RevealIn`.
- **Kaydırma:** kokpitin Android'deki zorunlu bounce'u kalktı (platform varsayılanı).
  Tek döngülü listeler `ListView.builder`; üç seçim penceresi `prototypeItem` ile
  (başlık ve alt satır tek satır).
- **Bilinçli istisnalar** (`test/motion_tokens_test.dart` listeler; yeni sabit süre ya
  da eğri bu testi düşürür): açılış, haftalık özet, bahçe, gökyüzü başlığı, alev /
  kavanoz / rozet, bal kadranı, maskot, konfeti. Düğme içi ve açılış kapısındaki
  dönen göstergeler ile "daha fazla yükle" göstergeleri de kaldı.
- **Yapılmadı:** SnackBar'a aşağıdan kayma eklenmedi (yüzen SnackBar çatıda yalnızca
  belirir; süre zaten 4 sn); öğrenci temasında SnackBar yüzen değil. Düğmelerde yalnızca
  dolu düğmenin içeriği küçülür (tema ile bütün düğme ölçeklenemiyor). Karışık içerikli
  uzun listeler (`ListView(children)`) dönüştürülmedi. Tarih seçici çatının süresiyle
  açılır. Alt sayfa eğrisi çatıda sabit, yalnızca süresi ayarlanır.

## 85. İnceleme düzeltmeleri: oturum değişimi, SMS kilidi (10 Kasım 2026)

- **Önceki hesabın verisi:** repository sağlayıcıları `supabaseClientProvider` yerine
  `sessionClient(ref)` ile istemci alır (`auth_repository.dart`); bu yardımcı oturumdaki
  kullanıcı kimliğini de izler. Çıkış yapıp başka hesapla girince repository yeniden
  kurulur, ona bağlı bütün `FutureProvider`'lar sıfırlanır (önceden öğrenci listesi,
  finans, kurum bilgisi aşağı çekip yenileyene kadar önceki hesabınki kalıyordu). Ayrı bir
  sağlayıcı değil, çünkü istemci nesnesi hep aynı; Riverpod `==` ile eşit değerde
  bağımlıları yenilemez. Yeni repository yazarken `sessionClient(ref)` kullanın;
  `test/auth/session_scope_test.dart` tarar. İstisna: `app_version.dart` (oturumsuz).
- **Çift SMS:** `send-sms` (v2) mesajları `claim_sms()` ile alır (migration
  `20261110100000_sms_claim`, canlıda): `for update skip locked` + `status = 'sending'`.
  15 dakikadan uzun `sending` kalan mesaj yeniden gönderilmez, `failed` olur (gitmiş
  olabilir). Test: `supabase/tests/sms_claim_test.mjs`.
- **Netgsm:** GET + adreste parola yerine REST v2 (`POST /sms/rest/v2/send`, Basic auth,
  JSON; yanıt `code: "00"`). Biçim resmi dokümandan değil, Netgsm Go istemcisinin
  (`mobinova/netgsm-go`) kaynağından doğrulandı; sağlayıcı bağlanınca ilk mesajla deneyin.
- **Demo + env.json:** router'daki oturum dinleyicisi demo modunda Supabase'e dokunmaz.

## 86. Öğretmen rolü ve öğretmen paneli (11 Kasım 2026)

Plan: `docs/OGRETMEN_WHATSAPP_PLANI.md` (A aşaması; B soru çözümü ve C WhatsApp
henüz yok). Migration'lar `20261111100000_teacher_role_enum` (enum değeri ayrı dosyada:
PostgreSQL yeni değeri aynı işlemde kullandırmaz) ve `20261111110000_teacher_role`
(rollback'leri var; ikisi de **canlıda**). Test: `supabase/tests/teacher_role_test.mjs`,
`test/teacher_test.dart`, `test/auth/invite_signup_test.dart` (öğretmen kaydı).

- **Rol:** `user_role` = `teacher`, ana sayfa `/teacher`. Öğretmen öğrenci verisi
  görmez (koç değil); `teachers` tablosunu da doğrudan okuyamaz, kendi satırı
  `my_teacher()` ile gelir. Programı mevcut `my_timetable()` (`teachers.profile_id`).
- **Davet:** müdür → `create_invite('teacher')` (kredi harcamaz). Müdür panelinde
  Koçlar sekmesi şeridinde "Öğretmenler" (`/admin/teachers`): liste, "Hesabı var /
  Hesap yok", "Öğretmen davet et". Kayıt ekranında öğretmen davetinde branş seçimi
  zorunlu (`teacher_branches`); sunucu boş gelirse `Genel` yazar.
- **Kendiliğinden liste:** `apply_signup_invite` öğretmen profilini açınca `teachers`
  satırını da açar. `guard_timetable_row` (20261105140000 sürümü üzerine) yalnızca
  SECURITY DEFINER fonksiyonların işlem içinde açtığı `mentoria.timetable_trusted`
  bayrağıyla müdür denetimini atlar; `teachers.profile_id` artık `teacher` rolünü de
  kabul eder.
- **Branş:** öğretmen panelindeki "Branşlarım" → `set_my_teacher_branches`.
- **Birleştirme:** müdür daha önce elle eklediği hesapsız öğretmenle aynı adlı hesaplı
  satır görünce "Birleştir" → `merge_teachers(keep, from)`: program, ders ihtiyacı,
  müsaitlik (elle girilen kalır), ücret, gider, personel bağlantısı korunur; aynı saatte
  iki satırın dersi varsa `TEACHER_MERGE_CONFLICT`. Otomatik birleştirme yok (yanlış
  eşleşme riski).
- **Demo:** `DEMO_ROLE=teacher` (Mehmet Arslan, demo programındaki Fizik öğretmeni);
  web `/demo` için `tool/web/build_web.py` APP_ROUTES'a `teacher` eklendi.
- **SSS:** `tool/faq/faq_content.py` TEACHER. Oluşturucu, elle güncellenmiş lisans
  sorusunu eski metne döndürüyordu; kaynak güncellendi, SSS bloğu içindeki iki lisans
  çevirisi bloğun dışına taşındı.
- **Açık:** öğretmene bildirim yok (program yayınlanınca yalnızca öğrenciye gidiyor);
  öğretmen müsaitliğini kendisi giremiyor; KVKK aydınlatma metninde öğretmen rolü yok.

## 87. Soru çözümü, birebir ders ve etüt talepleri (11 Kasım 2026)

Plan B aşaması (`docs/OGRETMEN_WHATSAPP_PLANI.md`). Migration
`20261111120000_tutoring_sessions` (rollback'i var; **canlıda**), `send-push` v17.
Testler: `supabase/tests/tutoring_sessions_test.mjs` (48 adım), `test/tutoring_test.dart`.
Ad notu: `study_sessions` pomodoro tablosu olduğu için yeni tablolar `tutoring_*`.

- **Kullanıcı kararı:** talebi yalnızca öğretmen onaylar / reddeder; koç ve müdür
  yalnızca görür.
- **Oturum (`tutoring_sessions`):** müdür açar (`/admin/tutoring`, Koçlar şeridinde
  "Soru çözümü ve birebir"): öğretmen, tür (soru çözümü / birebir / etüt), gün, saat,
  kontenjan (birebirde 1), ders (boşsa öğretmenin ilk branşı), açık/kapalı. Haftalık
  tekrarlar. Öğretmenin aynı gün çakışan oturumu (`TUTOR_SESSION_OVERLAP`) ya da
  yayındaki programda o saatte dersi (`TUTOR_TEACHER_BUSY`) varsa reddedilir. Program
  üreticisi bu oturumları henüz görmüyor (ters yönde koruma yok).
- **Talep (`tutoring_requests`, yalnızca RPC):** öğrenci `/student/study` (ana sayfada
  `TutoringHomeCard`, kurumda oturum yoksa görünmez): 7 günlük liste, "Talep et" + konu.
  Kurallar: 14 gün, başlamış oturum yok, aynı oturuma aynı gün tek etkin talep, günde 3
  etkin talep, onaylı sayısı kontenjana ulaşınca `TUTOR_SESSION_FULL`. Öğrenci iptal
  edebilir. Saatler Türkiye saatiyle (`tr_now()`).
- **Öğretmen:** ana sayfada "Soru çözümü ve birebir" bölümü: bekleyenler (onayla /
  gerekçeli reddet), yaklaşan onaylılar, haftalık oturumları.
- **Koç:** İletişim sekmesinde "Soru çözümü talepleri" (`/coach/tutoring`, kendi
  öğrencileri); müdür aynı listeyi oturum ekranının Talepler sekmesinde görür.
- **Bildirim `tutoring_request`:** yeni talep → öğretmene (hesabı varsa, rota
  `/teacher`); karar → öğrenciye (`/student/study`).
- `merge_teachers` oturumları da taşır (aksi hâlde silinen satırla giderdi).
- **Açık:** talep kayıtları için saklama süresi yok (KVKK listesinde); geçmiş talepler
  ekranda görünmüyor (yalnızca bugün ve sonrası); öğretmen gelen/gelmeyen işaretlemiyor.

## 88. Velilere WhatsApp, SMS kapandı (11 Kasım 2026)

Kurum velilerle yalnızca WhatsApp'tan konuşuyor (docs/OGRETMEN_WHATSAPP_PLANI.md §C, F).
Migration `20261111130000_whatsapp`, Edge Function `send-whatsapp` ve `whatsapp-webhook`.
Kurulum: `docs/WHATSAPP_KURULUM.md`.

- **Kuyruk aynı:** `sms_outbox` (adı korunuyor; yoklama, taksit, toplu mesaj, deneme sonucu
  fonksiyonları adla yazıyor). Yeni sütunlar `channel` (varsayılan `whatsapp`), `template`,
  `params`, `media_path` (ödev PDF'i için hazır), `wa_message_id`, `delivered_at`, `read_at`.
  Sıradaki eski SMS'ler de `whatsapp` yapıldı.
- **Bağlantı `org_whatsapp`:** kurum başına `phone_number_id`, `waba_id`, görünen numara,
  kalıcı erişim anahtarı, şablon adı. Politika yok, istemci hiç okuyamaz; müdür
  `org_whatsapp_status()` ile durumu ve son 30 gün sayılarını görür (anahtar dönmez),
  `set_org_whatsapp` (anahtar boşsa eskisi kalır) / `disconnect_org_whatsapp`.
  Embedded Signup yok: bilgiler Meta panelinden elle girilir.
- **Gönderim:** `kick_sms()` artık `send-whatsapp`'ı dürter (adı korunuyor, 5 dakikalık
  zamanlayıcı aynı). `claim_messages()` kilitli alır (çift gönderim yok, 15 dk'dan uzun
  'sending' → 'failed'); yalnızca bağlı kurumların mesajları. Satırda şablon yoksa kurumun
  genel şablonu `kurum_bilgilendirme`: {{1}} metin, {{2}} kurum adı. Değişkende satır sonu
  olamaz (` · ` olur), en çok 1024 karakter.
- **Webhook:** Meta imzası (`X-Hub-Signature-256`, `WHATSAPP_APP_SECRET`) doğrulanır;
  `whatsapp_mark` teslim / okundu / hata yazar. Veli cevapları alınmaz (coexistence: müdürün
  WhatsApp Business uygulamasında kalır).
- **SMS:** `claim_sms` yalnızca `channel = 'sms'` alır; `send-sms` repoda duruyor ama
  `SMS_PROVIDER` boş, hiçbir şey göndermez. Panodan silinebilir. Ekranlarda "SMS" yazıları
  WhatsApp oldu; toplu mesajdaki SMS sayacı kaldırıldı.
- **Uygulama:** `/admin/whatsapp` (`WhatsAppConnectScreen`), toplu mesaj ekranının başında
  `WhatsAppStatusCard` (bağlı değilse kırmızı, sıradaki mesaj sayısı). Demo: bağlı.
- **Açık:** ödev PDF'i (4. aşama), koçun veliye mesajı için şablon, veli WhatsApp rızası
  (`whatsapp_guardian`) ve yurt dışına aktarım (KVKK listesinde).

## 89. Ödev PDF'i ve koçun mesajı veliye WhatsApp'tan (11 Kasım 2026)

Migration `20261111140000_homework_whatsapp`, `send-whatsapp` v2. Şablonlar:
`docs/WHATSAPP_KURULUM.md`.

- **Ödev:** koç / müdür "Öğrenciye gönder" deyince ödev kaydedilir (`send_assignment` artık
  kimliği döndürür), sayfa kapanır ve arkada veliye gönderim başlar:
  `queue_homework_whatsapp` önce denenir; `no_phone` / `already` ise PDF hiç üretilmez.
  `HW_NO_PDF` gelirse uygulama PDF'i çizer (`renderHomeworkPdf`: tek A4, kurum şeridi marka
  renginde, başlık, öğrenci, ödevi veren, tarihler, maddeler, not), `homework` kovasına
  `<kurum>/<ödev>.pdf` olarak yükler ve yeniden çağırır. Yolu sunucu kurar; yükleme politikası
  yalnızca o ödevi yönetebilene (`can_manage_assignment`) ve kendi kurum klasörüne izin verir.
  Mesaj `odev_bildirimi` şablonu, belge başlığında `Odev.pdf` (7 günlük imzalı adres);
  değişkenler: veren, öğrenci, başlık, son tarih, kurum. Her ödev bir kez (tekil index).
  Sonuç koça alttaki bildirimle söylenir (gönderiliyor / veli telefonu yok / gönderilemedi).
- **Koç → veli:** öğrenci sayfasının üst çubuğunda sohbet simgesi ("Veliye WhatsApp") →
  `GuardianMessageSheet`: metin (1-900), `send_guardian_message` (`koc_mesaji` şablonu:
  öğrenci, koç, metin, kurum), öğrenci başına 24 saatte en çok 5 (`GUARDIAN_MSG_LIMIT`).
  Altında son 30 mesaj ve durumu (`guardian_messages`: sırada / gönderildi / teslim /
  okundu / gitmedi + hata).
- `sms_outbox.student_id` (öğrenci silinince satır da silinir), `assignment_id`.
- **Saklama:** PDF 80 gün (`purge_homework_pdfs`, pg_cron `homework-pdf-retention` →
  `storage_cleanup`), mesaj kaydı 90 gün (mevcut).
- **Açık:** öğretmen rolü ödev veremiyor (`can_manage_student` yalnızca koç / müdür);
  kuruma logo PDF'e basılmıyor (yalnızca ad ve renk); sınıfa toplu ödev yok (her öğrenci ayrı).

## 90. Kurum sınavı: cevap anahtarı dosyası isteğe bağlı (11 Kasım 2026)

Kurumun kazanım tablosu (`soru_no;bolum;kazanim;zorluk;a_cevap;b_sorusunun_yeri`) her sorunun
A cevabını ve B kitapçığındaki yerini zaten içeriyor. "Dosyalardan sınav kur" artık yalnızca
kazanım tablosu (+ isteğe bağlı optik çıktısı) ile çalışır: `answerKeyFromTable` A anahtarını
`a_cevap`'tan, B anahtarını yerlerden kurar (iptal: `-` / `X` / `İPTAL`). Ad ve tarih küçük bir
pencerede sorulur (ad, tablonun dosya adından önerilir; tür addan ya da soru sayısından).
Anahtar dosyası da seçilirse eskisi gibi o kullanılır ve tabloyla çelişki denetlenir. Tabloda
bir sorunun cevabı eksikse anahtar dosyası istenir. Test: TYT07 örneğinde tablodan kurulan
anahtar dosyadakiyle bire bir aynı, öğrenci satırları da aynı.


## 91. Öğrencinin sınıf seviyesi (11 Kasım 2026)

Öğrenci kaydolurken sınıfını seçer: 9, 10, 11, 12 / mezun (12 ile mezun aynı).
Konu listeleri buna göre süzülür.

- **Sunucu:** `profiles.grade_level` (9-12, boş = bilinmiyor). Kayıt verisindeki
  `grade_level` `apply_signup_invite` ile yazılır. `set_grade_level(öğrenci,
  seviye)` ile öğrencinin kendisi ya da onu yöneten koç / müdür değiştirir;
  doğrudan güncelleme kapalı. Migration `20261111150000_grade_level`.
- **Eşleme uygulamada:** `lib/core/constants/grade_levels.dart`. Mevcut YKS
  konularının her biri işlendiği sınıfa (9 / 10 / 11) bağlandı. 9-11 yalnızca
  kendi sınıfının konularını görür; 12 / mezun ve sınıfı seçilmemiş eski hesaplar
  hepsini. TYT ile AYT'de aynı olan konu alt sınıflara bir kez gösterilir.
  `test/grade_level_test.dart`, eşlemedeki her adın seed'de olduğunu denetler
  (seed'de konu adı değişirse eşleme de değişmeli).
- **Ekranlar:** kayıt ekranında "Sınıf" seçimi zorunlu. Konular ekranında 9-11
  için TYT / AYT sekmesi yok; konular ders ders tek listede (TYT ve AYT
  Matematik tek "Matematik"). Soru ekleme, yanlış defteri ve ödev verme
  ekranındaki konu seçimi de süzülür; ödev verme ekranında konusu olmayan dersler
  gizlenir. Profilde ("Sınıfın") ve koçun öğrenci sayfasında ("Sınıfı") değişir.
- **Açık:** eşleme eski MEB müfredatının ünite sırasına göre. Maarif Modeli'nin
  yeni ünitelerine göre bir öğretmenle gözden geçirilmeli. Deneme, YKS sayacı,
  hedef ve net hesabı sınıfa göre değişmiyor. Yeni öğretim yılında sınıflar kendi
  kendine artmıyor.
