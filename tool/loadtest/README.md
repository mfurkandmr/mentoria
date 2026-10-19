# Yük testi (k6)

"Deneme sonucu açıklandı, binlerce öğrenci aynı anda uygulamayı açtı" senaryosunu
ölçer. Her iterasyon bir öğrencinin uygulamayı açıp ana sayfaya gelmesidir.

**Canlı projede (`lmbykdvvxormfiaomysn`) çalıştırma.** Ayrı bir staging projesi
ya da Supabase branch'i kullan. Branch, Pro planda var. Ücretsiz planda ikinci
bir proje açıp bütün migration'ları oraya uygulayabilirsin.

## 1. Deneme öğrencileri

Staging'de bir kurum, bir koç ve koçun öğrenci davet kodu olsun. Kurumun
`seat_limit` değeri COUNT'tan büyük olmalı.

```bash
cd tool/loadtest
SUPABASE_URL=https://<staging>.supabase.co SERVICE_ROLE_KEY=... ANON_KEY=... \
INVITE_CODE=ABCD1234 COUNT=500 node make_users.mjs
```

Her öğrenciye 20 soru kaydı ve 3 deneme eklenir. Oturum anahtarları
`users.json`'a yazılır; bu dosya git'e girmez ve anahtarlar yaklaşık 1 saat
geçerlidir. Auth'un oturum açma hız sınırına takılırsan Dashboard →
Authentication → Rate Limits'ten geçici olarak yükselt.

500 hesap yeterli. k6 her açılışta rastgele birini seçer, ölçülen şey eş
zamanlı istek yükü.

## 2. Çalıştır

[k6'yı kur](https://grafana.com/docs/k6/latest/set-up/install-k6/), sonra:

```bash
k6 run -e SUPABASE_URL=https://<staging>.supabase.co -e ANON_KEY=... -e RATE=40 -e MODE=new student_open.js
```

- `RATE`: saniyede kaç açılış. 40 → 2 dakikada yaklaşık 5.000 öğrenci. Push
  kuyruğu bildirimleri saniyede 40 hızla yaydığı için gerçekçi tepe değer bu.
  Kuyruk olmasaydı ne olacağını görmek için `RATE=150` dene.
- `MODE=old`: ana sayfa verisi eskisi gibi 6 ayrı sorguyla gelir. Aynı RATE'le
  `new` ve `old`'u karşılaştır.
- `HOLD`: tepe sürenin uzunluğu (varsayılan `2m`).

## 3. Neye bak

- `app_open_ms` p95: açılışların %95'inin süresi. Eşik 2,5 saniye.
- `http_req_failed`: hata oranı. Eşik %1. 429/5xx görürsen sınıra
  dayanmışsın demektir.
- Supabase Dashboard → Reports: CPU, bağlantı sayısı, yavaş sorgular.

Sonuç kötüyse önce Reports'taki yavaş sorgulara bak. Yeterli değilse
Settings → Compute'tan bir üst boyuta geçip aynı testi tekrarla.
