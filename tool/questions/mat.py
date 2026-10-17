"""TYT Matematik: parametreli şablonlar (cevap hesaplanır, hep doğrudur)."""
import math
from fractions import Fraction

from common import ek_dir, ek_i, fmt_frac, fmt_num, make, num_distractors

T = 'TYT_MAT'


def us_carpim(r):
    a = r.choice([2, 3, 5, 7])
    m, n = r.randint(2, 9), r.randint(2, 9)
    c = m + n
    return make(r, 'Üslü sayılar', f'{a}^{m} · {a}^{n} çarpımı {a} sayısının kaçıncı kuvvetidir?',
                c, [m * n, c + 1, c - 1, abs(m - n), c + 2],
                f'Tabanlar aynıysa üsler toplanır: {m} + {n} = {c}.')


def us_bolum(r):
    a = r.choice([2, 3, 5, 10])
    m = r.randint(6, 15)
    n = r.randint(2, m - 1)
    c = m - n
    return make(r, 'Üslü sayılar', f'{a}^{m} / {a}^{n} işleminin sonucu aşağıdakilerden hangisidir?',
                f'{a}^{c}', [f'{a}^{m + n}', f'{a}^{c + 1}', f'{a}^{max(1, c - 1)}', f'{a}^{m * n}', f'1^{c}'],
                f'Tabanlar aynıysa bölmede üsler çıkarılır: {m} − {n} = {c}.')


def us_negatif(r):
    a = r.choice([-2, -3])
    k = r.randint(2, 6)
    v = a ** k
    return make(r, 'Üslü sayılar', f'({a})^{k} ifadesinin değeri kaçtır?',
                v, [-v, v * 2, abs(a) ** (k - 1), -(abs(a) ** (k - 1)), v + abs(a)],
                f'Negatif sayının {"çift" if k % 2 == 0 else "tek"} kuvveti {"pozitiftir" if k % 2 == 0 else "negatiftir"}: {v}.')


def kok_sadelestir(r):
    b = r.choice([2, 3, 5, 6, 7])
    a = r.randint(2, 9)
    n = a * a * b
    return make(r, 'Köklü sayılar', f'√{n} ifadesinin en sade hâli aşağıdakilerden hangisidir?',
                f'{a}√{b}', [f'{b}√{a}', f'{a + 1}√{b}', f'{a - 1}√{b}' if a > 2 else f'{a * 2}√{b}', f'{a}√{b + 1}', f'{a * b}√{a}'],
                f'{n} = {a * a} · {b} olduğundan √{n} = {a}√{b}.')


def kok_toplam(r):
    b = r.choice([2, 3, 5])
    x, y = r.randint(2, 6), r.randint(2, 6)
    s = x + y
    return make(r, 'Köklü sayılar', f'√{x * x * b} + √{y * y * b} işleminin sonucu kaçtır?',
                f'{s}√{b}', [f'{s}√{2 * b}', f'{x * y}√{b}', f'{s + 1}√{b}', f'√{(x + y) * b}', f'{s - 1}√{b}'],
                f'√{x * x * b} = {x}√{b}, √{y * y * b} = {y}√{b}; toplam {s}√{b}.')


def ebob(r):
    g = r.choice([2, 3, 4, 5, 6, 7, 8, 9, 12])
    p, q = r.sample([2, 3, 5, 7, 11, 13], 2)
    a, b = g * p, g * q
    return make(r, 'EBOB - EKOK', f'{a} ile {b} sayılarının en büyük ortak böleni (EBOB) kaçtır?',
                g, num_distractors(r, g, 4) + [g * p, g * q],
                f'{a} = {g}·{p}, {b} = {g}·{q}; ortak en büyük çarpan {g}.')


def ekok(r):
    g = r.choice([2, 3, 4, 5, 6])
    p, q = r.sample([2, 3, 5, 7], 2)
    a, b = g * p, g * q
    l = g * p * q
    return make(r, 'EBOB - EKOK', f'{a} ile {b} sayılarının en küçük ortak katı (EKOK) kaçtır?',
                l, [a * b, l + g, l - g, g, l * 2],
                f'EKOK = (a·b) / EBOB = ({a}·{b}) / {g} = {l}.')


def ekok_problem(r):
    a, b = r.sample([6, 8, 9, 10, 12, 15, 18, 20], 2)
    l = a * b // math.gcd(a, b)
    return make(r, 'EBOB - EKOK',
                f'İki zil aynı anda çaldıktan sonra biri {a} dakikada, diğeri {b} dakikada bir çalıyor. '
                f'İkisi en az kaç dakika sonra yeniden aynı anda çalar?',
                l, [a + b, a * b if a * b != l else l * 2, l + a, abs(a - b) or 1, l // 2 if l % 2 == 0 else l + b],
                f'Aranan süre {a} ve {b} sayılarının EKOK\'udur: {l}.')


def bolunebilme9(r):
    digits = [r.randint(1, 9), r.randint(0, 9), r.randint(0, 9)]
    pos = r.randint(1, 3)
    s = sum(digits)
    a = (9 - s % 9) % 9
    cands = [d for d in range(10) if (s + d) % 9 == 0]
    if len(cands) != 1:
        return None
    a = cands[0]
    num = digits[:pos] + ['a'] + digits[pos:]
    txt = ''.join(str(d) for d in num)
    return make(r, 'Bölünebilme', f'Dört basamaklı {txt} sayısı 9 ile tam bölünebildiğine göre a rakamı kaçtır?',
                a, [d for d in range(10) if d != a and (s + d) % 3 == 0] + num_distractors(r, a, 4, positive=False),
                f'Rakamlar toplamı 9\'un katı olmalı: {s} + a = {s + a}.')


def bolunebilme_kalan(r):
    b = r.choice([3, 4, 5, 6, 7, 8, 9, 11])
    a = r.randint(100, 999)
    k = a % b
    return make(r, 'Bölünebilme', f'{a} sayısının {b} ile bölümünden kalan kaçtır?',
                k, [x for x in range(b) if x != k] + [b],
                f'{a} = {b} · {a // b} + {k}.')


def asal_bolen(r):
    primes = r.sample([2, 3, 5, 7, 11], r.randint(2, 3))
    n = 1
    for p in primes:
        n *= p ** r.randint(1, 3)
    if n > 5000:
        return None
    c = len(primes)
    return make(r, 'Asal sayılar', f'{n} sayısının kaç farklı asal böleni vardır?',
                c, [1, 2, 3, 4, 5, 6],
                f'{n} = ' + ' · '.join(f'{p}^{_us(n, p)}' for p in sorted(primes)) + f'; farklı asal bölen sayısı {c}.')


def _us(n, p):
    k = 0
    while n % p == 0:
        n //= p
        k += 1
    return k


def bolen_sayisi(r):
    primes = r.sample([2, 3, 5, 7], r.randint(1, 3))
    us = {p: r.randint(1, 3) for p in primes}
    n = 1
    for p, k in us.items():
        n *= p ** k
    if n > 3000 or n < 10:
        return None
    c = 1
    for k in us.values():
        c *= k + 1
    return make(r, 'Asal sayılar', f'{n} sayısının kaç tane pozitif tam sayı böleni vardır?',
                c, num_distractors(r, c, 4),
                'Asal çarpanlarına ayır, üslerin birer fazlasını çarp: ' + ' · '.join(f'({k}+1)' for k in us.values()) + f' = {c}.')


def kesir_toplam(r):
    a, b = r.randint(1, 9), r.choice([2, 3, 4, 5, 6, 8])
    c, d = r.randint(1, 9), r.choice([2, 3, 4, 5, 6, 9])
    s = Fraction(a, b) + Fraction(c, d)
    wrong = [Fraction(a + c, b + d), s + Fraction(1, b * d), s - Fraction(1, b * d), Fraction(a * c, b * d), s * 2]
    return make(r, 'Rasyonel sayılar', f'{a}/{b} + {c}/{d} işleminin sonucu kaçtır?',
                fmt_frac(s), [fmt_frac(w) for w in wrong if w > 0],
                f'Paydalar eşitlenir: {fmt_frac(Fraction(a, b))} + {fmt_frac(Fraction(c, d))} = {fmt_frac(s)}.')


def kesir_carpim(r):
    a, b = r.randint(1, 9), r.randint(2, 9)
    c, d = r.randint(1, 9), r.randint(2, 9)
    s = Fraction(a, b) / Fraction(c, d)
    wrong = [Fraction(a, b) * Fraction(c, d), s + 1, Fraction(b * c, a * d) if a * d else s + 2, s * 2, s + Fraction(1, 2)]
    return make(r, 'Rasyonel sayılar', f'({a}/{b}) ÷ ({c}/{d}) işleminin sonucu kaçtır?',
                fmt_frac(s), [fmt_frac(w) for w in wrong if w > 0 and w != s],
                f'Bölmede ikinci kesir ters çevrilip çarpılır: {a}/{b} · {d}/{c} = {fmt_frac(s)}.')


def denklem1(r):
    a = r.randint(2, 9)
    x = r.randint(-9, 15)
    b = r.randint(-20, 20)
    c = a * x + b
    sb = f'+ {b}' if b >= 0 else f'− {-b}'
    return make(r, 'Denklemler', f'{a}x {sb} = {c} denklemini sağlayan x değeri kaçtır?',
                x, num_distractors(r, x, 5, positive=False) + [-x],
                f'{a}x = {c} − ({b}) = {c - b}, x = {x}.')


def denklem_iki_taraf(r):
    a, c = r.sample(range(2, 10), 2)
    x = r.randint(-6, 12)
    b = r.randint(-15, 15)
    d = a * x + b - c * x
    def t(k, m):
        return f'{k}x {"+ " + str(m) if m >= 0 else "− " + str(-m)}'
    return make(r, 'Denklemler', f'{t(a, b)} = {t(c, d)} eşitliğini sağlayan x kaçtır?',
                x, num_distractors(r, x, 5, positive=False),
                f'x\'li terimler bir tarafa: ({a} − {c})x = {d} − ({b}) → x = {x}.')


def oran(r):
    p, q = r.sample(range(2, 10), 2)
    if math.gcd(p, q) != 1:
        return None
    k = r.randint(2, 12)
    s = (p + q) * k
    return make(r, 'Oran - orantı', f'x/y = {p}/{q} ve x + y = {s} olduğuna göre x kaçtır?',
                p * k, [q * k, s - p, p * k + k, p + q, k],
                f'x = {p}k, y = {q}k; {p + q}k = {s} → k = {k}, x = {p * k}.')


def yuzde(r):
    p = r.choice([10, 15, 20, 25, 30, 40, 50, 60, 75])
    n = r.randint(2, 40) * 20
    v = n * p // 100
    return make(r, 'Yüzde problemleri', f'Bir sayının %{ek_i(p)} {v} olduğuna göre bu sayı kaçtır?',
                n, [v * p, n + 20, n - 20, v + p, n * 2],
                f'Sayı = {v} · 100 / {p} = {n}.')


def kar(r):
    m = r.randint(4, 40) * 25
    k = r.choice([10, 20, 25, 30, 40, 50])
    s = m * (100 + k) // 100
    return make(r, 'Kâr - zarar', f'Maliyeti {m} TL olan bir ürün %{k} kârla satılıyor. Satış fiyatı kaç TL\'dir?',
                s, [m + k, m * k // 100, s + 25, s - 25, m * (100 - k) // 100],
                f'Kâr = {m} · {k}/100 = {m * k // 100}; satış = {s} TL.')


def indirim(r):
    f = r.randint(4, 40) * 50
    k = r.choice([10, 20, 25, 30, 40, 50])
    s = f * (100 - k) // 100
    return make(r, 'Kâr - zarar', f'Etiket fiyatı {f} TL olan bir ürüne %{k} indirim yapılıyor. Ürün kaç TL\'ye satılır?',
                s, [f - k, f * k // 100, s + 50, s - 50, f * (100 + k) // 100],
                f'İndirim {f} · {k}/100 = {f * k // 100} TL; {f} − {f * k // 100} = {s}.')


def yas(r):
    k = r.choice([2, 3, 4])
    c = r.randint(4, 14)
    n = r.randint(2, 10)
    m = k * c
    total = m + c + 2 * n
    return make(r, 'Yaş problemleri',
                f'Bir annenin yaşı kızının yaşının {k} katıdır. {n} yıl sonra yaşları toplamı {total} olacağına göre kızın bugünkü yaşı kaçtır?',
                c, num_distractors(r, c, 4) + [c + n, m],
                f'Kız x, anne {k}x; {n} yıl sonra ({k + 1})x + {2 * n} = {total} → x = {c}.')


def isci(r):
    pairs = [(a, b) for a in range(2, 31) for b in range(a + 1, 61) if (a * b) % (a + b) == 0]
    a, b = r.choice(pairs)
    t = a * b // (a + b)
    return make(r, 'İşçi problemleri',
                f'Bir işi Ali tek başına {a} günde, Veli tek başına {b} günde bitiriyor. İkisi birlikte bu işi kaç günde bitirir?',
                t, [a + b, (a + b) // 2, t + 1, t + 2, abs(b - a)],
                f'1/{a} + 1/{b} = 1/{t}; birlikte {t} günde.')


def hiz(r):
    v1, v2 = r.randint(4, 12) * 10, r.randint(4, 12) * 10
    t = r.randint(2, 6)
    x = (v1 + v2) * t
    return make(r, 'Hız problemleri',
                f'Aralarında {x} km bulunan iki araç saatte {v1} km ve {v2} km hızla birbirine doğru aynı anda yola çıkıyor. Kaç saat sonra karşılaşırlar?',
                t, num_distractors(r, t, 3) + [t + 1, x // max(v1, v2)],
                f'Karşılaşma süresi = yol / hızlar toplamı = {x} / {v1 + v2} = {t} saat.')


def ortalama(r):
    n = r.randint(3, 6)
    avg = r.randint(10, 40)
    new = r.randint(avg + 2, avg + 30)
    total = n * avg + new
    if total % (n + 1):
        return None
    na = total // (n + 1)
    return make(r, 'Ortalama', f'{n} sayının aritmetik ortalaması {ek_dir(avg)}. Bu sayılara {new} eklenirse yeni ortalama kaç olur?',
                na, num_distractors(r, na, 3) + [(avg + new) // 2],
                f'Toplam {n}·{avg} + {new} = {total}; {total} / {n + 1} = {na}.')


def mutlak(r):
    a, b, c = r.randint(-15, 15), r.randint(-15, 15), r.randint(-10, 10)
    v = abs(a - b) + abs(c)
    return make(r, 'Mutlak değer', f'|{a} − ({b})| + |{c}| işleminin sonucu kaçtır?',
                v, num_distractors(r, v, 5) + [abs(a + b) + abs(c), abs(a - b) - abs(c)],
                f'|{a - b}| = {abs(a - b)}, |{c}| = {abs(c)}; toplam {v}.')


def esitsizlik(r):
    a = r.randint(2, 7)
    b = r.randint(-10, 10)
    c = r.randint(5, 40)
    # a·x + b < c → x < (c - b)/a ; en büyük tam sayı
    lim = Fraction(c - b, a)
    best = math.ceil(lim) - 1
    sb = f'+ {b}' if b >= 0 else f'− {-b}'
    return make(r, 'Eşitsizlikler', f'{a}x {sb} < {c} eşitsizliğini sağlayan en büyük x tam sayısı kaçtır?',
                best, num_distractors(r, best, 3, positive=False) + [best + 1],
                f'x < ({c} − ({b}))/{a} = {fmt_frac(lim)}; en büyük tam sayı {best}.')


def fonksiyon(r):
    a, b = r.randint(-5, 6) or 2, r.randint(-10, 10)
    k = r.randint(-5, 8)
    v = a * k + b
    sb = f'+ {b}' if b >= 0 else f'− {-b}'
    return make(r, 'Fonksiyonlar', f'f(x) = {a}x {sb} olduğuna göre f({k}) kaçtır?',
                v, num_distractors(r, v, 5, positive=False) + [a + k + b],
                f'f({k}) = {a}·({k}) {sb} = {v}.')


def ters_fonksiyon(r):
    a = r.choice([2, 3, 4, 5])
    b = r.randint(-9, 9)
    x = r.randint(-5, 10)
    y = a * x + b
    sb = f'+ {b}' if b >= 0 else f'− {-b}'
    return make(r, 'Fonksiyonlar', f'f(x) = {a}x {sb} olduğuna göre f⁻¹({y}) kaçtır?',
                x, num_distractors(r, x, 4, positive=False) + [a * y + b],
                f'f(x) = {y} → {a}x = {y - b} → x = {x}.')


def kume(r):
    a, b = r.randint(8, 30), r.randint(8, 30)
    k = r.randint(1, min(a, b) - 1)
    u = a + b - k
    return make(r, 'Kümeler', f's(A) = {a}, s(B) = {b} ve s(A ∩ B) = {k} olduğuna göre s(A ∪ B) kaçtır?',
                u, [a + b, u + k, u - 1, a + k, b + k],
                f's(A ∪ B) = s(A) + s(B) − s(A ∩ B) = {a} + {b} − {k} = {u}.')


def kume_problem(r):
    n = r.randint(30, 60)
    a, b = r.randint(10, n - 10), r.randint(10, n - 10)
    both = a + b - n
    if both <= 0:
        return None
    return make(r, 'Kümeler',
                f'{n} kişilik bir sınıfta herkes en az bir dil biliyor. İngilizce bilen {a}, Almanca bilen {b} kişi olduğuna göre her iki dili bilen kaç kişidir?',
                both, num_distractors(r, both, 4) + [n - a, n - b],
                f'{a} + {b} − {n} = {both}.')


def permutasyon(r):
    n = r.randint(3, 7)
    v = math.factorial(n)
    return make(r, 'Permütasyon', f'{n} farklı kitap bir rafa yan yana kaç farklı şekilde dizilebilir?',
                v, [n * n, v // n, v * 2, n * (n - 1), math.factorial(n - 1) * 2],
                f'{n}! = {v}.')


def permutasyon_r(r):
    n = r.randint(5, 9)
    k = r.randint(2, 3)
    v = math.perm(n, k)
    return make(r, 'Permütasyon', f'{n} kişilik bir yarışmada birinci, ikinci{" ve üçüncü" if k == 3 else ""} kaç farklı şekilde belirlenebilir?',
                v, [math.comb(n, k), n ** k, v + n, v - n, math.factorial(n) // k],
                f'P({n}, {k}) = {v}.')


def kombinasyon(r):
    n = r.randint(5, 10)
    k = r.randint(2, 4)
    v = math.comb(n, k)
    return make(r, 'Kombinasyon', f'{n} kişilik bir gruptan {k} kişilik bir ekip kaç farklı şekilde seçilir?',
                v, [math.perm(n, k), v + n, v - k, n * k, v * 2],
                f'C({n}, {k}) = {v}.')


def olasilik_top(r):
    k, m = r.randint(2, 9), r.randint(2, 9)
    p = Fraction(k, k + m)
    return make(r, 'Olasılık', f'Bir torbada {k} kırmızı ve {m} mavi top vardır. Rastgele çekilen bir topun kırmızı olma olasılığı kaçtır?',
                fmt_frac(p), [fmt_frac(Fraction(m, k + m)), fmt_frac(Fraction(k, m)) if k != m else '1/2', fmt_frac(Fraction(1, k + m)), fmt_frac(Fraction(k, k + m + 1)), fmt_frac(Fraction(k + 1, k + m))],
                f'İstenen / tüm = {k} / {k + m} = {fmt_frac(p)}.')


def olasilik_zar(r):
    s = r.randint(3, 11)
    c = sum(1 for a in range(1, 7) for b in range(1, 7) if a + b == s)
    p = Fraction(c, 36)
    return make(r, 'Olasılık', f'İki zar birlikte atılıyor. Üst yüze gelen sayıların toplamının {s} olma olasılığı kaçtır?',
                fmt_frac(p), [fmt_frac(Fraction(x, 36)) for x in range(1, 7) if x != c] + ['1/6', '1/12'],
                f'Toplamı {s} olan {c} durum vardır; {c}/36 = {fmt_frac(p)}.')


def ucgen_aci(r):
    a, b = r.randint(20, 90), r.randint(20, 90)
    if a + b >= 170:
        return None
    c = 180 - a - b
    return make(r, 'Üçgenler', f'Bir üçgenin iki iç açısı {a}° ve {b}° olduğuna göre üçüncü açısı kaç derecedir?',
                c, num_distractors(r, c, 15) + [360 - a - b, a + b],
                f'İç açılar toplamı 180°: 180 − {a} − {b} = {c}.')


def pisagor(r):
    base = r.choice([(3, 4, 5), (5, 12, 13), (8, 15, 17), (7, 24, 25)])
    k = r.randint(1, 4)
    a, b, c = (x * k for x in base)
    return make(r, 'Üçgenler', f'Dik kenarları {a} cm ve {b} cm olan dik üçgenin hipotenüsü kaç cm\'dir?',
                c, [a + b, c + k, c - k, a * b // 2, c + 2],
                f'√({a}² + {b}²) = √{a * a + b * b} = {c}.')


def dikdortgen(r):
    a, b = r.randint(3, 20), r.randint(3, 20)
    if a == b:
        return None
    c = 2 * (a + b)
    return make(r, 'Dörtgenler', f'Alanı {a * b} cm² olan bir dikdörtgenin bir kenarı {a} cm\'dir. Çevresi kaç cm\'dir?',
                c, [a + b, a * b, c + 2, c - 2, 4 * a],
                f'Diğer kenar {a * b}/{a} = {b}; çevre 2·({a} + {b}) = {c}.')


def daire(r):
    rad = r.randint(2, 12)
    v = 3 * rad * rad
    return make(r, 'Çember ve daire', f'Yarıçapı {rad} cm olan dairenin alanı kaç cm²\'dir? (π = 3 alınız)',
                v, [6 * rad, 3 * rad, v + 3, 3 * (rad + 1) ** 2, 12 * rad],
                f'Alan = π·r² = 3 · {rad}² = {v}.')


def ardisik(r):
    x = r.randrange(1, 60, 2)
    s = 3 * x + 6
    return make(r, 'Sayı problemleri', f'Ardışık üç tek sayının toplamı {s} olduğuna göre en büyüğü kaçtır?',
                x + 4, [x, x + 2, x + 6, x + 3, s // 3],
                f'x + (x+2) + (x+4) = {s} → x = {x}; en büyük {x + 4}.')


def basamak(r):
    a, b = r.randint(1, 9), r.randint(1, 9)
    if a == b:
        return None
    s = 11 * (a + b)
    return make(r, 'Basamak analizi', f'Rakamları farklı iki basamaklı AB sayısı ile BA sayısının toplamı {s} ise A + B kaçtır?',
                a + b, num_distractors(r, a + b, 3) + [s // 10],
                f'AB + BA = 11(A + B) = {s} → A + B = {a + b}.')


def sifir_sayisi(r):
    n = r.randint(10, 60)
    z, p = 0, 5
    while p <= n:
        z += n // p
        p *= 5
    return make(r, 'Faktöriyel', f'{n}! sayısının sonunda kaç tane sıfır vardır?',
                z, num_distractors(r, z, 3) + [n // 5, n // 10],
                f'5\'in çarpan sayısı sayılır: ' + ' + '.join(str(n // 5 ** i) for i in range(1, 4) if n // 5 ** i) + f' = {z}.')


def egim(r):
    x1, y1 = r.randint(-6, 6), r.randint(-6, 6)
    dx = r.choice([1, 2, 3, 4])
    m = r.choice([-3, -2, -1, 1, 2, 3])
    x2, y2 = x1 + dx, y1 + m * dx
    return make(r, 'Doğru denklemi', f'A({x1}, {y1}) ve B({x2}, {y2}) noktalarından geçen doğrunun eğimi kaçtır?',
                m, [-m, m + 1, m - 1, dx, Fraction(dx, m) if m else 1],
                f'Eğim = (y₂ − y₁)/(x₂ − x₁) = {y2 - y1}/{dx} = {m}.')


def cokgen(r):
    n = r.randint(5, 12)
    v = (n - 2) * 180
    return make(r, 'Çokgenler', f'{n} kenarlı bir dışbükey çokgenin iç açıları toplamı kaç derecedir?',
                v, [n * 180, (n - 1) * 180, v + 90, 360, (n - 3) * 180],
                f'(n − 2)·180 = ({n} − 2)·180 = {v}.')


GENERATORS = [(f, 1) for f in [
    us_carpim, us_bolum, us_negatif, kok_sadelestir, kok_toplam, ebob, ekok, ekok_problem,
    bolunebilme9, bolunebilme_kalan, asal_bolen, bolen_sayisi, kesir_toplam, kesir_carpim,
    denklem1, denklem_iki_taraf, oran, yuzde, kar, indirim, yas, isci, hiz, ortalama, mutlak,
    esitsizlik, fonksiyon, ters_fonksiyon, kume, kume_problem, permutasyon, permutasyon_r,
    kombinasyon, olasilik_top, olasilik_zar, ucgen_aci, pisagor, dikdortgen, daire, ardisik,
    basamak, sifir_sayisi, egim, cokgen,
]]
