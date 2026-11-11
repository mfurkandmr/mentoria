# Öğretmen paneli, soru çözümü / etüt ve WhatsApp planı (11 Kasım 2026)

Kurumun istekleri:

1. Öğretmenin kendi paneli olsun: ders programı, soru çözümü ve etüt saatleri.
2. Öğretmen kendi kayıt olsun, müdürün listesine kendiliğinden düşsün (bugün
   `teachers` elle yazılıyor).
3. Müdür ders programına soru çözümü saatleri eklesin ve öğretmene atasın.
4. Öğrenci, o günkü soru çözümü / birebir ders için öğretmen seçip talep etsin;
   talep koçunun onayına bağlı olsun.
5. Veliyle iletişim SMS yerine yalnızca WhatsApp'tan olsun. Mesajlar kurumun
   tek WhatsApp numarasından gitsin (koçun mesajı da).
6. Öğretmen verdiği ödevi PDF yapsın; gönderince veliye WhatsApp'tan düşsün.
   Mesajda öğretmenin / koçun ve öğrencinin adı kesinlikle olsun.

---

## A. Öğretmen rolü

**Karar:** yeni rol `teacher`. Koçtan ayrı tutulur: öğretmen öğrenci takibi
yapmaz (deneme, çalışma, risk görmez), yalnızca kendi derslerini, soru
çözümlerini ve verdiği ödevleri görür. Bir kişi hem koç hem öğretmense bugünkü
gibi koç hesabı `teachers.profile_id` ile bağlanır (mevcut davranış korunur).

- **Kayıt:** müdür "Öğretmen davet et" (`create_invite` → `teacher`) ya da
  kurumun öğretmen kodu. Kayıt tetikleyicisi `teachers` satırını kendisi açar
  (`profile_id` dolu, ad soyad profilden, branş kayıtta seçilir). Elle
  eklenmiş ama hesabı olmayan aynı adlı öğretmen varsa müdüre "Eşleştir"
  önerisi çıkar (otomatik birleştirme yok, yanlış eşleşme riski).
- **Kredi:** öğretmen kaydı kredi harcamaz (`consume_student_credit` yalnızca
  öğrenci).
- **Yetki:** `teacher` → `/teacher` öneki (`RoleGateScreen.homeFor`). RLS: kendi
  `teachers` satırı, kendi `schedule_entries`'i, kendi oturumları ve talepleri,
  kendi verdiği ödevler. Öğrencinin yalnızca adı + sınıfı (oturuma gelenler).
- **Öğretmen paneli (kokpit dili):** Bugün (sıradaki ders, soru çözümü),
  haftalık program ızgarası, soru çözümü / etüt listesi (kimler geliyor),
  ödev ver (PDF), müsaitlik saatlerini kendisi girer
  (`teacher_availability`; müdür kilitleyebilir).

## B. Soru çözümü ve etüt saatleri

**Karar:** derslerden ayrı bir "oturum" kavramı. Ders programındaki sınıf
dersleri aynen kalır; soru çözümü sınıfa değil öğrenciye açık bir saattir.

- **Tablo `study_sessions`:** öğretmen, gün/saat (`time_slots` ya da serbest
  saat), tür (`question_solving` soru çözümü / `private_lesson` birebir /
  `etut` grup etüdü), kontenjan (birebirde 1), derslik, branş, yayında mı.
  Tekrar eden haftalık şablon + tek seferlik oturum.
- **Müdür:** program ekranında yeni "Soru çözümü" sekmesi: boş saatlere oturum
  ekler, öğretmene atar. Üretici bu oturumları sert kısıt olarak görür
  (öğretmen o saatte derse yerleştirilmez, derslik dolu sayılır).
- **Öğrenci talebi `session_requests`:** öğrenci o gün / hafta açık oturumları
  öğretmen ve branşa göre görür, "Talep et" der (konu + kısa not, isteğe bağlı
  soru fotoğrafı sonra). Durum: `pending` → koç `approved` / `rejected` →
  kontenjan dolarsa `waitlist`. Onaylanınca öğrenciye ve öğretmene bildirim.
  Kurallar: öğrenci aynı saate iki talep veremez, günde en çok N talep (müdür
  ayarı), oturumdan X saat önce talep kapanır.
- **Koç:** "Bekleyen işler" ekranına (§63) talepler düşer; tek dokunuşla
  onay / ret, toplu onay. Müdür ayarı: "koç onayı gerekmesin" (kurum isterse).
- **Öğretmen:** oturumunda onaylı öğrenci listesi; oturum sonunda "geldi /
  gelmedi" (yoklamaya benzer, `attendance`'tan ayrı tablo).

## C. WhatsApp

### Nasıl bağlanacak

**Öneri: resmî WhatsApp Business Platform (Cloud API).** Müdür uygulamada
"WhatsApp'ı bağla" der, Meta'nın Embedded Signup penceresinde kurumun
numarasıyla giriş yapar. Numara zaten WhatsApp Business uygulamasında
kullanılıyorsa "coexistence" ile hem telefondan kullanmaya devam eder hem de
sistem aynı numaradan gönderir. Her kurum kendi numarasını bağlar (white label
ile uyumlu); faturayı Meta doğrudan kuruma keser.

**Önerilmeyen yol:** müdürün normal WhatsApp'ına WhatsApp Web üzerinden
"oturum açıp" otomatik mesaj attırmak (QR ile bağlanan gayriresmî kütüphaneler).
Meta'nın kurallarına aykırı; toplu gönderimde numara kalıcı kapatılabilir,
sunucuda sürekli açık bir tarayıcı oturumu gerekir, Edge Function'da çalışmaz.
Kurumun tek iletişim kanalı olacağı için bu risk alınmamalı.

### Kurallar (Meta tarafı)

- Velinin son 24 saatte yazmadığı her mesaj **önceden onaylı şablonla** gider.
  Serbest metin ancak veli yazdıktan sonraki 24 saat içinde olur. Toplu
  duyuru da şablonla gönderilir (şablonda değişken alan).
- Şablonlar Meta'ya bir kez gönderilir, onay genelde dakikalar-saatler sürer.
- Mesaj başına Meta ücreti var (bilgilendirme/"utility" kategorisi en ucuzu).
  **Uygulamada fiyat / satın alma ekranı olmayacak** (kredi kuralı); ödeme
  yöntemi Meta Business hesabında kurumun kendisi tarafından girilir.
- Veli WhatsApp'tan mesaj almayı kabul etmiş olmalı (opt-in); kayıtta / velinin
  numarası girilirken alınır ve saklanır.

### Şablonlar (taslak, Türkçe)

| Şablon | Metin |
|---|---|
| `odev_bildirimi` (PDF ekli) | "Sayın {{veli}}, {{öğretmen}} öğrenciniz {{öğrenci}} için {{ders}} ödevi verdi. Son tarih: {{tarih}}. Ayrıntılar ekteki dosyada. — {{kurum}}" |
| `haftalik_odev_ozeti` | "Sayın {{veli}}, {{öğrenci}} için bu hafta verilen ödevler: {{liste}}. Koçu: {{koç}}. — {{kurum}}" |
| `devamsizlik` | "Sayın {{veli}}, öğrenciniz {{öğrenci}} {{tarih}} tarihinde kuruma gelmedi. — {{kurum}}" |
| `taksit_hatirlatma` | "Sayın {{veli}}, {{öğrenci}} için {{tarih}} vadeli {{tutar}} TL taksiti hatırlatırız. — {{kurum}}" |
| `koc_mesaji` | "Sayın {{veli}}, {{öğrenci}} hakkında koçu {{koç}} size mesaj gönderdi: {{metin}} — {{kurum}}" |
| `duyuru` | "Sayın veli, {{kurum}} duyurusu: {{metin}}" |

Öğretmen/koç adı ve öğrenci adı her şablonda var (kurumun şartı). Mesaj kurum
numarasından gider ama kimin yazdığı metinde açıkça görünür.

### Sistem

- `sms_outbox` → genel `message_outbox` (`channel`: `whatsapp` / `sms`,
  `template`, `params jsonb`, `media_path`). Mevcut SMS çağrıları (yoklama,
  taksit, toplu, finans) aynı kuyruğa yazar; kanal kurum ayarından gelir
  (`organizations.messaging_channel`). SMS kodu silinmez, yedek kanal kalır.
- `claim_sms` kilidi (§85) aynen `claim_messages` olur (çift gönderim yok).
- Edge Function `send-whatsapp`: kuyruğu alır, Cloud API'ye şablon mesajı
  atar, PDF için önce medya yükler ya da imzalı Storage adresi verir.
  Teslim / okundu / hata durumları için `whatsapp-webhook` fonksiyonu
  (`delivered`, `read`, `failed` → kuyruk satırına yazılır; müdür ekranında
  "okundu" görünür).
- Kurum bağlantı bilgileri (`phone_number_id`, `waba_id`, erişim anahtarı)
  `org_whatsapp` tablosunda, istemciye hiç gitmez (yalnızca Edge Function
  okur; anahtar Vault'ta).
- Veli 24 saat içinde cevap yazarsa: ilk sürümde mesaj müdürün WhatsApp Business
  uygulamasına düşer (coexistence), uygulamada gelen kutusu **yok**. İkinci
  aşamada istenirse uygulamaya gelen kutusu eklenir.

### Ödev PDF'i

- Öğretmen (ve koç) "Ödev ver" ekranında: öğrenci(ler) / sınıf, ders, konu,
  soru sayısı, son tarih, not; isterse kendi PDF'ini / fotoğrafını ekler.
  Uygulama bunları kurum logolu tek sayfalık PDF'e çevirir (mevcut
  `jpegPagesToPdf` yolu, Türkçe karakterler uygulama yazı tipiyle).
- PDF Storage'a (`homework/` kovası, kurum klasörü, 90 gün saklama) yüklenir;
  `assignments` satırına `pdf_path`, `teacher_id` eklenir.
- "Gönder" → öğrenciye uygulama bildirimi + velisine `odev_bildirimi`
  şablonu (PDF ekli). Sınıfa verilirse her öğrencinin velisine ayrı mesaj,
  aynı numaraya (kardeş) tek mesaj.
- Haftalık özet: pg_cron, Pazar 18:00 (TR), o hafta verilmiş ödevler
  `haftalik_odev_ozeti` ile. Kurum ayarı: anında / yalnızca haftalık / ikisi.

## D. KVKK

- **Yurt dışına aktarım:** WhatsApp (Meta) sunucuları yurt dışında. Veli adı,
  telefonu, öğrenci adı ve ödev/devamsızlık bilgisi aktarılıyor → KVKK md. 9.
  Aydınlatma metnine eklenmeli; veliden WhatsApp için ayrı açık rıza
  (`consents` tablosuna yeni tür `whatsapp_guardian`). Avukata sorulacaklar
  listesine eklenecek (`docs/kvkk/00_README.md`).
- Öğretmenin gördüğü öğrenci verisi en az düzeyde (ad, sınıf, oturum).
- Ödev PDF'leri ve mesaj kayıtları için saklama süresi (öneri: 90 gün).

## E. Sıra ve tahmini süre

Durum (11 Kasım 2026): 1. aşama (NOTLAR §86) ve 2. aşama (NOTLAR §87; tablolar
`tutoring_sessions` / `tutoring_requests`, onay yalnızca öğretmende) tamam ve canlıda.
Sırada 3. aşama (WhatsApp).

| Aşama | İş | Kurumdan beklenen |
|---|---|---|
| 1 | Öğretmen rolü, davet/kayıt, otomatik `teachers` satırı, öğretmen paneli (program) | — |
| 2 | Soru çözümü oturumları (müdür), öğrenci talebi, koç onayı, öğretmen listesi | Kurallar: günlük talep sınırı, talep kapanma saati |
| 3 | `message_outbox` + `send-whatsapp` + webhook, kurum bağlama ekranı, mevcut SMS akışlarının WhatsApp'a geçişi | Meta Business hesabı + doğrulama, WhatsApp numarası, ödeme yöntemi |
| 4 | Ödev PDF'i + anında ve haftalık veli mesajı | Şablon metinlerine onay |
| 5 | KVKK metinleri, rıza, testler (SQL + widget), demo verisi | Avukat görüşü |

1, 2 ve 4'ün uygulama tarafı WhatsApp onayını beklemeden yapılabilir; mesajlar
bağlantı kurulana kadar kuyrukta bekler (bugünkü SMS gibi).

## F. Kararlar (kullanıcı, 11 Kasım 2026)

1. Öğretmen **ayrı rol** (`teacher`).
2. Soru çözümü / birebir talebini **öğretmen onaylar / reddeder**; koç
   yalnızca görür (onay yetkisi yok). B bölümündeki "koç onayı" bu yüzden
   geçersiz: talep `pending` → öğretmen `approved` / `rejected`; koçun
   "Bekleyen işler"inde değil, öğrenci detayında / bir listede salt okunur.
3. Kurumun **WhatsApp Business** hesabı kullanılacak (Cloud API +
   coexistence).
4. Veli cevapları uygulamaya **gelmez**; müdürün WhatsApp Business
   uygulamasında kalır. Gelen kutusu yok.
5. Ödev mesajı **anında** gider (haftalık özet yok).
6. **SMS tamamen kapanır.** Mevcut SMS akışları (yoklama, taksit, toplu,
   duyuru) WhatsApp'a geçer; SMS ekranları ve `send-sms` kaldırılır.
