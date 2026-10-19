# Mentoria Açık Rıza Metni (taslak)

> Taslak, avukat incelemesi gerekir.
>
> **Tasarım ilkeleri (KVKK Kurulu'nun açık rıza rehberine göre):**
> - Açık rıza **belirli bir konuya ilişkin, bilgilendirmeye dayalı ve özgür
>   iradeyle** verilmeli. Bu yüzden her madde ayrı onay kutusudur ve hiçbiri
>   önceden işaretli değildir.
> - Rıza **hizmet şartına bağlanmaz**: hiçbir kutuyu işaretlemeden de kayıt
>   olunur ve temel özellikler kullanılır.
> - Sözleşmenin ifası gibi başka bir hukuki sebebe dayanan işlemler için
>   rıza **istenmez**. Kurul, gereksiz rıza istemeyi "aldatıcı" bulabiliyor.
> - Rıza her an, verildiği kadar kolay **geri çekilebilir** ("Gizlilik ve
>   izinler" sayfası). Geri çekme ileriye etkilidir.
> - Her onay; metin sürümü, tarih ve kullanıcıyla kayıt altına alınır.
> - 18 yaş altı kullanıcılar için rıza veli tarafından verilir (bkz. veli
>   onay metni).

**Sürüm:** 1.0 · **Yürürlük tarihi:** [GG.AA.YYYY]

---

[VERİ SORUMLUSU UNVANI] ("Mentoria") tarafından hazırlanan **Aydınlatma
Metni**'ni okudum. Aşağıda **işaretlediğim** konularda kişisel verilerimin
işlenmesine açık rıza veriyorum. İşaretlemediğim konularda verilerim bu
amaçlarla işlenmez. Hiçbirini işaretlemesem de Mentoria'yı kullanabileceğimi
ve rızamı istediğim zaman uygulamadaki "Gizlilik ve izinler" sayfasından
geri çekebileceğimi biliyorum.

### ☐ 1. Başarı sıralamasında görünmek

Kurumum başarı sıralamasını açarsa; adımın kısaltması (ör. "El***"),
avatarım ve deneme netimin aynı kurumdaki diğer öğrencilere sıralama
listesinde gösterilmesine izin veriyorum.

*İzin vermezsen:* sıralamada görünmezsin ama kendi sıranı sen görmeye devam
edersin. [Ürün kararı: kendi sırası gösterilecek mi?]

### ☐ 2. Velimin çalışmalarımı görmesi (yalnızca 18 yaş ve üstü)

Davet ettiğim velimin; çalışma sürelerimi, çözdüğüm soru sayılarını, deneme
sonuçlarımı ve haftalık özetimi görmesine izin veriyorum.

*Not:* Bu kutu yalnızca 18 yaşından büyük öğrencilere gösterilir. 18 yaşından
küçüklerde veli zaten veli onayı sürecinin parçasıdır. Rıza velinin
davetinde, davet anında istenir.

### ☐ 3. Tanıtım ve kampanya bildirimleri [kullanılacaksa]

Mentoria'nın yeni özellikler, kampanyalar ve etkinliklerle ilgili bana
uygulama bildirimi ve e-posta göndermesine izin veriyorum.

*Not:* Ticari elektronik ileti gönderilecekse 6563 sayılı Kanun ve İleti
Yönetim Sistemi (İYS) kaydı da gerekir. Ödev, deneme sonucu, görüşme
hatırlatması gibi hizmet bildirimleri bu izne bağlı değildir.

### ☐ 4. Yurt dışına aktarım [yalnızca avukat gerekli görürse]

Kişisel verilerimin, Aydınlatma Metni'nde belirtilen hizmet sağlayıcılara
(Supabase: Almanya'daki sunucular; Google: telefon bildirimi) yurt dışına
aktarılmasına izin veriyorum.

*Not:* 2024 değişikliğinden sonra (KVKK md. 9) yurt dışı aktarımın birincil
yolu **standart sözleşmeler**. Açık rıza yalnızca "arızi" (ara sıra,
süreklilik arz etmeyen) aktarımlarda geçerli. Uygulamanın sürekli aktarımı
için bu madde **yeterli dayanak olmayabilir**. Önerilen: Supabase ve Google
ile standart sözleşmelerin imzalanıp 5 iş günü içinde Kurum'a bildirilmesi
ve bu maddenin hiç kullanılmaması. Avukata sorulacak.

---

**Onaylayan:** [Ad Soyad, uygulamadan otomatik] ·
**Tarih:** [otomatik] · **Metin sürümü:** 1.0

## Uygulamadaki görünüm (kod aşaması için not)

- Kayıt ekranında iki ayrı bölüm olmalı:
  1. **Zorunlu:** "Aydınlatma Metni'ni okudum." Bağlantıya dokununca tam
     metin açılır. Bu kutu rıza değil, bilgilendirme teyididir.
  2. **İsteğe bağlı:** yukarıdaki maddeler, her biri ayrı kutu, hiçbiri
     önceden işaretli değil.
- Her maddenin altında "İzin vermezsen ne olur?" satırı görünmeli.
- "Gizlilik ve izinler" sayfasında her madde bir anahtar (açık/kapalı)
  olmalı; kapatınca rıza geri çekilir.
- Kayıt (`consents` tablosu): kullanıcı, madde, metin sürümü, verildi/geri
  çekildi tarihi, veren (kendisi / velisi / kurum beyanı).
