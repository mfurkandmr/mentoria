"""AYT Tarih-2: XX. yüzyıl başından günümüze Türkiye ve dünya; kronoloji
soruları yıllardan hesaplanır."""
from common import chrono_gens, define_gens, fact_gen, make, relation_gens, stem_limit

T = 'AYT_TAR2'

EVENTS = [
    ('Rus İhtilali', 1917), ('Milletler Cemiyeti\'nin kurulması', 1920), ('Mussolini\'nin İtalya\'da iktidara gelmesi', 1922),
    ('Dünya Ekonomik Bunalımı (1929 Buhranı)', 1929), ('Hitler\'in Almanya\'da iktidara gelmesi', 1933),
    ('Münih Konferansı', 1938), ('II. Dünya Savaşı\'nın başlaması', 1939), ('Pearl Harbor Baskını', 1941),
    ('Birleşmiş Milletler\'in kurulması', 1945), ('Türkiye\'de çok partili hayata geçiş (Demokrat Parti\'nin kurulması)', 1946),
    ('Truman Doktrini', 1947), ('İsrail Devleti\'nin kurulması', 1948), ('NATO\'nun kurulması', 1949),
    ('Demokrat Parti\'nin iktidara gelmesi', 1950), ('Türkiye\'nin NATO\'ya girmesi', 1952), ('Balkan Paktı', 1953),
    ('Varşova Paktı\'nın kurulması', 1955), ('Süveyş Krizi', 1956), ('Roma Antlaşması (AET\'nin kuruluşu)', 1957),
    ('27 Mayıs askerî müdahalesi', 1960), ('Berlin Duvarı\'nın yapılması', 1961), ('Küba Füze Krizi', 1962),
    ('Ankara Antlaşması (Türkiye-AET ortaklığı)', 1963), ('Johnson Mektubu', 1964), ('Altı Gün Savaşı', 1967),
    ('İnsanın Ay\'a ayak basması', 1969), ('12 Mart Muhtırası', 1971), ('Petrol Krizi ve Yom Kippur Savaşı', 1973),
    ('Kıbrıs Barış Harekâtı', 1974), ('Helsinki Nihai Senedi', 1975), ('Camp David Antlaşması', 1978),
    ('İran İslam Devrimi', 1979), ('12 Eylül askerî müdahalesi', 1980), ('1982 Anayasası\'nın kabulü', 1982),
    ('KKTC\'nin kurulması', 1983), ('Çernobil Nükleer Kazası', 1986), ('Berlin Duvarı\'nın yıkılması', 1989),
    ('Almanya\'nın birleşmesi', 1990), ('SSCB\'nin dağılması', 1991), ('Maastricht Antlaşması', 1992),
    ('Türkiye-AB Gümrük Birliği\'nin yürürlüğe girmesi', 1996), ('Türkiye\'nin AB\'ye aday ülke ilan edilmesi', 1999),
    ('11 Eylül saldırıları', 2001), ('Atlantik Bildirisi', 1941), ('Yalta Konferansı', 1945), ("Kore Savaşı'nın başlaması", 1950),
    ('Bandung Konferansı', 1955), ("Sputnik'in fırlatılması", 1957), ("OPEC'in kurulması", 1960),
    ("İslam İşbirliği Teşkilatı'nın kurulması", 1969), ('Körfez Savaşı', 1991), ("Euro'nun tedavüle girmesi", 2002),
    ("Kıbrıs Cumhuriyeti'nin kurulması", 1960), ("Marshall Planı'nın uygulanmaya başlaması", 1948), ('Bağdat Paktı', 1955),
]

PEOPLE = [
    ('II. Dünya Savaşı\'nda İngiltere başbakanı olması', 'Winston Churchill'), ('Atlantik Bildirisi\'ni ABD adına imzalaması', 'Franklin D. Roosevelt'),
    ('Yalta Konferansı\'nda SSCB\'yi temsil etmesi', 'Josef Stalin'), ('Nazi Almanyası\'nın lideri olması', 'Adolf Hitler'),
    ('İtalya\'da faşist rejimi kurması', 'Benito Mussolini'), ('Türkiye ve Yunanistan\'a yardımı öngören doktrini ilan etmesi', 'Harry S. Truman'),
    ('Küba Füze Krizi sırasında ABD başkanı olması', 'John F. Kennedy'), ('Küba Füze Krizi sırasında SSCB lideri olması', 'Nikita Kruşçev'),
    ('Glasnost ve perestroyka politikalarını başlatması', 'Mihail Gorbaçov'), ('Çin Halk Cumhuriyeti\'nin kurucusu olması', 'Mao Zedong'),
    ('Hindistan\'ın bağımsızlığı için pasif direniş hareketine önderlik etmesi', 'Mahatma Gandhi'), ('Bağımsız Hindistan\'ın ilk başbakanı olması', 'Cevahirlal Nehru'),
    ('Süveyş Kanalı\'nı millîleştirmesi', 'Cemal Abdünnasır'), ('Yugoslavya lideri olarak Bağlantısızlar Hareketi\'ne öncülük etmesi', 'Josip Broz Tito'),
    ('Güney Afrika\'da ırk ayrımcılığına (apartheid) karşı mücadelesi', 'Nelson Mandela'), ('Fransa\'da V. Cumhuriyet\'in kurucusu olması', 'Charles de Gaulle'),
    ('Demokrat Parti iktidarında başbakanlık yapması (1950-1960)', 'Adnan Menderes'), ('Türkiye\'nin üçüncü cumhurbaşkanı olması', 'Celal Bayar'),
    ('Millî Şef olarak anılan ikinci cumhurbaşkanı olması', 'İsmet İnönü'), ('1980\'lerde ekonomide dışa açılma politikasını başlatan başbakan olması', 'Turgut Özal'),
]

PRESIDENTS = ['Mustafa Kemal Atatürk', 'İsmet İnönü', 'Celal Bayar', 'Cemal Gürsel', 'Cevdet Sunay', 'Fahri Korutürk',
              'Kenan Evren', 'Turgut Özal', 'Süleyman Demirel', 'Ahmet Necdet Sezer', 'Abdullah Gül']
ORD = ['birinci', 'ikinci', 'üçüncü', 'dördüncü', 'beşinci', 'altıncı', 'yedinci', 'sekizinci', 'dokuzuncu', 'onuncu', 'on birinci']


@stem_limit(1)
def cumhurbaskani(r):
    i = r.randrange(len(PRESIDENTS))
    p = PRESIDENTS[i]
    others = [x for x in PRESIDENTS if x != p]
    r.shuffle(others)
    if r.random() < 0.5:
        return make(r, 'Türkiye\'de siyasi hayat', f'Türkiye Cumhuriyeti\'nin {ORD[i]} cumhurbaşkanı kimdir?', p, others,
                    f'Sıra: {", ".join(PRESIDENTS)}.')
    return make(r, 'Türkiye\'de siyasi hayat', f'{p} Türkiye Cumhuriyeti\'nin kaçıncı cumhurbaşkanıdır?', f'{i + 1}.',
                [f'{x + 1}.' for x in range(len(PRESIDENTS)) if x != i], f'Sıra: {", ".join(PRESIDENTS)}.')


CONCEPTS = {
    'Soğuk Savaş': 'II. Dünya Savaşı sonrası ABD ve SSCB önderliğindeki blokların silahlı çatışmaya girmeden yürüttüğü rekabet',
    'Truman Doktrini': 'ABD\'nin Türkiye ve Yunanistan\'ı komünizme karşı desteklemek için ilan ettiği yardım politikası',
    'Marshall Planı': 'ABD\'nin savaş sonrası Avrupa\'nın ekonomik kalkınması için uyguladığı yardım programı',
    'Demir Perde': 'Doğu Bloku ülkelerini Batı\'dan ayıran siyasi ve ideolojik sınırı anlatan kavram',
    'Detant (Yumuşama)': 'Soğuk Savaş\'ta iki blok arasındaki gerginliğin azaldığı dönem',
    'Glasnost': 'SSCB\'de açıklık ve şeffaflığı amaçlayan politika',
    'Perestroyka': 'SSCB\'de ekonomik ve siyasi yapıyı yeniden yapılandırma politikası',
    'Bağlantısızlar Hareketi': 'İki bloktan da uzak durmayı amaçlayan ülkelerin oluşturduğu hareket',
    'Apartheid': 'Güney Afrika\'da uygulanan ırk ayrımcılığı politikası',
    'Küreselleşme': 'Ekonomik, kültürel ve siyasi ilişkilerin dünya ölçeğinde yoğunlaşıp bütünleşmesi',
    'Dekolonizasyon': 'Sömürge altındaki ülkelerin bağımsızlıklarını kazanması süreci',
}

FACTS = [
    ('Türkiye II. Dünya Savaşı\'nda nasıl bir politika izlemiştir?', 'Savaşın sonuna kadar fiilen savaşa girmeme (denge) politikası',
     ['Mihver devletlerinin yanında savaşa girme', 'Savaşın başında Almanya\'ya savaş açma', 'SSCB ile ittifak kurup savaşa girme', 'Tamamen yalnızlık politikası ve sınırları kapatma', 'Japonya ile ittifak kurma']),
    ('Türkiye\'nin Kore Savaşı\'na asker göndermesinin en önemli sonucu hangisidir?', 'NATO\'ya üyeliğin kolaylaşması',
     ['Varşova Paktı\'na girmesi', 'Kıbrıs\'ın Türkiye\'ye katılması', 'AET\'ye tam üye olması', 'Balkan Antantı\'nın kurulması', 'Sadabat Paktı\'nın imzalanması']),
    ('Kıbrıs Cumhuriyeti hangi yıl kurulmuştur?', '1960', ['1955', '1964', '1974', '1983', '1950']),
    ('Türkiye\'nin kurucu üyeleri arasında yer aldığı uluslararası örgüt hangisidir?', 'Birleşmiş Milletler', ['NATO', 'Avrupa Birliği', 'Varşova Paktı', 'ASEAN', 'OPEC']),
    ('Berlin Duvarı\'nın yıkılmasıyla sembolleşen gelişme hangisidir?', 'Soğuk Savaş\'ın sona ermesi', ['II. Dünya Savaşı\'nın başlaması', 'NATO\'nun kurulması', 'Marshall Planı\'nın ilanı', 'Kore Savaşı', 'Küba Krizi']),
    ('SSCB\'nin dağılmasının ardından bağımsızlığını kazanan Türk cumhuriyetlerinden biri hangisidir?', 'Kazakistan', ['Moğolistan', 'Afganistan', 'İran', 'Pakistan', 'Gürcistan']),
    ('1961 Anayasası\'yla oluşturulan yasama organının yapısı nasıldır?', 'Millet Meclisi ve Cumhuriyet Senatosu\'ndan oluşan iki meclisli yapı',
     ['Tek meclisli yapı', 'Yalnızca Cumhuriyet Senatosu', 'Danışma Meclisi', 'Millî Birlik Komitesi', 'Ayan Meclisi']),
]


GENERATORS = chrono_gens('Kronoloji', EVENTS, limit=90, weights=(3, 0, 2, 2)) \
    + relation_gens('Liderler', PEOPLE, fwd='"{item}" hangi liderle ilgilidir?',
                    has='Aşağıdakilerden hangisi {group} ile ilgilidir?', weights=(3, 1, 0), has_limit=1) \
    + [(cumhurbaskani, 2), (fact_gen('Türkiye ve dünya', FACTS), 1)] \
    + define_gens('Kavramlar', CONCEPTS, fwd='"{k}" kavramı aşağıdakilerden hangisini ifade eder?',
                  back='"{v}" hangi kavramla ifade edilir?', weights=(2, 2))
