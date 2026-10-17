"""TYT Tarih: olay-yıl-hükümdar tablosu; kronoloji soruları hesaplanır."""
from common import make, num_distractors, stem_limit

T = 'TYT_TAR'

# (olay, yıl)
EVENTS = [
    ('Kavimler Göçü\'nün başlaması', 375), ('Göktürk Devleti\'nin kurulması', 552),
    ('Uygur Devleti\'nin kurulması', 744), ('Talas Savaşı', 751), ('Dandanakan Savaşı', 1040),
    ('Pasinler Savaşı', 1048), ('Malazgirt Savaşı', 1071), ('Türkiye Selçuklu Devleti\'nin kurulması', 1075),
    ('I. Haçlı Seferi\'nin başlaması', 1096), ('Miryokefalon Savaşı', 1176), ('Kösedağ Savaşı', 1243),
    ('Osmanlı Devleti\'nin kurulması', 1299), ('Koyunhisar (Bafeus) Savaşı', 1302), ('Bursa\'nın fethi', 1326),
    ('I. Kosova Savaşı', 1389), ('Niğbolu Savaşı', 1396), ('Ankara Savaşı', 1402), ('Varna Savaşı', 1444),
    ('II. Kosova Savaşı', 1448), ('İstanbul\'un fethi', 1453), ('Otlukbeli Savaşı', 1473),
    ('Çaldıran Savaşı', 1514), ('Mercidabık Savaşı', 1516), ('Ridaniye Savaşı', 1517), ('Mohaç Meydan Savaşı', 1526),
    ('I. Viyana Kuşatması', 1529), ('Preveze Deniz Savaşı', 1538), ('İnebahtı Deniz Savaşı', 1571),
    ('Kasr-ı Şirin Antlaşması', 1639), ('II. Viyana Kuşatması', 1683), ('Karlofça Antlaşması', 1699),
    ('Pasarofça Antlaşması', 1718), ('Patrona Halil İsyanı', 1730), ('Belgrad Antlaşması', 1739),
    ('Küçük Kaynarca Antlaşması', 1774), ('Sened-i İttifak\'ın imzalanması', 1808),
    ('Yeniçeri Ocağı\'nın kaldırılması', 1826), ('Tanzimat Fermanı\'nın ilanı', 1839),
    ('Islahat Fermanı\'nın ilanı', 1856), ('I. Meşrutiyet\'in ilanı', 1876), ('93 Harbi\'nin başlaması', 1877),
    ('Berlin Antlaşması', 1878), ('II. Meşrutiyet\'in ilanı', 1908), ('Trablusgarp Savaşı\'nın başlaması', 1911),
    ('I. Balkan Savaşı\'nın başlaması', 1912), ('I. Dünya Savaşı\'nın başlaması', 1914),
    ('Çanakkale Deniz Zaferi', 1915), ('Mondros Ateşkes Antlaşması', 1918),
    ('Mustafa Kemal\'in Samsun\'a çıkışı', 1919), ('Sivas Kongresi', 1919), ('Erzurum Kongresi', 1919),
    ('Amasya Genelgesi', 1919), ('TBMM\'nin açılışı', 1920), ('Sevr Antlaşması', 1920),
    ('Sakarya Meydan Muharebesi', 1921), ('I. İnönü Muharebesi', 1921), ('Büyük Taarruz', 1922),
    ('Mudanya Ateşkes Antlaşması', 1922), ('Saltanatın kaldırılması', 1922), ('Lozan Barış Antlaşması', 1923),
    ('Cumhuriyetin ilanı', 1923), ('İzmir İktisat Kongresi', 1923), ('Halifeliğin kaldırılması', 1924),
    ('Tevhid-i Tedrisat Kanunu', 1924), ('Şapka Kanunu', 1925), ('Tekke ve zaviyelerin kapatılması', 1925),
    ('Türk Medeni Kanunu\'nun kabulü', 1926), ('Harf İnkılabı', 1928),
    ('Kadınlara belediye seçimlerinde seçme ve seçilme hakkı', 1930), ('Türk Tarih Kurumu\'nun kurulması', 1931),
    ('Türk Dil Kurumu\'nun kurulması', 1932), ('Türkiye\'nin Milletler Cemiyeti\'ne girmesi', 1932),
    ('Soyadı Kanunu', 1934), ('Kadınlara milletvekili seçme ve seçilme hakkı', 1934), ('Balkan Antantı', 1934),
    ('Montrö Boğazlar Sözleşmesi', 1936), ('Sadabat Paktı', 1937), ('Laikliğin anayasaya girmesi', 1937),
    ('Hatay\'ın Türkiye\'ye katılması', 1939), ('Türkiye\'nin NATO\'ya girmesi', 1952),
]
YEAR_COUNT = {}
for _, y in EVENTS:
    YEAR_COUNT[y] = YEAR_COUNT.get(y, 0) + 1
UNIQUE = [(e, y) for e, y in EVENTS if YEAR_COUNT[y] == 1]

RULERS = [
    ('İstanbul\'un fethi', 'II. Mehmet (Fatih)'), ('Otlukbeli Savaşı', 'II. Mehmet (Fatih)'),
    ('Çaldıran Savaşı', 'I. Selim (Yavuz)'), ('Mercidabık Savaşı', 'I. Selim (Yavuz)'),
    ('Ridaniye Savaşı', 'I. Selim (Yavuz)'), ('Mohaç Meydan Savaşı', 'I. Süleyman (Kanuni)'),
    ('I. Viyana Kuşatması', 'I. Süleyman (Kanuni)'), ('Preveze Deniz Savaşı', 'I. Süleyman (Kanuni)'),
    ('Ankara Savaşı', 'I. Bayezid (Yıldırım)'), ('Niğbolu Savaşı', 'I. Bayezid (Yıldırım)'),
    ('I. Kosova Savaşı', 'I. Murad'), ('Varna Savaşı', 'II. Murad'), ('II. Kosova Savaşı', 'II. Murad'),
    ('Bursa\'nın fethi', 'Orhan Bey'), ('Koyunhisar (Bafeus) Savaşı', 'Osman Bey'),
    ('Malazgirt Savaşı', 'Alparslan'), ('Dandanakan Savaşı', 'Tuğrul Bey'),
    ('Miryokefalon Savaşı', 'II. Kılıç Arslan'), ('Kösedağ Savaşı', 'II. Gıyaseddin Keyhüsrev'),
    ('Pasarofça Antlaşması', 'III. Ahmet'), ('Yeniçeri Ocağı\'nın kaldırılması', 'II. Mahmut'),
    ('Sened-i İttifak\'ın imzalanması', 'II. Mahmut'), ('Tanzimat Fermanı\'nın ilanı', 'Abdülmecit'),
    ('Islahat Fermanı\'nın ilanı', 'Abdülmecit'), ('I. Meşrutiyet\'in ilanı', 'II. Abdülhamit'),
    ('İnebahtı Deniz Savaşı', 'II. Selim'), ('Kasr-ı Şirin Antlaşması', 'IV. Murat'),
    ('II. Viyana Kuşatması', 'IV. Mehmet'), ('Karlofça Antlaşması', 'II. Mustafa'),
    ('Küçük Kaynarca Antlaşması', 'I. Abdülhamit'),
]
ALL_RULERS = sorted({x for _, x in RULERS} | {'III. Selim', 'II. Osman', 'I. Ahmet', 'Sultan Vahdettin'})

FACTS = [
    ('Türk adının resmî devlet adı olarak ilk kez kullanıldığı devlet hangisidir?', 'Göktürkler', ['Uygurlar', 'Asya Hun Devleti', 'Karahanlılar', 'Hazarlar', 'Avarlar']),
    ('Yerleşik hayata geçen ilk Türk devleti hangisidir?', 'Uygurlar', ['Göktürkler', 'Asya Hun Devleti', 'Peçenekler', 'Kumanlar', 'Avarlar']),
    ('İslamiyet\'i resmî din olarak kabul eden ilk Türk devleti hangisidir?', 'Karahanlılar', ['Gazneliler', 'Büyük Selçuklular', 'Uygurlar', 'Göktürkler', 'Tolunoğulları']),
    ('Orhun Yazıtları hangi Türk devletinden kalmıştır?', 'Göktürkler', ['Uygurlar', 'Karahanlılar', 'Asya Hun Devleti', 'Hazarlar', 'Gazneliler']),
    ('Kutadgu Bilig adlı eserin yazarı kimdir?', 'Yusuf Has Hacip', ['Kaşgarlı Mahmut', 'Edip Ahmet Yükneki', 'Nizamülmülk', 'Ahmet Yesevi', 'Farabi']),
    ('Divanü Lügati\'t-Türk adlı eserin yazarı kimdir?', 'Kaşgarlı Mahmut', ['Yusuf Has Hacip', 'Edip Ahmet Yükneki', 'Nizamülmülk', 'Ahmet Yesevi', 'Biruni']),
    ('Atabetü\'l-Hakayık adlı eserin yazarı kimdir?', 'Edip Ahmet Yükneki', ['Yusuf Has Hacip', 'Kaşgarlı Mahmut', 'Ahmet Yesevi', 'Nizamülmülk', 'Farabi']),
    ('Siyasetname adlı eserin yazarı kimdir?', 'Nizamülmülk', ['Yusuf Has Hacip', 'Kaşgarlı Mahmut', 'Gazali', 'Farabi', 'Biruni']),
    ('Göktürk Devleti\'nin kurucusu kimdir?', 'Bumin Kağan', ['Mete Han', 'Bilge Kağan', 'Kutluk Kağan', 'Satuk Buğra Han', 'Tuğrul Bey']),
    ('Büyük Selçuklu Devleti\'nin kurucusu kimdir?', 'Tuğrul Bey', ['Alparslan', 'Melikşah', 'Sultan Sencer', 'Süleyman Şah', 'Çağrı Bey']),
    ('Türkiye Selçuklu Devleti\'nin kurucusu kimdir?', 'Süleyman Şah', ['I. Kılıç Arslan', 'Alparslan', 'Tuğrul Bey', 'Alaeddin Keykubat', 'Melikşah']),
    ('Osmanlı Devleti\'nin kurucusu kimdir?', 'Osman Bey', ['Orhan Bey', 'Ertuğrul Gazi', 'I. Murad', 'Süleyman Şah', 'I. Bayezid']),
    ('Osmanlı Devleti\'nde ilk düzenli ordu hangi padişah döneminde kurulmuştur?', 'Orhan Bey', ['Osman Bey', 'I. Murad', 'I. Bayezid', 'II. Mehmet (Fatih)', 'II. Mahmut']),
    ('Yeniçeri Ocağı hangi padişah döneminde kurulmuştur?', 'I. Murad', ['Orhan Bey', 'Osman Bey', 'I. Bayezid', 'II. Murad', 'II. Mahmut']),
    ('Osmanlı Devleti\'nde ilk anayasa olan Kanun-i Esasi hangi yıl ilan edilmiştir?', '1876', ['1839', '1856', '1908', '1923', '1921']),
    ('Türkiye Cumhuriyeti\'nin ilk cumhurbaşkanı kimdir?', 'Mustafa Kemal Atatürk', ['İsmet İnönü', 'Celal Bayar', 'Fevzi Çakmak', 'Kâzım Karabekir', 'Rauf Orbay']),
    ('Türkiye Cumhuriyeti\'nin ilk başbakanı kimdir?', 'İsmet İnönü', ['Mustafa Kemal Atatürk', 'Fethi Okyar', 'Celal Bayar', 'Rauf Orbay', 'Refik Saydam']),
    ('Millî Mücadele döneminde Doğu Cephesi komutanı kimdir?', 'Kâzım Karabekir', ['İsmet İnönü', 'Ali Fuat Cebesoy', 'Fevzi Çakmak', 'Refet Bele', 'Rauf Orbay']),
    ('Misak-ı Millî hangi meclis tarafından kabul edilmiştir?', 'Son Osmanlı Mebusan Meclisi', ['TBMM', 'Temsil Heyeti', 'Erzurum Kongresi', 'Sivas Kongresi', 'Meclis-i Mebusan\'ın ilk dönemi']),
    ('Kurtuluş Savaşı\'nın kazanılmasıyla imzalanan ve yeni Türk devletinin bağımsızlığını uluslararası alanda tanıtan antlaşma hangisidir?', 'Lozan Barış Antlaşması', ['Sevr Antlaşması', 'Mudanya Ateşkes Antlaşması', 'Mondros Ateşkes Antlaşması', 'Ankara Antlaşması', 'Gümrü Antlaşması']),
    ('TBMM\'nin Doğu Cephesi\'nde imzaladığı ilk antlaşma hangisidir?', 'Gümrü Antlaşması', ['Moskova Antlaşması', 'Kars Antlaşması', 'Ankara Antlaşması', 'Mudanya Ateşkes Antlaşması', 'Lozan Barış Antlaşması']),
    ('Kurtuluş Savaşı\'nda Batı Cephesi\'nde düzenli ordunun kazandığı ilk zafer hangisidir?', 'I. İnönü Muharebesi', ['Sakarya Meydan Muharebesi', 'II. İnönü Muharebesi', 'Büyük Taarruz', 'Kütahya-Eskişehir Muharebeleri', 'Dumlupınar Muharebesi']),
]


@stem_limit(1)
def yil(r):
    e, y = r.choice(EVENTS)
    return make(r, 'Kronoloji', f'{e} hangi yılda gerçekleşmiştir?', y,
                num_distractors(r, y, 25 if y > 1800 else 60), f'{e}: {y}.')


@stem_limit(1)
def yuzyil(r):
    e, y = r.choice(EVENTS)
    c = (y - 1) // 100 + 1
    return make(r, 'Kronoloji', f'{e} hangi yüzyılda gerçekleşmiştir?', f'{c}. yüzyıl',
                [f'{x}. yüzyıl' for x in [c - 1, c + 1, c - 2, c + 2, c + 3] if x > 0],
                f'{y} yılı {c}. yüzyıldadır.')


@stem_limit(1)
def hukumdar(r):
    e, h = r.choice(RULERS)
    others = [x for x in ALL_RULERS if x != h]
    r.shuffle(others)
    return make(r, 'Hükümdarlar', f'{e} hangi hükümdar döneminde gerçekleşmiştir?', h, others,
                f'{e}: {h} dönemi.')


@stem_limit(60)
def en_once(r):
    picks = r.sample(UNIQUE, 5)
    first = min(picks, key=lambda p: p[1])
    return make(r, 'Kronoloji', 'Aşağıdaki gelişmelerden hangisi diğerlerinden önce gerçekleşmiştir?', first[0],
                [p[0] for p in picks if p != first],
                'Yıllar: ' + ', '.join(f'{e} ({y})' for e, y in sorted(picks, key=lambda p: p[1])) + '.')


@stem_limit(60)
def en_son(r):
    picks = r.sample(UNIQUE, 5)
    last = max(picks, key=lambda p: p[1])
    return make(r, 'Kronoloji', 'Aşağıdaki gelişmelerden hangisi diğerlerinden sonra gerçekleşmiştir?', last[0],
                [p[0] for p in picks if p != last],
                'Yıllar: ' + ', '.join(f'{e} ({y})' for e, y in sorted(picks, key=lambda p: p[1])) + '.')


@stem_limit(1)
def bilgi(r):
    q, a, others = r.choice(FACTS)
    return make(r, 'Genel bilgi', q, a, others, f'Doğru cevap: {a}.')


GENERATORS = [(yil, 4), (yuzyil, 3), (hukumdar, 2), (en_once, 3), (en_son, 3), (bilgi, 1)]
