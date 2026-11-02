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
| Hata defteri fotoğrafları | Kart veya hesap silinene kadar | Depodan silinir | **Var** (`storage-cleanup`, 10 dakikada bir) |
| Silinen hesabın verileri | Hemen; öğrenci silme talebinde en geç 29 gün | Kalıcı silme | **Var** (`overdue-deletion-requests`) |
| Sistem yedekleri | 7 gün (Supabase'in yedek döngüsü) | Yedekle birlikte kendiliğinden silinir | Supabase tarafında |
| Lisansı biten kurumun verileri | Lisans bitiminden 1 yıl sonra (lisans yenilenmezse) | Kurumdaki tüm hesaplar silinir | **Var** (`retention-jobs`) |
| Uzun süre kullanılmayan hesaplar | Son etkinlikten 2 yıl sonra, 30 gün önceden uygulama içi ve telefon bildirimiyle uyarılarak | Silinir | **Var** (`retention-jobs`); öğrencisi olan koç ve öğrencisi olan kurumun tek müdürü silinmez |
| Uygulama içi bildirimler | 90 gün (duyurular hariç) | Gece otomatik silinir | **Var** (`cleanup-notifications`) |
| Duyurular | 1 yıl | Duyuru ve bildirimleri silinir | **Var** (`retention-jobs`) |
| Telefon bildirim adresi (FCM token) | Çıkış yapılınca veya geçersizleşince | Silinir | Var |
| Giriş ve güvenlik kayıtları (Supabase Auth) | [Yasal süre; 5651 için 1–2 yıl] | Supabase döngüsüyle | Supabase tarafında; avukata sorulacak |
| Rıza ve veli onay kayıtları | Rıza geri çekildikten veya hesap silindikten sonra [10 yıl] (zamanaşımı ve ispat için) | Silinir | Kod aşamasında eklenecek |
| Hesap silme talebi kaydı | Hesapla birlikte | Silinir | Var (hesap silinince cascade) |
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

Mentoria bireysel geliştirici tarafından sunulduğu için tüm görevlerin
sorumlusu veri sorumlusunun kendisidir.

| Görev | Sorumlu |
|---|---|
| Politikanın güncellenmesi | [AD SOYAD] |
| Silme taleplerinin yanıtlanması (30 gün içinde) | [AD SOYAD] |
| Teknik imha ve otomatik görevler | [AD SOYAD] |
| Veri ihlali bildirimi (Kurul'a 72 saat içinde) | [AD SOYAD] |
