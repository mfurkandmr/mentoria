# E-posta (SMTP) kurulumu

Neden: Supabase'in yerleşik e-postası saatte birkaç adrese gider ve yalnızca proje
ekibine. Gerçek öğrenci kayıt kodu (`confirm_signup`) ve şifre sıfırlama (`recovery`)
alamaz. NOTLAR §17.

## Sağlayıcı seçimi

| | Ücretsiz sınır | Not |
|---|---|---|
| **Brevo** | günde 300 | Kurum açılış gününde 200-300 öğrenci kayıt olacaksa yeter. Önerilen başlangıç. |
| Resend | günde 100, ayda 3.000 | Supabase'le resmi entegrasyon. Günde 100 sınırı bir kurumun ilk gününde yetmez; Pro 20 USD/ay (50.000). |

Gönderen adres: `bildirim@mentoria.com.tr` (alan adı Cloudflare'de, gelen kutusu yok: Email
Routing yalnızca `iletisim@` ve `kvkk@` için; yanıt gelmesin diye gönderen "Mentoria
<bildirim@mentoria.com.tr>").

## Adımlar (hesap işlemleri size ait)

1. **Hesap aç** (Brevo ya da Resend), alan adı olarak `mentoria.com.tr` ekle.
2. Sağlayıcının gösterdiği **DNS kayıtlarını Cloudflare'e gir** (DNS → Records): SPF (TXT),
   DKIM (CNAME ya da TXT) ve varsa DMARC. **Cloudflare Email Routing'in mevcut SPF kaydını
   silme**; sağlayıcının `include:` değerini aynı SPF TXT kaydına ekle (tek SPF kaydı olur).
   Bulut simgesini **DNS only (gri)** yap.
3. Sağlayıcıda alan adı **Verified** olunca SMTP bilgisini al:
   - Resend: host `smtp.resend.com`, port `465`, kullanıcı `resend`, şifre = API anahtarı.
   - Brevo: host `smtp-relay.brevo.com`, port `587`, kullanıcı = Brevo SMTP girişi, şifre = SMTP anahtarı.
4. **Supabase → Authentication → Emails → SMTP Settings**: "Enable custom SMTP" aç; gönderen
   `bildirim@mentoria.com.tr`, gönderen adı `Mentoria`; yukarıdaki host/port/kullanıcı/şifre.
5. **Şablonlar** (Authentication → Emails → Templates):
   - "Confirm signup": konu `Mentoria doğrulama kodun: {{ .Token }}`, gövde `supabase/templates/confirm_signup.html`.
   - "Reset password": konu `Mentoria şifre sıfırlama`, gövde `supabase/templates/recovery.html`.
   - "Magic link": gövde `supabase/templates/magic_link.html` (kullanılıyorsa).
6. **Rate Limits** (Authentication → Rate Limits): "Rate limit for sending emails" değerini
   sağlayıcı planına göre yükselt (varsayılan 30/saat çok düşük; Brevo için 100-300).
7. **Sınama:** Yeni bir e-postayla kayıt dene → kod gelmeli, spam'e düşmemeli. Şifremi unuttum →
   bağlantı gelmeli ve `/app/reset-password` açmalı. Gmail'de "Orijinali göster" ile SPF/DKIM/DMARC
   = PASS kontrol et.

## Sonra

- `docs/YAPILACAKLAR.md` madde 1'i işaretle (tarih ekle).
- Supabase Pro'ya geçince (madde 3) "Leaked password protection" da açılır.
