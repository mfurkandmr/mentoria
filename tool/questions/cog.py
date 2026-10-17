"""TYT Coğrafya: il-bölge tablosu ve harita/iklim hesapları."""
from common import fmt_num, make, num_distractors, stem_limit

T = 'TYT_COG'

REGIONS = {
    'Marmara': ['İstanbul', 'Edirne', 'Kırklareli', 'Tekirdağ', 'Çanakkale', 'Balıkesir', 'Bursa',
                'Bilecik', 'Kocaeli', 'Sakarya', 'Yalova'],
    'Ege': ['İzmir', 'Manisa', 'Aydın', 'Denizli', 'Muğla', 'Uşak', 'Kütahya', 'Afyonkarahisar'],
    'Akdeniz': ['Antalya', 'Isparta', 'Burdur', 'Mersin', 'Adana', 'Osmaniye', 'Hatay', 'Kahramanmaraş'],
    'İç Anadolu': ['Ankara', 'Konya', 'Eskişehir', 'Kayseri', 'Sivas', 'Yozgat', 'Kırşehir', 'Kırıkkale',
                   'Nevşehir', 'Niğde', 'Aksaray', 'Karaman', 'Çankırı'],
    'Karadeniz': ['Zonguldak', 'Bartın', 'Karabük', 'Düzce', 'Bolu', 'Kastamonu', 'Sinop', 'Samsun',
                  'Amasya', 'Çorum', 'Tokat', 'Ordu', 'Giresun', 'Trabzon', 'Rize', 'Artvin', 'Gümüşhane', 'Bayburt'],
    'Doğu Anadolu': ['Erzurum', 'Erzincan', 'Kars', 'Ardahan', 'Iğdır', 'Ağrı', 'Van', 'Muş', 'Bitlis',
                     'Bingöl', 'Elazığ', 'Malatya', 'Tunceli', 'Hakkari'],
    'Güneydoğu Anadolu': ['Gaziantep', 'Kilis', 'Şanlıurfa', 'Adıyaman', 'Diyarbakır', 'Mardin', 'Batman',
                          'Siirt', 'Şırnak'],
}
assert sum(len(v) for v in REGIONS.values()) == 81
REGION_OF = {il: b for b, ils in REGIONS.items() for il in ils}


@stem_limit(1)
def il_bolge(r):
    il = r.choice(list(REGION_OF))
    b = REGION_OF[il]
    return make(r, 'Türkiye\'nin bölgeleri', f'{il} ili hangi coğrafi bölgede yer alır?', f'{b} Bölgesi',
                [f'{x} Bölgesi' for x in REGIONS if x != b], f'{il}: {b} Bölgesi.')


@stem_limit(30)
def bolge_disinda(r):
    b = r.choice(list(REGIONS))
    inside = r.sample(REGIONS[b], 4)
    out = r.choice([il for il in REGION_OF if REGION_OF[il] != b])
    return make(r, 'Türkiye\'nin bölgeleri', f'Aşağıdaki illerden hangisi {b} Bölgesi\'nde yer almaz?', out, inside,
                f'{out}, {REGION_OF[out]} Bölgesi\'ndedir.')


def olcek(r):
    s = r.choice([100000, 200000, 250000, 500000, 1000000, 2000000, 5000000])
    cm = r.randint(1, 15)
    km = cm * s / 100000
    return make(r, 'Harita bilgisi', f'1/{s:,} ölçekli bir haritada iki şehir arası {cm} cm\'dir. Gerçek uzaklık kaç km\'dir?'.replace(',', '.'),
                fmt_num(km), [fmt_num(x) for x in [km * 10, km / 10, km * 2, km + cm, cm * s / 1000]],
                f'{cm} cm × {s:,} = {cm * s:,} cm = {fmt_num(km)} km.'.replace(',', '.'))


def olcek_ters(r):
    s = r.choice([100000, 200000, 500000, 1000000])
    km = r.randint(2, 40) * s // 100000
    cm = km * 100000 // s
    return make(r, 'Harita bilgisi', f'Gerçekte {km} km olan bir uzaklık 1/{s:,} ölçekli haritada kaç cm ile gösterilir?'.replace(',', '.'),
                cm, num_distractors(r, cm, 5) + [cm * 10, km],
                f'{km} km = {km * 100000:,} cm; ÷ {s:,} = {cm} cm.'.replace(',', '.'))


def saat_farki(r):
    a, b = sorted(r.sample(range(0, 180, 5), 2))
    diff = (b - a) * 4
    h = r.randint(6, 14)
    tot = h * 60 + diff
    hh, mm = divmod(tot, 60)
    if hh >= 24:
        return None
    ans = f'{hh:02d}.{mm:02d}'
    wrong = []
    for d in [-diff, diff // 2, diff * 2, diff + 60, -diff + 60]:
        t = h * 60 + d
        if 0 <= t < 24 * 60:
            wrong.append(f'{t // 60:02d}.{t % 60:02d}')
    return make(r, 'Dünya\'nın hareketleri', f'{a}° doğu boylamındaki A şehrinde yerel saat {h:02d}.00 iken {b}° doğu boylamındaki B şehrinde yerel saat kaçtır?',
                ans, wrong, f'Her 1° boylam farkı 4 dakikadır: {b - a} · 4 = {diff} dk; doğudaki şehrin saati ileridir.')


def yukselti(r):
    t0 = r.randint(15, 30)
    h = r.randint(2, 20) * 200
    t = t0 - h // 200
    return make(r, 'İklim', f'Deniz seviyesinde sıcaklığın {t0} °C olduğu bir yerde {h} m yükseklikteki bir dağın zirvesinde sıcaklık kaç °C olur? (Her 200 m\'de 1 °C azaldığı varsayılıyor)',
                t, num_distractors(r, t, 5, positive=False) + [t0 - h // 100],
                f'{h} / 200 = {h // 200} °C azalır: {t0} − {h // 200} = {t}.')


def yogunluk(r):
    alan = r.randint(2, 40) * 1000
    d = r.randint(10, 400)
    n = alan * d
    return make(r, 'Nüfus', f'Yüzölçümü {alan:,} km² ve nüfusu {n:,} olan bir ilin aritmetik nüfus yoğunluğu kaç kişi/km²\'dir?'.replace(',', '.'),
                d, num_distractors(r, d, 30),
                f'Yoğunluk = nüfus / alan = {d} kişi/km².')


FACTS = [
    ('Türkiye\'nin en yüksek dağı hangisidir?', 'Ağrı Dağı', ['Erciyes Dağı', 'Süphan Dağı', 'Uludağ', 'Kaçkar Dağı', 'Hasan Dağı']),
    ('Türkiye\'nin yüzölçümü en büyük gölü hangisidir?', 'Van Gölü', ['Tuz Gölü', 'Beyşehir Gölü', 'Eğirdir Gölü', 'İznik Gölü', 'Burdur Gölü']),
    ('Türkiye sınırları içinde doğup yine Türkiye\'de denize dökülen en uzun akarsu hangisidir?', 'Kızılırmak', ['Fırat', 'Sakarya', 'Yeşilırmak', 'Dicle', 'Seyhan']),
    ('Türkiye\'nin yüzölçümü en büyük ili hangisidir?', 'Konya', ['Sivas', 'Ankara', 'Erzurum', 'Antalya', 'Van']),
    ('Türkiye\'nin yüzölçümü en küçük ili hangisidir?', 'Yalova', ['Kilis', 'Bartın', 'Bayburt', 'Düzce', 'Iğdır']),
    ('Türkiye\'nin nüfusu en kalabalık ili hangisidir?', 'İstanbul', ['Ankara', 'İzmir', 'Bursa', 'Antalya', 'Konya']),
    ('Her mevsim yağışlı olan iklim tipi hangisidir?', 'Karadeniz iklimi', ['Akdeniz iklimi', 'Karasal iklim', 'Çöl iklimi', 'Tundra iklimi', 'Muson iklimi']),
    ('Yazları sıcak ve kurak, kışları ılık ve yağışlı geçen iklim tipi hangisidir?', 'Akdeniz iklimi', ['Karadeniz iklimi', 'Karasal iklim', 'Ekvatoral iklim', 'Tundra iklimi', 'Okyanusal iklim']),
    ('Akdeniz ikliminin doğal bitki örtüsü hangisidir?', 'Maki', ['Bozkır (step)', 'Tundra', 'Savan', 'Çayır', 'Tayga']),
    ('Karasal iklimin görüldüğü İç Anadolu\'nun doğal bitki örtüsü hangisidir?', 'Bozkır (step)', ['Maki', 'Orman', 'Savan', 'Tundra', 'Çalı']),
    ('Türkiye\'de çay tarımının en çok yapıldığı il hangisidir?', 'Rize', ['Trabzon', 'Ordu', 'Samsun', 'Artvin', 'Giresun']),
    ('Türkiye\'de pamuk üretiminin en fazla olduğu il hangisidir?', 'Şanlıurfa', ['Adana', 'Aydın', 'İzmir', 'Hatay', 'Diyarbakır']),
    ('Türkiye\'nin kuzeyinden geçen ve büyük depremlere neden olan fay hattı hangisidir?', 'Kuzey Anadolu Fay Hattı', ['Doğu Anadolu Fay Hattı', 'Batı Anadolu Fay Hattı', 'Ölü Deniz Fayı', 'Ege Graben Sistemi', 'Tuz Gölü Fayı']),
    ('Dünya\'nın kendine özgü şekline ne ad verilir?', 'Geoit', ['Küre', 'Elips', 'Silindir', 'Ekliptik', 'Ekvator']),
    ('Başlangıç meridyeni olarak kabul edilen meridyen hangi şehirden geçer?', 'Londra (Greenwich)', ['Paris', 'İstanbul', 'New York', 'Roma', 'Tokyo']),
    ('Dünya kendi ekseni etrafındaki bir dönüşünü yaklaşık kaç saatte tamamlar?', '24', ['12', '48', '6', '36', '365']),
    ('Kuzey Yarım Küre\'de en uzun gündüzün yaşandığı tarih hangisidir?', '21 Haziran', ['21 Aralık', '21 Mart', '23 Eylül', '1 Ocak', '15 Temmuz']),
    ('21 Haziran\'da Güneş ışınlarının öğle vakti dik geldiği enlem hangisidir?', 'Yengeç Dönencesi', ['Oğlak Dönencesi', 'Ekvator', 'Kuzey Kutup Dairesi', 'Güney Kutup Dairesi', 'Başlangıç meridyeni']),
    ('21 Aralık\'ta Güneş ışınlarının öğle vakti dik geldiği enlem hangisidir?', 'Oğlak Dönencesi', ['Yengeç Dönencesi', 'Ekvator', 'Kuzey Kutup Dairesi', 'Güney Kutup Dairesi', 'Başlangıç meridyeni']),
    ('21 Mart ve 23 Eylül\'de Güneş ışınlarının öğle vakti dik geldiği enlem hangisidir?', 'Ekvator', ['Yengeç Dönencesi', 'Oğlak Dönencesi', 'Kuzey Kutup Dairesi', 'Güney Kutup Dairesi', '45° Kuzey paraleli']),
    ('Haritalarda aynı yükseltideki noktaları birleştiren eğrilere ne ad verilir?', 'Eş yükselti eğrisi', ['Eş sıcaklık eğrisi', 'Eş basınç eğrisi', 'Paralel', 'Meridyen', 'Profil']),
    ('Türkiye hangi kuzey enlemleri arasında yer alır?', '36° - 42°', ['26° - 45°', '30° - 36°', '42° - 48°', '20° - 30°', '45° - 50°']),
    ('Türkiye hangi doğu boylamları arasında yer alır?', '26° - 45°', ['36° - 42°', '20° - 30°', '40° - 50°', '10° - 26°', '45° - 60°']),
    ('Fındık üretiminin en yoğun olduğu bölge hangisidir?', 'Karadeniz Bölgesi', ['Marmara Bölgesi', 'Ege Bölgesi', 'Akdeniz Bölgesi', 'İç Anadolu Bölgesi', 'Doğu Anadolu Bölgesi']),
    ('Zeytin ve zeytinyağı üretiminde öne çıkan bölge hangisidir?', 'Ege Bölgesi', ['Karadeniz Bölgesi', 'İç Anadolu Bölgesi', 'Doğu Anadolu Bölgesi', 'Güneydoğu Anadolu Bölgesi', 'Marmara Bölgesi']),
    ('Turunçgil (portakal, limon) tarımının en çok yapıldığı bölge hangisidir?', 'Akdeniz Bölgesi', ['Karadeniz Bölgesi', 'İç Anadolu Bölgesi', 'Doğu Anadolu Bölgesi', 'Ege Bölgesi', 'Marmara Bölgesi']),
    ('Büyükbaş hayvancılığın en yaygın olduğu bölge hangisidir?', 'Doğu Anadolu Bölgesi', ['Ege Bölgesi', 'Akdeniz Bölgesi', 'Marmara Bölgesi', 'Karadeniz Bölgesi', 'İç Anadolu Bölgesi']),
]


@stem_limit(1)
def bilgi(r):
    q, a, others = r.choice(FACTS)
    return make(r, 'Genel bilgi', q, a, others, f'Doğru cevap: {a}.')


GENERATORS = [(il_bolge, 4), (bolge_disinda, 3), (olcek, 2), (olcek_ters, 2), (saat_farki, 2),
              (yukselti, 2), (yogunluk, 2), (bilgi, 1)]
