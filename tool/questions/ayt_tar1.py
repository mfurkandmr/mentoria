"""AYT Tarih-1: İslam tarihi, Türk-İslam devletleri, Osmanlı (kuruluştan
dağılmaya) ve Avrupa; kronoloji soruları yıllardan hesaplanır."""
from common import chrono_gens, define_gens, relation_gens

T = 'AYT_TAR1'

EVENTS = [
    ('Hicret', 622), ('Bedir Savaşı', 624), ('Uhud Savaşı', 625), ('Hendek Savaşı', 627), ('Hudeybiye Antlaşması', 628),
    ('Mekke\'nin fethi', 630), ('Kadisiye Savaşı', 636), ('Kerbela Olayı', 680), ('Abbasi Devleti\'nin kurulması', 750),
    ('Magna Carta\'nın imzalanması', 1215), ('Ümit Burnu\'nun dolaşılması', 1488), ('Amerika\'nın keşfi', 1492),
    ('Hindistan deniz yolunun bulunması', 1498), ('Reform hareketinin başlaması (Luther)', 1517), ('Haçova Savaşı', 1596),
    ('Zitvatorok Antlaşması', 1606), ('Westphalia Barışı', 1648), ('Kandiye\'nin fethi', 1669), ('Bucaş Antlaşması', 1672),
    ('Prut Savaşı', 1711), ('İbrahim Müteferrika matbaasının kurulması', 1727), ('Çeşme Baskını', 1770),
    ('Amerikan Bağımsızlık Bildirgesi', 1776), ('Kırım\'ın Rusya\'ya katılması', 1783), ('Fransız İhtilali', 1789),
    ('Ziştovi Antlaşması', 1791), ('Yaş Antlaşması', 1792), ('Nizam-ı Cedit ordusunun kurulması', 1793),
    ('Napolyon\'un Mısır Seferi', 1798), ('Sırp İsyanı\'nın başlaması', 1804), ('Bükreş Antlaşması', 1812),
    ('Viyana Kongresi', 1815), ('Mora İsyanı\'nın başlaması', 1821), ('Navarin Baskını', 1827), ('Edirne Antlaşması', 1829),
    ('Takvim-i Vekayi\'nin yayımlanması', 1831), ('Hünkâr İskelesi Antlaşması', 1833), ('Mekteb-i Harbiye\'nin açılması', 1834),
    ('Balta Limanı Ticaret Antlaşması', 1838), ('Londra Boğazlar Sözleşmesi', 1841), ('Kırım Savaşı\'nın başlaması', 1853),
    ('Paris Antlaşması', 1856), ('Ayastefanos Antlaşması', 1878), ('Duyun-ı Umumiye\'nin kurulması', 1881),
    ('Mısır\'ın İngiltere tarafından işgali', 1882), ('Osmanlı-Yunan (Dömeke) Savaşı', 1897), ('31 Mart Vakası', 1909),
    ('Uşi Antlaşması', 1912), ('Bab-ı Âli Baskını', 1913),
]

RULERS = [
    ('Edirne\'nin fethi', 'I. Murad'), ('I. Kosova Savaşı', 'I. Murad'),
    ('Anadolu Hisarı\'nın yapılması', 'I. Bayezid (Yıldırım)'), ('Niğbolu Savaşı', 'I. Bayezid (Yıldırım)'),
    ('Rumeli Hisarı\'nın yapılması', 'II. Mehmet (Fatih)'), ('Kanunname-i Âl-i Osman\'ın hazırlanması', 'II. Mehmet (Fatih)'),
    ('Mısır\'ın fethi', 'I. Selim (Yavuz)'), ('Halifeliğin Osmanlı\'ya geçmesi', 'I. Selim (Yavuz)'),
    ('Belgrad\'ın fethi', 'I. Süleyman (Kanuni)'), ('Rodos\'un fethi', 'I. Süleyman (Kanuni)'), ('Preveze Deniz Savaşı', 'I. Süleyman (Kanuni)'),
    ('Kıbrıs\'ın fethi', 'II. Selim'), ('Haçova Savaşı', 'III. Mehmet'), ('Zitvatorok Antlaşması', 'I. Ahmet'),
    ('Yeniçerilerce öldürülen ilk padişah olması', 'II. Osman'), ('Bağdat\'ın geri alınması (1638)', 'IV. Murat'),
    ('Kandiye\'nin fethi', 'IV. Mehmet'), ('Lale Devri', 'III. Ahmet'), ('İlk matbaanın kurulması', 'III. Ahmet'),
    ('Prut Savaşı', 'III. Ahmet'), ('Nizam-ı Cedit ordusunun kurulması', 'III. Selim'),
    ('Balta Limanı Ticaret Antlaşması', 'II. Mahmut'), ('Takvim-i Vekayi\'nin çıkarılması', 'II. Mahmut'),
    ('Islahat Fermanı\'nın ilanı', 'Abdülmecit'), ('Duyun-ı Umumiye\'nin kurulması', 'II. Abdülhamit'),
    ('31 Mart Vakası', 'II. Abdülhamit'), ('Trablusgarp Savaşı', 'V. Mehmet Reşat'), ('Bab-ı Âli Baskını', 'V. Mehmet Reşat'),
    ('Osmanlı\'nın I. Dünya Savaşı\'na girmesi', 'V. Mehmet Reşat'), ('Mondros Ateşkes Antlaşması', 'Vahdettin'),
]

STATES = [
    ('İlk Müslüman Türk devleti olması', 'Karahanlılar'), ('Kutadgu Bilig\'in yazıldığı devlet olması', 'Karahanlılar'),
    ('Türkçeyi resmî dil olarak kullanan ilk Müslüman Türk devleti olması', 'Karahanlılar'), ('Satuk Buğra Han\'ın Müslüman olması', 'Karahanlılar'),
    ('Hindistan\'a 17 sefer düzenlenmesi', 'Gazneliler'), ('"Sultan" unvanını ilk kullanan Türk hükümdarının (Mahmut) devleti olması', 'Gazneliler'),
    ('Dandanakan Savaşı\'nda yenilmesi', 'Gazneliler'), ('Şehname\'nin bu devletin sultanına sunulması', 'Gazneliler'),
    ('Nizamiye Medreselerinin açılması', 'Büyük Selçuklu Devleti'), ('Malazgirt Savaşı\'nı kazanması', 'Büyük Selçuklu Devleti'),
    ('Katvan Savaşı\'nda Karahitaylara yenilmesi', 'Büyük Selçuklu Devleti'), ('Siyasetname\'nin vezir Nizamülmülk tarafından yazılması', 'Büyük Selçuklu Devleti'),
    ('Miryokefalon Savaşı\'nı kazanması', 'Türkiye Selçuklu Devleti'), ('Kösedağ Savaşı\'nda Moğollara yenilmesi', 'Türkiye Selçuklu Devleti'),
    ('Antalya ve Sinop\'un fethedilmesi', 'Türkiye Selçuklu Devleti'), ('Alaeddin Keykubat döneminde en parlak çağını yaşaması', 'Türkiye Selçuklu Devleti'),
    ('Ayn Calut Savaşı\'nda Moğolları durdurması', 'Memlükler'), ('Ridaniye Savaşı\'nda Osmanlı\'ya yenilmesi', 'Memlükler'),
    ('Mısır\'da kurulan ilk Türk devleti olması', 'Tolunoğulları'), ('Mısır ve Suriye\'ye hâkim olan, Tolunoğullarından sonra kurulan Türk devleti olması', 'İhşidiler'),
]

TERMS = {
    'Tımar': 'Toprak gelirinin asker yetiştirme karşılığında devlet görevlilerine bırakıldığı sistem',
    'İltizam': 'Bir bölgenin vergisini toplama hakkının açık artırmayla belirli süreliğine satılması',
    'Malikane': 'Vergi toplama hakkının peşin para karşılığında ömür boyu verilmesi',
    'Esham': 'Devletin halktan borçlanmak için çıkardığı, faiz getiren hisse senedi benzeri belge',
    'Müsadere': 'Ölen ya da görevden alınan devlet görevlisinin servetine devletçe el konulması',
    'Devşirme': 'Hristiyan ailelerin çocuklarının toplanıp eğitilerek devlet hizmetine alınması',
    'Lonca': 'Esnaf ve sanatkârların üretimi, kaliteyi ve fiyatı denetleyen meslek örgütü',
    'Ahilik': 'Esnafa hem meslek hem ahlak eğitimi veren, Anadolu Selçukluları döneminde güçlenen teşkilat',
    'Gedik': 'Bir esnafın dükkân açma ve meslek icra etme hakkı',
    'Vakıf': 'Bir malın gelirinin sürekli olarak bir hayır işine ayrılması',
    'Kapıkulu': 'Devşirmelerden oluşan, merkezde bulunan ve maaşla çalışan sürekli ordu',
    'Örfi hukuk': 'Padişah fermanlarına ve geleneklere dayanan hukuk',
    'Cülus bahşişi': 'Yeni padişahın tahta çıkışında kapıkulu askerlerine verilen para',
    'Kafes usulü': 'Şehzadelerin sancağa gönderilmeyip sarayda yetiştirilmesi',
    'Ekber ve erşed': 'Hanedanın en yaşlı ve akıllı üyesinin tahta geçmesi ilkesi',
    'Kapitülasyon': 'Yabancı devletlere tanınan ticari, hukuki ve mali ayrıcalıklar',
    'Meşrutiyet': 'Padişahın yanında halkın seçtiği meclisin de yönetime katıldığı yönetim biçimi',
    'Mukataa': 'Gelirleri belirli bir bedel karşılığında işletilmek üzere ayrılan devlet kaynağı',
    'Sened-i İttifak': 'Ayanların gücünü tanıyan, padişahın yetkisini ilk kez sınırlayan belge',
    'Ayan': 'Yerel halk ile devlet arasında aracılık yapan, sonradan güçlenen bölgesel eşraf',
}

DIVAN = {
    'Sadrazam (veziriazam)': 'Padişahın mutlak vekili; Divan\'a padişah adına başkanlık eder',
    'Kazasker': 'Adalet ve eğitim işlerine, kadı ve müderris atamalarına bakar',
    'Defterdar': 'Devletin mali işlerinden, gelir ve giderlerinden sorumludur',
    'Nişancı': 'Fermanlara tuğra çeker, tapu ve tahrir kayıtlarını tutar',
    'Kaptan-ı Derya': 'Donanmanın komutanıdır',
    'Şeyhülislam': 'Dinî konularda fetva verir',
    'Reisülküttap': 'Dış yazışmaları yürütür; dışişleri görevini üstlenir',
}


GENERATORS = chrono_gens('Kronoloji', EVENTS, limit=50) \
    + relation_gens('Osmanlı padişahları', RULERS, fwd='{item} hangi padişah döneminde gerçekleşmiştir?',
                    has='Aşağıdakilerden hangisi {group} döneminde gerçekleşmiştir?', weights=(3, 2, 0), has_limit=3,
                    extra_groups=['II. Murad', 'Orhan Bey', 'IV. Mustafa', 'Abdülaziz']) \
    + relation_gens('Türk-İslam devletleri', STATES, fwd='"{item}" özelliği hangi devlete aittir?',
                    has='Aşağıdakilerden hangisi {group} ile ilgili bir gelişmedir?',
                    has_not='Aşağıdakilerden hangisi {group} ile ilgili bir gelişme değildir?', weights=(3, 2, 2), has_limit=4,
                    extra_groups=['Harzemşahlar', 'Eyyubiler']) \
    + define_gens('Osmanlı kurumları', TERMS, fwd='"{k}" kavramı aşağıdakilerden hangisini ifade eder?',
                  back='"{v}" hangi kavramla ifade edilir?', weights=(3, 3)) \
    + define_gens('Divan-ı Hümayun', DIVAN, fwd='Divan-ı Hümayun\'da {k} hangi görevi üstlenir?',
                  back='Divan-ı Hümayun\'da "{v}" görevini kim üstlenir?')
