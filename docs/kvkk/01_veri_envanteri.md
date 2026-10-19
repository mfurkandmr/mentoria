# Kişisel Veri Envanteri (taslak)

> Taslak. 19 Ekim 2026'daki veritabanı şemasından ve uygulama kodundan
> çıkarıldı. Avukat incelemesi gerekir. Köşeli parantezli yerler (`[...]`)
> doldurulacak.

Bu belge, aydınlatma metni ile saklama-imha politikasının dayanağıdır. Bir
tabloya yeni kişisel veri alanı eklendiğinde burası da güncellenmeli.

## İlgili kişi grupları

| Grup | Açıklama |
|---|---|
| Öğrenci | YKS'ye hazırlanan kullanıcı. Çoğu 18 yaşından küçük. |
| Veli | Öğrencinin davet ettiği ebeveyn ya da vasi. |
| Koç | Öğrenciyi takip eden öğretmen ya da eğitim koçu. |
| Kurum yöneticisi | Dershane, okul ya da kurs müdürü. |
| Platform yöneticisi | Mentoria ekibi (super-admin). |

## Veri kategorileri

| Kategori | Veriler | Kimden | Nerede | Hukuki sebep (KVKK md. 5) |
|---|---|---|---|---|
| Kimlik | Ad soyad, öğrenci numarası (isteğe bağlı) | Tüm roller | `profiles` | Sözleşmenin ifası (5/2-c) |
| İletişim | E-posta adresi | Tüm roller | Supabase Auth (`auth.users`) | Sözleşmenin ifası (5/2-c) |
| Hesap güvenliği | Şifre (yalnızca özeti, açık hâli saklanmaz), oturum anahtarları, giriş zamanları, IP adresi ve tarayıcı/cihaz bilgisi (Supabase Auth kayıtları) | Tüm roller | Supabase Auth | Hukuki yükümlülük (5/2-ç; 5651 sayılı Kanun), meşru menfaat (5/2-f) |
| Eğitim / sınav | Hedef sınav yılı, alan (SAY/EA/SÖZ/DİL), deneme sonuçları (doğru/yanlış/boş/net), yanlış yapılan konular | Öğrenci; koç ve kurum (toplu yükleme) | `profiles`, `exams`, `exam_subject_results`, `exam_wrong_topics` | Sözleşmenin ifası (5/2-c) |
| Çalışma kayıtları | Çözülen soru sayıları, konu ilerlemesi, pomodoro/çalışma süreleri, hedefler (hedef üniversite, bölüm, sıralama), haftalık plan, Günün Sorusu ve alıştırma cevapları, düello sonuçları | Öğrenci; koç (plan, hedef) | `question_logs`, `topic_progress`, `study_sessions`, `goals`, `plan_items`, `daily_answers`, `practice_answers`, `duels` | Sözleşmenin ifası (5/2-c) |
| Hata defteri | Soru fotoğrafı, not, tekrar takvimi | Öğrenci | `mistake_cards`; fotoğraflar `mistake-photos` deposunda | Sözleşmenin ifası (5/2-c) |
| Koçluk | Koç notları, görevler, ödevler, görüşme takvimi ve katılım durumu | Koç | `coach_notes`, `tasks`, `assignments`, `assignment_items`, `meeting_schedules`, `meeting_occurrences` | Sözleşmenin ifası (5/2-c) |
| İlişkiler | Koç–öğrenci, veli–öğrenci bağları, kurum üyeliği, davet kodları | Sistem | `coach_students`, `parent_students`, `invite_codes`, `profiles.org_id` | Sözleşmenin ifası (5/2-c) |
| Bildirimler | Uygulama içi bildirimler, duyurular, telefon bildirim adresi (FCM token), platform (Android/iOS) | Sistem; koç ve müdür (duyuru) | `notifications`, `announcements`, `device_tokens` | Sözleşmenin ifası (5/2-c) |
| Oyunlaştırma | Avatar seçimi, açılan avatar parçaları, başarı sıralaması (kısaltılmış adla) | Öğrenci, sistem | `profiles.avatar`, `user_unlocked_items`, sıralama sorguları | Avatar: sözleşmenin ifası. Sıralamada görünmek: **açık rıza önerilir** (bkz. açık rıza metni) |
| Hesap işlemleri | Hesap silme talebi ve tarihi, KVKK onay tarihi | Öğrenci | `account_deletion_requests`, `profiles.kvkk_consent_at` | Hukuki yükümlülük (5/2-ç) |
| Cihazdaki veriler | Ayarlar, son görülen ana sayfa (önbellek), pomodoro durumu, ders/konu listeleri | Uygulama | Kullanıcının kendi cihazı (sunucuya gitmez) | Sözleşmenin ifası (5/2-c). Çıkışta ana sayfa önbelleği silinir. |

**Toplanmayanlar:** T.C. kimlik numarası, doğum tarihi (henüz; yaş kontrolü
için doğum yılı eklenecek), telefon numarası, adres, konum, sağlık verisi ve
diğer özel nitelikli veriler, yüz veya biyometrik veri, reklam kimliği.
Uygulamada analiz/reklam SDK'sı yoktur.

**Telefon sensörü:** Ana sayfadaki "Bızz'ı salla" etkileşimi ivmeölçeri
yalnızca cihaz içinde kullanır; veri kaydedilmez ve gönderilmez.

## Özel nitelikli veri riski

Koç notları, görev açıklamaları, ödev notları ve hata defteri notları
serbest metindir. Koç ya da öğrenci buraya sağlık, din, aile durumu gibi
**özel nitelikli** bilgi yazabilir. Bu tür verinin işlenmesi ayrı koşullara
bağlı olduğundan:

- Kullanım koşullarında koçlara "notlara sağlık ve benzeri özel nitelikli
  bilgi yazmayın" uyarısı konmalı.
- Not alanlarının yanına kısa bir uyarı metni eklenmeli (kod aşamasında).

## Veri aktarımları

| Alıcı | Ne | Neden | Nerede |
|---|---|---|---|
| Öğrencinin koçu | Öğrencinin tüm eğitim ve çalışma verileri | Koçluk hizmeti | Yurt içi |
| Kurum yöneticisi | Kurumdaki öğrencilerin verileri, koçların listesi | Kurumun hizmeti | Yurt içi |
| Veli (öğrencinin davet ettiği) | Çocuğun çalışma ve deneme özetleri, haftalık rapor | Veli takibi | Yurt içi |
| Aynı kurumdaki diğer öğrenciler | Sıralamada kısaltılmış ad ("El***"), avatar ve net; düello rakibinin adı | Oyunlaştırma | Yurt içi |
| Supabase Inc. (veri işleyen) | Bütün sunucu verileri | Barındırma, veritabanı, kimlik doğrulama, dosya depolama | **Yurt dışı:** AB (Frankfurt, AWS eu-central-1); şirket ABD merkezli |
| Google LLC: Firebase Cloud Messaging | Cihaz bildirim adresi, bildirim başlığı ve metni | Telefon bildirimi göndermek | **Yurt dışı** (ABD ve diğer Google veri merkezleri) |
| E-posta gönderimi (Supabase Auth) | E-posta adresi, doğrulama kodu | Kayıt doğrulama, şifre sıfırlama | **Yurt dışı** (Supabase'in e-posta sağlayıcısı; [kendi SMTP sağlayıcınız kullanılacaksa adı]) |

## Koddan çıkan düzeltilecek noktalar

1. ~~**Hata defteri fotoğrafları** hesap silinince depodan silinmiyor.~~
   **Giderildi:** `storage-cleanup` (NOTLAR §35).
2. ~~**Google Fonts** yazı tiplerini çalışma anında Google'dan indiriyor.~~
   **Giderildi (19 Ekim 2026):** yazı tipleri uygulamaya gömüldü
   (`assets/google_fonts`), çalışma anında indirme kapalı. Google'a IP
   aktarımı yok.
3. **Rıza kaydı** yalnızca tarih tutuyor (`kvkk_consent_at`); hangi metnin
   hangi sürümünün onaylandığı ve rızanın geri çekilip çekilmediği
   tutulmuyor.
4. **Yaş bilgisi yok:** 18 yaş altı ayrımı yapılamıyor.
5. **Başarı sıralaması** kurum düzeyinde açılıyor; öğrencinin kendi rızası
   alınmıyor.
