# Kişisel Veri Saklama ve İmha Politikası (taslak)

> Taslak, avukat incelemesi gerekir. Süreler **öneridir**; senin ve avukatın
> onayıyla kesinleşecek. Kişisel Verilerin Silinmesi, Yok Edilmesi veya
> Anonim Hâle Getirilmesi Hakkında Yönetmelik'e göre hazırlandı. VERBİS
> kaydı zorunluysa bu politika da zorunludur; değilse yine iyi uygulamadır.

**Sürüm:** 1.0 · **Yürürlük tarihi:** [GG.AA.YYYY]

## 1. Amaç ve kapsam

Mentoria'nın işlediği kişisel verilerin ne kadar süre saklanacağını ve
süresi dolunca nasıl imha edileceğini düzenler. Sunucudaki veritabanını,
dosya deposunu, yedekleri ve kullanıcının cihazındaki önbelleği kapsar.

## 2. Saklama süreleri

| Veri | Saklama süresi | Sonra ne olur | Uygulamada durum |
|---|---|---|---|
| Hesap, profil, çalışma ve deneme kayıtları | Hesap açık olduğu sürece | Hesap silinince silinir | Var (silme akışı) |
| Hata defteri fotoğrafları | Kart veya hesap silinene kadar | Depodan silinir | **Eksik:** hesap silinince depodaki fotoğraflar kalıyor |
| Silinen hesabın verileri | En geç [30] gün | Kalıcı silme | [Kontrol edilecek] |
| Sistem yedekleri | [7] gün (Supabase'in yedek döngüsü) | Yedekle birlikte kendiliğinden silinir | Supabase tarafında |
| Lisansı biten kurumun öğrenci verileri | Lisans bitiminden [1 yıl] sonra (kurum veya öğrenci devam etmezse) | Silinir ya da anonimleştirilir | **Eksik:** otomatik görev yok |
| Uzun süre kullanılmayan hesaplar | Son girişten [2 yıl] sonra, [30] gün önceden e-posta uyarısıyla | Silinir | **Eksik** |
| Uygulama içi bildirimler | 90 gün (duyurular hariç) | Gece otomatik silinir | **Var** (`cleanup-notifications`) |
| Duyurular | [1 yıl] | Silinir | **Eksik** |
| Telefon bildirim adresi (FCM token) | Çıkış yapılınca veya geçersizleşince | Silinir | Var |
| Giriş ve güvenlik kayıtları (Supabase Auth) | [Yasal süre; 5651 için 1–2 yıl] | Supabase döngüsüyle | Supabase tarafında; avukata sorulacak |
| Rıza ve veli onay kayıtları | Rıza geri çekildikten veya hesap silindikten sonra [10 yıl] (zamanaşımı ve ispat için) | Silinir | Kod aşamasında eklenecek |
| Hesap silme talebi kaydı | Talep tamamlandıktan sonra [1 yıl] | Silinir | [Kontrol edilecek] |
| Cihazdaki önbellek | Çıkışta veya en çok 7 gün | Cihazdan silinir | Var |

**Anonim istatistik:** Silme yerine anonimleştirme seçilirse (ör. "bu
yayınevinin denemesinde ortalama net"), kişiyle hiçbir şekilde
eşleştirilemeyecek biçimde toplulaştırılır. Anonim veri KVKK kapsamı
dışındadır.

## 3. İmha yöntemleri

- **Veritabanı:** satırlar kalıcı olarak silinir (`DELETE`). Bağlı kayıtlar
  `ON DELETE CASCADE` ile birlikte silinir.
- **Dosya deposu:** fotoğraflar depodan kalıcı olarak silinir.
- **Yedekler:** yedek döngüsü dolunca kendiliğinden silinir. Yedekten geri
  yükleme yapılırsa silinmiş kişilerin verileri yeniden silinir.
- **Cihaz:** uygulama çıkışta önbelleği siler; uygulamayı kaldırmak cihazdaki
  tüm verileri siler.

## 4. Periyodik imha

Otomatik görevler (pg_cron) her gece çalışır. Otomatikleşmeyen imhalar için
**her 6 ayda bir** kontrol yapılır ve kayıt altına alınır (Yönetmelik
periyodik imha süresini en çok 6 ay olarak belirler).

## 5. Sorumlular

| Görev | Sorumlu |
|---|---|
| Politikanın güncellenmesi | [Ad Soyad / unvan] |
| Silme taleplerinin yanıtlanması (30 gün içinde) | [Ad Soyad] |
| Teknik imha ve otomatik görevler | [Ad Soyad] |
| Veri ihlali bildirimi (Kurul'a 72 saat içinde) | [Ad Soyad] |
