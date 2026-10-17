"""AYT Türk Dili ve Edebiyatı: yazar-eser, dönem, nazım biçimi, söz sanatı,
tür ve akım tabloları; hece sayısı soruları bu dosyadaki özgün dizelerden
hesaplanır."""
from common import define_gens, fact_gen, make, relation_gens, stem_limit

T = 'AYT_EDB'

WORKS = {
    'Şinasi': ['Şair Evlenmesi', 'Tercüme-i Manzume', 'Müntehabat-ı Eş\'ar', 'Durub-ı Emsal-i Osmaniye'],
    'Namık Kemal': ['İntibah', 'Cezmi', 'Vatan yahut Silistre', 'Gülnihal', 'Celaleddin Harzemşah', 'Akif Bey'],
    'Ziya Paşa': ['Harabat', 'Terkib-i Bent', 'Terci-i Bent', 'Zafername', 'Rüya'],
    'Ahmet Mithat Efendi': ['Felatun Bey ile Rakım Efendi', 'Letaif-i Rivayat', 'Hasan Mellah', 'Henüz On Yedi Yaşında', 'Müşahedat'],
    'Recaizade Mahmut Ekrem': ['Araba Sevdası', 'Talim-i Edebiyat', 'Zemzeme', 'Nijad Ekrem', 'Takdir-i Elhan'],
    'Abdülhak Hamit Tarhan': ['Makber', 'Sahra', 'Finten', 'Tarık', 'Eşber', 'Duhter-i Hindu'],
    'Şemsettin Sami': ['Taaşşuk-ı Talat ve Fitnat', 'Kamus-ı Türki', 'Besa'],
    'Samipaşazade Sezai': ['Sergüzeşt', 'Küçük Şeyler'],
    'Nabizade Nazım': ['Karabibik', 'Zehra'],
    'Muallim Naci': ['Ateşpare', 'Füruzan', 'Şerare'],
    'Tevfik Fikret': ['Rübab-ı Şikeste', 'Haluk\'un Defteri', 'Rübabın Cevabı', 'Şermin'],
    'Halit Ziya Uşaklıgil': ['Mai ve Siyah', 'Aşk-ı Memnu', 'Kırık Hayatlar', 'Nemide', 'Ferdi ve Şürekası', 'Kırk Yıl'],
    'Mehmet Rauf': ['Eylül', 'Ferda-yı Garam', 'Genç Kız Kalbi'],
    'Cenap Şahabettin': ['Hac Yolunda', 'Evrak-ı Eyyam', 'Avrupa Mektupları', 'Tiryaki Sözleri'],
    'Hüseyin Cahit Yalçın': ['Hayat-ı Muhayyel', 'Hayal İçinde', 'Nesl-i Ahir'],
    'Hüseyin Rahmi Gürpınar': ['Şıpsevdi', 'Mürebbiye', 'Kuyruklu Yıldız Altında Bir İzdivaç', 'Gulyabani', 'Metres'],
    'Ahmet Haşim': ['Göl Saatleri', 'Piyale', 'Gurabahane-i Laklakan', 'Frankfurt Seyahatnamesi', 'Bize Göre'],
    'Ömer Seyfettin': ['Kaşağı', 'Forsa', 'Pembe İncili Kaftan', 'Bomba', 'Diyet', 'Yalnız Efe', 'Efruz Bey'],
    'Ziya Gökalp': ['Kızıl Elma', 'Yeni Hayat', 'Altın Işık', 'Türkçülüğün Esasları'],
    'Mehmet Emin Yurdakul': ['Türkçe Şiirler', 'Türk Sazı', 'Tan Sesleri'],
    'Mehmet Akif Ersoy': ['Safahat'],
    'Yakup Kadri Karaosmanoğlu': ['Yaban', 'Kiralık Konak', 'Sodom ve Gomore', 'Hüküm Gecesi', 'Ankara', 'Nur Baba', 'Panorama'],
    'Halide Edip Adıvar': ['Sinekli Bakkal', 'Ateşten Gömlek', 'Vurun Kahpeye', 'Mor Salkımlı Ev', 'Handan'],
    'Reşat Nuri Güntekin': ['Çalıkuşu', 'Yaprak Dökümü', 'Yeşil Gece', 'Acımak', 'Dudaktan Kalbe', 'Miskinler Tekkesi', 'Anadolu Notları'],
    'Refik Halit Karay': ['Memleket Hikâyeleri', 'Gurbet Hikâyeleri', 'Sürgün', 'Yezidin Kızı', 'Nilgün'],
    'Yahya Kemal Beyatlı': ['Kendi Gök Kubbemiz', 'Eski Şiirin Rüzgârıyla', 'Aziz İstanbul', 'Eğil Dağlar', 'Siyasi ve Edebi Portreler'],
    'Faruk Nafiz Çamlıbel': ['Çoban Çeşmesi', 'Dinle Neyden', 'Akın', 'Canavar'],
    'Nazım Hikmet': ['835 Satır', 'Memleketimden İnsan Manzaraları', 'Kuvayi Milliye', 'Jokond ile Si-Ya-U'],
    'Necip Fazıl Kısakürek': ['Kaldırımlar', 'Çile', 'Örümcek Ağı', 'Ben ve Ötesi', 'Bir Adam Yaratmak', 'Tohum'],
    'Ahmet Hamdi Tanpınar': ['Huzur', 'Saatleri Ayarlama Enstitüsü', 'Beş Şehir', 'Mahur Beste', 'Sahnenin Dışındakiler', 'Abdullah Efendinin Rüyaları'],
    'Peyami Safa': ['Dokuzuncu Hariciye Koğuşu', 'Fatih-Harbiye', 'Matmazel Noraliya\'nın Koltuğu', 'Yalnızız', 'Bir Tereddüdün Romanı'],
    'Sait Faik Abasıyanık': ['Semaver', 'Sarnıç', 'Lüzumsuz Adam', 'Alemdağ\'da Var Bir Yılan', 'Son Kuşlar', 'Medarı Maişet Motoru', 'Şahmerdan'],
    'Sabahattin Ali': ['Kuyucaklı Yusuf', 'İçimizdeki Şeytan', 'Kürk Mantolu Madonna', 'Değirmen', 'Kağnı', 'Ses'],
    'Memduh Şevket Esendal': ['Ayaşlı ve Kiracıları', 'Otlakçı', 'Mendil Altında', 'Vassaf Bey'],
    'Kemal Tahir': ['Devlet Ana', 'Yorgun Savaşçı', 'Esir Şehrin İnsanları', 'Göl İnsanları', 'Rahmet Yolları Kesti'],
    'Yaşar Kemal': ['İnce Memed', 'Yer Demir Gök Bakır', 'Orta Direk', 'Ölmez Otu', 'Teneke', 'Demirciler Çarşısı Cinayeti'],
    'Orhan Kemal': ['Bereketli Topraklar Üzerinde', 'Murtaza', 'Cemile', 'Baba Evi', 'Avare Yıllar', 'Gurbet Kuşları'],
    'Tarık Buğra': ['Küçük Ağa', 'Osmancık', 'İbiş\'in Rüyası', 'Firavun İmanı', 'Yağmur Beklerken'],
    'Oğuz Atay': ['Tutunamayanlar', 'Tehlikeli Oyunlar', 'Bir Bilim Adamının Romanı', 'Korkuyu Beklerken'],
    'Yusuf Atılgan': ['Anayurt Oteli', 'Aylak Adam', 'Canistan'],
    'Orhan Veli Kanık': ['Garip', 'Vazgeçemediğim', 'Destan Gibi', 'Karşı'],
    'Oktay Rifat': ['Perçemli Sokak', 'Aşağı Yukarı'],
    'Melih Cevdet Anday': ['Rahatı Kaçan Ağaç', 'Kolları Bağlı Odysseus', 'Telgrafhane'],
    'Cemal Süreya': ['Üvercinka', 'Göçebe', 'Sevda Sözleri', 'Beni Öp Sonra Doğur Beni'],
    'Edip Cansever': ['Yerçekimli Karanfil', 'Masa da Masaymış Ha', 'Tragedyalar'],
    'Turgut Uyar': ['Göğe Bakma Durağı', 'Dünyanın En Güzel Arabistanı', 'Tütünler Islak'],
    'Ece Ayhan': ['Kınar Hanımın Denizleri', 'Bakışsız Bir Kedi Kara', 'Yort Savul'],
    'Sezai Karakoç': ['Körfez', 'Şahdamar', 'Hızırla Kırk Saat'],
    'Attila İlhan': ['Duvar', 'Sisler Bulvarı', 'Yağmur Kaçağı', 'Ben Sana Mecburum'],
    'Cahit Sıtkı Tarancı': ['Ömrümde Sükût', 'Düşten Güzel'],
    'Ziya Osman Saba': ['Sebil ve Güvercinler', 'Geçen Zaman', 'Nefes Almak'],
    'Arif Nihat Asya': ['Dualar ve Aminler', 'Bir Bayrak Rüzgâr Bekliyor'],
    'Behçet Necatigil': ['Evler', 'Kapalıçarşı', 'Çevre', 'Eski Toprak'],
    'Fazıl Hüsnü Dağlarca': ['Havaya Çizilen Dünya', 'Çocuk ve Allah', 'Toprak Ana', 'Çakırın Destanı'],
    'Aziz Nesin': ['Zübük', 'Yaşar Ne Yaşar Ne Yaşamaz', 'Gol Kralı', 'Şimdiki Çocuklar Harika'],
    'Haldun Taner': ['Keşanlı Ali Destanı', 'Gözlerimi Kaparım Vazifemi Yaparım', 'On İkiye Bir Var'],
    'Necati Cumalı': ['Susuz Yaz', 'Boş Beşik', 'Tütün Zamanı'],
    'Adalet Ağaoğlu': ['Ölmeye Yatmak', 'Fikrimin İnce Gülü', 'Bir Düğün Gecesi'],
    'Falih Rıfkı Atay': ['Zeytindağı', 'Çankaya', 'Deniz Aşırı'],
    'Halikarnas Balıkçısı': ['Aganta Burina Burinata', 'Deniz Gurbetçileri', 'Ötelerin Çocuğu', 'Merhaba Akdeniz'],
    'Fakir Baykurt': ['Yılanların Öcü', 'Irazca\'nın Dirliği', 'Tırpan'],
    'Nurullah Ataç': ['Günlerin Getirdiği', 'Karalama Defteri', 'Söz Arasında'],
    'Fuzuli': ['Leyla ile Mecnun', 'Su Kasidesi', 'Şikâyetname', 'Hadikatü\'s-Süeda', 'Beng ü Bade'],
    'Şeyh Galip': ['Hüsn ü Aşk'],
    'Nabi': ['Hayriyye', 'Hayrabad'],
    'Nefi': ['Siham-ı Kaza'],
    'Evliya Çelebi': ['Seyahatname'],
    'Katip Çelebi': ['Keşfü\'z-Zünun', 'Cihannüma', 'Mizanü\'l-Hak'],
    'Ali Şir Nevai': ['Muhakemetü\'l-Lugateyn', 'Mecalisü\'n-Nefais'],
    'Süleyman Çelebi': ['Vesiletü\'n-Necat (Mevlid)'],
    'Ahmedi': ['İskendername'],
    'Sinan Paşa': ['Tazarruname'],
    'Aşık Paşa': ['Garipname'],
    'Yunus Emre': ['Risaletü\'n-Nushiyye'],
    'Ahmet Yesevi': ['Divan-ı Hikmet'],
    'Şeyhi': ['Harname', 'Hüsrev ü Şirin'],
    'Kaygusuz Abdal': ['Budalaname'],
    'Âşık Veysel': ['Dostlar Beni Hatırlasın', 'Sazımdan Sesler'],
}
WORK_REL = [(w, a) for a, ws in WORKS.items() for w in ws]

PERIOD = {
    'Tanzimat edebiyatı': ['Şinasi', 'Namık Kemal', 'Ziya Paşa', 'Ahmet Mithat Efendi', 'Recaizade Mahmut Ekrem',
                           'Abdülhak Hamit Tarhan', 'Şemsettin Sami', 'Samipaşazade Sezai', 'Nabizade Nazım', 'Muallim Naci'],
    'Servet-i Fünun edebiyatı': ['Tevfik Fikret', 'Halit Ziya Uşaklıgil', 'Mehmet Rauf', 'Cenap Şahabettin', 'Hüseyin Cahit Yalçın', 'Süleyman Nazif'],
    'Fecr-i Âti topluluğu': ['Ahmet Haşim', 'Emin Bülent Serdaroğlu', 'Şahabettin Süleyman', 'Tahsin Nahit', 'Ahmet Samim'],
    'Millî Edebiyat': ['Ömer Seyfettin', 'Ziya Gökalp', 'Mehmet Emin Yurdakul', 'Ali Canip Yöntem'],
    'Beş Hececiler': ['Faruk Nafiz Çamlıbel', 'Halit Fahri Ozansoy', 'Enis Behiç Koryürek', 'Orhan Seyfi Orhon', 'Yusuf Ziya Ortaç'],
    'Yedi Meşaleciler': ['Sabri Esat Siyavuşgil', 'Ziya Osman Saba', 'Yaşar Nabi Nayır', 'Cevdet Kudret', 'Muammer Lütfi', 'Vasfi Mahir Kocatürk', 'Kenan Hulusi Koray'],
    'Garip akımı': ['Orhan Veli Kanık', 'Oktay Rifat', 'Melih Cevdet Anday'],
    'İkinci Yeni': ['Cemal Süreya', 'Edip Cansever', 'Turgut Uyar', 'İlhan Berk', 'Ece Ayhan', 'Sezai Karakoç'],
    'Divan edebiyatı': ['Fuzuli', 'Baki', 'Nefi', 'Nedim', 'Şeyh Galip', 'Nabi'],
    'Âşık edebiyatı': ['Karacaoğlan', 'Pir Sultan Abdal', 'Köroğlu', 'Dadaloğlu', 'Erzurumlu Emrah', 'Âşık Ömer'],
    'Tekke (dinî-tasavvufi) edebiyatı': ['Yunus Emre', 'Ahmet Yesevi', 'Kaygusuz Abdal', 'Eşrefoğlu Rumi', 'Niyazi Mısri'],
}
PERIOD_REL = [(a, p) for p, aa in PERIOD.items() for a in aa]

FORMS = {
    'Divan edebiyatı': ['Gazel', 'Kaside', 'Mesnevi', 'Rubai', 'Tuyuğ', 'Murabba', 'Şarkı', 'Terkib-i bent', 'Terci-i bent', 'Muhammes', 'Kıta'],
    'Âşık edebiyatı': ['Koşma', 'Semai', 'Varsağı', 'Destan (âşık tarzı)', 'Güzelleme', 'Koçaklama', 'Taşlama'],
    'Anonim halk edebiyatı': ['Mani', 'Türkü', 'Ninni', 'Ağıt', 'Bilmece', 'Tekerleme'],
}
FORM_REL = [(f, g) for g, ff in FORMS.items() for f in ff]

FORM_DEF = {
    'Gazel': 'Genellikle 5-15 beyitten oluşan, aa ba ca biçiminde kafiyelenen, aşk ve şarap konulu divan şiiri',
    'Kaside': 'Bir büyüğü övmek için yazılan; nesib, girizgâh, methiye, fahriye ve dua bölümleri bulunan uzun divan şiiri',
    'Mesnevi': 'Her beyti kendi içinde kafiyeli (aa bb cc) olan, uzun konuların anlatıldığı nazım biçimi',
    'Rubai': 'Aruzun özel kalıplarıyla yazılan, aaxa kafiyeli, dört dizelik felsefi şiir',
    'Tuyuğ': 'Aruzun "fâilâtün fâilâtün fâilün" kalıbıyla yazılan, Türklere özgü dört dizelik nazım biçimi',
    'Koşma': 'Âşık edebiyatında 11\'li hece ölçüsüyle yazılan, lirik konulu nazım biçimi',
    'Mani': 'Genellikle 7\'li hece ölçüsüyle söylenen, aaxa kafiyeli, dört dizelik anonim şiir',
    'Varsağı': 'Hece ölçüsünün 8\'li kalıbıyla yazılan, "bre, hey" gibi ünlemlerle söylenen yiğitçe âşık şiiri',
    'Semai': 'Hece ölçüsünün 8\'li kalıbıyla yazılan, kendine özgü ezgisi olan âşık şiiri',
    'Şarkı': 'Bestelenmek için yazılan, nakarat dizesi bulunan, genellikle dört bentlik divan şiiri',
    'Terkib-i bent': 'Bentleri birbirine bağlayan vasıta beyitlerinin her bentte farklı olduğu divan şiiri',
    'Terci-i bent': 'Bentleri bağlayan vasıta beytinin her bentte aynen tekrarlandığı divan şiiri',
    'Destan (âşık tarzı)': 'Savaş, kıtlık, deprem gibi toplumu etkileyen olayları anlatan uzun âşık şiiri',
    'Taşlama': 'Kişileri ya da toplumdaki aksaklıkları eleştiren, alaycı âşık şiiri',
    'Ağıt': 'Ölen bir kişinin ardından duyulan acıyı dile getiren anonim şiir',
}

ARTS = {
    'Teşbih': 'Aralarında benzerlik bulunan iki varlıktan zayıfı güçlüye benzetme',
    'İstiare': 'Benzetmenin temel ögelerinden yalnızca biriyle yapılan benzetme',
    'Mecaz-ı mürsel': 'Benzetme amacı gütmeden bir sözü başka bir söz yerine kullanma (ad aktarması)',
    'Teşhis': 'İnsan dışındaki varlıklara insana ait özellikler verme (kişileştirme)',
    'İntak': 'İnsan dışındaki varlıkları konuşturma',
    'Tezat': 'Birbirine karşıt kavram ya da düşünceleri bir arada kullanma',
    'Mübalağa': 'Bir durumu olduğundan çok büyük ya da çok küçük gösterme',
    'Tecahül-i arif': 'Bilinen bir gerçeği, söze incelik katmak için bilmezlikten gelme',
    'Hüsn-i talil': 'Bir olayı gerçek nedeni dışında güzel bir nedene bağlama',
    'Telmih': 'Herkesçe bilinen bir olaya, kişiye ya da hikâyeye gönderme yapma',
    'İrsal-i mesel': 'Bir düşünceyi kanıtlamak için atasözü ya da özdeyiş kullanma',
    'Tenasüp': 'Aralarında anlam ilgisi bulunan sözcükleri bir arada kullanma',
    'Kinaye': 'Bir sözü hem gerçek hem mecaz anlamını düşündürecek biçimde kullanıp mecaz anlamı kastetme',
    'Tevriye': 'Birden çok anlamı olan bir sözcüğü, yakın anlamını düşündürüp uzak anlamını kastederek kullanma',
    'Cinas': 'Yazılışı ve okunuşu aynı, anlamı farklı sözcükleri bir arada kullanma',
    'Aliterasyon': 'Dizelerde aynı ünsüzü tekrarlayarak ahenk sağlama',
    'Asonans': 'Dizelerde aynı ünlüyü tekrarlayarak ahenk sağlama',
    'Leff ü neşr': 'Önce birkaç sözcük sayıp sonra bunlarla ilgili sözcükleri sırayla ya da karışık söyleme',
    'İstifham': 'Duyguyu güçlendirmek için soru sorma',
    'Nida': 'Coşkun bir duyguyu seslenme ya da ünlemle anlatma',
}

GENRES = {
    'Deneme': 'Yazarın herhangi bir konudaki kişisel düşüncelerini kesin yargıya varmadan, samimi bir dille anlattığı yazı',
    'Makale': 'Bir düşünceyi kanıtlamak amacıyla bilgi ve belgelere dayanarak yazılan yazı',
    'Fıkra (gazete)': 'Gazete ya da dergide güncel bir konunun kısa ve yorum katılarak işlendiği köşe yazısı',
    'Sohbet (söyleşi)': 'Bir konunun okurla karşılıklı konuşuyormuş gibi, samimi bir dille anlatıldığı yazı',
    'Eleştiri': 'Bir eserin olumlu ve olumsuz yönlerini değerlendiren yazı',
    'Anı (hatıra)': 'Yazarın yaşadığı ya da tanık olduğu olayları aradan zaman geçtikten sonra anlattığı yazı',
    'Gezi yazısı': 'Gezilip görülen yerlerin ilgi çekici özelliklerinin anlatıldığı yazı',
    'Biyografi': 'Bir kişinin hayatının ve eserlerinin başkası tarafından anlatıldığı yazı',
    'Otobiyografi': 'Bir kişinin kendi hayatını anlattığı yazı',
    'Günlük': 'Yazarın yaşadıklarını tarih düşerek gün gün yazdığı metin',
    'Röportaj': 'Bir kişiyle ya da bir yerde inceleme yapılarak görüşmelere dayanan, yorum katılan yazı',
    'Mülakat': 'Tanınmış bir kişiyle soru-cevap biçiminde yapılan görüşmenin yazıya geçirilmesi',
}

MOVEMENTS = [
    ('Racine', 'Klasisizm'), ('Corneille', 'Klasisizm'), ('Molière', 'Klasisizm'), ('La Fontaine', 'Klasisizm'), ('Boileau', 'Klasisizm'),
    ('Victor Hugo', 'Romantizm'), ('Lamartine', 'Romantizm'), ('Lord Byron', 'Romantizm'), ('Alfred de Musset', 'Romantizm'),
    ('Balzac', 'Realizm'), ('Flaubert', 'Realizm'), ('Stendhal', 'Realizm'), ('Dostoyevski', 'Realizm'), ('Tolstoy', 'Realizm'),
    ('Emile Zola', 'Natüralizm'), ('Goncourt Kardeşler', 'Natüralizm'),
    ('Leconte de Lisle', 'Parnasizm'), ('Théophile Gautier', 'Parnasizm'), ('José-Maria de Heredia', 'Parnasizm'), ('Sully Prudhomme', 'Parnasizm'),
    ('Baudelaire', 'Sembolizm'), ('Mallarmé', 'Sembolizm'), ('Verlaine', 'Sembolizm'), ('Rimbaud', 'Sembolizm'), ('Paul Valéry', 'Sembolizm'),
]

FIRSTS = [
    ('Türk edebiyatında ilk yerli roman kabul edilen eser hangisidir?', 'Taaşşuk-ı Talat ve Fitnat', ['İntibah', 'Araba Sevdası', 'Sergüzeşt', 'Karabibik', 'Telemak']),
    ('Türk edebiyatında Batılı anlamdaki ilk tiyatro eseri hangisidir?', 'Şair Evlenmesi', ['Vatan yahut Silistre', 'Zavallı Çocuk', 'Akif Bey', 'Finten', 'Eşber']),
    ('Türk edebiyatında ilk edebî roman kabul edilen eser hangisidir?', 'İntibah', ['Taaşşuk-ı Talat ve Fitnat', 'Eylül', 'Mai ve Siyah', 'Sergüzeşt', 'Telemak']),
    ('Türk edebiyatında ilk realist roman hangisidir?', 'Araba Sevdası', ['İntibah', 'Eylül', 'Karabibik', 'Cezmi', 'Zehra']),
    ('Türk edebiyatında ilk psikolojik roman hangisidir?', 'Eylül', ['Araba Sevdası', 'Mai ve Siyah', 'Zehra', 'Sergüzeşt', 'İntibah']),
    ('Türk edebiyatında ilk köy romanı (uzun hikâyesi) kabul edilen eser hangisidir?', 'Karabibik', ['Yaban', 'Bizim Köy', 'Çalıkuşu', 'Toprak Kokusu', 'Zehra']),
    ('Türk edebiyatında ilk tarihî roman hangisidir?', 'Cezmi', ['İntibah', 'Küçük Ağa', 'Osmancık', 'Sergüzeşt', 'Akif Bey']),
    ('Türk edebiyatında ilk çeviri roman hangisidir?', 'Telemak', ['Sefiller', 'Monte Kristo', 'Robinson', 'Atala', 'Taaşşuk-ı Talat ve Fitnat']),
    ('Türk edebiyatında ilk çeviri şiir kitabı hangisidir?', 'Tercüme-i Manzume', ['Müntehabat-ı Eş\'ar', 'Harabat', 'Zemzeme', 'Makber', 'Sahra']),
    ('Türk edebiyatında ilk özel gazete hangisidir?', 'Tercüman-ı Ahval', ['Takvim-i Vekayi', 'Ceride-i Havadis', 'Tasvir-i Efkâr', 'Servet-i Fünun', 'Muhbir']),
    ('Türk edebiyatında ilk resmî gazete hangisidir?', 'Takvim-i Vekayi', ['Tercüman-ı Ahval', 'Ceride-i Havadis', 'Tasvir-i Efkâr', 'Muhbir', 'Hürriyet']),
    ('Pastoral şiirin ilk örneği kabul edilen eser hangisidir?', 'Sahra', ['Makber', 'Çoban Çeşmesi', 'Harabat', 'Zemzeme', 'Göl Saatleri']),
    ('Türk edebiyatında ilk antoloji kabul edilen eser hangisidir?', 'Harabat', ['Tercüme-i Manzume', 'Kamus-ı Türki', 'Talim-i Edebiyat', 'Zemzeme', 'Divan-ı Hikmet']),
    ('Batılı anlamda ilk hikâye örneği kabul edilen eser hangisidir?', 'Letaif-i Rivayat', ['Küçük Şeyler', 'Memleket Hikâyeleri', 'Semaver', 'Bomba', 'Kaşağı']),
    ('Türk edebiyatında Batılı anlamda ilk modern hikâyeler sayılan eser hangisidir?', 'Küçük Şeyler', ['Letaif-i Rivayat', 'Semaver', 'Kaşağı', 'Sarnıç', 'Memleket Hikâyeleri']),
    ('İstiklal Marşı\'nın şairi kimdir?', 'Mehmet Akif Ersoy', ['Yahya Kemal Beyatlı', 'Ziya Gökalp', 'Mehmet Emin Yurdakul', 'Faruk Nafiz Çamlıbel', 'Namık Kemal']),
    ('"Vatan şairi" olarak anılan Tanzimat sanatçısı kimdir?', 'Namık Kemal', ['Şinasi', 'Ziya Paşa', 'Tevfik Fikret', 'Mehmet Emin Yurdakul', 'Abdülhak Hamit Tarhan']),
    ('"Şair-i Azam" olarak anılan sanatçı kimdir?', 'Abdülhak Hamit Tarhan', ['Namık Kemal', 'Tevfik Fikret', 'Yahya Kemal Beyatlı', 'Ziya Paşa', 'Muallim Naci']),
    ('"Sultanü\'ş-şuara" (şairler sultanı) olarak anılan divan şairi kimdir?', 'Baki', ['Fuzuli', 'Nefi', 'Nedim', 'Şeyh Galip', 'Nabi']),
]

# Hece sayısı soruları: özgün dize parçaları, hece = ünlü sayısı.
LEFT = ['Uzak köylerin yolunda', 'Sessiz bir akşam vakti', 'Dağların ardında güneş', 'Bir kuş kanat çırptı',
        'Gece yarısı pencerede', 'Ilık bir rüzgâr eser', 'Eski bir türkü dilimde', 'Çınarın gölgesinde',
        'Yağmur yağar yine', 'Deniz mavisi gözler', 'Yaslı bir kavak başında', 'İnce bir yol uzanır',
        'Bahar gelince bahçede', 'Kar yağar dağ başına', 'Bir çoban kaval çalar', 'Köprünün altında su',
        'Akşam olur birden', 'Ayrılık vakti geldi', 'Hasret yanar içimde', 'Gönlüm bir kuş gibi']
RIGHT = ['bekler beni annem', 'bir türkü söyler rüzgâr', 'yanar sabaha kadar', 'çiçekler açar',
         'ağlar gözlerim', 'geçer ömür sessizce', 'gelir aklıma yâr', 'susar bütün sokaklar',
         'uyur köyüm', 'dolar içime sevinç', 'yol alır kervan', 'akar gider dereler',
         'bir ses duyulur', 'söner son ışık', 'kalbim çarpar', 'beklerim seni']
VOWELS = 'aeıioöuüâîû'


def hece(s):
    return sum(1 for c in s.lower() if c in VOWELS)


@stem_limit(1)
def hece_sayisi(r):
    line = f'{r.choice(LEFT)} {r.choice(RIGHT)}'
    n = hece(line)
    return make(r, 'Şiir bilgisi (ölçü)', f'"{line}" dizesi kaç hecelidir?', n, [n - 1, n + 1, n - 2, n + 2, n + 3],
                f'Hece sayısı ünlü sayısına eşittir: {n}.')


@stem_limit(40)
def hece_secim(r):
    target = r.choice([11, 12, 13, 14])
    lines = {}
    for _ in range(400):
        line = f'{r.choice(LEFT)} {r.choice(RIGHT)}'
        lines.setdefault(hece(line), []).append(line)
    if target not in lines:
        return None
    right = r.choice(lines[target])
    others = [r.choice(v) for k, v in lines.items() if k != target]
    if len(others) < 4:
        return None
    r.shuffle(others)
    return make(r, 'Şiir bilgisi (ölçü)', f'Aşağıdaki dizelerden hangisi {target}\'li hece ölçüsüyle yazılmıştır?'.replace("11'li", "11'li").replace("12'li", "12'li").replace("13'li", "13'lü").replace("14'li", "14'lü"),
                right, others, f'"{right}": {target} hece.')


GENERATORS = relation_gens(
    'Yazar ve eser', WORK_REL,
    fwd='"{item}" adlı eser kime aittir?',
    has='Aşağıdaki eserlerden hangisi {group} tarafından yazılmıştır?',
    has_not='Aşağıdaki eserlerden hangisi {group} tarafından yazılmamıştır?',
    weights=(5, 3, 3), has_limit=3, has_not_limit=6,
    explain=lambda w, a: f'"{w}": {a}.',
) + relation_gens(
    'Edebî dönemler', PERIOD_REL,
    fwd='{item} hangi edebî dönem ya da topluluk içinde yer alır?',
    has='Aşağıdaki sanatçılardan hangisi {group} içinde yer alır?',
    has_not='Aşağıdaki sanatçılardan hangisi {group} içinde yer almaz?',
    weights=(3, 2, 3), has_limit=3, has_not_limit=8,
) + relation_gens(
    'Nazım biçimleri', FORM_REL,
    fwd='{item} hangi edebiyat geleneğine ait bir türdür?',
    has='Aşağıdakilerden hangisi {group} türlerinden biridir?',
    has_not='Aşağıdakilerden hangisi {group} türlerinden biri değildir?',
    weights=(1, 1, 2), has_limit=3, has_not_limit=10, extra_groups=['Tekke edebiyatı', 'Cumhuriyet dönemi serbest şiiri'],
) + define_gens('Nazım biçimleri', FORM_DEF, fwd='{k} nazım biçiminin özelliği aşağıdakilerden hangisidir?',
                back='"{v}" tanımı hangi nazım biçimine aittir?') \
  + define_gens('Söz sanatları', ARTS, fwd='"{k}" söz sanatının tanımı aşağıdakilerden hangisidir?',
                back='"{v}" hangi söz sanatıdır?', weights=(2, 2)) \
  + define_gens('Düzyazı türleri', GENRES, fwd='"{k}" türünün tanımı aşağıdakilerden hangisidir?',
                back='"{v}" hangi türün tanımıdır?') \
  + relation_gens('Edebî akımlar', MOVEMENTS, fwd='{item} hangi edebî akımın temsilcisidir?',
                  has='Aşağıdaki sanatçılardan hangisi {group} akımının temsilcisidir?',
                  has_not='Aşağıdaki sanatçılardan hangisi {group} akımının temsilcisi değildir?',
                  weights=(2, 1, 1), has_limit=3, has_not_limit=6) \
  + [(fact_gen('Edebiyatımızda ilkler', FIRSTS), 2), (hece_sayisi, 3), (hece_secim, 1)]
