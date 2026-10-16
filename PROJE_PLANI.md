# Mentoria — Proje Planı (v0.1)

YKS öğrencileri için takip ve istatistik uygulaması. Flutter (iOS + Android) + Supabase.
Gelir modeli: **koç/kurum lisansı (B2B)** — kurumlar ve bağımsız koçlar öğrenci başına lisans öder, öğrenci ve veli uygulamayı ücretsiz kullanır.

---

## 1. Kullanıcı rolleri

| Rol | Ne yapar |
|---|---|
| **Kurum müdürü** | Kurumu yönetir; koçları ve öğrencileri ekler, lisans/koltuk sayısını görür, kurum geneli raporlar (koç bazlı performans, sınıf ortalamaları). |
| **Koç (mentor)** | Kendisine bağlı öğrencileri takip eder; haftalık program/görev atar, deneme sonuçlarını ve soru istatistiklerini inceler, not/geri bildirim bırakır. Bir kuruma bağlı da olabilir, bağımsız da. |
| **Öğrenci** | Deneme, günlük soru, konu ilerlemesi ve çalışma süresi girer; kendi istatistiklerini görür; koçun atadığı görevleri tamamlar. |
| **Veli** | Bağlı olduğu öğrencinin özet istatistiklerini **salt-okunur** görür; haftalık rapor bildirimi alır. |

**Bağlantı akışı:** Kurum/koç bir **davet kodu** üretir → öğrenci kodu girer ve bağlanır. Öğrenci de kendi **veli kodunu** üretip veliye verir.

> Bağımsız bir koç, kurumsuz "tek kişilik kurum" olarak modellenir. Böylece lisans mantığı tek yerden yönetilir.

---

## 2. MVP özellikleri

### 2.1 Deneme net takibi
- TYT / AYT (SAY, EA, SÖZ, DİL) / YDT deneme girişi: ders bazlı doğru-yanlış-boş → **net = D − Y/4** otomatik.
- Soru sayıları (2025 formatı):
  - **TYT:** Türkçe 40, Sosyal 20 (Tarih 5, Coğrafya 5, Felsefe 5, Din 5), Matematik 40, Fen 20 (Fizik 7, Kimya 7, Biyoloji 6)
  - **AYT:** Matematik 40, Fizik 14, Kimya 13, Biyoloji 13, Edebiyat 24, Tarih-1 10, Coğrafya-1 6, Tarih-2 11, Coğrafya-2 11, Felsefe Grubu 12, Din 6
  - **YDT:** 80
- Deneme adı, yayın, tarih, (opsiyonel) yanlış yapılan konular.
- Grafikler: toplam net trendi, ders bazlı net trendi, son 5 deneme ortalaması, en çok gelişen/geriye giden ders.
- **Tahmini puan ve sıralama (MVP'de):** Deneme netlerinden tahmini TYT/SAY/EA/SÖZ/DİL puanı ve geçen yılın puan–sıralama verisine göre tahmini sıralama. Katsayılar ve sıralama tabloları Supabase'de bir tabloda tutulur; her yıl uygulamayı güncellemeden yalnızca veri güncellenir.

### 2.2 Günlük soru takibi
- Ders + konu seçerek çözülen soru, doğru/yanlış/boş girişi (hızlı giriş: tek ekranda +10/+20 butonları).
- Günlük/haftalık hedef (koç atayabilir), hedef yüzdesi halkası.
- Isı haritası (GitHub tarzı takvim), ders dağılımı pasta grafiği, konu bazlı başarı oranı.

### 2.3 Konu takibi
- YKS müfredatı ön tanımlı konu listesi (ders → konu → alt konu).
- Durumlar: Başlanmadı / Çalışılıyor / Bitti / Tekrar gerekli.
- Ders bazlı ilerleme çubuğu; koç öğrencinin eksik konularını görür.
- Deneme ve soru takibindeki yanlışlar konulara bağlanır → "zayıf konular" otomatik çıkar.

### 2.4 Çalışma süresi / Pomodoro
- Pomodoro (25/5 ayarlanabilir) ve serbest kronometre; ders seçimi.
- Günlük/haftalık toplam süre, seri (streak), en verimli saatler.
- Arka planda çalışan zamanlayıcı + bildirim.

### 2.5 Rol panelleri (MVP için minimum)
- **Koç:** öğrenci listesi (son aktivite, haftalık net/soru/süre özeti, uyarı rozetleri), öğrenci detay ekranı (öğrencinin gördüğü tüm istatistikler), görev atama.
- **Veli:** tek ekran özet + haftalık rapor.
- **Kurum müdürü:** koç ve öğrenci yönetimi, davet kodları, kurum geneli özet. (İleride web paneli — Flutter Web ile aynı kod tabanından.)

---

## 3. Piyasadan esinlenilecek fikirler

| Kaynak türü | Alınacak fikir |
|---|---|
| Odak uygulamaları (Forest, Study Bunny vb.) | Pomodoro'yu oyunlaştırma, maskotun büyümesi/tepki vermesi, seri sayacı |
| Duolingo | Maskot odaklı marka, günlük seri, nazik hatırlatma bildirimleri, haftalık lig fikri (ileri sürüm) |
| YKS net/deneme takip uygulamaları | Hızlı deneme girişi, ders bazlı net grafikleri, puan/sıralama tahmini |
| Online koçluk platformları | Koç–öğrenci eşleşmesi, haftalık program atama, öğrenci raporu |
| GitHub katkı grafiği | Çalışma/soru ısı haritası |

**Farklılaşma noktamız:** Dört rolün (kurum–koç–öğrenci–veli) tek uygulamada birleşmesi ve verilerin birbirine bağlı olması (yanlış → zayıf konu → koç görevi).

---

## 4. Teknik mimari

### Flutter
- **State management:** Riverpod (riverpod_generator)
- **Routing:** go_router (rol bazlı yönlendirme / shell route)
- **Backend:** supabase_flutter (Auth, Postgres, Realtime, Storage, Edge Functions)
- **Grafikler:** fl_chart
- **Modeller:** freezed + json_serializable
- **Yerel:** shared_preferences (ayarlar), ileride offline için drift
- **Bildirim:** firebase_messaging (FCM) + flutter_local_notifications (Pomodoro)
- **Klasör yapısı (feature-first):**
  ```
  lib/
    core/        (tema, router, supabase client, sabitler, yardımcılar)
    features/
      auth/  exams/  questions/  topics/  study_timer/
      coach/  parent/  institution/  profile/
    shared/      (ortak widget'lar, grafik bileşenleri)
  ```

### Supabase — veritabanı taslağı
```
organizations        (id, name, type: institution|solo_coach, seat_limit, plan, created_at)
profiles             (id = auth.users.id, full_name, role: admin|coach|student|parent, avatar_url, exam_year, field: SAY|EA|SOZ|DIL)
org_members          (org_id, user_id, role)
coach_students       (coach_id, student_id, org_id, started_at)
parent_students      (parent_id, student_id)
invite_codes         (code, org_id, created_by, target_role, expires_at, max_uses)

score_coefficients   (year, score_type, subject_id, coefficient, base_score)
rank_tables          (year, score_type, score, rank)
subjects             (id, exam_type: TYT|AYT|YDT, name, question_count, sort)
topics               (id, subject_id, parent_id, name, sort)

exams                (id, student_id, exam_type, field, name, publisher, taken_at, total_net)
exam_subject_results (exam_id, subject_id, correct, wrong, blank, net)
exam_wrong_topics    (exam_id, topic_id, count)

question_logs        (id, student_id, subject_id, topic_id, correct, wrong, blank, logged_on, source)
topic_progress       (student_id, topic_id, status, updated_at)
study_sessions       (id, student_id, subject_id, started_at, duration_sec, type: pomodoro|free)

tasks                (id, coach_id, student_id, title, subject_id, topic_id, target_questions, due_date, status)
goals                (student_id, daily_questions, daily_minutes, target_university, target_rank)
coach_notes          (id, coach_id, student_id, body, created_at)
```
- **RLS (Row Level Security) zorunlu:** öğrenci yalnızca kendi verisi; koç yalnızca `coach_students` ile bağlı öğrenciler; veli yalnızca `parent_students` ile bağlı öğrenci (salt-okunur); müdür yalnızca kendi `org_id`'si.
- İstatistikler için Postgres **view / RPC fonksiyonları** (haftalık özet, ders bazlı trend) → istemci hafif kalır.
- Lisans kontrolü: öğrenci kuruma bağlanırken `seat_limit` Edge Function / trigger ile kontrol edilir.

---

## 5. Yol haritası

| Faz | İçerik |
|---|---|
| **0 – Kurulum** | Flutter projesi, tema & marka, Supabase projesi, şema + RLS, auth (e-posta + Google/Apple) |
| **1 – Öğrenci çekirdeği** | Onboarding (alan, hedef), deneme girişi + grafik, soru takibi, konu listesi, Pomodoro, ana sayfa özeti |
| **2 – Koç** | Davet kodu ile bağlanma, öğrenci listesi, öğrenci detay, görev atama, notlar |
| **3 – Veli & Kurum** | Veli özet ekranı, kurum müdürü paneli, lisans/koltuk yönetimi |
| **4 – Cila & yayın** | Bildirimler, haftalık rapor, maskot animasyonları, mağaza hazırlığı (KVKK metinleri dahil) |

---

## 6. Alınan kararlar

1. **Kayıt yalnızca davetle.** Açık kayıt yok. Kurum müdürü → koç davet eder; koç/kurum → öğrenci davet eder; öğrenci → veli davet eder. Davet kodu olmadan hesap oluşturulamaz (Supabase'de kayıt, kodu doğrulayan bir Edge Function üzerinden yapılır).
2. **Kurum müdürü paneli Flutter Web.** Mobil uygulamayla aynı kod tabanı; koçlar da web panelini kullanabilir.
3. **Lisans ödemesi — öneri:**
   - **MVP:** Satış ve fatura uygulama dışında (havale/EFT, sözleşme). Lisans/koltuk sayısı süper-admin tarafından Supabase'de tanımlanır. Ödeme altyapısı yazmadan pazara çıkılır.
   - **Sonraki sürüm:** Web panelinden **iyzico** ile abonelik (Türk kurumlar için kart, taksit ve e-fatura entegrasyonu kolay). Stripe Türkiye'de şirket hesabı açmaya izin vermediği için iyzico daha uygun.
   - Ödeme yalnızca web panelinde alınır, mobil uygulamada satın alma ekranı olmaz. Öğrenci/veli bir şey satın almadığı için App Store / Google Play uygulama içi satın alma zorunluluğuna ve %15–30 komisyonuna takılmayız.
4. **Mesajlaşma MVP'de yok.** Koç yalnızca not ve görev bırakır.
5. **KVKK hukuki metin desteği yok.** Uyarı: Mağazalar gizlilik politikası ister ve 18 yaş altı kullanıcılar için KVKK açık rıza/aydınlatma metni gerekir. Yayın öncesi en azından şablon bir aydınlatma metni + gizlilik politikası hazırlanmalı. Teknik tarafı (onay kutusu, onay kaydı) uygulamaya şimdiden eklenecek.

## 7. Marka

- **Maskot:** "Bızz" — önünde yükselen net grafiğini tutan arı (`logo/mentoria-bizz.html`). Küçük boyutlar için sadeleştirilmiş yüz ikonu.
- **Palet:** Bal Sarısı #FFC531 · Koyu Bal #F5A300 · Gece Moru #2B2350 · Grafik Moru #6C5CE7 · Krem #FFF8DE
