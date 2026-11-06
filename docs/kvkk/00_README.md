# KVKK belgeleri (taslak paket)

> **Durum (29 Ekim 2026):** Taslaklar hazır, kod aşaması büyük ölçüde bitti.
> Avukat incelemesi ve kişisel bilgiler (ad, adres, e-posta) bekleniyor.
> Bu metinler hukuki görüş değildir; yayımlanmadan önce bir KVKK avukatı
> tarafından incelenmelidir.

## Dosyalar

| Dosya | Ne işe yarar | Nerede kullanılacak |
|---|---|---|
| `01_veri_envanteri.md` | Hangi veri, kimden, nerede, hangi hukuki sebeple | İç belge; diğer metinlerin dayanağı |
| `02_aydinlatma_metni.md` | KVKK md. 10 bilgilendirmesi | Uygulamada kayıt ekranı ve "Gizlilik ve izinler"; web sitesi |
| `03_acik_riza_metni.md` | İsteğe bağlı işlemler için ayrı ayrı rıza | Uygulamada kayıt ekranı ve "Gizlilik ve izinler" |
| `04_veli_onay_metni.md` | 18 yaş altı için veli onayı (A), kurum beyanı (B), kurum formu paragrafı (C) | Veli kaydı, kurum davet ekranı, kurumların kendi formları |
| `05_gizlilik_politikasi.md` | Kısa, herkese açık politika ve mağaza formu özeti | Uygulamada "Gizlilik ve izinler"; web sitesi, Google Play, App Store |
| `06_saklama_imha_politikasi.md` | Saklama süreleri ve imha yöntemleri | İç belge (VERBİS'e kayıtlıysa zorunlu) |
| `07_veri_isleme_sozlesmesi.md` | Kurumlarla veri işleme sözleşmesi iskeleti | Kurumlarla lisans sözleşmesinin eki |
| `08_kullanim_kosullari.md` | Kullanım kuralları, fikrî mülkiyet ("tüm hakları saklıdır"), sorumluluk | Uygulamada kayıt ekranı ve "Gizlilik ve izinler"; web sitesi, mağazalar |

## Senin doldurman gerekenler

- [x] Veri sorumlusu: şirket yok, bireysel geliştirici (gerçek kişi; MERSİS
      ve KEP yok). Metinler buna göre düzenlendi (29 Ekim 2026).
- [ ] Ad soyad (`[AD SOYAD]`) ve yazışma adresi (`[ADRES]`)
- [ ] KVKK başvuruları için e-posta adresi (`[KVKK E-POSTA ADRESİ]`)
- [ ] Web sürümünün adresi (`[WEB ADRESİ]`; hesap silme sayfası
      `[WEB ADRESİ]/#/hesap-sil`, Google Play formuna da bu yazılır)
- [x] Saklama süreleri: silinen hesap 30 gün, lisansı biten kurum 1 yıl,
      uzun süre kullanılmayan hesap 2 yıl (30 gün önceden uyarı), duyurular
      1 yıl (29 Ekim 2026, taslaktaki öneriler kabul edildi)
- [x] Tanıtım ve kampanya bildirimi gönderilmeyecek (19 Ekim 2026 kararı).
      İleride gönderilirse açık rıza maddesi ve İYS kaydı gerekir.
- [x] Sorumlu kişiler: hepsi veri sorumlusunun kendisi (saklama-imha
      politikası 5. bölüm)
- [ ] Kullanım koşulları: yetkili mahkeme ili ve ücretlendirme modeli
      (`08_kullanim_kosullari.md` 8. ve 12. maddeler)
- [ ] Kurum finansı (NOTLAR §46-47): veli adı ve cep telefonu taksit
      hatırlatma SMS'i için işleniyor; aydınlatma metnine (işlenen veriler,
      amaç, SMS sağlayıcısı alıcı olarak) eklenmeli, sonra `legalVersion`
      artırılmalı. SMS sağlayıcısıyla veri işleme sözleşmesi gerekir.
- [ ] Finans (NOTLAR §56, 6 Kasım 2026): veli artık çocuğunun ücret, taksit ve
      makbuzlarını uygulamada görüyor; makbuzda ödeyen veli adı var. Aydınlatma
      metnine "veliye ödeme bilgisinin gösterilmesi" eklenmeli.
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

## Kod aşaması

**19 Ekim 2026'da yapıldı** (ayrıntı: NOTLAR.md §35):

- [x] Kayıt ekranı: aydınlatma teyidi ayrı, açık rıza maddeleri ayrı ve isteğe bağlı
- [x] Doğum yılı ve 18 yaş altı için veli onayı (kurum beyanı ya da veli kaydı)
- [x] `consents` tablosu: sürüm, kaynak, geri çekme geçmişi
- [x] "Gizlilik ve izinler" ekranı ve verilerimi indir
- [x] Başarı sıralaması ve avatar liderliği öğrencinin rızasına bağlandı
- [x] Hata defteri fotoğrafları hesap/kart silinince depodan siliniyor
- [x] Öğrenci silme talebi 29 günde sonuçlanmazsa otomatik siliniyor
- [x] Koç notu ve görev açıklamasında özel bilgi uyarısı

**Kalanlar:**

- [x] Google Fonts: yazı tipleri uygulamaya gömüldü (`assets/google_fonts`,
      `tool/fonts/fetch_fonts.py`); Google'a IP aktarımı kalktı.
- [x] Saklama görevleri (29 Ekim 2026, NOTLAR.md §42): lisansı biten kurum,
      uzun süre kullanılmayan hesap (uyarı + silme), eski duyurular. Gece
      `retention-jobs` (pg_cron). Canlıda (31 Ekim 2026; risk_alerts'ten
      sonra uygulandığı için bildirim türü kısıtı yeniden yazılmadı).
- [x] Web'den hesap silme sayfası: `/#/hesap-sil` (e-posta kodu ile giriş).
      Canlıda çalışması için `supabase/templates/magic_link.html` şablonu
      Supabase'e yapıştırılmalı.
- [ ] Hareketsiz hesap uyarısı şimdilik uygulama içi + telefon bildirimi;
      kendi e-posta sağlayıcınız olursa e-posta uyarısı da eklenebilir.
- [ ] Rıza ve veli onay kayıtları hesapla birlikte siliniyor; avukat "10 yıl
      ispat için sakla" derse ayrı bir arşiv tablosu gerekir.
- [ ] `kvkkContactEmail` ve metinlerdeki `[...]` yerleri doldurulsun; sonra
      `python tool/legal/build_legal.py` çalıştırılıp `legalVersion` artırılsın
      (şu an 1.2)
- [ ] Avukat onayından sonra metin değişirse aynı adım
- [ ] Rehberlik görüşme kayıtları (`guidance_logs`, 31 Ekim 2026): öğrenci ve
      veli görmez, "verilerimi indir"e de girmiyor. KVKK md. 11 başvurusunda
      öğrenciye verilmesi gerekip gerekmediği avukata sorulsun; gerekirse
      dışa aktarmaya eklenir. Veri envanteri ve aydınlatma metnine "koç ve
      kurum müdürünün tuttuğu rehberlik notları" satırı eklenmeli.
- [ ] Yoklama (5 Kasım 2026, NOTLAR.md §48): devam bilgisi ve yoklama için
      girilen veli telefonu yeni kişisel veri; veri envanterine ve aydınlatma
      metnine eklenmeli ("gelmedi" SMS'i velinin numarasına gider). Saklama
      1 yıl (öneri, avukata sorulsun). "Verilerimi indir"e henüz girmiyor.
- [ ] Ders programı (5 Kasım 2026, NOTLAR.md §49): `teachers` tablosunda
      uygulama hesabı olmayan öğretmenlerin adı ve müsaitlik saatleri
      tutuluyor (kurum girer; öğretmenin kendi rızası/aydınlatması yok).
      Kurum ile veri işleme sözleşmesine ve aydınlatma metnine "kurumun
      girdiği öğretmen bilgileri" eklenmeli. Öğrencinin sınıf ataması da
      "verilerimi indir"e girmiyor.
- [ ] Öğrenci listesi (5 Kasım 2026, NOTLAR.md §51): `expected_students`
      kurumun yüklediği, henüz hesabı olmayan öğrencilerin numara, ad soyad,
      sınıf ve veli telefonunu tutar (ilgili kişi uygulamaya girmeden).
      Veri işleme sözleşmesine ve aydınlatma metnine eklenmeli; eşleşmeyen
      satırlar için saklama süresi belirlenmeli (şimdilik süresiz). Sınıf ve
      numara değişiklik geçmişi de hesapla birlikte siliniyor.
- [ ] Velilere toplu SMS (5 Kasım 2026, NOTLAR.md §52): veli telefonu artık
      kurum duyuruları için de kullanılıyor; aydınlatma metnindeki amaçlara
      "kurum bilgilendirme SMS'leri" eklenmeli. Ticari/kampanya SMS'i için
      İYS kaydı ve onay gerekir (uygulama yalnızca uyarıyor, içeriği denetlemiyor).
