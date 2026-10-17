"""AYT Coğrafya-2: küresel ortam (kıtalar, boğazlar, örgütler), enerji ve
doğal afetler tablodan; yerel saat soruları boylamdan hesaplanır."""
from common import define_gens, make, relation_gens, stem_limit

T = 'AYT_COG2'

CONTINENT = [
    ('Nil Nehri', 'Afrika'), ('Kongo Nehri', 'Afrika'), ('Nijer Nehri', 'Afrika'), ('Zambezi Nehri', 'Afrika'),
    ('Sahra Çölü', 'Afrika'), ('Kalahari Çölü', 'Afrika'), ('Namib Çölü', 'Afrika'), ('Atlas Dağları', 'Afrika'), ('Kilimanjaro Dağı', 'Afrika'),
    ('Amazon Nehri', 'Güney Amerika'), ('Parana Nehri', 'Güney Amerika'), ('Orinoko Nehri', 'Güney Amerika'), ('Atacama Çölü', 'Güney Amerika'),
    ('Patagonya Çölü', 'Güney Amerika'), ('And Dağları', 'Güney Amerika'),
    ('Mississippi Nehri', 'Kuzey Amerika'), ('Yukon Nehri', 'Kuzey Amerika'), ('Mackenzie Nehri', 'Kuzey Amerika'), ('Mojave Çölü', 'Kuzey Amerika'),
    ('Kayalık (Rocky) Dağları', 'Kuzey Amerika'), ('Appalaş Dağları', 'Kuzey Amerika'),
    ('Yangçe Nehri', 'Asya'), ('Ganj Nehri', 'Asya'), ('Mekong Nehri', 'Asya'), ('İndus Nehri', 'Asya'), ('Gobi Çölü', 'Asya'), ('Thar Çölü', 'Asya'),
    ('Himalaya Dağları', 'Asya'), ('Altay Dağları', 'Asya'),
    ('Tuna Nehri', 'Avrupa'), ('Ren Nehri', 'Avrupa'), ('Volga Nehri', 'Avrupa'), ('Alp Dağları', 'Avrupa'), ('Pirene Dağları', 'Avrupa'), ('Karpat Dağları', 'Avrupa'),
    ('Murray Nehri', 'Okyanusya (Avustralya)'), ('Büyük Victoria Çölü', 'Okyanusya (Avustralya)'), ('Büyük Set Sıradağları', 'Okyanusya (Avustralya)'),
    ('Büyük Kum Çölü', 'Okyanusya (Avustralya)'),
]
STRAITS = {
    'Cebelitarık Boğazı': 'Akdeniz ile Atlas Okyanusu\'nu',
    'Süveyş Kanalı': 'Akdeniz ile Kızıldeniz\'i',
    'Panama Kanalı': 'Atlas Okyanusu ile Büyük Okyanus\'u',
    'Hürmüz Boğazı': 'Basra Körfezi ile Umman Denizi\'ni',
    'Babülmendep Boğazı': 'Kızıldeniz ile Aden Körfezi\'ni',
    'Malakka Boğazı': 'Hint Okyanusu ile Güney Çin Denizi\'ni',
    'Bering Boğazı': 'Kuzey Buz Denizi ile Büyük Okyanus\'u',
    'Manş Denizi': 'Kuzey Denizi ile Atlas Okyanusu\'nu',
    'İstanbul Boğazı': 'Karadeniz ile Marmara Denizi\'ni',
    'Çanakkale Boğazı': 'Marmara Denizi ile Ege Denizi\'ni',
    'Kerç Boğazı': 'Karadeniz ile Azak Denizi\'ni',
}
ORGS = [
    ('NATO', 'Brüksel'), ('Birleşmiş Milletler (BM)', 'New York'), ('OPEC', 'Viyana'), ('İslam İşbirliği Teşkilatı', 'Cidde'),
    ('UNESCO', 'Paris'), ('Dünya Sağlık Örgütü', 'Cenevre'), ('Türk Devletleri Teşkilatı', 'İstanbul'),
    ('Karadeniz Ekonomik İşbirliği Örgütü', 'İstanbul'), ('Ekonomik İşbirliği Teşkilatı (EİT)', 'Tahran'), ('ASEAN', 'Cakarta'),
    ('Avrupa Konseyi', 'Strazburg'),
]
ORG_AIM = {
    'NATO': 'Üye ülkelerin ortak savunmasını amaçlayan askerî ittifak',
    'OPEC': 'Petrol üreten ve ihraç eden ülkelerin petrol politikalarını düzenleyen örgüt',
    'Avrupa Birliği (AB)': 'Avrupa ülkeleri arasında ekonomik ve siyasi bütünleşmeyi amaçlayan birlik',
    'UNESCO': 'Eğitim, bilim ve kültür alanında iş birliğini amaçlayan BM kuruluşu',
    'UNICEF': 'Çocukların sağlık, eğitim ve haklarını korumayı amaçlayan BM kuruluşu',
    'Dünya Sağlık Örgütü (WHO)': 'Uluslararası halk sağlığını korumayı ve geliştirmeyi amaçlayan BM kuruluşu',
    'G20': 'Dünyanın büyük ekonomilerinin küresel ekonomik konuları görüştüğü forum',
    'D-8': 'Gelişmekte olan sekiz Müslüman ülkenin ekonomik iş birliği örgütü',
    'Türk Devletleri Teşkilatı': 'Türk dili konuşan ülkeler arasında iş birliğini amaçlayan örgüt',
    'Karadeniz Ekonomik İşbirliği Örgütü (KEİ)': 'Karadeniz çevresindeki ülkeler arasında ekonomik iş birliğini amaçlayan örgüt',
}
ENERGY = [
    ('Güneş enerjisi', 'yenilenebilir'), ('Rüzgâr enerjisi', 'yenilenebilir'), ('Jeotermal enerji', 'yenilenebilir'),
    ('Hidroelektrik enerji', 'yenilenebilir'), ('Biyokütle enerjisi', 'yenilenebilir'), ('Dalga enerjisi', 'yenilenebilir'),
    ('Taşkömürü', 'yenilenemez'), ('Linyit', 'yenilenemez'), ('Petrol', 'yenilenemez'), ('Doğal gaz', 'yenilenemez'), ('Uranyum (nükleer)', 'yenilenemez'),
]
HAZARDS = {
    'Deprem': 'Yer kabuğundaki kırılmalar sonucu oluşan titreşimlerin yeryüzünü sarsması',
    'Heyelan': 'Eğimli yamaçlardaki toprak ve kaya kütlelerinin yer çekimiyle kayması',
    'Çığ': 'Dağ yamaçlarında biriken kar kütlesinin aniden aşağı kayması',
    'Tsunami': 'Deniz tabanındaki deprem ya da volkanizma sonucu oluşan dev dalgalar',
    'Erozyon': 'Toprağın akarsu, rüzgâr gibi etkenlerle aşınıp taşınması',
    'Sel': 'Aşırı yağış ya da kar erimesi sonucu akarsuların taşarak çevreye zarar vermesi',
    'Kuraklık': 'Yağışın uzun süre ortalamanın altında kalmasıyla su kaynaklarının azalması',
    'Volkanizma': 'Yerin derinliklerindeki magmanın yeryüzüne çıkması',
    'Hortum': 'Dar alanda çok hızlı dönen, büyük yıkım yapan hava girdabı',
}


@stem_limit(1)
def yerel_saat(r):
    a = r.randint(-12, 12) * 15 + r.choice([0, 5, 10, -5])
    b = r.randint(-12, 12) * 15 + r.choice([0, 5, 10, -5])
    if a == b or abs(a) > 180 or abs(b) > 180:
        return None
    diff = (a - b) * 4  # dakika; doğudaki ileridedir
    h0, m0 = r.randint(0, 23), r.choice([0, 15, 30, 45])
    t = (h0 * 60 + m0 - diff) % (24 * 60)

    def lon(x):
        return f'{abs(x)}° {"doğu" if x > 0 else "batı"}' if x else '0°'

    def hm(m):
        return f'{m // 60:02d}.{m % 60:02d}'
    right = hm(t)
    wrong = {hm((h0 * 60 + m0 + diff) % 1440), hm((t + 60) % 1440), hm((t - 60) % 1440), hm((t + 30) % 1440), hm((t + 120) % 1440)} - {right}
    return make(r, 'Yerel saat', f'{lon(a)} boylamında yerel saat {hm(h0 * 60 + m0)} iken {lon(b)} boylamında yerel saat kaçtır?',
                right, sorted(wrong), f'Boylam farkı {abs(a - b)}°, her 1° 4 dakika: {abs(diff)} dk. Doğudaki ileridedir → {right}.')


GENERATORS = [(yerel_saat, 3)] \
    + relation_gens('Kıtalar', CONTINENT, fwd='{item} hangi kıtada yer alır?',
                    has='Aşağıdakilerden hangisi {group} kıtasında yer alır?',
                    has_not='Aşağıdakilerden hangisi {group} kıtasında yer almaz?', weights=(3, 2, 2), has_limit=4, has_not_limit=10,
                    extra_groups=['Antarktika']) \
    + define_gens('Boğazlar ve kanallar', STRAITS, fwd='{k} hangi iki su kütlesini birbirine bağlar?',
                  back='{v} birbirine bağlayan su yolu hangisidir?') \
    + relation_gens('Uluslararası örgütler', ORGS, fwd='{item} örgütünün merkezi hangi şehirdedir?', weights=(1, 0, 0)) \
    + define_gens('Uluslararası örgütler', ORG_AIM, fwd='{k} için aşağıdakilerden hangisi doğrudur?', back='"{v}" hangisidir?') \
    + relation_gens('Enerji kaynakları', ENERGY, fwd=None,
                    has='Aşağıdakilerden hangisi {group} enerji kaynaklarından biridir?',
                    has_not='Aşağıdakilerden hangisi {group} enerji kaynaklarından biri değildir?', weights=(0, 2, 2), has_limit=6, has_not_limit=20) \
    + define_gens('Doğal afetler', HAZARDS, fwd='{k} doğal afetinin tanımı aşağıdakilerden hangisidir?', back='"{v}" hangi doğal afettir?')
