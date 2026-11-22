# Yapılacaklar (sıralı)

13 Kasım 2026'da çıkarıldı. Sıra: önce gerçek kullanıcıyı engelleyecekler, sonra
yasal, sonra dağıtım, en son küçük ürün eksikleri. Bitenleri `[x]` yap, tarih ekle.
Ayrıntılar NOTLAR.md'deki bölümlerde.

## 1. Gerçek kullanıcı gelmeden önce

- [ ] **1. Kendi SMTP'miz** — Supabase'in yerleşik e-postası saatte birkaç mailde
      kesiliyor; kayıt doğrulama ve şifre sıfırlama takılır. Resend / Brevo (ücretsiz
      plan), gönderici `bildirim@mentoria.com.tr`, DNS kayıtları Cloudflare'de (SPF,
      DKIM). Supabase → Authentication → SMTP Settings. Bizim iş: kurulum + şablon
      kontrolü (`supabase/templates/`). **Hazır:** adım adım rehber `docs/SMTP_KURULUM.md`, şablonlar
      `supabase/templates/` (confirm_signup, recovery, magic_link); hesap + DNS + Supabase paneli sizde.
- [ ] **2. Tanıtım sayfasına "Masaüstüne / telefona yükle" bölümü** — PWA yalnızca
      `/app`'te. Chrome/Edge adres çubuğu "Yükle"; masaüstü Opera desteklemiyor;
      iPhone Paylaş → Ana Ekrana Ekle; Android ⋮ → Uygulamayı yükle. Ekle, derle,
      `npx wrangler@4 pages deploy build/site --project-name mentoria --branch main`.
- [ ] **3. Supabase Pro** (kullanıcı) — ücretsiz planda 1 hafta hareketsizlikte proje
      duraklıyor, günlük yedek yok. İlk kurum anlaşmasıyla birlikte. Pro'da: sızdırılmış
      parola koruması aç (Authentication → Policies), yedekleri doğrula.
- [ ] **4. WhatsApp bağlantısı** (kurum + biz) — kurumun Meta Business hesabı,
      `phone_number_id`, `waba_id`, kalıcı anahtar; şablonlar onaylatılacak
      (`docs/WHATSAPP_KURULUM.md`). Müdür panelinde `/admin/whatsapp`. Bağlanana kadar
      yoklama/ödev/taksit mesajları kuyrukta.
- [~] **5. Maarif Modeli müfredatı** — kod ve katalog hazır (NOTLAR §104), canlıya uygulanmadı;
      ÖSYM'nin YKS kapsamı ve öğretmen gözden geçirmesi açık. Eski not: — **kurum önem veriyor.** Konu listesi ve sınıf
      seviyesine göre konu eşlemesi (NOTLAR §91, `20261111150000_grade_level`) hâlâ eski
      MEB müfredatının ünite sırasına göre. Türkiye Yüzyılı Maarif Modeli'nin derslere
      göre konu/kazanım listesi çıkarılacak; konular, kaynak takibi (§92) ve kazanım
      analizi buna göre güncellenecek. Önce kurumla hangi sınıf ve derslerin geçtiği
      netleşmeli.

## 2. Yasal

- [ ] **6. Avukat incelemesi** (kullanıcı) — `docs/kvkk/00_README.md` "Avukata
      sorulacaklar" + veli WhatsApp rızası, yurt dışı aktarım (Supabase, Google, Meta,
      Cloudflare), ev adresi yerine tebligat adresi.
- [ ] **7. Kullanım koşulları** — yetkili mahkeme ili ve ücretlendirme modeli
      (`docs/kvkk/08_kullanim_kosullari.md` 8. ve 12. madde). Sonra `build_legal.py` +
      `legalVersion` artır + siteyi yeniden yükle.
- [ ] **8. Saklama süreleri** — soru çözümü talepleri (`tutoring_requests`) ve diğer
      KVKK listesindeki kayıtlar için süre + pg_cron temizliği.
- [ ] **9. Marka tescili** (kullanıcı) — TÜRKPATENT'te geçerli "Mentoria" kaydı yok
      (13 Kasım). Sınıf 41 + 42 (ve 9); 3 sınıf ~16.000 TL.
- [ ] **10. KVKK README'yi toparla** — yapılmış ama açık görünen maddeler (KVKK
      e-postası, `[...]` yer tutucuları, NOTLAR §99 "Açık" satırı).

## 3. Dağıtım

- [ ] **11. Güncel APK** — 12 Kasım'dan sonraki düzeltmeler (Talep et düğmesi, araç
      ızgarası, personel davet kartı, KVKK 1.3) telefonda yok.
- [ ] **12. Web bildirimi** — Firebase → Project settings → Your apps → Web uygulaması;
      `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID` env.json'a. Sonra yeniden derle.
- [ ] **13. Otomatik web yayını** — Cloudflare API token + GitHub Secrets
      (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`), `WEB_DEPLOY=true`;
      `main`'e her gönderimde site kendiliğinden yüklenir.
- [ ] **14. Mağazalar** (kullanıcı, kurumlarla anlaşınca) — Play: 12 testçi + 14 gün
      kapalı test; iOS: Mac yok (Codemagic), PrivacyInfo.xcprivacy eksik.

## 4. Ürün eksikleri

- [ ] **15. Güvenlik:** `book_question_report` kurum lisansını (`my_tenant_active`)
      denetlemiyor.
- [ ] **16. Öğretmene bildirim** — program yayınlanınca / değişince öğretmene de.
- [ ] **17. Soru çözümü:** geçmiş talepler ekranı; öğretmen geldi/gelmedi işaretlesin.
- [ ] **18. Öğretmen:** müsaitliğini kendisi girsin; ödev verebilsin (`can_manage_student`).
- [ ] **19. Optik:** sabit genişlikli `.txt` çıktısı okunsun (kurumun gerçek dosyasıyla).
