"""TYT Türkçe: ses bilgisi (kurala göre hesaplanır), sözcük bilgisi listeleri."""
from common import make, stem_limit

T = 'TYT_TUR'
VOWELS = 'aeıioöuü'
BACK, FRONT = set('aıou'), set('eiöü')
ALPHABET = 'abcçdefgğhıijklmnoöprsştuüvyz'

WORDS = [
    'kalem', 'defter', 'kitap', 'okul', 'öğretmen', 'öğrenci', 'bilgisayar', 'pencere', 'kapı', 'masa',
    'sandalye', 'televizyon', 'buzdolabı', 'çiçek', 'ağaç', 'orman', 'deniz', 'gökyüzü', 'yıldız', 'güneş',
    'bulut', 'yağmur', 'kar', 'rüzgâr', 'toprak', 'dağ', 'nehir', 'ırmak', 'göl', 'ada', 'kelebek', 'karınca',
    'arı', 'köpek', 'kedi', 'tavşan', 'kaplumbağa', 'zürafa', 'aslan', 'kaplan', 'elma', 'armut', 'portakal',
    'mandalina', 'karpuz', 'kavun', 'üzüm', 'kiraz', 'domates', 'patates', 'havuç', 'ıspanak', 'ekmek', 'peynir',
    'zeytin', 'çorba', 'yoğurt', 'süt', 'çay', 'kahve', 'şeker', 'tuz', 'anne', 'baba', 'kardeş', 'arkadaş',
    'komşu', 'doktor', 'hemşire', 'mühendis', 'avukat', 'çiftçi', 'balıkçı', 'şoför', 'pilot', 'kitaplık',
    'gözlük', 'bilezik', 'yüzük', 'ayakkabı', 'çanta', 'şemsiye', 'saat', 'telefon', 'radyo', 'gazete',
    'dergi', 'mektup', 'zarf', 'pul', 'harita', 'ülke', 'şehir', 'kasaba', 'köy', 'mahalle', 'sokak', 'cadde',
    'köprü', 'otobüs', 'tren', 'uçak', 'gemi', 'bisiklet', 'motosiklet', 'araba', 'yolculuk', 'bayram',
    'düğün', 'misafir', 'hediye', 'sevgi', 'saygı', 'mutluluk', 'üzüntü', 'korku', 'cesaret', 'umut',
    'özgürlük', 'bağımsızlık', 'cumhuriyet', 'demokrasi', 'adalet', 'barış', 'savaş', 'tarih', 'coğrafya',
    'matematik', 'edebiyat', 'resim', 'müzik', 'tiyatro', 'sinema', 'hikâye', 'roman', 'şiir', 'masal',
    'destan', 'kahraman', 'ordu', 'asker', 'bayrak', 'marş', 'vatan', 'millet', 'devlet', 'insan', 'hayat',
    'zaman', 'mevsim', 'ilkbahar', 'sonbahar', 'kış', 'yaz', 'sabah', 'akşam', 'gece', 'gündüz', 'öğle',
    'pazartesi', 'çarşamba', 'cumartesi', 'kitapçı', 'çalışkan', 'güzel', 'mavi', 'yeşil', 'kırmızı', 'sarı',
    'turuncu', 'mor', 'beyaz', 'siyah', 'büyük', 'küçük', 'uzun', 'kısa', 'geniş', 'dar', 'kolay', 'zor',
    'hızlı', 'yavaş', 'akıllı', 'cömert', 'sabırlı', 'dürüst', 'nazik', 'neşeli', 'yorgun', 'heyecan',
    'merak', 'bilgi', 'düşünce', 'duygu', 'hayal', 'rüya', 'oyun', 'oyuncak', 'top', 'uçurtma', 'kumsal',
    'dalga', 'liman', 'fener', 'kale', 'saray', 'cami', 'kütüphane', 'müze', 'hastane', 'eczane', 'fırın',
    'pazar', 'manav', 'kasap', 'terzi', 'berber',
]


def vowels(w):
    return [c for c in w.replace('â', 'a').replace('î', 'i').replace('û', 'u') if c in VOWELS]


def buyuk_uyum(w):
    v = set(vowels(w))
    return v <= BACK or v <= FRONT


def kucuk_uyum(w):
    v = vowels(w)
    for a, b in zip(v, v[1:]):
        if a in 'aeıi' and b not in 'aeıi':
            return False
        if a in 'oöuü' and b not in 'aeuü':
            return False
    return True


def tr_key(w):
    w = w.replace('â', 'a').replace('î', 'i').replace('û', 'u')
    return [ALPHABET.index(c) for c in w if c in ALPHABET]


def hece(r):
    w = r.choice(WORDS)
    n = len(vowels(w))
    return make(r, 'Ses bilgisi', f'"{w}" sözcüğü kaç hecelidir?', n,
                [x for x in range(1, 7) if x != n], 'Türkçede her hecede bir ünlü bulunur; ünlü sayısı hece sayısını verir.')


def _odd_one(r, rule, want_false):
    good = [w for w in WORDS if rule(w) and len(vowels(w)) >= 2]
    bad = [w for w in WORDS if not rule(w) and len(vowels(w)) >= 2]
    if want_false:
        return r.choice(bad), r.sample(good, 4)
    return r.choice(good), r.sample(bad, 4)


@stem_limit(45)
def buyuk_uymaz(r):
    ans, others = _odd_one(r, buyuk_uyum, True)
    return make(r, 'Ses bilgisi', 'Aşağıdaki sözcüklerden hangisi büyük ünlü uyumuna uymaz?', ans, others,
                f'"{ans}" sözcüğünde hem kalın hem ince ünlü bulunur.')


@stem_limit(45)
def buyuk_uyar(r):
    ans, others = _odd_one(r, buyuk_uyum, False)
    return make(r, 'Ses bilgisi', 'Aşağıdaki sözcüklerden hangisi büyük ünlü uyumuna uyar?', ans, others,
                f'"{ans}" sözcüğünün ünlüleri hep {"kalın" if set(vowels(ans)) <= BACK else "ince"}.')


@stem_limit(35)
def kucuk_uymaz(r):
    ans, others = _odd_one(r, kucuk_uyum, True)
    return make(r, 'Ses bilgisi', 'Aşağıdaki sözcüklerden hangisi küçük ünlü uyumuna uymaz?', ans, others,
                'Düz ünlüden sonra düz; yuvarlak ünlüden sonra düz-geniş (a, e) ya da dar-yuvarlak (u, ü) gelmelidir.')


HARD_ROOTS = ['sokak', 'kitap', 'ağaç', 'süt', 'çocuk', 'kulak', 'yaprak', 'park', 'sepet', 'saç',
              'kat', 'top', 'ip', 'dert', 'renk', 'ekmek', 'çiçek', 'bilet', 'ses', 'göğüs', 'kış', 'baş', 'güneş',
              'cep', 'uçak', 'tabak', 'dolap', 'çanak', 'kazak', 'kabuk', 'hukuk', 'tarih']
SOFT_ROOTS = ['ev', 'okul', 'masa', 'kapı', 'deniz', 'yol', 'oda', 'köy', 'şehir', 'bahçe', 'göl', 'dağ',
              'kalem', 'defter', 'pencere', 'araba', 'çarşı', 'saray', 'liman', 'orman', 'ova', 'yayla']


def _suffix_da(root):
    v = vowels(root)[-1]
    hard = root[-1] in 'fstkçşhp'
    a = 'a' if v in BACK else 'e'
    return root + ('t' if hard else 'd') + a


@stem_limit(30)
def benzesme(r):
    if r.random() < 0.5:
        hard = r.choice([w for w in HARD_ROOTS if w != 'tarih'])
        ans = _suffix_da(hard)
        others = [_suffix_da(w) for w in r.sample(SOFT_ROOTS, 4)]
        return make(r, 'Ses olayları', 'Aşağıdaki sözcüklerin hangisinde ünsüz benzeşmesi (sertleşme) vardır?', ans, others,
                    f'Sert ünsüzle biten "{hard}" sözcüğüne gelen -da/-de eki -ta/-te olur: {ans}.')
    ans = _suffix_da(r.choice(SOFT_ROOTS))
    others = [_suffix_da(w) for w in r.sample([w for w in HARD_ROOTS if w != 'tarih'], 4)]
    return make(r, 'Ses olayları', 'Aşağıdaki sözcüklerin hangisinde ünsüz benzeşmesi (sertleşme) yoktur?', ans, others,
                f'"{ans}" sözcüğünde kök sert ünsüzle bitmediği için ek değişmemiştir.')


SOFTENS = {'kitap': 'kitabı', 'dolap': 'dolabı', 'ağaç': 'ağacı', 'kanat': 'kanadı', 'ayak': 'ayağı',
           'çocuk': 'çocuğu', 'kulak': 'kulağı', 'yaprak': 'yaprağı', 'renk': 'rengi', 'ekmek': 'ekmeği',
           'bıçak': 'bıçağı', 'toprak': 'toprağı', 'tabak': 'tabağı', 'kazak': 'kazağı', 'sokak': 'sokağı',
           'armut': 'armudu', 'yoğurt': 'yoğurdu', 'kurt': 'kurdu', 'dert': 'derdi', 'kalp': 'kalbi',
           'cep': 'cebi', 'dip': 'dibi', 'uç': 'ucu', 'güç': 'gücü', 'taç': 'tacı', 'çorap': 'çorabı',
           'kabuk': 'kabuğu', 'bilek': 'bileği', 'çiçek': 'çiçeği', 'köpek': 'köpeği'}
NO_SOFTEN = {'top': 'topu', 'at': 'atı', 'saç': 'saçı', 'ip': 'ipi', 'ok': 'oku', 'et': 'eti',
             'süt': 'sütü', 'sepet': 'sepeti', 'hukuk': 'hukuku', 'millet': 'milleti', 'devlet': 'devleti',
             'kibrit': 'kibriti', 'bisiklet': 'bisikleti', 'tank': 'tankı', 'park': 'parkı', 'kat': 'katı',
             'bilet': 'bileti', 'sınıf': 'sınıfı', 'hak': 'hakkı', 'ahlak': 'ahlakı'}


@stem_limit(30)
def yumusama(r):
    if r.random() < 0.5:
        root = r.choice(list(NO_SOFTEN))
        others = r.sample(list(SOFTENS), 4)
        return make(r, 'Ses olayları', 'Aşağıdaki sözcüklerin hangisine ünlüyle başlayan bir ek getirildiğinde ünsüz yumuşaması olmaz?', root, others,
                    f'{root} → {NO_SOFTEN[root]}: son ünsüz değişmez.')
    root = r.choice(list(SOFTENS))
    others = r.sample(list(NO_SOFTEN), 4)
    return make(r, 'Ses olayları', 'Aşağıdaki sözcüklerin hangisine ünlüyle başlayan bir ek getirildiğinde ünsüz yumuşaması olur?', root, others,
                f'{root} → {SOFTENS[root]}.')


DROPS = {'ağız': 'ağzı', 'burun': 'burnu', 'oğul': 'oğlu', 'alın': 'alnı', 'beyin': 'beyni', 'gönül': 'gönlü',
         'karın': 'karnı', 'boyun': 'boynu', 'akıl': 'aklı', 'fikir': 'fikri', 'şehir': 'şehri', 'resim': 'resmi',
         'isim': 'ismi', 'emir': 'emri', 'sabır': 'sabrı', 'zehir': 'zehri', 'metin': 'metni', 'nesil': 'nesli',
         'ömür': 'ömrü', 'devir': 'devri', 'hüküm': 'hükmü', 'kahır': 'kahrı', 'şekil': 'şekli', 'vakit': 'vakti'}
NO_DROP = ['kalem', 'kitap', 'ekmek', 'bilet', 'araba', 'kapı', 'deniz', 'okul', 'pencere', 'kalın', 'tavuk',
           'uzun', 'ekin', 'kuzu', 'yemek', 'bulut', 'demir', 'çamur', 'güneş', 'kazan']


@stem_limit(35)
def dusme(r):
    w = r.choice(list(DROPS))
    return make(r, 'Ses olayları', 'Aşağıdaki sözcüklerin hangisine ünlüyle başlayan bir ek getirildiğinde ünlü düşmesi görülür?', w,
                r.sample(NO_DROP, 4), f'{w} → {DROPS[w]}: ikinci hecedeki dar ünlü düşer.')


SYN = [
    ('siyah', 'kara'), ('beyaz', 'ak'), ('kırmızı', 'al'), ('yaşlı', 'ihtiyar'), ('cevap', 'yanıt'),
    ('okul', 'mektep'), ('öğrenci', 'talebe'), ('hediye', 'armağan'), ('misafir', 'konuk'), ('yıl', 'sene'),
    ('ad', 'isim'), ('soru', 'sual'), ('ırmak', 'nehir'), ('kâğıt', 'kâğıt'), ('doğa', 'tabiat'),
    ('özgür', 'hür'), ('millet', 'ulus'), ('cümle', 'tümce'), ('örnek', 'misal'), ('şiir', 'nazım'),
    ('fakir', 'yoksul'), ('zengin', 'varlıklı'), ('cesur', 'yürekli'), ('kalp', 'yürek'), ('akıl', 'us'),
    ('düşünce', 'fikir'), ('neden', 'sebep'), ('sonuç', 'netice'), ('deneme', 'tecrübe'), ('ilim', 'bilim'),
    ('hekim', 'doktor'), ('ödül', 'mükâfat'), ('sınav', 'imtihan'), ('anı', 'hatıra'), ('dost', 'arkadaş'),
    ('kent', 'şehir'), ('ülke', 'memleket'), ('yurt', 'vatan'), ('savaş', 'harp'), ('barış', 'sulh'),
    ('ilgi', 'alaka'), ('acele', 'ivedi'), ('kural', 'kaide'), ('olanak', 'imkân'), ('gereksinim', 'ihtiyaç'),
    ('yetenek', 'kabiliyet'), ('özen', 'itina'), ('yardım', 'destek'), ('rüzgâr', 'yel'), ('yokuş', 'bayır'),
    ('köprü', 'köprü'), ('çaba', 'gayret'), ('uyarı', 'ikaz'), ('dinlenme', 'istirahat'), ('ağaç', 'ağaç'),
    ('kıymet', 'değer'), ('sevinç', 'neşe'), ('üzüntü', 'keder'), ('istek', 'arzu'), ('umut', 'ümit'),
    ('vakit', 'zaman'), ('yanlış', 'hata'), ('hızlı', 'süratli'), ('ebat', 'boyut'),
    ('cimri', 'pinti'), ('aşk', 'sevda'), ('kuşku', 'şüphe'), ('saygı', 'hürmet'), ('dürüst', 'doğru sözlü'),
    ('zor', 'güç'), ('kolay', 'basit'), ('temiz', 'pak'), ('tuhaf', 'garip'), ('hasta', 'rahatsız'),
    ('yalnız', 'tek başına'), ('kocaman', 'iri'), ('ölümsüz', 'ebedi'), ('ilk', 'evvel'), ('son', 'nihayet'),
]
SYN = [(a, b) for a, b in SYN if a != b]


def _clusters(pairs):
    """Eş anlamlı zincirleri (yurt-vatan-memleket-ülke) tek küme; çeldirici
    olarak aynı kümeden sözcük seçilmez."""
    group = {}
    for a, b in pairs:
        ga, gb = group.get(a, {a}), group.get(b, {b})
        merged = ga | gb
        for w in merged:
            group[w] = merged
    return group


SYN_GROUP = _clusters(SYN)
ANT = [
    ('büyük', 'küçük'), ('uzun', 'kısa'), ('geniş', 'dar'), ('kolay', 'zor'), ('hızlı', 'yavaş'),
    ('sıcak', 'soğuk'), ('ağır', 'hafif'), ('yeni', 'eski'), ('genç', 'yaşlı'), ('zengin', 'yoksul'),
    ('erken', 'geç'), ('kalın', 'ince'), ('derin', 'sığ'), ('acı', 'tatlı'), ('aydınlık', 'karanlık'),
    ('sevinç', 'üzüntü'), ('cesur', 'korkak'), ('çalışkan', 'tembel'), ('dost', 'düşman'), ('savaş', 'barış'),
    ('gece', 'gündüz'), ('sabah', 'akşam'), ('giriş', 'çıkış'), ('alçak', 'yüksek'), ('ileri', 'geri'),
    ('iç', 'dış'), ('ön', 'arka'), ('alt', 'üst'), ('doğru', 'yanlış'), ('var', 'yok'), ('dolu', 'boş'),
    ('açık', 'kapalı'), ('temiz', 'kirli'), ('ıslak', 'kuru'), ('sert', 'yumuşak'), ('pahalı', 'ucuz'),
    ('cömert', 'cimri'), ('sessiz', 'gürültülü'), ('mutlu', 'mutsuz'), ('güçlü', 'güçsüz'), ('kazanmak', 'kaybetmek'),
    ('almak', 'vermek'), ('gelmek', 'gitmek'), ('açmak', 'kapamak'), ('ağlamak', 'gülmek'), ('başlamak', 'bitirmek'),
    ('sevmek', 'nefret etmek'), ('hatırlamak', 'unutmak'), ('yükselmek', 'alçalmak'), ('artmak', 'azalmak'),
    ('kabul', 'ret'), ('ilk', 'son'), ('az', 'çok'), ('yakın', 'uzak'), ('güzel', 'çirkin'), ('akıllı', 'akılsız'),
    ('olumlu', 'olumsuz'), ('somut', 'soyut'), ('nesnel', 'öznel'), ('yerli', 'yabancı'), ('kara', 'ak'),
]


@stem_limit(1)
def es_anlam(r):
    a, b = r.choice(SYN)
    if r.random() < 0.5:
        a, b = b, a
    pool = sorted({x for p in SYN for x in p} - SYN_GROUP[a])
    return make(r, 'Sözcükte anlam', f'"{a}" sözcüğünün eş anlamlısı aşağıdakilerden hangisidir?', b, r.sample(pool, 8),
                f'{a} = {b}.')


@stem_limit(1)
def zit_anlam(r):
    a, b = r.choice(ANT)
    if r.random() < 0.5:
        a, b = b, a
    pool = sorted({x for p in ANT for x in p} - {a, b})
    return make(r, 'Sözcükte anlam', f'"{a}" sözcüğünün zıt (karşıt) anlamlısı aşağıdakilerden hangisidir?', b, r.sample(pool, 8),
                f'{a} ↔ {b}.')


@stem_limit(60)
def sozluk(r):
    words = r.sample(WORDS, 5)
    first = min(words, key=tr_key)
    others = [w for w in words if w != first]
    return make(r, 'Sözlük bilgisi', 'Aşağıdaki sözcüklerden hangisi sözlükte diğerlerinden önce yer alır?', first, others,
                'Türk alfabesi sırası: a b c ç d e f g ğ h ı i j k l m n o ö p r s ş t u ü v y z.')


@stem_limit(60)
def sozluk_son(r):
    words = r.sample(WORDS, 5)
    last = max(words, key=tr_key)
    others = [w for w in words if w != last]
    return make(r, 'Sözlük bilgisi', 'Aşağıdaki sözcüklerden hangisi sözlükte diğerlerinden sonra yer alır?', last, others,
                'Türk alfabesi sırası: a b c ç d e f g ğ h ı i j k l m n o ö p r s ş t u ü v y z.')


COMPOUND = ['hanımeli', 'aslanağzı', 'kuşburnu', 'bilgisayar', 'açıkgöz', 'karabiber', 'ayakkabı',
            'başöğretmen', 'Akdeniz', 'buzdolabı', 'gökdelen', 'cumartesi', 'kaynana', 'babaanne',
            'atkuyruğu', 'çekyat', 'demiryolu', 'hanımeli', 'imambayıldı', 'kahverengi', 'pazartesi',
            'suçiçeği', 'bugün', 'karadut', 'Kuşadası', 'dedikodu']
SIMPLE = ['kalem', 'kitap', 'masa', 'pencere', 'okul', 'deniz', 'çiçek', 'bulut', 'ırmak', 'kelebek',
          'sandalye', 'öğrenci', 'zeytin', 'portakal', 'merdiven', 'kapı', 'yağmur', 'yıldız', 'tavşan']


@stem_limit(30)
def birlesik(r):
    ans = r.choice(sorted(set(COMPOUND)))
    return make(r, 'Sözcük yapısı', 'Aşağıdaki sözcüklerden hangisi birleşik sözcüktür?', ans, r.sample(SIMPLE, 4),
                f'"{ans}" iki ayrı sözcüğün birleşmesiyle oluşmuştur.')


GENERATORS = [
    (hece, 6), (buyuk_uymaz, 3), (buyuk_uyar, 2), (kucuk_uymaz, 2), (benzesme, 3), (yumusama, 3),
    (dusme, 2), (es_anlam, 4), (zit_anlam, 4), (sozluk, 2), (sozluk_son, 2), (birlesik, 2),
]
