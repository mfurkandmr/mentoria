"""AYT Coğrafya-1: nüfus yoğunlukları, nüfus artışı ve sıcaklık hesapları
parametreli; Türkiye ekonomisi, projeler ve biyomlar tablodan."""
from common import define_gens, make, num_distractors, relation_gens, stem_limit

T = 'AYT_COG1'


@stem_limit(1)
def yogunluk(r):
    kind = r.choice(['aritmetik', 'fizyolojik', 'tarımsal'])
    d = r.randint(20, 250)
    area = r.choice([100, 200, 250, 400, 500, 800, 1000, 1200, 2000])
    if kind == 'aritmetik':
        pop = d * area
        q = f'Yüz ölçümü {area} km² olan bir bölgede {pop} kişi yaşamaktadır. Bu bölgenin aritmetik nüfus yoğunluğu kaç kişi/km²\'dir?'
        e = f'Aritmetik yoğunluk = nüfus / yüz ölçümü = {pop}/{area} = {d}.'
    elif kind == 'fizyolojik':
        pop = d * area
        q = f'Tarım alanı {area} km² olan bir bölgede toplam {pop} kişi yaşamaktadır. Bu bölgenin fizyolojik nüfus yoğunluğu kaç kişi/km²\'dir?'
        e = f'Fizyolojik yoğunluk = toplam nüfus / tarım alanı = {pop}/{area} = {d}.'
    else:
        pop = d * area
        total = pop * r.choice([2, 3, 4])
        q = f'Toplam nüfusu {total} olan bir bölgede tarımla geçinen nüfus {pop}, tarım alanı {area} km²\'dir. Bölgenin tarımsal nüfus yoğunluğu kaç kişi/km²\'dir?'
        e = f'Tarımsal yoğunluk = tarımla geçinen nüfus / tarım alanı = {pop}/{area} = {d}.'
    return make(r, 'Nüfus', q, d, num_distractors(r, d, max(6, d // 4)), e)


@stem_limit(1)
def dogal_artis(r):
    b = r.randint(10, 40)
    o = r.randint(4, 15)
    if o >= b:
        return None
    v = (b - o) / 10
    s = f'%{str(v).replace(".", ",").rstrip("0").rstrip(",")}'
    wrong = [b - o, (b + o) / 10, (b - o) / 100, (b - o) / 10 + 1, (b - o) / 10 - 0.5]
    return make(r, 'Nüfus', f'Doğum oranı binde {b}, ölüm oranı binde {o} olan bir ülkenin yıllık doğal nüfus artış hızı yüzde kaçtır?',
                s, [f'%{str(x).replace(".", ",").rstrip("0").rstrip(",")}' for x in wrong if x > 0],
                f'(‰{b} − ‰{o}) = ‰{b - o} = {s}.')


@stem_limit(1)
def yukselti_sicaklik(r):
    t0 = r.randint(10, 30)
    h = r.choice([400, 600, 800, 1000, 1200, 1400, 1600, 2000, 2400, 3000])
    v = t0 - h // 200
    return make(r, 'İklim', f'Deniz seviyesinde sıcaklığın {t0} °C olduğu bir yerde {h} m yükseltideki dağın zirvesinde sıcaklık yaklaşık kaç °C olur? (Her 200 m\'de 1 °C azalır)',
                f'{v} °C', [f'{x} °C' for x in num_distractors(r, v, 5, positive=False)] + [f'{t0 - h // 100} °C'],
                f'{h}/200 = {h // 200} °C azalma: {t0} − {h // 200} = {v} °C.')


@stem_limit(1)
def sicaklik_farki(r):
    mx = r.randint(18, 34)
    mn = r.randint(-12, 12)
    v = mx - mn
    return make(r, 'İklim', f'En sıcak ay ortalaması {mx} °C, en soğuk ay ortalaması {mn} °C olan bir merkezin yıllık sıcaklık farkı kaç °C\'dir?',
                f'{v} °C', [f'{x} °C' for x in num_distractors(r, v, 6)] + [f'{mx + mn} °C'], f'{mx} − ({mn}) = {v} °C.')


@stem_limit(1)
def nufus_artisi(r):
    p0 = r.choice([1000, 2000, 4000, 5000, 8000, 10000, 20000, 50000])
    pct = r.choice([5, 10, 15, 20, 25, 40, 50])
    p1 = p0 * (100 + pct) // 100
    return make(r, 'Nüfus', f'Nüfusu {p0} olan bir kasabanın nüfusu on yılda {p1} olmuştur. Bu sürede nüfus yüzde kaç artmıştır?',
                f'%{pct}', [f'%{x}' for x in num_distractors(r, pct, 6)], f'({p1} − {p0})/{p0}·100 = %{pct}.')


PRODUCTS = [
    ('Fındık', 'Karadeniz Bölgesi'), ('Çay', 'Karadeniz Bölgesi'), ('Muz', 'Akdeniz Bölgesi'), ('Turunçgiller', 'Akdeniz Bölgesi'),
    ('Zeytin', 'Ege Bölgesi'), ('İncir', 'Ege Bölgesi'), ('Çekirdeksiz kuru üzüm', 'Ege Bölgesi'), ('Antep fıstığı', 'Güneydoğu Anadolu Bölgesi'),
    ('Kırmızı mercimek', 'Güneydoğu Anadolu Bölgesi'), ('Pamuk', 'Güneydoğu Anadolu Bölgesi'), ('Şeker pancarı', 'İç Anadolu Bölgesi'),
    ('Buğday', 'İç Anadolu Bölgesi'), ('Kayısı', 'Doğu Anadolu Bölgesi'), ('Ayçiçeği', 'Marmara Bölgesi'), ('Çeltik (pirinç)', 'Marmara Bölgesi'),
]
MINES = [
    ('Taşkömürü', 'Zonguldak'), ('Petrol', 'Batman'), ('Demir', 'Divriği (Sivas)'), ('Krom', 'Guleman (Elazığ)'), ('Bakır', 'Murgul (Artvin)'),
    ('Linyit', 'Afşin-Elbistan (Kahramanmaraş)'), ('Boksit', 'Seydişehir (Konya)'), ('Bor', 'Bigadiç (Balıkesir)'), ('Fosfat', 'Mazıdağı (Mardin)'),
    ('Tuz', 'Tuz Gölü'), ('Simli kurşun', 'Keban (Elazığ)'),
]
DAMS = [
    ('Atatürk Barajı', 'Fırat'), ('Keban Barajı', 'Fırat'), ('Karakaya Barajı', 'Fırat'), ('Birecik Barajı', 'Fırat'), ('Ilısu Barajı', 'Dicle'),
    ('Hirfanlı Barajı', 'Kızılırmak'), ('Altınkaya Barajı', 'Kızılırmak'), ('Kesikköprü Barajı', 'Kızılırmak'), ('Boyabat Barajı', 'Kızılırmak'),
    ('Hasan Uğurlu Barajı', 'Yeşilırmak'), ('Sarıyar Barajı', 'Sakarya'), ('Gökçekaya Barajı', 'Sakarya'), ('Seyhan Barajı', 'Seyhan'),
    ('Aslantaş Barajı', 'Ceyhan'), ('Deriner Barajı', 'Çoruh'), ('Yusufeli Barajı', 'Çoruh'), ('Demirköprü Barajı', 'Gediz'), ('Kemer Barajı', 'Büyük Menderes'),
]
PROJECTS = {
    'GAP': 'Güneydoğu Anadolu Projesi; sulama ve enerji üretimiyle bölgenin kalkınmasını amaçlar',
    'DAP': 'Doğu Anadolu Projesi; hayvancılık ve tarımın geliştirilmesini amaçlar',
    'DOKAP': 'Doğu Karadeniz Projesi; bölgenin sanayi, turizm ve ulaşımını geliştirmeyi amaçlar',
    'KOP': 'Konya Ovası Projesi; kuraklıkla mücadele ve sulu tarımı amaçlar',
    'ZBK': 'Zonguldak-Bartın-Karabük Bölgesel Gelişme Projesi; kömür ve demir-çelik bölgesinin kalkınmasını amaçlar',
    'YHGP': 'Yeşilırmak Havzası Gelişim Projesi; havzanın çevre ve ekonomik gelişimini amaçlar',
}
BIOMES = {
    'Tundra': 'Kutuplara yakın, toprağı yılın büyük bölümünde donmuş, yosun ve likenlerin yaygın olduğu biyom',
    'Tayga': 'Soğuk iklimde görülen, iğne yapraklı ormanlardan oluşan biyom',
    'Tropikal yağmur ormanı': 'Ekvator çevresinde, her mevsim yağışlı ve sıcak, tür çeşitliliği en fazla olan biyom',
    'Savan': 'Yaz yağışlı tropikal bölgelerde, uzun boylu otlar ve seyrek ağaçlardan oluşan biyom',
    'Step (bozkır)': 'Karasal iklimde, ilkbahar yağışlarıyla yeşeren kısa boylu otlardan oluşan biyom',
    'Çöl': 'Yağışın çok az olduğu, kurakçıl bitkilerin seyrek görüldüğü biyom',
    'Maki': 'Akdeniz ikliminde, yaz kuraklığına dayanıklı, her mevsim yeşil kalan çalılardan oluşan biyom',
    'Ilıman yaprak döken orman': 'Dört mevsimin belirgin olduğu ılıman bölgelerde, sonbaharda yaprağını döken ağaçlardan oluşan biyom',
}
TERMS = {
    'Ekosistem': 'Canlıların birbirleriyle ve cansız çevreleriyle etkileşim hâlinde bulunduğu sistem',
    'Besin zinciri': 'Canlılar arasında beslenme yoluyla madde ve enerji aktarımını gösteren sıralama',
    'Nüfus piramidi': 'Nüfusun yaş gruplarına ve cinsiyete göre dağılımını gösteren grafik',
    'Göç': 'İnsanların sürekli ya da geçici olarak yaşadıkları yeri değiştirmesi',
    'Beyin göçü': 'Eğitimli ve nitelikli insanların başka ülkelere göç etmesi',
    'Kentleşme': 'Kır nüfusunun kentlere göç etmesiyle kent nüfusunun artması süreci',
    'Ekstansif tarım': 'Doğal koşullara bağlı, az emek ve teknoloji kullanılan, verimi düşük tarım',
    'Entansif tarım': 'Modern teknoloji, gübre ve sulamayla yapılan, verimi yüksek tarım',
    'Transhümans': 'Hayvanların mevsime göre yaylaya çıkarılıp kışın köye indirildiği hayvancılık',
    'Plantasyon tarımı': 'Sömürge döneminde başlayan, geniş alanda tek ürüne dayalı ticari tarım',
    'Organik tarım': 'Kimyasal gübre ve ilaç kullanılmadan yapılan tarım',
}


GENERATORS = [(yogunluk, 2), (dogal_artis, 2), (yukselti_sicaklik, 2), (sicaklik_farki, 1), (nufus_artisi, 1)] \
    + relation_gens('Türkiye\'de tarım', PRODUCTS, fwd='Türkiye\'de {item} üretiminin en fazla yapıldığı bölge hangisidir?',
                    weights=(2, 0, 0)) \
    + relation_gens('Türkiye\'de madenler', MINES, fwd='{item} yataklarıyla tanınan yer aşağıdakilerden hangisidir?',
                    weights=(2, 0, 0)) \
    + relation_gens('Türkiye\'de enerji', DAMS, fwd='{item} hangi akarsu üzerine kurulmuştur?',
                    has='Aşağıdaki barajlardan hangisi {group} üzerindedir?',
                    has_not='Aşağıdaki barajlardan hangisi {group} üzerinde değildir?', weights=(2, 1, 1), has_limit=2, has_not_limit=6) \
    + define_gens('Bölgesel kalkınma projeleri', PROJECTS, fwd='{k} kısaltmasıyla bilinen proje hangisidir?',
                  back='"{v}" hangi projedir?') \
    + define_gens('Biyomlar', BIOMES, fwd='{k} biyomunun özelliği aşağıdakilerden hangisidir?', back='"{v}" hangi biyomdur?') \
    + define_gens('Kavramlar', TERMS, fwd='"{k}" kavramı aşağıdakilerden hangisini ifade eder?', back='"{v}" hangi kavramdır?', weights=(2, 2))
