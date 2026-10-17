"""AYT Fizik: hesap soruları parametreli (g = 10 m/s²), kavram soruları tablodan."""
from fractions import Fraction

from common import fact_gen, fmt_frac, fmt_num, make, num_distractors, relation_gens, stem_limit

T = 'AYT_FIZ'


def u(v, unit):
    return f'{fmt_num(v)} {unit}'


def opts(r, v, unit, spread=None, integer=True):
    return [u(x, unit) for x in num_distractors(r, v, spread)]


@stem_limit(1)
def newton_surtunme(r):
    m = r.randint(2, 10)
    mu = r.choice([Fraction(1, 10), Fraction(1, 5), Fraction(1, 4), Fraction(1, 2)])
    a = r.randint(1, 6)
    f = m * a + mu * m * 10
    if f.denominator != 1:
        return None
    f = int(f)
    return make(r, 'Newton\'un hareket yasaları',
                f'Sürtünme katsayısı {fmt_num(float(mu))} olan yatay düzlemde duran {m} kg kütleli cisme yatay {f} N kuvvet uygulanıyor. Cismin ivmesi kaç m/s² olur? (g = 10 m/s²)',
                u(a, 'm/s²'), opts(r, a, 'm/s²', 3), f'Sürtünme = μmg = {fmt_num(float(mu * m * 10))} N; net kuvvet {fmt_num(float(f - mu * m * 10))} N; a = F/m = {a} m/s².')


@stem_limit(1)
def asansor(r):
    m = r.randint(40, 90)
    a = r.randint(1, 4)
    up = r.random() < 0.5
    n = m * (10 + a) if up else m * (10 - a)
    yon = 'yukarı' if up else 'aşağı'
    return make(r, 'Newton\'un hareket yasaları',
                f'{a} m/s² ivmeyle {yon} doğru hızlanan asansördeki {m} kg kütleli kişinin tartıda okuduğu değer kaç N olur? (g = 10 m/s²)',
                u(n, 'N'), [u(x, 'N') for x in [m * 10, m * (10 - a) if up else m * (10 + a), m * a, n + 10 * a, n - 10 * a]],
                f'N = m(g {"+" if up else "−"} a) = {m}·{10 + a if up else 10 - a} = {n} N.')


@stem_limit(1)
def momentum_carpisma(r):
    m1, m2 = r.randint(1, 8), r.randint(1, 8)
    v1 = r.randint(2, 12) * (m1 + m2) // m1 if (r.randint(2, 12) * (m1 + m2)) % m1 == 0 else None
    if v1 is None:
        return None
    v = Fraction(m1 * v1, m1 + m2)
    if v.denominator != 1:
        return None
    v = int(v)
    return make(r, 'Momentum',
                f'{v1} m/s hızla giden {m1} kg kütleli cisim, durmakta olan {m2} kg kütleli cisme çarpıp yapışıyor. Ortak hızları kaç m/s olur?',
                u(v, 'm/s'), opts(r, v, 'm/s', 3) + [u(v1, 'm/s')], f'Momentum korunur: {m1}·{v1} = {m1 + m2}·v → v = {v} m/s.')


@stem_limit(1)
def itme(r):
    m = r.randint(1, 10)
    v1, v2 = r.randint(0, 10), r.randint(11, 30)
    t = r.choice([1, 2, 4, 5])
    f = Fraction(m * (v2 - v1), t)
    if f.denominator != 1:
        return None
    f = int(f)
    return make(r, 'Momentum', f'{m} kg kütleli cismin hızı {t} s içinde {v1} m/s\'den {v2} m/s\'ye çıkıyor. Cisme etki eden ortalama net kuvvet kaç N\'dur?',
                u(f, 'N'), opts(r, f, 'N', max(3, f // 4)), f'FΔt = Δp → F = {m}·{v2 - v1}/{t} = {f} N.')


@stem_limit(1)
def yatay_atis(r):
    t = r.randint(1, 6)
    h = 5 * t * t
    v = r.randint(5, 30)
    if r.random() < 0.5:
        return make(r, 'Atışlar', f'{h} m yükseklikten {v} m/s hızla yatay atılan cisim yere kaç saniyede düşer? (g = 10 m/s², hava direnci önemsiz)',
                    u(t, 's'), [u(x, 's') for x in [t + 1, t + 2, t * 2, max(1, t - 1) if t > 1 else 8, h // v + 7, 9]],
                    f'Düşey: h = ½gt² → {h} = 5t² → t = {t} s (yatay hız süreyi etkilemez).')
    x = v * t
    return make(r, 'Atışlar', f'{h} m yükseklikten {v} m/s hızla yatay atılan cismin yatayda aldığı yol kaç m olur? (g = 10 m/s²)',
                u(x, 'm'), opts(r, x, 'm', max(5, x // 4)), f't = √(2h/g) = {t} s; x = v·t = {x} m.')


@stem_limit(1)
def dusey_atis(r):
    v = r.choice([10, 20, 30, 40, 50, 60])
    if r.random() < 0.5:
        h = v * v // 20
        return make(r, 'Atışlar', f'Yerden {v} m/s hızla düşey yukarı atılan cismin çıkabileceği en büyük yükseklik kaç m\'dir? (g = 10 m/s²)',
                    u(h, 'm'), opts(r, h, 'm', max(5, h // 4)), f'h = v²/2g = {v * v}/20 = {h} m.')
    t = v // 10
    return make(r, 'Atışlar', f'Yerden {v} m/s hızla düşey yukarı atılan cisim kaç saniye sonra atıldığı yere geri döner? (g = 10 m/s²)',
                u(2 * t, 's'), [u(x, 's') for x in [t, 2 * t + 1, 2 * t + 2, 4 * t, max(1, 2 * t - 1)]],
                f'Çıkış süresi v/g = {t} s; iniş de {t} s → toplam {2 * t} s.')


@stem_limit(1)
def cembersel(r):
    m = r.randint(1, 6)
    v = r.randint(2, 10)
    rad = r.choice([1, 2, 4, 5])
    f = Fraction(m * v * v, rad)
    if f.denominator != 1:
        return None
    f = int(f)
    return make(r, 'Çembersel hareket', f'{m} kg kütleli cisim {rad} m yarıçaplı çembersel yörüngede {v} m/s sabit süratle dolanıyor. Merkezcil kuvvet kaç N\'dur?',
                u(f, 'N'), opts(r, f, 'N', max(4, f // 4)) + [u(m * v * v * rad, 'N')], f'F = mv²/r = {m}·{v * v}/{rad} = {f} N.')


@stem_limit(1)
def yay_periyot(r):
    # T = 2π√(m/k); m/k tam kare seçilir → T = 2π·s
    k = r.choice([4, 9, 16, 25, 36, 100, 400])
    s_ = r.choice([1, 2, 3, 4])
    m = s_ * s_ * k
    if m > 2000:
        return None
    t = f'{2 * s_}π s'
    return make(r, 'Basit harmonik hareket', f'Yay sabiti {k} N/m olan yaya bağlı {m} kg kütleli cismin basit harmonik hareketinin periyodu kaçtır?',
                t, [f'{x}π s' for x in [s_, 4 * s_, 2 * s_ + 2, 2 * s_ + 1, s_ + 1] if x != 2 * s_],
                f'T = 2π√(m/k) = 2π√({m}/{k}) = 2π·{s_} = {t}.')


@stem_limit(1)
def sarkac(r):
    # T = 2π√(L/g), g = 10 ≈ π² alınır → T = 2√L
    L = r.choice([1, 4, 9, 16, 25, 36])
    t = 2 * int(L ** 0.5)
    return make(r, 'Basit harmonik hareket', f'Uzunluğu {L} m olan basit sarkacın periyodu kaç saniyedir? (g = π² m/s² alınız)',
                u(t, 's'), opts(r, t, 's', 3), f'T = 2π√(L/g) = 2π√({L}/π²) = 2√{L} = {t} s.')


@stem_limit(1)
def tork(r):
    f1, d1 = r.randint(2, 20), r.randint(1, 6)
    d2 = r.randint(1, 6)
    f2 = Fraction(f1 * d1, d2)
    if f2.denominator != 1 or d1 == d2:
        return None
    f2 = int(f2)
    return make(r, 'Tork ve denge', f'Desteğin bir yanında {d1} m uzaklıkta {f1} N\'luk ağırlık vardır. Kaldıracın dengede kalması için öbür yanda {d2} m uzaklığa kaç N\'luk ağırlık asılmalıdır?',
                u(f2, 'N'), opts(r, f2, 'N', max(3, f2 // 3)) + [u(f1, 'N')], f'Torklar eşit: {f1}·{d1} = F·{d2} → F = {f2} N.')


@stem_limit(1)
def coulomb_oran(r):
    a, b = r.choice([1, 2, 3]), r.choice([1, 2, 3, 4])
    if a == 1 and b == 1:
        return None
    f = Fraction(a * a, b * b)
    # q'lar a katına, uzaklık b katına → F' = F·a²/b²
    return make(r, 'Elektrik', f'Aralarında d uzaklık bulunan iki yük birbirine F büyüklüğünde kuvvet uyguluyor. Yüklerin her biri {a} katına, aradaki uzaklık {b} katına çıkarılırsa kuvvet kaç F olur?'.replace('1 katına çıkarılırsa', 'değişmezse').replace('her biri 1 katına, ', 'değişmeden '),
                f'{fmt_frac(f)}F', [f'{fmt_frac(x)}F' for x in [Fraction(a, b), Fraction(a * a, b), Fraction(b * b, a * a), Fraction(a, b * b), f * 2, f / 2] if x != f],
                f'F = kq₁q₂/d² → ({a}·{a})/({b}²) = {fmt_frac(f)} katı.')


@stem_limit(1)
def ohm(r):
    i = r.randint(1, 8)
    rs = [r.randint(1, 10) for _ in range(r.choice([2, 3]))]
    rt = sum(rs)
    v = i * rt
    return make(r, 'Elektrik', f'{", ".join(str(x) + " Ω" for x in rs)} dirençleri seri bağlanıp {v} V gerilime bağlanıyor. Devreden geçen akım kaç A\'dir?',
                u(i, 'A'), opts(r, i, 'A', 3), f'R(eş) = {rt} Ω; I = V/R = {v}/{rt} = {i} A.')


@stem_limit(1)
def paralel(r):
    a, b = r.choice([(2, 2), (3, 6), (4, 4), (6, 12), (10, 15), (4, 12), (6, 6), (12, 24), (20, 30), (8, 8), (5, 20), (10, 40)])
    e = Fraction(a * b, a + b)
    return make(r, 'Elektrik', f'{a} Ω ve {b} Ω\'luk iki direnç paralel bağlanıyor. Eşdeğer direnç kaç Ω olur?',
                f'{fmt_frac(e)} Ω', [f'{fmt_frac(x)} Ω' for x in [a + b, e * 2, e + 1, Fraction(a, 2), Fraction(a + b, 2), e + 2] if x != e],
                f'1/R = 1/{a} + 1/{b} → R = {a}·{b}/({a}+{b}) = {fmt_frac(e)} Ω.')


@stem_limit(1)
def kondansator(r):
    c = r.randint(2, 20)
    v = r.randint(2, 12)
    if r.random() < 0.5:
        return make(r, 'Kondansatörler', f'Sığası {c} μF olan kondansatör {v} V gerilime bağlanıyor. Biriktirdiği yük kaç μC olur?',
                    u(c * v, 'μC'), opts(r, c * v, 'μC', max(4, c * v // 4)), f'Q = C·V = {c}·{v} = {c * v} μC.')
    e = Fraction(c * v * v, 2)
    return make(r, 'Kondansatörler', f'Sığası {c} μF olan kondansatör {v} V gerilimle yüklendiğinde depoladığı enerji kaç μJ olur?',
                f'{fmt_frac(e)} μJ', [f'{fmt_frac(x)} μJ' for x in [e * 2, Fraction(c * v, 2), e / 2, e + v, Fraction(c * v)] if x != e],
                f'E = ½CV² = ½·{c}·{v * v} = {fmt_frac(e)} μJ.')


@stem_limit(1)
def manyetik(r):
    b = r.randint(1, 5)
    i = r.randint(1, 10)
    L = r.choice([Fraction(1, 2), Fraction(1), Fraction(2), Fraction(3)])
    f = b * i * L
    return make(r, 'Manyetizma', f'{b} T büyüklüğündeki düzgün manyetik alana dik konmuş {fmt_frac(L)} m uzunluğundaki telden {i} A akım geçiyor. Tele etki eden manyetik kuvvet kaç N\'dur?',
                f'{fmt_frac(f)} N', [f'{fmt_frac(x)} N' for x in [f * 2, f / 2, f + 1, Fraction(b * i), f + 2, Fraction(i, b)] if x != f],
                f'F = B·I·L = {b}·{i}·{fmt_frac(L)} = {fmt_frac(f)} N.')


@stem_limit(1)
def induksiyon(r):
    b, L, v = r.randint(1, 4), r.randint(1, 5), r.randint(2, 10)
    e = b * L * v
    return make(r, 'İndüksiyon', f'{L} m uzunluğundaki iletken çubuk, {b} T\'lık düzgün manyetik alanda alana dik olarak {v} m/s hızla hareket ediyor. Çubuğun uçları arasında oluşan indüksiyon emk\'sı kaç V\'tur?',
                u(e, 'V'), opts(r, e, 'V', max(3, e // 4)), f'ε = B·L·v = {b}·{L}·{v} = {e} V.')


@stem_limit(1)
def transformator(r):
    n1, n2 = r.choice([100, 200, 400, 500, 1000]), r.choice([50, 100, 200, 800, 2000])
    if n1 == n2:
        return None
    v1 = r.choice([10, 20, 40, 100, 220])
    v2 = Fraction(v1 * n2, n1)
    if v2.denominator != 1:
        return None
    v2 = int(v2)
    return make(r, 'Transformatör', f'Primer sarım sayısı {n1}, sekonder sarım sayısı {n2} olan ideal transformatörün primerine {v1} V uygulanıyor. Sekonder gerilim kaç V olur?',
                u(v2, 'V'), [u(x, 'V') for x in [v1, Fraction(v1 * n1, n2), v2 * 2, v2 + 10, max(1, v2 // 2)] if (x != v2 and (not isinstance(x, Fraction) or x.denominator == 1))] + [u(v2 + 5, 'V'), u(v2 + 20, 'V')],
                f'V₂/V₁ = N₂/N₁ → V₂ = {v1}·{n2}/{n1} = {v2} V.')


@stem_limit(1)
def foton(r):
    lam = r.choice([124, 155, 248, 310, 413, 496, 620, 1240])
    e = Fraction(1240, lam)
    s = fmt_num(round(float(e), 2))
    return make(r, 'Modern fizik', f'Dalga boyu {lam} nm olan fotonun enerjisi yaklaşık kaç eV\'tur? (hc = 1240 eV·nm)',
                f'{s} eV', [f'{fmt_num(round(float(x), 2))} eV' for x in [e * 2, e / 2, e + 1, e + 2, Fraction(lam, 124)] if x != e],
                f'E = hc/λ = 1240/{lam} ≈ {s} eV.')


@stem_limit(1)
def fotoelektrik(r):
    e = r.randint(4, 12)
    w = r.choice([2, 3, 4])
    if w >= e:
        return None
    k = e - w
    return make(r, 'Modern fizik', f'Bağlanma enerjisi {w} eV olan metale {e} eV enerjili fotonlar düşürülüyor. Sökülen elektronların en büyük kinetik enerjisi kaç eV olur?',
                u(k, 'eV'), [u(x, 'eV') for x in [e, w, e + w, k + 1, max(1, k - 1)] if x != k], f'Ek(max) = E − W = {e} − {w} = {k} eV.')


@stem_limit(1)
def dalga(r):
    f = r.randint(2, 50)
    lam = r.choice([Fraction(1, 2), Fraction(1), Fraction(2), Fraction(3), Fraction(4)])
    v = f * lam
    return make(r, 'Dalgalar', f'Frekansı {f} Hz, dalga boyu {fmt_frac(lam)} m olan dalganın yayılma hızı kaç m/s\'dir?',
                f'{fmt_frac(v)} m/s', [f'{fmt_frac(x)} m/s' for x in [v * 2, v / 2, v + 1, Fraction(f) / lam, v + 4] if x != v],
                f'v = λ·f = {fmt_frac(lam)}·{f} = {fmt_frac(v)} m/s.')


@stem_limit(1)
def yari_omur(r):
    t = r.choice([2, 5, 8, 10, 20])
    n = r.randint(1, 5)
    m0 = r.choice([64, 128, 256, 320, 640, 800])
    m = Fraction(m0, 2 ** n)
    if m.denominator != 1:
        return None
    return make(r, 'Modern fizik', f'Yarı ömrü {t} gün olan {m0} g radyoaktif maddenin {t * n} gün sonra bozunmadan kalan kütlesi kaç g olur?',
                u(int(m), 'g'), [u(x, 'g') for x in [m0 // 2, int(m) * 2, max(1, int(m) // 2), m0 - int(m), int(m) + n]],
                f'{n} yarı ömür geçti: {m0}/2^{n} = {int(m)} g.')


CONCEPTS = [
    ('Fotoelektrik olayı', 'Einstein'), ('Kütle-enerji eşdeğerliği (E = mc²)', 'Einstein'), ('Özel görelilik', 'Einstein'),
    ('Kara cisim ışımasında enerjinin kuantumlu olması', 'Planck'), ('Hidrojen atom modeli (yörüngeler)', 'Bohr'),
    ('Atom çekirdeğinin keşfi (altın levha deneyi)', 'Rutherford'), ('Elektronun keşfi', 'Thomson'),
    ('Madde dalgaları (dalga-parçacık ikiliği)', 'de Broglie'), ('Belirsizlik ilkesi', 'Heisenberg'),
    ('Compton saçılması', 'Compton'), ('Elektromanyetik indüksiyon', 'Faraday'), ('Elektromanyetik dalga denklemleri', 'Maxwell'),
    ('Evrensel kütle çekim yasası', 'Newton'), ('Gezegenlerin hareket yasaları', 'Kepler'), ('Yüklü cisimler arası kuvvet yasası', 'Coulomb'),
    ('Kaldırma kuvveti ilkesi', 'Arşimet'), ('Sıvılarda basıncın iletilmesi ilkesi', 'Pascal'),
]

FACTS = [
    ('Işık hızına yakın hızlarda hareket eden bir cismin, durgun gözlemciye göre hareket doğrultusundaki boyu nasıl ölçülür?', 'Kısalmış', ['Uzamış', 'Değişmemiş', 'Sıfır', 'İki katına çıkmış', 'Önce uzamış sonra kısalmış']),
    ('Fotoelektrik olayda sökülen elektronların kinetik enerjisi aşağıdakilerden hangisine bağlıdır?', 'Işığın frekansına', ['Işığın şiddetine', 'Işık kaynağının uzaklığına', 'Metalin kütlesine', 'Işığın süresine', 'Ortamın sıcaklığına']),
    ('Fotoelektrik olayda ışığın şiddeti artırılırsa ne artar?', 'Sökülen elektron sayısı', ['Elektronların en büyük kinetik enerjisi', 'Eşik frekansı', 'Bağlanma enerjisi', 'Fotonun enerjisi', 'Elektronun kütlesi']),
    ('Düzgün çembersel harekette hangi nicelik sabittir?', 'Sürat', ['Hız vektörü', 'İvme vektörü', 'Konum vektörü', 'Merkezcil kuvvetin yönü', 'Momentum vektörü']),
    ('Basit harmonik harekette cismin hızı nerede en büyüktür?', 'Denge noktasında', ['Uç noktalarda', 'Genliğin yarısında', 'Her yerde eşittir', 'Uç noktaya yakın yerde', 'Hareketin başında']),
    ('Basit harmonik harekette ivme nerede en büyüktür?', 'Uç noktalarda', ['Denge noktasında', 'Genliğin yarısında', 'Her yerde eşittir', 'Hız en büyükken', 'Hiçbir yerde']),
    ('Bir basit sarkacın periyodu aşağıdakilerden hangisine bağlı değildir?', 'Kütleye', ['İp uzunluğuna', 'Yer çekimi ivmesine', 'Bulunduğu gezegene', 'Sarkacın boyuna', 'Çekim alanının şiddetine']),
    ('Kondansatörün sığası aşağıdakilerden hangisine bağlı değildir?', 'Uygulanan gerilime', ['Levhaların alanına', 'Levhalar arası uzaklığa', 'Aradaki yalıtkanın cinsine', 'Dielektrik sabitine', 'Levhaların konumuna']),
    ('Transformatör hangi tür akımla çalışır?', 'Alternatif akım', ['Doğru akım', 'Statik elektrik', 'Yalnızca pil akımı', 'Sabit manyetik alan', 'Isı akımı']),
    ('Radyoaktif bozunmada alfa parçacığı nedir?', 'Helyum çekirdeği', ['Elektron', 'Foton', 'Nötron', 'Pozitron', 'Proton']),
    ('Beta eksi bozunmasında çekirdekten hangi parçacık salınır?', 'Elektron', ['Helyum çekirdeği', 'Foton', 'Nötron', 'Proton', 'Nötrino yalnızca']),
    ('Gama ışını nedir?', 'Yüksek enerjili elektromanyetik dalga', ['Helyum çekirdeği', 'Elektron demeti', 'Nötron demeti', 'Ses dalgası', 'Proton demeti']),
    ('Bir yüklü parçacık manyetik alana paralel girerse ne olur?', 'Manyetik kuvvet etkimez', ['Çembersel yörünge izler', 'Durur', 'Hızı iki katına çıkar', 'Geri döner', 'Yükü değişir']),
    ('Eylemsizlik momenti hangi hareket türünde kütlenin karşılığıdır?', 'Dönme hareketi', ['Öteleme hareketi', 'Serbest düşme', 'Yatay atış', 'Isı iletimi', 'Dalga hareketi']),
    ('Açısal momentumun korunması için cisme etki eden net ne sıfır olmalıdır?', 'Tork', ['Kuvvet', 'Hız', 'İvme', 'Kütle', 'Enerji']),
    ('Kepler\'in ikinci yasasına göre gezegen Güneş\'e yaklaştıkça hızı nasıl değişir?', 'Artar', ['Azalır', 'Değişmez', 'Sıfır olur', 'Önce azalır sonra artar', 'Yön değiştirmez']),
]


GENERATORS = [
    (newton_surtunme, 3), (asansor, 2), (momentum_carpisma, 2), (itme, 2), (yatay_atis, 3), (dusey_atis, 2),
    (cembersel, 2), (yay_periyot, 1), (sarkac, 1), (tork, 2), (coulomb_oran, 1), (ohm, 2), (paralel, 1),
    (kondansator, 2), (manyetik, 2), (induksiyon, 2), (transformator, 1), (foton, 1), (fotoelektrik, 2),
    (dalga, 1), (yari_omur, 2), (fact_gen('Kavramlar', FACTS), 1),
] + relation_gens('Bilim insanları', CONCEPTS, fwd='"{item}" hangi bilim insanıyla ilişkilidir?',
                  has='Aşağıdakilerden hangisi {group} ile ilişkilendirilen bir çalışmadır?', has_not=None,
                  weights=(1, 1, 0), has_limit=3)
