"""TYT Din Kültürü ve Ahlak Bilgisi: kavram ve bilgi tabloları."""
from common import make, stem_limit

T = 'TYT_DIN'

GROUPS = {
    'imanın şartlarından': ['Allah\'a inanmak', 'Meleklere inanmak', 'Kitaplara inanmak', 'Peygamberlere inanmak',
                            'Ahiret gününe inanmak', 'Kadere inanmak'],
    'İslam\'ın şartlarından': ['Kelime-i şehadet getirmek', 'Namaz kılmak', 'Oruç tutmak', 'Zekât vermek', 'Hacca gitmek'],
    'dört büyük melekten': ['Cebrail', 'Mikail', 'İsrafil', 'Azrail'],
    'dört halifeden': ['Hz. Ebubekir', 'Hz. Ömer', 'Hz. Osman', 'Hz. Ali'],
    'fıkhi (amelî) mezheplerden': ['Hanefilik', 'Şafiilik', 'Malikilik', 'Hanbelilik'],
    'itikadi mezheplerden': ['Maturidilik', 'Eşarilik'],
    'farz namazlardan': ['Sabah namazı', 'Öğle namazı', 'İkindi namazı', 'Akşam namazı', 'Yatsı namazı'],
}
DISTRACT = {
    'imanın şartlarından': ['Oruç tutmak', 'Zekât vermek', 'Namaz kılmak', 'Hacca gitmek', 'Kurban kesmek'],
    'İslam\'ın şartlarından': ['Kadere inanmak', 'Meleklere inanmak', 'Kurban kesmek', 'Umreye gitmek', 'Fitre vermek'],
    'dört büyük melekten': ['Kiramen Kâtibin', 'Münker', 'Nekir', 'Hafaza melekleri'],
    'dört halifeden': ['Hz. Hamza', 'Hz. Hasan', 'Hz. Hüseyin', 'Muaviye', 'Hz. Abbas'],
    'fıkhi (amelî) mezheplerden': ['Maturidilik', 'Eşarilik', 'Mutezile'],
    'farz namazlardan': ['Vitir namazı', 'Bayram namazı', 'Teravih namazı', 'Kuşluk namazı'],
}

ANGELS = {'Cebrail': 'Vahiy getirmek', 'Mikail': 'Tabiat olaylarını yönetmek',
          'İsrafil': 'Sûr\'a üflemek', 'Azrail': 'Can almak'}
BOOKS = {'Tevrat': 'Hz. Musa', 'Zebur': 'Hz. Davud', 'İncil': 'Hz. İsa', 'Kur\'an-ı Kerim': 'Hz. Muhammed'}
PROPHETS_EXTRA = ['Hz. İbrahim', 'Hz. Nuh', 'Hz. Yusuf', 'Hz. Süleyman']

FACTS = [
    ('Kur\'an-ı Kerim\'de kaç sure vardır?', '114', ['110', '120', '99', '124', '100']),
    ('Kur\'an-ı Kerim\'in ilk suresi hangisidir?', 'Fatiha Suresi', ['Bakara Suresi', 'Nas Suresi', 'İhlas Suresi', 'Alak Suresi', 'Yasin Suresi']),
    ('Kur\'an-ı Kerim\'in en uzun suresi hangisidir?', 'Bakara Suresi', ['Fatiha Suresi', 'Âl-i İmran Suresi', 'Yasin Suresi', 'Kevser Suresi', 'Nisa Suresi']),
    ('Kur\'an-ı Kerim\'in son suresi hangisidir?', 'Nas Suresi', ['Felak Suresi', 'İhlas Suresi', 'Fatiha Suresi', 'Kevser Suresi', 'Asr Suresi']),
    ('Kur\'an-ı Kerim\'in en kısa suresi hangisidir?', 'Kevser Suresi', ['Fatiha Suresi', 'Nas Suresi', 'İhlas Suresi', 'Bakara Suresi', 'Felak Suresi']),
    ('İlk vahyin geldiği yer neresidir?', 'Hira Mağarası', ['Sevr Mağarası', 'Kâbe', 'Uhud Dağı', 'Mescid-i Nebevi', 'Arafat']),
    ('İlk inen ayetlerin bulunduğu sure hangisidir?', 'Alak Suresi', ['Fatiha Suresi', 'Bakara Suresi', 'Müddessir Suresi', 'İhlas Suresi', 'Yasin Suresi']),
    ('Hz. Muhammed\'in Mekke\'den Medine\'ye göç etmesine ne ad verilir?', 'Hicret', ['Miraç', 'Vahiy', 'Biat', 'Hac', 'Fetih']),
    ('Hicret hangi yılda gerçekleşmiştir?', '622', ['571', '610', '630', '632', '624']),
    ('Hz. Muhammed hangi yılda doğmuştur?', '571', ['610', '622', '632', '570', '580']),
    ('Mekke\'nin fethi hangi yılda gerçekleşmiştir?', '630', ['622', '624', '632', '627', '610']),
    ('Hz. Muhammed hangi yılda vefat etmiştir?', '632', ['622', '630', '610', '640', '571']),
    ('İlk vahyin geldiği yıl hangisidir?', '610', ['571', '622', '630', '600', '632']),
    ('Müslümanların ilk kıblesi neresidir?', 'Mescid-i Aksa', ['Kâbe', 'Mescid-i Nebevi', 'Kuba Mescidi', 'Arafat', 'Hira Mağarası']),
    ('İslam tarihinde inşa edilen ilk mescit hangisidir?', 'Kuba Mescidi', ['Mescid-i Nebevi', 'Mescid-i Aksa', 'Kâbe', 'Emevi Camii', 'Ayasofya']),
    ('Müslümanlarla Mekkeli müşrikler arasındaki ilk büyük savaş hangisidir?', 'Bedir Savaşı', ['Uhud Savaşı', 'Hendek Savaşı', 'Hayber\'in fethi', 'Huneyn Savaşı', 'Tebük Seferi']),
    ('Zenginlerin mallarının belli bir kısmını yılda bir kez ihtiyaç sahiplerine vermesi ibadeti hangisidir?', 'Zekât', ['Fitre', 'Sadaka', 'Kurban', 'Hac', 'Vakıf']),
    ('Ramazan ayında, bayramdan önce verilmesi gereken sadakaya ne ad verilir?', 'Fitre', ['Zekât', 'Öşür', 'Kurban', 'Nafaka', 'Hediye']),
    ('Belirli zamanda Kâbe\'yi ve kutsal yerleri ziyaret ederek yapılan ibadet hangisidir?', 'Hac', ['Umre', 'Zekât', 'İtikâf', 'Kurban', 'Teravih']),
    ('Yılın herhangi bir zamanında Kâbe\'yi ziyaret ederek yapılan ibadet hangisidir?', 'Umre', ['Hac', 'Zekât', 'İtikâf', 'Kurban', 'Teravih']),
    ('Ramazan ayında yatsı namazından sonra kılınan namaz hangisidir?', 'Teravih namazı', ['Vitir namazı', 'Bayram namazı', 'Cuma namazı', 'Kuşluk namazı', 'Cenaze namazı']),
    ('Namaz kılmadan önce belirli organları yıkayarak yapılan temizliğe ne ad verilir?', 'Abdest', ['Gusül', 'Teyemmüm', 'İhram', 'Niyet', 'Tekbir']),
    ('Su bulunmadığında temiz toprakla yapılan manevi temizliğe ne ad verilir?', 'Teyemmüm', ['Abdest', 'Gusül', 'İhram', 'Niyet', 'Tekbir']),
    ('Hz. Muhammed\'in sözlerine, davranışlarına ve onaylarına ne ad verilir?', 'Sünnet', ['Farz', 'Vacip', 'Mubah', 'İcma', 'Kıyas']),
    ('İslam\'da yapılması kesin olarak emredilen davranışlara ne ad verilir?', 'Farz', ['Sünnet', 'Mubah', 'Mekruh', 'Haram', 'Müstehap']),
    ('İslam\'da yapılması kesin olarak yasaklanan davranışlara ne ad verilir?', 'Haram', ['Mekruh', 'Mubah', 'Farz', 'Sünnet', 'Vacip']),
    ('Yapılıp yapılmaması serbest bırakılan davranışlara ne ad verilir?', 'Mubah', ['Farz', 'Haram', 'Mekruh', 'Vacip', 'Sünnet']),
    ('İslam\'ın temel kaynakları arasında ilk sırada yer alan kaynak hangisidir?', 'Kur\'an-ı Kerim', ['Sünnet', 'İcma', 'Kıyas', 'İçtihat', 'Örf']),
    ('Hz. Muhammed\'in Mekke\'den Kudüs\'e, oradan göklere yaptığı yolculuğa ne ad verilir?', 'İsra ve Miraç', ['Hicret', 'Vahiy', 'Hac', 'Biat', 'Fetih']),
    ('Allah\'ın birliğine inanma ilkesine ne ad verilir?', 'Tevhit', ['Şirk', 'Nübüvvet', 'Ahiret', 'Kader', 'İhlas']),
    ('Allah\'a ortak koşmaya ne ad verilir?', 'Şirk', ['Tevhit', 'Küfür', 'Nifak', 'Riya', 'Kibir']),
    ('Kendi isteğiyle, karşılık beklemeden yapılan yardım ve iyiliklere ne ad verilir?', 'Sadaka', ['Zekât', 'Fitre', 'Öşür', 'Nafaka', 'Vergi']),
    ('Toplum yararı için malın belirli bir amaca sürekli olarak bağışlandığı kurum hangisidir?', 'Vakıf', ['Zekât', 'Ahilik', 'Sadaka', 'Fitre', 'Lonca']),
    ('Esnaf ve sanatkârların meslek ahlakını düzenleyen Türk-İslam kurumu hangisidir?', 'Ahilik', ['Vakıf', 'Medrese', 'Tekke', 'Kervansaray', 'İmaret']),
    ('Hanefi mezhebinin kurucusu kimdir?', 'İmam-ı Azam Ebu Hanife', ['İmam Şafii', 'İmam Malik', 'Ahmed bin Hanbel', 'İmam Maturidi', 'İmam Eşari']),
    ('Maturidilik mezhebinin kurucusu kimdir?', 'Ebu Mansur el-Maturidi', ['Ebu\'l-Hasan el-Eşari', 'Ebu Hanife', 'İmam Şafii', 'Gazali', 'İmam Malik']),
    ('Kurban Bayramı hangi hicri ayda kutlanır?', 'Zilhicce', ['Ramazan', 'Muharrem', 'Şevval', 'Recep', 'Şaban']),
    ('Ramazan Bayramı hangi hicri ayın ilk günlerinde kutlanır?', 'Şevval', ['Zilhicce', 'Muharrem', 'Ramazan', 'Recep', 'Şaban']),
    ('Cuma namazı hangi vakit namazının yerine kılınır?', 'Öğle namazı', ['Sabah namazı', 'İkindi namazı', 'Akşam namazı', 'Yatsı namazı', 'Vitir namazı']),
    ('Kâbe hangi şehirdedir?', 'Mekke', ['Medine', 'Kudüs', 'Taif', 'Şam', 'Bağdat']),
    ('Hicri takvimin başlangıcı olarak kabul edilen olay hangisidir?', 'Hicret', ['İlk vahiy', 'Mekke\'nin fethi', 'Bedir Savaşı', 'Veda Haccı', 'Hz. Muhammed\'in doğumu']),
    ('Kur\'an-ı Kerim hangi halife döneminde kitap hâline getirilmiştir?', 'Hz. Ebubekir', ['Hz. Ömer', 'Hz. Osman', 'Hz. Ali', 'Muaviye', 'Hz. Hasan']),
    ('Kur\'an-ı Kerim hangi halife döneminde çoğaltılarak İslam şehirlerine gönderilmiştir?', 'Hz. Osman', ['Hz. Ebubekir', 'Hz. Ömer', 'Hz. Ali', 'Muaviye', 'Hz. Hasan']),
    ('İlk Müslüman olan kişi kimdir?', 'Hz. Hatice', ['Hz. Ebubekir', 'Hz. Ali', 'Hz. Zeyd', 'Hz. Ömer', 'Hz. Osman']),
    ('Hz. Muhammed\'i küçük yaşta himaye eden amcası kimdir?', 'Ebu Talip', ['Ebu Leheb', 'Hz. Hamza', 'Hz. Abbas', 'Abdülmuttalip', 'Ebu Cehil']),
    ('Hz. Muhammed\'in annesinin adı nedir?', 'Âmine', ['Halime', 'Hatice', 'Fatıma', 'Aişe', 'Esma']),
    ('Hz. Muhammed\'in süt annesinin adı nedir?', 'Halime', ['Âmine', 'Hatice', 'Fatıma', 'Aişe', 'Esma']),
    ('Kur\'an-ı Kerim\'de adı geçen tek kadın kimdir?', 'Hz. Meryem', ['Hz. Hatice', 'Hz. Fatıma', 'Hz. Aişe', 'Hz. Havva', 'Hz. Âsiye']),
    ('Kur\'an-ı Kerim\'deki cümlelerin her birine ne ad verilir?', 'Ayet', ['Sure', 'Cüz', 'Hizip', 'Mushaf', 'Hadis']),
    ('Kur\'an-ı Kerim\'i ezberleyen kişiye ne ad verilir?', 'Hafız', ['Müezzin', 'İmam', 'Kâtip', 'Müftü', 'Vaiz']),
    ('Kur\'an-ı Kerim\'i açıklayan ve yorumlayan ilim dalı hangisidir?', 'Tefsir', ['Fıkıh', 'Kelam', 'Hadis', 'Siyer', 'Tasavvuf']),
    ('İslam hukukunu inceleyen ilim dalı hangisidir?', 'Fıkıh', ['Tefsir', 'Kelam', 'Hadis', 'Siyer', 'Tasavvuf']),
    ('İslam inanç esaslarını akli ve nakli delillerle açıklayan ilim dalı hangisidir?', 'Kelam', ['Fıkıh', 'Tefsir', 'Hadis', 'Siyer', 'Tasavvuf']),
    ('Hz. Muhammed\'in hayatını inceleyen ilim dalı hangisidir?', 'Siyer', ['Fıkıh', 'Tefsir', 'Kelam', 'Hadis', 'Tasavvuf']),
    ('Hristiyanların ibadethanesine ne ad verilir?', 'Kilise', ['Sinagog', 'Cami', 'Tapınak', 'Mescit', 'Cemevi']),
    ('Yahudilerin ibadethanesine ne ad verilir?', 'Sinagog', ['Kilise', 'Cami', 'Mescit', 'Cemevi', 'Manastır']),
    ('Hristiyanlıkta haftalık kutsal gün hangisidir?', 'Pazar', ['Cuma', 'Cumartesi', 'Pazartesi', 'Perşembe', 'Çarşamba']),
    ('Yahudilikte haftalık kutsal gün (Şabat) hangisidir?', 'Cumartesi', ['Cuma', 'Pazar', 'Pazartesi', 'Perşembe', 'Çarşamba']),
    ('Hinduizmin en eski kutsal metinleri hangileridir?', 'Vedalar', ['Tevrat', 'Zebur', 'İncil', 'Tripitaka', 'Avesta']),
    ('Budizmin kurucusu kimdir?', 'Siddhartha Gautama (Buda)', ['Konfüçyüs', 'Zerdüşt', 'Lao Tzu', 'Mahavira', 'Nanak']),
    ('Hz. Muhammed\'in vefatından önce yaptığı son hacca ne ad verilir?', 'Veda Haccı', ['Umre', 'Hicret', 'Biat', 'İsra', 'Fetih']),
    ('Hz. Muhammed\'in kabrinin bulunduğu mescit hangisidir?', 'Mescid-i Nebevi', ['Mescid-i Aksa', 'Kuba Mescidi', 'Mescid-i Haram', 'Emevi Camii', 'Kâbe']),
    ('Hz. Muhammed\'e peygamberlik geldiğinde kaç yaşındaydı?', '40', ['25', '30', '35', '45', '53']),
    ('Hz. Muhammed\'in dedesinin adı nedir?', 'Abdülmuttalip', ['Ebu Talip', 'Abdullah', 'Haşim', 'Hz. Hamza', 'Hz. Abbas']),
    ('Hz. Muhammed\'in babasının adı nedir?', 'Abdullah', ['Abdülmuttalip', 'Ebu Talip', 'Haşim', 'Hz. Hamza', 'Hz. Abbas']),
    ('Hendek Savaşı\'nda şehrin etrafına hendek kazılmasını öneren sahabe kimdir?', 'Selman-ı Farisi', ['Hz. Ömer', 'Hz. Hamza', 'Bilal-i Habeşi', 'Hz. Ali', 'Halid bin Velid']),
    ('Uhud Savaşı\'nda şehit düşen Hz. Muhammed\'in amcası kimdir?', 'Hz. Hamza', ['Ebu Talip', 'Hz. Abbas', 'Ebu Leheb', 'Hz. Ali', 'Abdullah']),
    ('Kur\'an-ı Kerim yaklaşık kaç yılda indirilmiştir?', '23', ['10', '13', '30', '40', '63']),
    ('Ezan okuyan görevliye ne ad verilir?', 'Müezzin', ['İmam', 'Hafız', 'Vaiz', 'Müftü', 'Hatip']),
    ('Cuma namazında minberde yapılan dinî konuşmaya ne ad verilir?', 'Hutbe', ['Vaaz', 'Ezan', 'Kamet', 'Dua', 'Tekbir']),
    ('İslam\'da ilk müezzin kimdir?', 'Bilal-i Habeşi', ['Hz. Ömer', 'Hz. Ali', 'Selman-ı Farisi', 'Hz. Osman', 'Hz. Zeyd']),
]

ESMA = {
    'Er-Rezzak': 'Rızık veren', 'El-Halık': 'Yaratan', 'El-Alim': 'Her şeyi bilen', 'Es-Semi': 'Her şeyi işiten',
    'El-Basir': 'Her şeyi gören', 'El-Gafur': 'Çok bağışlayan', 'El-Adl': 'Mutlak adalet sahibi',
    'El-Kadir': 'Gücü her şeye yeten', 'El-Vedud': 'Kullarını çok seven', 'Es-Selam': 'Esenlik veren',
    'El-Hayy': 'Diri, ölümsüz olan', 'El-Kerim': 'Cömert, ikramı bol olan', 'El-Hakim': 'Hikmet sahibi',
    'El-Melik': 'Mülkün gerçek sahibi', 'El-Vehhab': 'Karşılıksız veren', 'El-Fettah': 'Her türlü zorluğu açan',
    'El-Latif': 'Lütfu bol olan', 'El-Hafız': 'Koruyan', 'El-Vekil': 'Kendisine güvenilen',
    'El-Ahad': 'Tek olan', 'Es-Samed': 'Hiçbir şeye muhtaç olmayan', 'El-Evvel': 'Başlangıcı olmayan',
    'El-Ahir': 'Sonu olmayan',
}
PROPHET_STORY = {
    'Tufan ve gemi kıssasıyla bilinen peygamber kimdir?': 'Hz. Nuh',
    'Oğlu İsmail ile birlikte Kâbe\'yi inşa eden peygamber kimdir?': 'Hz. İbrahim',
    'Firavun\'a karşı mücadele eden peygamber kimdir?': 'Hz. Musa',
    'Balığın karnında kaldığı anlatılan peygamber kimdir?': 'Hz. Yunus',
    'Kardeşleri tarafından kuyuya atılan ve sonra Mısır\'da yönetici olan peygamber kimdir?': 'Hz. Yusuf',
    'Hayvanların dilini anladığı anlatılan peygamber kimdir?': 'Hz. Süleyman',
    'Sabrıyla örnek gösterilen peygamber kimdir?': 'Hz. Eyüp',
    'İlk insan ve ilk peygamber kimdir?': 'Hz. Âdem',
}
PROPHETS_ALL = sorted(set(PROPHET_STORY.values()) | {'Hz. İsa', 'Hz. Davud', 'Hz. Muhammed', 'Hz. Zekeriya'})
IBADET = {
    'bedenle yapılan ibadetlerden': ['Namaz', 'Oruç'],
    'malla yapılan ibadetlerden': ['Zekât', 'Kurban', 'Fitre'],
}
CONCEPT_DEF = {
    'Abdest': 'Namaz için belirli organları yıkayarak yapılan temizlik',
    'Teyemmüm': 'Su bulunmadığında temiz toprakla yapılan temizlik',
    'Zekât': 'Zenginin malının belli bir kısmını yılda bir kez ihtiyaç sahiplerine vermesi',
    'Fitre': 'Ramazan ayında bayramdan önce verilen sadaka',
    'Sadaka': 'Karşılık beklemeden yapılan gönüllü yardım',
    'Umre': 'Yılın herhangi bir zamanında Kâbe\'nin ziyaret edilmesi',
    'Tevhit': 'Allah\'ın birliğine inanmak', 'Şirk': 'Allah\'a ortak koşmak',
    'Hicret': 'Hz. Muhammed\'in Mekke\'den Medine\'ye göçü',
    'Farz': 'Yapılması kesin olarak emredilen davranış', 'Haram': 'Yapılması kesin olarak yasaklanan davranış',
    'Mubah': 'Yapılıp yapılmaması serbest bırakılan davranış',
    'Vakıf': 'Malın topluma yararlı bir amaç için sürekli bağışlanması',
    'Kanaat': 'Elindekiyle yetinmek', 'Tevazu': 'Alçakgönüllü olmak', 'İsraf': 'Gereksiz yere harcama yapmak',
    'İhlas': 'İbadeti yalnızca Allah rızası için yapmak', 'Riya': 'İbadeti gösteriş için yapmak',
    'Tövbe': 'Günahtan pişman olup Allah\'a yönelmek', 'Tevekkül': 'Elinden geleni yapıp sonucu Allah\'a bırakmak',
    'Emanet': 'Korunması için birine bırakılan şey ya da görev',
}


@stem_limit(30)
def grup(r):
    g = r.choice(list(GROUPS))
    item = r.choice(GROUPS[g])
    return make(r, 'Temel kavramlar', f'Aşağıdakilerden hangisi {g} biridir?', item, DISTRACT.get(g, []) or [],
                f'{item}, {g} biridir.') if g in DISTRACT else None


@stem_limit(30)
def grup_degil(r):
    g = r.choice([k for k, v in GROUPS.items() if len(v) >= 4 and k in DISTRACT])
    inside = r.sample(GROUPS[g], 4)
    out = r.choice(DISTRACT[g])
    return make(r, 'Temel kavramlar', f'Aşağıdakilerden hangisi {g} biri değildir?', out, inside,
                f'{out}, {g} değildir.')


@stem_limit(1)
def melek(r):
    a = r.choice(list(ANGELS))
    if r.random() < 0.5:
        return make(r, 'Melekler', f'{a}\'in görevi aşağıdakilerden hangisidir?' if a != 'Mikail' else 'Mikail\'in görevi aşağıdakilerden hangisidir?',
                    ANGELS[a], [v for k, v in ANGELS.items() if k != a] + ['İnsanların amellerini yazmak'],
                    f'{a}: {ANGELS[a]}.')
    return make(r, 'Melekler', f'"{ANGELS[a]}" görevi hangi meleğe aittir?', a, [k for k in ANGELS if k != a] + ['Münker'],
                f'{ANGELS[a]}: {a}.')


@stem_limit(1)
def kitap(r):
    b = r.choice(list(BOOKS))
    p = BOOKS[b]
    if r.random() < 0.5:
        return make(r, 'Kutsal kitaplar', f'{b} hangi peygambere indirilmiştir?', p,
                    [x for x in BOOKS.values() if x != p] + PROPHETS_EXTRA, f'{b}: {p}.')
    return make(r, 'Kutsal kitaplar', f'{p} peygambere indirilen kitap hangisidir?', b,
                [x for x in BOOKS if x != b] + ['Suhuf'], f'{p}: {b}.')


@stem_limit(1)
def halife_sira(r):
    order = GROUPS['dört halifeden']
    i = r.randint(0, 3)
    ords = ['birinci', 'ikinci', 'üçüncü', 'dördüncü']
    return make(r, 'İslam tarihi', f'İslam tarihinde {ords[i]} halife kimdir?', order[i],
                [x for x in order if x != order[i]] + ['Hz. Hamza'], f'Sıra: {", ".join(order)}.')


@stem_limit(1)
def bilgi(r):
    q, a, others = r.choice(FACTS)
    return make(r, 'Genel bilgi', q, a, others, f'Doğru cevap: {a}.')


@stem_limit(1)
def esma(r):
    n = r.choice(list(ESMA))
    if r.random() < 0.5:
        return make(r, 'Esmaü\'l-Hüsna', f'Allah\'ın güzel isimlerinden "{n}" isminin anlamı hangisidir?', ESMA[n],
                    [v for k, v in ESMA.items() if k != n], f'{n}: {ESMA[n]}.')
    return make(r, 'Esmaü\'l-Hüsna', f'"{ESMA[n]}" anlamına gelen Allah\'ın ismi hangisidir?', n,
                [k for k in ESMA if k != n], f'{ESMA[n]}: {n}.')


@stem_limit(1)
def tanim(r):
    c = r.choice(list(CONCEPT_DEF))
    return make(r, 'Temel kavramlar', f'"{c}" kavramının anlamı aşağıdakilerden hangisidir?', CONCEPT_DEF[c],
                [v for k, v in CONCEPT_DEF.items() if k != c], f'{c}: {CONCEPT_DEF[c]}.')


@stem_limit(1)
def tanim_ters(r):
    c = r.choice(list(CONCEPT_DEF))
    return make(r, 'Temel kavramlar', f'"{CONCEPT_DEF[c]}" anlamına gelen kavram hangisidir?', c,
                [k for k in CONCEPT_DEF if k != c], f'{CONCEPT_DEF[c]}: {c}.')


@stem_limit(1)
def peygamber(r):
    q = r.choice(list(PROPHET_STORY))
    a = PROPHET_STORY[q]
    return make(r, 'Peygamberler', q, a, [p for p in PROPHETS_ALL if p != a], f'Doğru cevap: {a}.')


@stem_limit(10)
def ibadet(r):
    g = r.choice(list(IBADET))
    other = [x for k, v in IBADET.items() if k != g for x in v] + ['Hac']
    return make(r, 'İbadetler', f'Aşağıdakilerden hangisi {g} biridir?', r.choice(IBADET[g]),
                [x for x in other if x not in IBADET[g]] + ['Hac', 'Umre'], 'Namaz ve oruç bedenle; zekât, kurban ve fitre malla yapılır; hac hem beden hem malla yapılır.')


GENERATORS = [(grup, 2), (grup_degil, 3), (melek, 1), (kitap, 1), (halife_sira, 1), (bilgi, 3),
              (esma, 2), (tanim, 1), (tanim_ters, 1), (peygamber, 1), (ibadet, 1)]
