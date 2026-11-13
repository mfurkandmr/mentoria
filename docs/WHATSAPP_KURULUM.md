# WhatsApp kurulumu (kurum müdürü için)

Velilere giden bütün mesajlar (yoklama, taksit hatırlatma, toplu mesaj, deneme
sonucu) kurumun WhatsApp Business numarasından gider. SMS kapandı. Bağlantı
kurulana kadar mesajlar sırada bekler, kaybolmaz.

## 1. Meta tarafı (bir kez)

1. business.facebook.com'da kurum için bir **Meta Business** hesabı aç ve
   işletmeyi doğrula (vergi levhası / fatura).
2. developers.facebook.com → **Uygulama oluştur** → tür "Business" →
   ürün olarak **WhatsApp** ekle.
3. WhatsApp → **API Setup**: kurumun numarasını ekle.
   - Numara şu an telefondaki **WhatsApp Business** uygulamasında kullanılıyorsa
     "mevcut WhatsApp Business uygulamasını bağla" (coexistence) seçeneğini
     kullan: müdür telefondan yazmaya devam eder, sistem aynı numaradan gönderir.
   - Normal (Business olmayan) WhatsApp'taki numara doğrudan bağlanamaz; önce
     WhatsApp Business uygulamasına taşınmalı.
4. Ödeme yöntemini Meta Business → **Faturalandırma**'dan gir. Mesaj başına
   ücreti Meta doğrudan kuruma keser (uygulamada ödeme ekranı yoktur).
5. Business Settings → **System users** → yeni sistem kullanıcısı → uygulamayı
   ve WhatsApp hesabını ata → `whatsapp_business_messaging` ve
   `whatsapp_business_management` izinleriyle **kalıcı anahtar** oluştur.

## 2. Şablonu onaylat

WhatsApp, velinin son 24 saatte yazmadığı mesajlar için önceden onaylı şablon
ister. WhatsApp Manager → **Message templates** → yeni şablon:

- Ad: `kurum_bilgilendirme`
- Kategori: **Utility** · Dil: **Turkish**
- Gövde:

```
Kurumunuzdan bilgilendirme:

{{1}}

Bu mesaj {{2}} tarafından gönderilmiştir.
```

Örnek değerler: {{1}} = "Öğrenciniz Ali bugün kuruma gelmedi.",
{{2}} = kurum adı. Onay genelde dakikalar-saatler sürer.

### Ödev ve koç mesajı şablonları

Ödev PDF'i ve koçun veliye mesajı için iki şablon daha (adlar aynen böyle):

**`odev_bildirimi`** · Utility · Turkish · Başlık (Header): **Document**

```
Sayın veli, {{1}}, öğrenciniz {{2}} adına ödevlendirme yapmıştır: {{3}}. Son tarih: {{4}}. Gerekli bilgiler için ekteki dosyaya tıklayın.

{{5}} tarafından gönderilmiştir.
```

Örnek: {{1}} Selin Kaya, {{2}} Ahmet Çelik, {{3}} Türev ödevi, {{4}} 20.11.2026,
{{5}} kurum adı.

**`koc_mesaji`** · Utility · Turkish

```
Sayın veli, öğrenciniz {{1}} hakkında koçu {{2}} size bir mesaj gönderdi:

{{3}}

Bu mesaj {{4}} tarafından gönderilmiştir.
```

Örnek: {{1}} Ahmet Çelik, {{2}} Selin Kaya, {{3}} koçun yazdığı metin, {{4}} kurum adı.

## 3. Uygulamada bağla

Mentoria → Müdür → İletişim → **Velilere WhatsApp** → üstteki kartta
**Bağla**:

| Alan | Nereden |
|---|---|
| Telefon numarası kimliği | API Setup → "Phone number ID" |
| WhatsApp Business hesap kimliği | API Setup → "WhatsApp Business Account ID" |
| Numara (görünen) | Velilerin göreceği numara (yalnızca bilgi) |
| Erişim anahtarı | 1.5'teki kalıcı anahtar |
| Şablon adı | `kurum_bilgilendirme` (2. adımdaki ad) |

Anahtar kaydedildikten sonra uygulamada bir daha gösterilmez. Sırada bekleyen
mesajlar hemen gönderilir.

## 4. Teslim / okundu bilgisi (platform yöneticisi, bir kez)

Meta uygulamasında WhatsApp → **Configuration** → Webhook:

- Callback URL: `https://lmbykdvvxormfiaomysn.supabase.co/functions/v1/whatsapp-webhook`
- Verify token: Supabase → Edge Functions → Secrets'taki `WHATSAPP_VERIFY_TOKEN`
- Abonelik: `messages`

Supabase gizli değerleri: `WHATSAPP_VERIFY_TOKEN` (rastgele uzun bir metin),
`WHATSAPP_APP_SECRET` (Meta uygulaması → App settings → Basic → App secret).
Bunlar yoksa mesajlar yine gider, yalnızca "okundu" sayıları boş kalır.

## Sorun giderme

- **"gitmedi" sayısı artıyor:** Velilere WhatsApp ekranındaki geçmişte hata
  metni görünür. Sık nedenler: numara WhatsApp kullanmıyor (131026), şablon
  onaylı değil ya da adı farklı (132001), anahtarın süresi doldu (190).
- **Veli cevap yazdı:** cevap kurumun WhatsApp Business uygulamasına düşer;
  uygulamaya gelmez.
- **Reklam / kampanya mesajı göndermeyin:** WhatsApp kurallarına aykırıdır,
  numara kapatılabilir.
