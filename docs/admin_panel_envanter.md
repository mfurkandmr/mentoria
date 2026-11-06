# Kurum müdürü paneli — özellik envanteri

Kokpit yeniden tasarımından (NOTLAR §59) önce `admin_home_screen.dart` içindeki
her özellik, yeni ekranda nerede olduğu ve hangi testle doğrulandığı. Hiçbir
satır kaybolmadı. Kontrol tarihi: 6 Kasım 2026. Sonuç: 488 Flutter testi ve 44
SQL test dosyası geçti; demo web sürümünde ekran ekran bakıldı.

Test kısaltmaları: **CK** = `test/admin_cockpit_test.dart`, **FF** =
`test/features_flow_test.dart`, **OC** = `test/org_credits_test.dart`, **RK** =
`test/ranking_test.dart`, **MF** = `test/meetings/meetings_flow_test.dart`,
**SQL** = `supabase/tests/admin_cockpit_test.mjs`.

## Genel sekmesi (eski)

| # | Özellik | Eski yeri | Yeni yeri | Kontrol |
|---|---------|-----------|-----------|---------|
| 1 | Denemeler kısayolu (`/admin/exams`) | Üst bar | Üst bar | ✓ CK "kurum adı, tarih" |
| 2 | Deneme sonuçlarını yükle (`/admin/import`) | Üst bar | Üst bar (her sekmede) | ✓ CK |
| 3 | Profil düğmesi (`/admin/profile`) | Üst bar | Üst bar (her sekmede) | ✓ CK |
| 4 | Düşük kredi / kurum kapalı uyarısı | `LowCreditBanner` | En üstte eşik bandı: kredi bitti / kayıtlı öğrencinin %10'unun altı, kurum kapalı, lisans bitti / ≤ 14 gün | ✓ CK "kredi bitince", "eşikler" |
| 5 | Kurum adı ve adı değiştirme | `_OrgCard` | Üst bar + Kurum ayarları "Kurum adı" | ✓ CK "kurum ayarları" |
| 6 | Kalan öğrenci kredisi | `_OrgCard` halkası | Kurum ayarları "Öğrenci kredisi" | ✓ CK, OC |
| 7 | Lisans bitişi / doldu uyarısı | `_OrgCard` | Kurum ayarları "Lisans" + eşik bandı | ✓ CK |
| 8 | Kurum görünümü: logo, renk, yazı tipi (`/admin/branding`) | `_OrgCard` düğmesi | Kurum ayarları "Görünüm" | ✓ CK |
| 9 | Kurum kodu: göster, kopyala, yenile | `OrgCodeCard` | Kurum ayarları "Kurum kodu" | ✓ CK, OC |
| 10 | Yoklama (bugünkü durum, `/admin/attendance`) | `AttendanceHomeCard` | Kurum araçları | ✓ CK "her modül kartı" |
| 11 | Ders programı (`/admin/schedule`) | `TimetableAdminCard` | Kurum araçları | ✓ CK |
| 12 | Sınıflar ve öğrenciler (`/admin/roster`) | `StudentsHomeCard` | Kurum araçları | ✓ CK |
| 13 | Kitap havuzu (`/admin/books`) | `BookPoolHomeCard` | Kurum araçları | ✓ CK |
| 14 | Kurum sınavları (`/admin/org-exams`) | `OrgExamsHomeCard` | Kurum araçları | ✓ CK |
| 15 | Velilere SMS (`/admin/sms`) | `BulkSmsHomeCard` | Kurum araçları | ✓ CK |
| 16 | Finans (`/admin/finance`) | `FinanceHomeCard` | Kurum araçları | ✓ CK |
| 17 | Öğrenci / koç / veli sayısı | `GlowStat` | Özet şeridi (öğrenci) + Kurum ayarları "Kurumdaki hesaplar" (öğrenci · koç · veli) | ✓ CK |
| 18 | Bu hafta soru, çalışma süresi | `GlowStat` | Özet şeridi "Bu hafta çözülen soru" (süre ikinci satırda) | ✓ CK "dört kart" |
| 19 | Ortalama son TYT neti | `GlowStat` | Dikkat bölümü "Net düşüşü" grubunun üst satırı (kurum ortalaması) | ✓ CK |
| 20 | Okul numarası eksik uyarısı (Öğrenciler sekmesine) | `PanelNotice` | Kurum araçları başında, yalnızca eksik varsa | ✓ CK "okul numarası eksikse" |
| 21 | Duyurular (liste, yeni duyuru) | `AnnouncementsHomeCard` | Kurum araçları | ✓ CK |
| 22 | Başarı sıralaması anahtarı + sıralamayı gör (`/admin/success`) | `_SuccessRankingCard` | Kurum araçları | ✓ CK, RK |
| 23 | Bu hafta konuşulacaklar (risk skoru) | `RiskCard` | Dikkat gerektirenler "Risk listesi" → `/admin/risk` (aynı kart) | ✓ CK |
| 24 | Son 5 denemede değişim | `ExamTrendsCard` | Kurum araçları "Deneme trendleri" → `/admin/trends` | ✓ CK |
| 25 | Koç görüşmeleri haftalık raporu (önceki/sonraki hafta) | `CoachMeetingsReport` | Koç performansı "Haftalık ayrıntı" → `/admin/meetings` | ✓ CK, MF |
| 26 | Bu hafta hareketsiz öğrenciler listesi | `StudentCard` listesi | "Bu hafta aktif" kartı → `/admin/activity` | ✓ CK "haftanın çalışması" |
| 27 | Aşağı çekip yenileme | `RefreshIndicator` | Kokpit (bütün bölümler yenilenir) | ✓ kod: `CockpitTab.refreshAll` |
| 28 | Geniş ekranda yan menü (`NavigationRail`) | iskelet | iskelet | ✓ CK "geniş ekranda" |

## Öteki sekmeler (davranış aynı)

| # | Özellik | Kontrol |
|---|---------|---------|
| 29 | Öğrenciler: arama (ad / numara), koç filtresi | ✓ CK, FF |
| 30 | Öğrenciler: detay, koçunu değiştir | ✓ FF |
| 31 | Koçlar: koç kartı, bu koça öğrenci daveti, "Koç davet et" | ✓ FF, CK |
| 32 | Koçlar: koç telefonu (yeni) | ✓ CK "öteki sekmeler" |
| 33 | Davetler: aktif kodlar, kopyala, iptal, "Öğrenci daveti" | ✓ CK |
| 34 | Davet penceresi: koç seçimi, kullanım hakkı, veli beyanı, kredi kontrolü | ✓ FF, OC |

## Yeni

| # | Özellik | Kontrol |
|---|---------|---------|
| 35 | Özet şeridinde geçen haftaya göre değişim oku | ✓ CK, SQL |
| 36 | Dikkat: 7+ gün girmeyen, son 2 denemede 3+ net düşen, taksiti geciken | ✓ CK, SQL |
| 37 | Satırdan koça bildirim (6 saatte bir) / koçu ara | ✓ CK, SQL |
| 38 | Deneme takvimi: planla, sil, en yakını özet şeridinde | ✓ CK, SQL |
| 39 | Koç performansı: öğrenci, bu hafta görüşme, öğrencilerinin aktifliği | ✓ CK, SQL |
| 40 | Her bölümde yükleniyor / boş (eylem düğmeli) / hata hali | ✓ CK |
| 41 | Son görülme (`touch_last_seen`) | ✓ SQL |

## İkinci tur (§60): sadeleştirme, kompakt araçlar, eğilim

| # | Değişiklik | Eski özellik nerede | Kontrol |
|---|------------|---------------------|---------|
| 42 | Kurum araçları kompakt ızgara (2/3/4 sütun) | 8 modülün hepsi ızgarada; durum satırı eski kartla aynı fonksiyondan (`attendanceTool`, `financeTool`...) | ✓ CK "her modül kartı" |
| 43 | Başarı sıralaması anahtarı | Kurum ayarları kartına taşındı ("Sıralamayı gör / Önizle" aynı) | ✓ CK, RK |
| 44 | Emojiler kaldırıldı | Risk, trend, görüşme, duyuru, şüpheli numara mesajları (metin aynı, emojisiz) | ✓ i18n testi |
| 45 | Öğrenci kartı ve avatarlar nötr | Yalnızca müdür / koç kokpitinde (`inCockpit`); öğrenci ve veli ekranları aynı | ✓ KC "öğrenci listesi nötr" |
| 46 | Son 8 hafta eğilim grafiği | Yeni (aktif öğrenci / çözülen soru) | ✓ KC, SQL |

## Koç paneli (eski → yeni)

**KC** = `test/coach_cockpit_test.dart`.

| # | Özellik | Eski yeri | Yeni yeri | Kontrol |
|---|---------|-----------|-----------|---------|
| K1 | Profil (`/coach/profile`) | Gökyüzü başlığı | Üst çubuk | ✓ KC |
| K2 | Alt çubuk: Ana sayfa, Davet et, Ödev ver, Yükle, Denemeler | Bal peteği çubuğu | Standart alt çubuk, aynı eylemler | ✓ KC "alt çubuk" |
| K3 | Öğrenci / aktif / bu hafta soru / bekleyen görev sayıları | `GlowStat` | Özet şeridi (geçen haftaya göre ok) | ✓ KC "özet şeridi" |
| K4 | Hızlı işlemler: davet, ödev, deneme yükle, denemeler | Kutucuklar | Alt çubukta (aynı eylemler) | ✓ KC |
| K5 | Optik oku (`/coach/optic`) | Kutucuk | Kısayollar | ✓ KC |
| K6 | Okul numarası eksik uyarısı | `PanelNotice` | Özetin altında, yalnızca eksik varsa (Sınıflar ve öğrencilere gider) | ✓ kod |
| K7 | Yoklama, ders programım, sınıflar ve öğrenciler, kitap havuzu, kurum sınavları | Liste kartları | Kısayollar ızgarası | ✓ KC |
| K8 | Duyurular (son duyuru, yeni duyuru) | Kart | Kart (aynı) | ✓ KC |
| K9 | Bu haftaki görüşmeler | `WeekMeetingsSection` | Aynı | ✓ KC, MF |
| K10 | Bu hafta konuşulacaklar (risk) | `RiskCard` | Aynı | ✓ KC |
| K11 | Son 5 denemede değişim | `ExamTrendsCard` | Kısayollar → `/coach/trends` | ✓ KC |
| K12 | Öğrencilerin: arama (5'ten fazlaysa), kart, silme talebi rozeti, boş hal + davet | Liste | "Öğrencilerin" bölümü | ✓ KC, `coach_deletion_badge_test` |
| K13 | Düşük kredi uyarısı | `LowCreditBanner` | Aynı (koça "yöneticinizle") | ✓ OC |
| K14 | Aşağı çekip yenileme | var | var | ✓ kod |

## İç ekranlar ve koyu tema (NOTLAR §62)

İç ekranların kodu değişmedi; yalnızca görünüm ve his. Bütün özellikler
yerinde (bütün testler geçiyor).

| # | Kontrol | Nasıl | Durum |
|---|---------|-------|-------|
| İ1 | Koç / müdür alt sayfalarının hepsi kokpit temasıyla, iOS kaydırmasıyla açılır | `admin_cockpit_test` "alt sayfaları kokpit temasıyla açılır" (rota ağacında her sayfa `pageBuilder`) | ✓ |
| İ2 | Uygulama koyu temadaysa kokpit de koyu | `admin_cockpit_test` "koyu temadaysa kokpit de koyu" + web demo | ✓ |
| İ3 | Kurum panelinde yükleniyor / boş durum maskotsuz | `admin_cockpit_test` "maskotsuz" | ✓ |
| İ4 | Yoklama: işaretleme anahtarları aynı (`att-<id>-<durum>`), kaydet, SMS sorusu | `attendance_test` | ✓ |
| İ5 | SMS: hazır metin, alıcı seçimi (tüm / sınıf / öğrenci), gönder, geçmiş | `bulk_sms_test` | ✓ |
| İ6 | Finans, kitap havuzu, kurum sınavları, ders programı, sınıflar, öğrenciler | ilgili testler + web demo (açık ve koyu) | ✓ |
| İ7 | Markalama (logo, renk, yazı tipi) iç sayfası açılıyor; vurgu ve "Bu hafta" kartı kurum renginden | `branding_test` + web demo | ✓ |
