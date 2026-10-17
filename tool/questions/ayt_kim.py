"""AYT Kimya: gazlar, çözeltiler, pH, denge, hız, termokimya, elektrokimya
hesapları parametreli; organik ve periyodik sistem soruları tablodan."""
from fractions import Fraction

from common import define_gens, fact_gen, fmt_frac, fmt_num, make, num_distractors, relation_gens, stem_limit

T = 'AYT_KIM'


def u(v, unit):
    return f'{fmt_num(v) if not isinstance(v, Fraction) else fmt_num(float(v))} {unit}'


@stem_limit(1)
def nsa_hacim(r):
    n = r.choice([Fraction(1, 4), Fraction(1, 2), Fraction(1), Fraction(3, 2), Fraction(2), Fraction(5, 2), Fraction(3), Fraction(4), Fraction(5)])
    v = n * Fraction(224, 10)
    if r.random() < 0.5:
        return make(r, 'Gazlar', f'Normal şartlarda (NŞ) {fmt_num(float(n))} mol ideal gaz kaç litre hacim kaplar?', u(v, 'L'),
                    [u(x, 'L') for x in [v * 2, v / 2, n * Fraction(245, 10), v + Fraction(224, 10), n * 22]],
                    f'NŞ\'de 1 mol gaz 22,4 L: {fmt_num(float(n))}·22,4 = {fmt_num(float(v))} L.')
    return make(r, 'Gazlar', f'Normal şartlarda {fmt_num(float(v))} L hacim kaplayan ideal gaz kaç moldür?', u(n, 'mol'),
                [u(x, 'mol') for x in [n * 2, n / 2, n + 1, n + Fraction(1, 2), n * 3] if x != n],
                f'n = V/22,4 = {fmt_num(float(v))}/22,4 = {fmt_num(float(n))} mol.')


@stem_limit(1)
def boyle(r):
    p1, v1 = r.randint(1, 6), r.randint(2, 12)
    p2 = r.randint(1, 8)
    v2 = Fraction(p1 * v1, p2)
    if v2.denominator != 1 or p1 == p2:
        return None
    return make(r, 'Gazlar', f'Sabit sıcaklıkta {p1} atm basınçta {v1} L hacim kaplayan gazın basıncı {p2} atm yapılırsa hacmi kaç L olur?',
                u(int(v2), 'L'), [u(x, 'L') for x in num_distractors(r, int(v2), 4)] + [u(v1, 'L')],
                f'P₁V₁ = P₂V₂ → {p1}·{v1} = {p2}·V₂ → V₂ = {int(v2)} L.')


@stem_limit(1)
def charles(r):
    t1 = r.choice([100, 200, 250, 300, 400, 500])
    k = r.choice([Fraction(1, 2), Fraction(3, 2), Fraction(2), Fraction(3)])
    v1 = r.randint(2, 10)
    t2 = t1 * k
    v2 = v1 * k
    if t2.denominator != 1 or v2.denominator != 1:
        return None
    return make(r, 'Gazlar', f'Sabit basınçta {t1} K sıcaklıkta {v1} L hacim kaplayan gaz {int(t2)} K\'e getirilirse hacmi kaç L olur?',
                u(int(v2), 'L'), [u(x, 'L') for x in num_distractors(r, int(v2), 4)] + [u(v1, 'L')],
                f'V/T sabit: V₂ = {v1}·{int(t2)}/{t1} = {int(v2)} L.')


@stem_limit(1)
def molarite(r):
    n = r.choice([Fraction(1, 10), Fraction(1, 5), Fraction(1, 4), Fraction(1, 2), Fraction(1), Fraction(2), Fraction(3)])
    v = r.choice([Fraction(1, 10), Fraction(1, 5), Fraction(1, 4), Fraction(1, 2), Fraction(1), Fraction(2)])
    m = n / v
    if m > 10 or (m * 100).denominator != 1:
        return None
    return make(r, 'Çözeltiler', f'{fmt_num(float(n))} mol çözünen içeren {fmt_num(float(v * 1000))} mL çözeltinin molar derişimi kaç M\'dir?',
                u(m, 'M'), [u(x, 'M') for x in [m * 2, m / 2, n * v, m + 1, m * 10, m / 10] if x != m],
                f'M = n/V = {fmt_num(float(n))}/{fmt_num(float(v))} L = {fmt_num(float(m))} M.')


@stem_limit(1)
def seyreltme(r):
    m1 = r.randint(1, 6)
    v1 = r.choice([100, 200, 250, 300, 400, 500])
    v2 = v1 * r.choice([2, 3, 4, 5])
    m2 = Fraction(m1 * v1, v2)
    return make(r, 'Çözeltiler', f'{m1} M {v1} mL çözeltiye su eklenerek hacmi {v2} mL yapılıyor. Yeni derişim kaç M olur?',
                f'{fmt_frac(m2)} M', [f'{fmt_frac(x)} M' for x in [m2 * 2, m2 / 2, Fraction(m1 * v2, v1), m2 + 1, Fraction(m1)] if x != m2],
                f'M₁V₁ = M₂V₂ → {m1}·{v1} = M₂·{v2} → M₂ = {fmt_frac(m2)} M.')


@stem_limit(1)
def kutlece_yuzde(r):
    a = r.randint(5, 60)
    b = r.choice([x for x in range(40, 400, 5) if (a * 100) % (a + x) == 0])  if any((a * 100) % (a + x) == 0 for x in range(40, 400, 5)) else None
    if b is None:
        return None
    p = a * 100 // (a + b)
    return make(r, 'Çözeltiler', f'{a} g tuzun {b} g suda çözünmesiyle hazırlanan çözeltinin kütlece yüzde derişimi kaçtır?',
                f'%{p}', [f'%{x}' for x in num_distractors(r, p, 6)], f'%  = {a}/({a}+{b})·100 = %{p}.')


@stem_limit(1)
def ph(r):
    k = r.randint(1, 13)
    if r.random() < 0.5:
        return make(r, 'Asitler ve bazlar', f'25 °C\'de [H⁺] = 1·10⁻{k} M olan çözeltinin pH değeri kaçtır?', k,
                    [x for x in [14 - k, k + 1, k - 1, k + 2, 7] if x != k and 0 <= x <= 14],
                    f'pH = −log[H⁺] = {k}.')
    k = r.randint(1, 6)
    return make(r, 'Asitler ve bazlar', f'25 °C\'de 1·10⁻{k} M NaOH çözeltisinin pH değeri kaçtır?', 14 - k,
                [x for x in [k, 14 - k + 1, 14 - k - 1, 7, 14] if x != 14 - k], f'[OH⁻] = 10⁻{k} → pOH = {k} → pH = 14 − {k} = {14 - k}.')


@stem_limit(1)
def denge_sabiti(r):
    a, b, c = r.choice([1, 2, 4, Fraction(1, 2)]), r.choice([1, 2, 4, Fraction(1, 2)]), r.randint(1, 8)
    kc = Fraction(c) / (Fraction(a) * Fraction(b))
    return make(r, 'Kimyasal denge', f'X(g) + Y(g) ⇌ Z(g) tepkimesi dengedeyken [X] = {fmt_num(float(a))} M, [Y] = {fmt_num(float(b))} M, [Z] = {c} M\'dir. Kc kaçtır?',
                fmt_frac(kc), [fmt_frac(x) for x in [1 / kc, kc * 2, kc / 2, kc + 1, Fraction(c) * a * b] if x != kc],
                f'Kc = [Z]/([X][Y]) = {c}/({fmt_num(float(a))}·{fmt_num(float(b))}) = {fmt_frac(kc)}.')


@stem_limit(1)
def hiz_derece(r):
    m, n = r.randint(0, 2), r.randint(1, 2)
    ka, kb = r.choice([2, 3]), r.choice([1, 2, 3])
    v = ka ** m * kb ** n
    if kb == 1:
        q = f'Hız denklemi k[A]^{m}[B]^{n} olan tepkimede yalnızca [A] {ka} katına çıkarılırsa hız kaç katına çıkar?'
    else:
        q = f'Hız denklemi k[A]^{m}[B]^{n} olan tepkimede [A] {ka} katına, [B] {kb} katına çıkarılırsa hız kaç katına çıkar?'
    q = q.replace('[A]^0', '').replace('^1', '')
    return make(r, 'Tepkime hızı', q, v, [x for x in num_distractors(r, v, max(3, v // 2)) if x > 0] + [ka * kb],
                f'Hız oranı = {ka}^{m}·{kb}^{n} = {v}.')


@stem_limit(1)
def hess(r):
    h1, h2 = r.randint(-400, 300), r.randint(-400, 300)
    a, b = r.choice([1, 2, -1]), r.choice([1, 2, -1, 3])
    v = a * h1 + b * h2

    def w(k):
        return {1: 'olduğu gibi', 2: '2 ile çarpılarak', 3: '3 ile çarpılarak', -1: 'ters çevrilerek'}[k]
    return make(r, 'Tepkime ısıları', f'ΔH₁ = {h1} kJ ve ΔH₂ = {h2} kJ olan iki tepkime; birincisi {w(a)}, ikincisi {w(b)} toplanıyor. Elde edilen tepkimenin ΔH değeri kaç kJ olur?',
                f'{v} kJ', [f'{x} kJ' for x in [h1 + h2, -v, a * h1 - b * h2, v + 100, v - 100]],
                f'Hess yasası: ΔH = {a}·({h1}) {"+" if b > 0 else "−"} {abs(b)}·({h2}) = {v} kJ.')


@stem_limit(1)
def faraday(r):
    ion, z = r.choice([('Cu²⁺', 2), ('Ag⁺', 1), ('Al³⁺', 3), ('Zn²⁺', 2), ('Na⁺', 1), ('Fe³⁺', 3), ('Ni²⁺', 2)])
    f = r.choice([1, 2, 3, 6])
    n = Fraction(f, z)
    return make(r, 'Elektrokimya', f'{ion} iyonu içeren çözeltiden {f} F yük geçirildiğinde katotta kaç mol metal toplanır?',
                f'{fmt_frac(n)} mol', [f'{fmt_frac(x)} mol' for x in [Fraction(f), Fraction(f * z), n * 2, n / 2, n + 1] if x != n],
                f'{ion} + {z}e⁻ → metal: n = {f}/{z} = {fmt_frac(n)} mol.')


ALKANES = ['metan', 'etan', 'propan', 'bütan', 'pentan', 'hekzan', 'heptan', 'oktan', 'nonan', 'dekan']


def formula(c, h, o=0):
    sub = str.maketrans('0123456789', '₀₁₂₃₄₅₆₇₈₉')
    s = 'C' + (str(c) if c > 1 else '') + 'H' + str(h) + ('O' + (str(o) if o > 1 else '') if o else '')
    return s.translate(sub)


@stem_limit(1)
def organik_formul(r):
    n = r.randint(1, 10)
    kind = r.choice(['alkan', 'alken', 'alkol'])
    if kind == 'alken' and n == 1:
        return None
    root = ALKANES[n - 1][:-2]
    if kind == 'alkan':
        name, f, others = ALKANES[n - 1], formula(n, 2 * n + 2), [formula(n, 2 * n), formula(n, 2 * n - 2), formula(n + 1, 2 * n + 2), formula(n, 2 * n + 1)]
        rule = 'CₙH₂ₙ₊₂'
    elif kind == 'alken':
        name, f, others = root + 'en', formula(n, 2 * n), [formula(n, 2 * n + 2), formula(n, 2 * n - 2), formula(n + 1, 2 * n), formula(n, 2 * n + 4)]
        rule = 'CₙH₂ₙ'
    else:
        name, f, others = root + 'ol', formula(n, 2 * n + 2, 1), [formula(n, 2 * n + 2), formula(n, 2 * n, 1), formula(n + 1, 2 * n + 2, 1), formula(n, 2 * n + 2, 2)]
        rule = 'CₙH₂ₙ₊₁OH'
    return make(r, 'Organik kimya', f'{name.capitalize()} bileşiğinin kapalı formülü hangisidir?', f, others,
                f'{kind.capitalize()} genel formülü {rule}; {n} karbonlu: {f}.')


FUNCTIONAL = [
    ('–OH (hidroksil)', 'Alkol'), ('–COOH (karboksil)', 'Karboksilik asit'), ('–CHO (formil)', 'Aldehit'),
    ('–CO– (karbonil, iki karbon arasında)', 'Keton'), ('–O– (iki karbon arasında)', 'Eter'), ('–COO– (iki karbon arasında)', 'Ester'),
    ('–NH₂ (amino)', 'Amin'), ('–CONH₂', 'Amit'), ('C=C ikili bağı', 'Alken'), ('C≡C üçlü bağı', 'Alkin'),
]

ELEMENTS = [  # (ad, Z, grup)
    ('Hidrojen', 1, '1A'), ('Helyum', 2, '8A'), ('Lityum', 3, '1A'), ('Berilyum', 4, '2A'), ('Bor', 5, '3A'),
    ('Karbon', 6, '4A'), ('Azot', 7, '5A'), ('Oksijen', 8, '6A'), ('Flor', 9, '7A'), ('Neon', 10, '8A'),
    ('Sodyum', 11, '1A'), ('Magnezyum', 12, '2A'), ('Alüminyum', 13, '3A'), ('Silisyum', 14, '4A'), ('Fosfor', 15, '5A'),
    ('Kükürt', 16, '6A'), ('Klor', 17, '7A'), ('Argon', 18, '8A'), ('Potasyum', 19, '1A'), ('Kalsiyum', 20, '2A'),
]
ORB = [('1s', 2), ('2s', 2), ('2p', 6), ('3s', 2), ('3p', 6), ('4s', 2)]


def config(z):
    out, left = [], z
    sup = str.maketrans('0123456789', '⁰¹²³⁴⁵⁶⁷⁸⁹')
    for o, cap in ORB:
        if left <= 0:
            break
        k = min(cap, left)
        out.append(o + str(k).translate(sup))
        left -= k
    return ' '.join(out)


@stem_limit(1)
def elektron_dizilimi(r):
    name, z, _ = r.choice(ELEMENTS)
    c = config(z)
    others = [config(x) for x in [z - 1, z + 1, z + 2, z - 2] if 1 <= x <= 20]
    return make(r, 'Atom ve periyodik sistem', f'{name} (Z = {z}) atomunun temel hâl elektron dizilimi hangisidir?', c, others,
                f'Aufbau sırasıyla {z} elektron: {c}.')


@stem_limit(1)
def grup(r):
    name, z, g = r.choice(ELEMENTS)
    groups = ['1A', '2A', '3A', '4A', '5A', '6A', '7A', '8A']
    per = 1 if z <= 2 else 2 if z <= 10 else 3 if z <= 18 else 4
    if r.random() < 0.5:
        return make(r, 'Atom ve periyodik sistem', f'Atom numarası {z} olan elementin periyodik sistemdeki grubu hangisidir?',
                    f'{g} grubu', [f'{x} grubu' for x in groups if x != g], f'{config(z)} → değerlik elektronları: {g}.')
    return make(r, 'Atom ve periyodik sistem', f'Atom numarası {z} olan element periyodik sistemin kaçıncı periyodundadır?',
                f'{per}. periyot', [f'{x}. periyot' for x in range(1, 8) if x != per], f'En yüksek enerji düzeyi {per}: {config(z)}.')


DEFS = {
    'Katalizör': 'Tepkimeye girip değişmeden çıkan, aktifleşme enerjisini düşürerek hızı artıran madde',
    'Aktifleşme enerjisi': 'Tepkimenin başlaması için taneciklerin sahip olması gereken en düşük enerji',
    'Le Chatelier ilkesi': 'Dengedeki sisteme bir etki yapıldığında sistemin bu etkiyi azaltacak yönde kayması',
    'Tampon çözelti': 'Az miktarda asit ya da baz eklendiğinde pH\'ı fazla değişmeyen çözelti',
    'Nötrleşme': 'Asit ile bazın tepkimesinden tuz ve su oluşması',
    'Anot': 'Elektrokimyasal hücrede yükseltgenmenin olduğu elektrot',
    'Katot': 'Elektrokimyasal hücrede indirgenmenin olduğu elektrot',
    'Tuz köprüsü': 'Galvanik hücrede iyon akışını sağlayarak devreyi tamamlayan düzenek',
    'İzomer': 'Kapalı formülü aynı, yapısı farklı bileşikler',
    'Hidroliz': 'Bir maddenin su ile tepkimeye girerek ayrışması',
    'Ekzotermik tepkime': 'Dışarıya ısı veren, ΔH değeri negatif olan tepkime',
    'Endotermik tepkime': 'Dışarıdan ısı alan, ΔH değeri pozitif olan tepkime',
    'Kısmi basınç': 'Gaz karışımındaki bir gazın tek başına kabı doldurduğunda yapacağı basınç',
    'Difüzyon': 'Gaz ya da sıvı taneciklerinin kendiliğinden yayılarak karışması',
    'Koligatif özellik': 'Çözünenin cinsine değil tanecik sayısına bağlı olan çözelti özelliği',
    'Elektroliz': 'Elektrik enerjisi kullanılarak kendiliğinden yürümeyen tepkimenin gerçekleştirilmesi',
}

FACTS = [
    ('Çözeltiye uçucu olmayan bir madde eklenirse kaynama noktası nasıl değişir?', 'Yükselir', ['Düşer', 'Değişmez', 'Önce düşer sonra yükselir', 'Sıfırlanır', 'Donma noktasına eşitlenir']),
    ('Çözeltiye uçucu olmayan bir madde eklenirse donma noktası nasıl değişir?', 'Düşer', ['Yükselir', 'Değişmez', 'Kaynama noktasına eşitlenir', 'Önce yükselir sonra düşer', '0 °C olur']),
    ('Katalizör kullanılması aşağıdakilerden hangisini değiştirmez?', 'Tepkime entalpisini (ΔH)', ['Tepkime hızını', 'Aktifleşme enerjisini', 'Tepkime mekanizmasını', 'Dengeye ulaşma süresini', 'Etkin çarpışma sayısını']),
    ('Ekzotermik bir denge tepkimesinde sıcaklık artırılırsa denge hangi yöne kayar?', 'Girenler yönüne', ['Ürünler yönüne', 'Kaymaz', 'Önce ürünler sonra girenler yönüne', 'Rastgele', 'Kc artar']),
    ('Gaz fazındaki bir denge tepkimesinde kabın hacmi küçültülürse denge hangi yöne kayar?', 'Gaz mol sayısının az olduğu yöne', ['Gaz mol sayısının çok olduğu yöne', 'Kaymaz', 'Daima ürünler yönüne', 'Daima girenler yönüne', 'Katıların olduğu yöne']),
    ('Kuvvetli asitlerin sulu çözeltide davranışı nasıldır?', 'Tamamen iyonlaşır', ['Hiç iyonlaşmaz', 'Kısmen iyonlaşır', 'Sadece ısıtılınca iyonlaşır', 'Çökelek oluşturur', 'Gaz çıkarır']),
    ('Pilin elektrot potansiyeli (E°) pozitif ise tepkime nasıldır?', 'İstemlidir', ['İstemsizdir', 'Dengededir', 'Gerçekleşmez', 'Endotermiktir', 'Hızı sıfırdır']),
    ('Alkanlarda karbon atomları arasındaki bağ türü hangisidir?', 'Tekli bağ', ['İkili bağ', 'Üçlü bağ', 'İyonik bağ', 'Metalik bağ', 'Hidrojen bağı']),
    ('Benzen halkasında kaç karbon atomu bulunur?', '6', ['5', '4', '8', '10', '12']),
    ('Aynı periyotta soldan sağa gidildikçe atom yarıçapı genellikle nasıl değişir?', 'Azalır', ['Artar', 'Değişmez', 'Önce artar sonra azalır', 'İki katına çıkar', 'Rastgele değişir']),
    ('Aynı grupta yukarıdan aşağı inildikçe iyonlaşma enerjisi genellikle nasıl değişir?', 'Azalır', ['Artar', 'Değişmez', 'Önce azalır sonra artar', 'Sıfır olur', 'İki katına çıkar']),
    ('Elektronegatifliği en yüksek element hangisidir?', 'Flor', ['Oksijen', 'Klor', 'Azot', 'Sodyum', 'Helyum']),
]


GENERATORS = [
    (nsa_hacim, 2), (boyle, 2), (charles, 1), (molarite, 2), (seyreltme, 2), (kutlece_yuzde, 1), (ph, 2),
    (denge_sabiti, 2), (hiz_derece, 2), (hess, 1), (faraday, 2), (organik_formul, 2), (elektron_dizilimi, 2), (grup, 2),
    (fact_gen('Genel bilgi', FACTS), 1),
] + define_gens('Kavramlar', DEFS, fwd='"{k}" kavramının tanımı aşağıdakilerden hangisidir?',
                back='"{v}" tanımı hangi kavrama aittir?') \
  + relation_gens('Organik kimya', FUNCTIONAL, fwd='{item} fonksiyonel grubunu taşıyan bileşik sınıfı hangisidir?',
                  weights=(1, 0, 0))
