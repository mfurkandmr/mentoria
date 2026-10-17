"""AYT Din Kültürü ve Ahlak Bilgisi: dünya dinleri, İslam düşüncesinde
yorumlar, Allah'ın sıfatları, Kur'an ve ahlak kavramları (tablolardan)."""
from common import define_gens, fact_gen, relation_gens

T = 'AYT_DIN'

RELIGIONS = [
    ('Vedalar', 'Hinduizm'), ('Kast sistemi', 'Hinduizm'), ('Upanişadlar', 'Hinduizm'), ('Brahman inancı', 'Hinduizm'),
    ('Nirvana', 'Budizm'), ('Tripitaka', 'Budizm'), ('Siddhartha Gautama', 'Budizm'), ('Dört Yüce Gerçek öğretisi', 'Budizm'),
    ('Tao Te Ching', 'Taoizm'), ('Lao Tzu', 'Taoizm'), ('Yin ve Yang anlayışı', 'Taoizm'),
    ('Konfüçyüs', 'Konfüçyüsçülük'), ('Analektler (Lun Yu)', 'Konfüçyüsçülük'), ('Atalara saygı ve beş temel ilişki öğretisi', 'Konfüçyüsçülük'),
    ('Kami inancı', 'Şintoizm'), ('Japonya\'nın geleneksel dini olması', 'Şintoizm'), ('Kojiki', 'Şintoizm'),
    ('Tevrat', 'Yahudilik'), ('Talmud', 'Yahudilik'), ('Sinagog', 'Yahudilik'), ('Fısıh (Hamursuz) Bayramı', 'Yahudilik'), ('Sebt (Cumartesi) günü', 'Yahudilik'),
    ('İncil', 'Hristiyanlık'), ('Kilise', 'Hristiyanlık'), ('Teslis inancı', 'Hristiyanlık'), ('Paskalya', 'Hristiyanlık'), ('Vaftiz', 'Hristiyanlık'),
    ('Avesta', 'Zerdüştlük'), ('Ahura Mazda', 'Zerdüştlük'), ('Ateşin kutsal sayılması', 'Zerdüştlük'),
    ('Guru Nanak', 'Sihizm'), ('Granth Sahib', 'Sihizm'), ('Gurdvara', 'Sihizm'), ('Altın Tapınak (Amritsar)', 'Sihizm'),
]
CHRISTIAN = [
    ('Papa', 'Katoliklik'), ('Vatikan', 'Katoliklik'), ('Martin Luther', 'Protestanlık'), ('Jean Calvin', 'Protestanlık'),
    ('Patrikhaneler ve ikona geleneği', 'Ortodoksluk'),
]
SCHOOLS = [
    ('Ebu Hanife', 'Hanefilik'), ('İmam Şafii', 'Şafiilik'), ('İmam Malik', 'Malikilik'), ('Ahmed bin Hanbel', 'Hanbelilik'),
    ('Ebu Mansur el-Maturidi', 'Maturidilik'), ('Ebu\'l-Hasan el-Eşari', 'Eşarilik'), ('Cafer-i Sadık', 'Caferilik'),
]
SCHOOL_TYPE = [
    ('Maturidilik', 'itikadi (inançla ilgili) mezhep'), ('Eşarilik', 'itikadi (inançla ilgili) mezhep'), ('Selefiyye', 'itikadi (inançla ilgili) mezhep'),
    ('Mutezile', 'itikadi (inançla ilgili) mezhep'), ('Hanefilik', 'fıkhi (amelle ilgili) mezhep'), ('Şafiilik', 'fıkhi (amelle ilgili) mezhep'),
    ('Malikilik', 'fıkhi (amelle ilgili) mezhep'), ('Hanbelilik', 'fıkhi (amelle ilgili) mezhep'),
]
ORDERS = [
    ('Mevlevilik', 'Mevlana Celaleddin Rumi'), ('Yesevilik', 'Ahmet Yesevi'), ('Nakşibendilik', 'Bahaeddin Nakşibend'),
    ('Kadirilik', 'Abdülkadir Geylani'), ('Bektaşilik', 'Hacı Bektaş Veli'), ('Rifailik', 'Ahmed er-Rifai'), ('Halvetilik', 'Ömer el-Halveti'),
]
PERSONS = [
    ('Buhari', 'Kütüb-i Sitte müellifi'), ('Müslim', 'Kütüb-i Sitte müellifi'), ('Ebu Davud', 'Kütüb-i Sitte müellifi'),
    ('Tirmizi', 'Kütüb-i Sitte müellifi'), ('Nesai', 'Kütüb-i Sitte müellifi'), ('İbn Mace', 'Kütüb-i Sitte müellifi'),
    ('Farabi', 'İslam filozofu'), ('İbn Sina', 'İslam filozofu'), ('Kindi', 'İslam filozofu'), ('İbn Rüşd', 'İslam filozofu'),
    ('Ebu Hanife', 'Mezhep imamı'), ('İmam Şafii', 'Mezhep imamı'), ('İmam Malik', 'Mezhep imamı'), ('Ahmed bin Hanbel', 'Mezhep imamı'),
]
ATTRS = [
    ('Vücud', 'zati sıfat'), ('Kıdem', 'zati sıfat'), ('Beka', 'zati sıfat'), ('Vahdaniyet', 'zati sıfat'),
    ('Muhalefetün li\'l-havadis', 'zati sıfat'), ('Kıyam bi-nefsihi', 'zati sıfat'),
    ('Hayat', 'subuti sıfat'), ('İlim', 'subuti sıfat'), ('Semi', 'subuti sıfat'), ('Basar', 'subuti sıfat'), ('İrade', 'subuti sıfat'),
    ('Kudret', 'subuti sıfat'), ('Kelam', 'subuti sıfat'), ('Tekvin', 'subuti sıfat'),
]
ATTR_DEF = {
    'Vücud': 'Allah\'ın var olması', 'Kıdem': 'Allah\'ın varlığının başlangıcının olmaması', 'Beka': 'Allah\'ın varlığının sonunun olmaması',
    'Vahdaniyet': 'Allah\'ın bir ve tek olması', 'Muhalefetün li\'l-havadis': 'Allah\'ın yaratılmışlara benzememesi',
    'Kıyam bi-nefsihi': 'Allah\'ın varlığının kendisinden olması, hiçbir şeye muhtaç olmaması', 'Hayat': 'Allah\'ın diri olması',
    'İlim': 'Allah\'ın her şeyi bilmesi', 'Semi': 'Allah\'ın her şeyi işitmesi', 'Basar': 'Allah\'ın her şeyi görmesi',
    'İrade': 'Allah\'ın dilemesi', 'Kudret': 'Allah\'ın her şeye gücünün yetmesi', 'Kelam': 'Allah\'ın konuşması',
    'Tekvin': 'Allah\'ın yaratması',
}
ETHICS = {
    'Takva': 'Allah\'ın emir ve yasaklarına uyarak kötülüklerden sakınma',
    'Tevekkül': 'Gereken bütün çabayı gösterdikten sonra sonucu Allah\'a bırakma',
    'Zühd': 'Dünya nimetlerine gönül bağlamadan sade yaşama',
    'İhlas': 'Bir işi yalnızca Allah rızası için samimiyetle yapma',
    'İhsan': 'Allah\'ı görüyormuş gibi ibadet etme; iyiliği en güzel biçimde yapma',
    'Kanaat': 'Elindekiyle yetinip gözü başkasının malında olmama',
    'Haya': 'Utanılacak söz ve davranışlardan kaçınma',
    'İsar': 'Kendisi muhtaç iken başkasını kendine tercih etme',
    'Sabır': 'Zorluklar karşısında dayanıklı olma ve metanet gösterme',
    'Tövbe': 'İşlenen günahtan pişman olup bir daha yapmamaya karar verme',
    'Vahiy': 'Allah\'ın iradesini peygamberlerine bildirmesi',
    'İçtihat': 'Dinî bir hükmü delillerden çıkarmak için uzmanın bütün gücünü harcaması',
}
FACTS = [
    ('Kur\'an-ı Kerim\'de kaç sure vardır?', '114', ['110', '120', '99', '124', '30']),
    ('Kur\'an-ı Kerim\'in ilk suresi hangisidir?', 'Fatiha', ['Bakara', 'Alak', 'Nas', 'İhlas', 'Yasin']),
    ('Kur\'an-ı Kerim\'in en uzun suresi hangisidir?', 'Bakara', ['Fatiha', 'Al-i İmran', 'Nisa', 'Yasin', 'Kevser']),
    ('Kur\'an-ı Kerim\'in son suresi hangisidir?', 'Nas', ['Felak', 'İhlas', 'Fatiha', 'Bakara', 'Kevser']),
    ('İlk inen ayetler hangi surede yer alır?', 'Alak', ['Fatiha', 'Bakara', 'Müddessir', 'Nas', 'Yasin']),
    ('Kur\'an-ı Kerim hangi halife döneminde kitap hâline getirilmiştir (cem)?', 'Hz. Ebubekir', ['Hz. Ömer', 'Hz. Osman', 'Hz. Ali', 'Muaviye', 'Hz. Hasan']),
    ('Kur\'an-ı Kerim hangi halife döneminde çoğaltılarak (istinsah) merkezlere gönderilmiştir?', 'Hz. Osman', ['Hz. Ebubekir', 'Hz. Ömer', 'Hz. Ali', 'Muaviye', 'Ömer bin Abdülaziz']),
    ('Kur\'an-ı Kerim kaç cüzden oluşur?', '30', ['114', '40', '20', '60', '12']),
    ('Hicretten önce inen surelere ne ad verilir?', 'Mekki sureler', ['Medeni sureler', 'Mesani', 'Müfassal', 'Tıval', 'Miun']),
    ('Hadis kaynaklarından en güvenilir altı esere verilen ad nedir?', 'Kütüb-i Sitte', ['Kütüb-i Erbaa', 'Sahihayn', 'Müsned', 'Muvatta', 'Siyer']),
    ('Hz. Peygamber\'in söz, fiil ve onaylarının bütününe ne ad verilir?', 'Sünnet', ['Fıkıh', 'Kelam', 'Siyer', 'Tefsir', 'Akaid']),
    ('Kur\'an ayetlerini açıklayıp yorumlayan ilim dalı hangisidir?', 'Tefsir', ['Hadis', 'Fıkıh', 'Kelam', 'Siyer', 'Tasavvuf']),
    ('İslam inanç esaslarını akli ve nakli delillerle açıklayan ilim dalı hangisidir?', 'Kelam', ['Fıkıh', 'Tefsir', 'Hadis', 'Siyer', 'Tasavvuf']),
    ('Alevi-Bektaşi geleneğinde cemlerin yapıldığı mekâna ne ad verilir?', 'Cemevi', ['Tekke', 'Dergâh', 'Mescit', 'Zaviye', 'Medrese']),
    ('Alevi-Bektaşi geleneğinde musahiplik kurumu neyi ifade eder?', 'İki ailenin ömür boyu kardeşlik bağıyla birbirine bağlanmasını', ['Dedelik makamını', 'Muharrem orucunu', 'Semahı', 'Cem ibadetini', 'Hızır orucunu']),
]


GENERATORS = relation_gens('Dünya dinleri', RELIGIONS, fwd='"{item}" hangi dinle ilgilidir?',
                           has='Aşağıdakilerden hangisi {group} ile ilgilidir?',
                           has_not='Aşağıdakilerden hangisi {group} ile ilgili değildir?', weights=(4, 2, 3), has_limit=4, has_not_limit=12,
                           extra_groups=['İslam']) \
    + relation_gens('Hristiyanlık', CHRISTIAN, fwd='"{item}" hangi Hristiyan mezhebiyle ilgilidir?', weights=(1, 0, 0),
                    extra_groups=['Nasturilik', 'Anglikanlık']) \
    + relation_gens('İslam düşüncesinde yorumlar', SCHOOLS, fwd='{item} hangi mezhebin kurucusu kabul edilir?', weights=(2, 0, 0)) \
    + relation_gens('İslam düşüncesinde yorumlar', SCHOOL_TYPE, fwd=None,
                    has='Aşağıdakilerden hangisi bir {group}tir?',
                    has_not='Aşağıdakilerden hangisi bir {group} değildir?', weights=(0, 1, 1), has_limit=4, has_not_limit=8) \
    + relation_gens('Tasavvufi yorumlar', ORDERS, fwd='{item} hangi mutasavvıfa dayanır?', weights=(2, 0, 0)) \
    + define_gens('Tasavvufi yorumlar', dict(ORDERS), fwd='{k} tarikatının kurucusu (pîri) kimdir?',
                  back='{v} hangi tasavvufi yolun pîridir?', weights=(0, 2)) \
    + relation_gens('İslam bilginleri', PERSONS, fwd='{item} aşağıdakilerden hangisidir?',
                    has='Aşağıdakilerden hangisi {group} olarak bilinir?',
                    has_not='Aşağıdakilerden hangisi {group} değildir?', weights=(1, 2, 3), has_limit=4, has_not_limit=12) \
    + relation_gens('Allah\'ın sıfatları', ATTRS, fwd='{item} hangi tür sıfattır?',
                    has='Aşağıdakilerden hangisi Allah\'ın {group}larındandır?',
                    has_not='Aşağıdakilerden hangisi Allah\'ın {group}larından biri değildir?', weights=(0, 1, 1), has_limit=3, has_not_limit=8) \
    + define_gens('Allah\'ın sıfatları', ATTR_DEF, fwd='Allah\'ın "{k}" sıfatının anlamı nedir?', back='"{v}" anlamına gelen sıfat hangisidir?') \
    + define_gens('Ahlak ve kavramlar', ETHICS, fwd='"{k}" kavramının anlamı aşağıdakilerden hangisidir?',
                  back='"{v}" hangi kavramla ifade edilir?', weights=(2, 2)) \
    + [(fact_gen('Kur\'an ve sünnet', FACTS), 2)]
