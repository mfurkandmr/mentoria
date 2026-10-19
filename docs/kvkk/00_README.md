# KVKK belgeleri (taslak paket)

> **Durum (19 Ekim 2026):** Taslaklar hazır. Avukat incelemesi bekleniyor.
> Kod değişiklikleri henüz yapılmadı (aşağıdaki "Kod aşaması" listesi).
> Bu metinler hukuki görüş değildir; yayımlanmadan önce bir KVKK avukatı
> tarafından incelenmelidir.

## Dosyalar

| Dosya | Ne işe yarar | Nerede kullanılacak |
|---|---|---|
| `01_veri_envanteri.md` | Hangi veri, kimden, nerede, hangi hukuki sebeple | İç belge; diğer metinlerin dayanağı |
| `02_aydinlatma_metni.md` | KVKK md. 10 bilgilendirmesi | Uygulamada kayıt ekranı ve "Gizlilik ve izinler"; web sitesi |
| `03_acik_riza_metni.md` | İsteğe bağlı işlemler için ayrı ayrı rıza | Uygulamada kayıt ekranı ve "Gizlilik ve izinler" |
| `04_veli_onay_metni.md` | 18 yaş altı için veli onayı (A), kurum beyanı (B), kurum formu paragrafı (C) | Veli kaydı, kurum davet ekranı, kurumların kendi formları |
| `05_gizlilik_politikasi.md` | Kısa, herkese açık politika ve mağaza formu özeti | Web sitesi, Google Play, App Store |
| `06_saklama_imha_politikasi.md` | Saklama süreleri ve imha yöntemleri | İç belge (VERBİS'e kayıtlıysa zorunlu) |
| `07_veri_isleme_sozlesmesi.md` | Kurumlarla veri işleme sözleşmesi iskeleti | Kurumlarla lisans sözleşmesinin eki |

## Senin doldurman gerekenler

- [ ] Veri sorumlusunun unvanı (şirket / şahıs şirketi), adresi, MERSİS
      veya vergi numarası
- [ ] KVKK başvuruları için e-posta adresi (ör. kvkk@...), varsa KEP adresi
- [ ] Saklama süreleri: silinen hesap ([30] gün), lisansı biten kurum
      ([1 yıl]), uzun süre kullanılmayan hesap ([2 yıl]), duyurular ([1 yıl])
- [ ] Tanıtım ve kampanya bildirimi gönderilecek mi? (Gönderilecekse İYS
      kaydı da gerekir.)
- [ ] Sorumlu kişiler (saklama-imha politikası 5. bölüm)
- [ ] Kendi SMTP/e-posta sağlayıcınız var mı? (Doğrulama e-postaları için)

## Avukata sorulacaklar

1. **Veri sorumlusu kim?** Kurum aracılığıyla gelen öğrenciler için kurum
   veri sorumlusu, Mentoria veri işleyen mi (A); yoksa ikisi ayrı veri
   sorumlusu mu (B)? Bireysel koçların öğrencileri için durum ne? Aydınlatma
   metninin 1. bölümü buna göre değişecek.
2. **18 yaş altı:** Veli onayı her yaş için mi gerekli, yoksa ayırt etme
   gücüne sahip (ör. 15+) öğrencinin kendi onayı bazı işlemler için yeterli
   mi? Kurumun beyanı (Metin B) yeterli güvence sayılır mı?
3. **Yurt dışı aktarım:** Supabase (AB) ve Google (ABD) için standart
   sözleşme yolu nasıl işletilecek? Supabase ve Google'ın kendi veri işleme
   ekleri (DPA) KVKK standart sözleşmesi yerine geçer mi? Kurul'a 5 iş günü
   içinde bildirim kim tarafından yapılacak?
4. **VERBİS:** Kayıt yükümlülüğü var mı? (Çalışan sayısı ve yıllık bilanço
   eşikleri; ana faaliyet özel nitelikli veri işleme değil.)
5. **Güvenlik kayıtları:** 5651 sayılı Kanun kapsamında saklama süresi ve
   yükümlülük var mı? (Supabase Auth giriş kayıtları)
6. **Başarı sıralaması:** Kurum içi, kısaltılmış adla sıralama için açık
   rıza mı gerekli, yoksa meşru menfaat yeterli mi?
7. **Öğrencinin hesabını koçun silmesi:** Mevcut akış (öğrenci talep eder,
   koç siler) KVKK md. 11 ve 30 günlük cevap süresiyle uyumlu mu? Taslakta
   "30 günde tamamlanmazsa Mentoria siler" önerildi.
8. **Koç notlarında özel nitelikli veri:** Serbest metin alanlarına sağlık
   vb. bilgi yazılması riskine karşı uyarı yeterli mi?

## Kod aşaması (metinler kesinleşince)

Önceden konuşulan plandaki Aşama 2–4 ve envanterde bulunan eksikler:

1. **Kayıt ekranı:**
   - Aydınlatma metni uygulama içinde tam metin olarak açılsın; kutucuk
     "okudum" teyidi olsun.
   - Açık rıza maddeleri ayrı, isteğe bağlı kutucuklar olsun; hiçbiri
     önceden işaretli olmasın.
2. **Doğum yılı:** kayıtta sorulsun; 18 yaş altı için veli onayı akışı
   (kurum beyanı veya veli daveti) eklensin.
3. **`consents` tablosu:** kullanıcı, madde, metin sürümü, verildi ve geri
   çekildi tarihleri, veren (kendisi / veli / kurum beyanı). Metin sürümü
   değişince yeniden onay istensin.
4. **"Gizlilik ve izinler" ekranı:** rızaları açıp kapatma, metinleri
   okuma, **verilerimi indir** (KVKK md. 11).
5. **Başarı sıralaması** kurum ayarına ek olarak öğrencinin rızasına
   bağlansın.
6. **Hata defteri fotoğrafları** hesap silinince depodan da silinsin
   (şu an kalıyor).
7. **Öğrenci silme talebi** 30 günde sonuçlanmazsa otomatik silinsin.
8. **Google Fonts:** yazı tipleri uygulamaya gömülsün; Google'a IP aktarımı
   kalksın.
9. **Saklama görevleri:** lisansı biten kurum, uzun süre kullanılmayan
   hesap ve eski duyurular için gece görevleri.
10. **Not alanları:** koç notu ve görev açıklamasının yanına "sağlık vb.
    özel bilgi yazmayın" uyarısı.
11. **Web'den hesap silme talebi sayfası** (Google Play zorunluluğu).
