# Mentoria 🐝

YKS öğrencileri için koç destekli takip ve istatistik uygulaması.
Flutter (Android · iOS · Web) + Supabase.

Ürün planı: [docs/PROJE_PLANI.md](docs/PROJE_PLANI.md) · Maskot: [docs/mentoria-bizz.html](docs/mentoria-bizz.html)

## Ekranlar

| Rol | Ekranlar |
|---|---|
| Öğrenci | Ana sayfa (bugünkü hedefler, seri, görevler, koç notları, son deneme) · Denemeler (salt okunur) · Soru takibi · Konu takibi · Çalışma süresi (Pomodoro / kronometre) · Profil (hedefler, veli davet kodu) |
| Koç | Öğrenci listesi (haftalık özet, eksik numara uyarısı, arama) · Öğrenci davet kodu · Öğrenci detayı (Özet, Denemeler, Sorular, Konular, Süre, Görevler, Notlar) · Elle deneme girişi · Excel'den deneme yükleme · Profil |
| Kurum müdürü | Genel (lisans, haftalık durum, hareketsiz öğrenciler) · Öğrenciler (arama, koç filtresi, koç değiştirme) · Koçlar · Davetler · Excel'den deneme yükleme · Öğrenci detayı · Profil — web'de yan menülü düzen |
| Veli | Çocuğunun özeti, denemeleri, soru, konu ve çalışma istatistikleri (salt okunur) · Profil |

## Görünüm, dil ve animasyonlar

- **Tema:** Sistem / Açık / Koyu (Profil → Görünüm ve dil; giriş ekranında sağ üstteki düğme). Cihazda saklanır.
- **Dil:** Türkçe / English. Kaynak metinler Türkçe yazılır ve `tr('...')` ile sarılır; İngilizceleri
  `lib/core/i18n/strings_en.dart` içinde. Yeni bir metin eklerken `tr()` kullanıp İngilizcesini bu dosyaya
  ekle — `test/i18n_test.dart` eksik çeviriyi yakalar. Konu adları (veritabanı) Türkçe kalır.
- **Canlı Bızz** (`lib/shared/widgets/bizz.dart`): süzülür, göz kırpar, etrafa bakınır, dokununca kıkırdar.
  Duyguları `BizzController` ile yönetilir (giriş ekranında şifre yazılırken gözlerini kapatır).
  Tüm ifadeleri görmek için: `flutter test test/tool/bizz_preview_test.dart` → `build/bizz_preview.png`.
- **Açılış animasyonu** (`lib/features/intro`), giriş efektleri ve konfeti (`lib/shared/widgets/effects.dart`).
  Cihazda "hareketi azalt" açıksa sürekli animasyonlar durur.

## Klasör yapısı

```
lib/
  core/        config (env), theme, router, constants (dersler, net hesabı)
  features/
    auth/      giriş, davetle kayıt, rol yönlendirme
    student/   öğrenci alt menüsü ve ana sayfa
    shared_roles/  koç · veli · kurum ekranları (şimdilik yer tutucu)
  shared/      ortak widget'lar (Bızz, yazı logosu)
assets/brand/  bizz.svg, bizz_head.svg
supabase/
  migrations/  şema + RLS + kayıt tetikleyicisi
  seed.sql     dersler ve konular
```

## Kurulum

### 1. Supabase projesi
Geliştirme projesi: **Mentoria** organizasyonundaki **Mentoria** projesi (`lmbykdvvxormfiaomysn`, Frankfurt).
Migration'lar ve seed uygulandı; `env.json` bu projeye bağlı.

Yeni bir ortam (ör. production) kurarken **SQL Editor**'de sırasıyla çalıştır:
1. `supabase/migrations/20261015120000_initial_schema.sql`
2. `supabase/migrations/20261015130000_advisor_fixes.sql`
3. `supabase/migrations/20261015140000_coach_exams_student_number.sql`
4. `supabase/migrations/20261015150000_summaries_for_all_roles.sql`
5. `supabase/migrations/20261015160000_delete_my_account.sql`
6. `supabase/seed.sql`
7. `supabase/seed_ayt_ydt_topics.sql`

**Şifre sıfırlama bağlantıları için** (Authentication → URL Configuration):
- *Site URL*: web panelinin yayın adresi (geliştirmede `http://localhost:PORT`)
- *Redirect URLs*: `mentoria://reset-password` ve web adresi

**Authentication → Providers → Email** açık olsun. Geliştirme sırasında
"Confirm email" kapatılabilir.

### 2. İlk kurum ve müdür (süper-admin, SQL Editor'den)
Kayıt yalnızca davetle olduğu için ilk kurum ve müdür daveti elle oluşturulur:

```sql
with org as (
  insert into public.organizations (name, seat_limit, license_expires_at)
  values ('Deneme Kurumu', 50, now() + interval '1 year')
  returning id
)
insert into public.invite_codes (code, org_id, target_role)
select 'MUDUR001', id, 'admin' from org;
```

Müdür uygulamada **"Davet kodum var"** → `MUDUR001` ile kayıt olur.
Sonra davet zinciri uygulama içinden ilerler (`create_invite` fonksiyonu):

| Davet eden | Davet edilen |
|---|---|
| Kurum müdürü | Koç, öğrenci (bir koça bağlı) |
| Koç | Kendi öğrencisi |
| Öğrenci | Velisi |

Öğrenci kaydında kurumun `seat_limit` (lisans) kotası ve `license_expires_at` kontrol edilir.

### 3. Uygulamayı çalıştır
```bash
cp env.example.json env.json   # URL ve publishable key'i doldur
flutter run --dart-define-from-file=env.json
```
`env.json` git'e eklenmez. Anahtar verilmezse uygulama kurulum ekranını gösterir.

**Demo modu** (Supabase'siz, örnek verilerle):
```bash
flutter run --dart-define=DEMO=true
```
Rol seçmek için `--dart-define=DEMO_ROLE=coach` (ya da `admin`, `parent`) ekle.
VS Code ve Android Studio'da her rol için hazır çalıştırma ayarları var.

### Uygulama ikonları
`assets/brand/icon/` altındaki PNG'ler değişirse:
```bash
dart run flutter_launcher_icons
```

### Testler
```bash
flutter test
```

## Notlar
- Klasör yolunda Türkçe karakter (`Masaüstü`) olduğunda `flutter analyze` çökebiliyor;
  `dart analyze` sorunsuz çalışıyor.
