"""AYT Matematik: tüm sorular parametreli şablonlardan hesaplanır."""
import math
from fractions import Fraction

from common import fmt_frac, make, num_distractors, stem_limit

T = 'AYT_MAT'


def frac_distractors(r, f, count=8):
    f = Fraction(f)
    out = []
    cands = [f + 1, f - 1, -f, 1 / f if f else Fraction(2), f * 2, f / 2, f + Fraction(1, 2),
             f - Fraction(1, 2), Fraction(f.denominator, f.numerator) if f.numerator else Fraction(3),
             Fraction(f.numerator + 1, f.denominator), Fraction(f.numerator, f.denominator + 1)]
    for c in cands:
        s = fmt_frac(c)
        if c != f and s not in out:
            out.append(s)
    r.shuffle(out)
    return out[:count]


def poly_str(coefs, var='x'):
    """[a_n, ..., a_0] → '2x³ − x + 5'."""
    sup = {2: '²', 3: '³', 4: '⁴', 5: '⁵'}
    n = len(coefs) - 1
    parts = []
    for i, c in enumerate(coefs):
        p = n - i
        if c == 0:
            continue
        sign = '−' if c < 0 else '+'
        a = abs(c)
        if p == 0:
            body = str(a)
        else:
            body = ('' if a == 1 else str(a)) + var + (sup[p] if p > 1 else '')
        parts.append((sign, body))
    if not parts:
        return '0'
    s = ('−' if parts[0][0] == '−' else '') + parts[0][1]
    for sign, body in parts[1:]:
        s += f' {sign} {body}'
    return s


def peval(coefs, x):
    v = 0
    for c in coefs:
        v = v * x + c
    return v


def signed(n):
    return f'+ {n}' if n >= 0 else f'− {-n}'


# --- Logaritma ve üstel ---
@stem_limit(1)
def log_deger(r):
    b = r.choice([2, 3, 5, 10])
    k1, k2 = r.randint(1, 4), r.randint(1, 4)
    if b ** max(k1, k2) > 10000:
        return None
    op = r.choice(['+', '−'])
    v = k1 + k2 if op == '+' else k1 - k2
    return make(r, 'Logaritma', f'log{b}({b ** k1}) {op} log{b}({b ** k2}) ifadesinin değeri kaçtır?', v,
                num_distractors(r, v, 4, positive=False),
                f'log{b}({b ** k1}) = {k1}, log{b}({b ** k2}) = {k2} → {v}.')


@stem_limit(1)
def log_denklem(r):
    b = r.choice([2, 3, 5])
    k = r.randint(2, 5)
    c = r.randint(-5, 9)
    x = b ** k - c
    if x <= 0:
        return None
    return make(r, 'Logaritma', f'log{b}(x {signed(c)}) = {k} olduğuna göre x kaçtır?', x,
                num_distractors(r, x, max(4, x // 4)), f'x {signed(c)} = {b}^{k} = {b ** k} → x = {x}.')


@stem_limit(1)
def log_carpim(r):
    b = r.choice([2, 3, 6, 10])
    a = r.randint(2, 9)
    c = b ** r.randint(2, 4)
    if c % a:
        return None
    d = c // a
    return make(r, 'Logaritma', f'log{b}({a}) + log{b}({d}) toplamı kaçtır?', round(math.log(c, b)),
                num_distractors(r, round(math.log(c, b)), 3), f'log{b}({a}·{d}) = log{b}({c}) = {round(math.log(c, b))}.')


@stem_limit(1)
def ustel_denklem(r):
    b = r.choice([2, 3, 5])
    a = r.randint(-4, 6)
    k = r.randint(2, 6)
    if b ** k > 3200:
        return None
    m = r.choice([1, 2, 3])
    # b^(m x + a) = b^k → x = (k − a) / m
    x = Fraction(k - a, m)
    lhs = (f'{m}x' if m > 1 else 'x') + f' {signed(a)}' if a else (f'{m}x' if m > 1 else 'x')
    return make(r, 'Üstel fonksiyon', f'{b}^({lhs}) = {b ** k} olduğuna göre x kaçtır?', fmt_frac(x),
                frac_distractors(r, x), f'{b ** k} = {b}^{k} → {lhs} = {k} → x = {fmt_frac(x)}.')


# --- Polinomlar ---
@stem_limit(1)
def polinom_deger(r):
    n = r.choice([2, 3])
    coefs = [r.randint(1, 5)] + [r.randint(-6, 6) for _ in range(n)]
    k = r.randint(-3, 3)
    v = peval(coefs, k)
    return make(r, 'Polinomlar', f'P(x) = {poly_str(coefs)} olduğuna göre P({k}) kaçtır?', v,
                num_distractors(r, v, max(5, abs(v) // 3), positive=False), f'x yerine {k} yazılır: P({k}) = {v}.')


@stem_limit(1)
def polinom_kalan(r):
    coefs = [r.randint(1, 4)] + [r.randint(-7, 7) for _ in range(3)]
    k = r.randint(-3, 4)
    if k == 0:
        return None
    v = peval(coefs, k)
    return make(r, 'Polinomlar', f'P(x) = {poly_str(coefs)} polinomunun x {signed(-k)} ile bölümünden kalan kaçtır?', v,
                num_distractors(r, v, max(5, abs(v) // 3), positive=False),
                f'Kalan teoremi: kalan = P({k}) = {v}.')


@stem_limit(1)
def katsayi_toplami(r):
    coefs = [r.randint(1, 6)] + [r.randint(-8, 8) for _ in range(r.choice([2, 3]))]
    a = r.choice([2, 3])
    b = r.randint(-3, 3)
    # P(ax + b) polinomunun katsayılar toplamı = P(a + b)
    v = peval(coefs, a + b)
    return make(r, 'Polinomlar',
                f'P(x) = {poly_str(coefs)} olduğuna göre P({a}x {signed(b)}) polinomunun katsayılar toplamı kaçtır?'
                if b else f'P(x) = {poly_str(coefs)} olduğuna göre P({a}x) polinomunun katsayılar toplamı kaçtır?',
                v, num_distractors(r, v, max(5, abs(v) // 3), positive=False),
                f'Katsayılar toplamı x = 1 için bulunur: P({a + b}) = {v}.')


# --- İkinci dereceden denklemler ---
@stem_limit(1)
def kok_toplam_carpim(r):
    x1, x2 = r.randint(-7, 9), r.randint(-7, 9)
    if x1 == x2:
        return None
    a = r.choice([1, 1, 2, 3])
    b, c = -a * (x1 + x2), a * x1 * x2
    kind = r.choice(['toplamı', 'çarpımı', 'kareleri toplamı'])
    v = {'toplamı': x1 + x2, 'çarpımı': x1 * x2, 'kareleri toplamı': x1 * x1 + x2 * x2}[kind]
    poly = poly_str([a, b, c])
    return make(r, 'İkinci dereceden denklemler', f'{poly} = 0 denkleminin kökleri x₁ ve x₂ ise köklerin {kind} kaçtır?',
                v, num_distractors(r, v, max(4, abs(v) // 3), positive=False),
                f'x₁ + x₂ = −b/a = {x1 + x2}, x₁·x₂ = c/a = {x1 * x2}' +
                (f'; x₁² + x₂² = (x₁+x₂)² − 2x₁x₂ = {v}.' if kind == 'kareleri toplamı' else '.'))


@stem_limit(1)
def diskriminant(r):
    a, b, c = r.randint(1, 4), r.randint(-9, 9), r.randint(-9, 9)
    d = b * b - 4 * a * c
    return make(r, 'İkinci dereceden denklemler', f'{poly_str([a, b, c])} = 0 denkleminin diskriminantı (Δ) kaçtır?', d,
                num_distractors(r, d, max(5, abs(d) // 4), positive=False), f'Δ = b² − 4ac = {b * b} − {4 * a * c} = {d}.')


@stem_limit(1)
def parabol_tepe(r):
    a = r.choice([1, 2, -1, -2, 3])
    r_ = r.randint(-5, 5)
    k = r.randint(-9, 9)
    b, c = -2 * a * r_, a * r_ * r_ + k
    ask = r.choice(['apsisi', 'ordinatı'])
    v = r_ if ask == 'apsisi' else k
    return make(r, 'Parabol', f'f(x) = {poly_str([a, b, c])} parabolünün tepe noktasının {ask} kaçtır?', v,
                num_distractors(r, v, 5, positive=False), f'r = −b/2a = {r_}, k = f({r_}) = {k}.')


# --- Karmaşık sayılar ---
@stem_limit(1)
def karmasik_carpim(r):
    a, b, c, d = (r.randint(-5, 6) for _ in range(4))
    if 0 in (a, b, c, d):
        return None
    re, im = a * c - b * d, a * d + b * c
    ask = r.choice(['gerçel', 'sanal'])
    v = re if ask == 'gerçel' else im

    def z(x, y):
        return f'({x} {"+" if y > 0 else "−"} {abs(y) if abs(y) != 1 else ""}i)'
    return make(r, 'Karmaşık sayılar', f'{z(a, b)} · {z(c, d)} çarpımının {ask} kısmı kaçtır?', v,
                num_distractors(r, v, max(4, abs(v) // 3), positive=False),
                f'i² = −1: gerçel kısım ({a})·({c}) − ({b})·({d}) = {re}, sanal kısım ({a})·({d}) + ({b})·({c}) = {im}.')


@stem_limit(1)
def karmasik_mutlak(r):
    a, b, c = r.choice([(3, 4, 5), (5, 12, 13), (6, 8, 10), (8, 15, 17), (9, 12, 15), (7, 24, 25), (12, 16, 20), (20, 21, 29)])
    if r.random() < 0.5:
        a, b = b, a
    sa, sb = r.choice([1, -1]), r.choice([1, -1])
    return make(r, 'Karmaşık sayılar', f'z = {sa * a} {"+" if sb > 0 else "−"} {b}i karmaşık sayısının modülü |z| kaçtır?', c,
                num_distractors(r, c, 4), f'|z| = √({a}² + {b}²) = {c}.')


@stem_limit(1)
def i_kuvvet(r):
    n = r.randint(5, 200)
    vals = ['1', 'i', '−1', '−i']
    v = vals[n % 4]
    return make(r, 'Karmaşık sayılar', f'i^{n} ifadesinin eşiti nedir?', v, [x for x in vals if x != v] + ['0', '2i'],
                f'i\'nin kuvvetleri 4\'te bir tekrar eder: {n} mod 4 = {n % 4} → {v}.')


# --- Diziler ---
@stem_limit(1)
def aritmetik(r):
    a1, d, n = r.randint(-10, 15), r.choice([x for x in range(-6, 8) if x]), r.randint(8, 40)
    if r.random() < 0.5:
        v = a1 + (n - 1) * d
        return make(r, 'Diziler', f'İlk terimi {a1}, ortak farkı {d} olan aritmetik dizinin {n}. terimi kaçtır?', v,
                    num_distractors(r, v, max(5, abs(d) * 2), positive=False), f'aₙ = a₁ + (n−1)d = {a1} + {n - 1}·{d} = {v}.')
    n = r.randint(5, 20)
    v = n * (2 * a1 + (n - 1) * d) // 2
    return make(r, 'Diziler', f'İlk terimi {a1}, ortak farkı {d} olan aritmetik dizinin ilk {n} teriminin toplamı kaçtır?', v,
                num_distractors(r, v, max(8, abs(v) // 6), positive=False), f'Sₙ = n(2a₁ + (n−1)d)/2 = {v}.')


@stem_limit(1)
def geometrik(r):
    a1, q, n = r.randint(1, 6), r.choice([2, 3, -2]), r.randint(3, 8)
    v = a1 * q ** (n - 1)
    if abs(v) > 50000:
        return None
    return make(r, 'Diziler', f'İlk terimi {a1}, ortak çarpanı {q} olan geometrik dizinin {n}. terimi kaçtır?', v,
                [a1 * q ** n, a1 * q ** (n - 2), -v, v * 2, a1 + (n - 1) * q, v // 2 if v % 2 == 0 else v + 3],
                f'aₙ = a₁·qⁿ⁻¹ = {a1}·({q})^{n - 1} = {v}.')


# --- Limit ---
@stem_limit(1)
def limit_kesir(r):
    a = r.randint(-6, 7)
    if a == 0:
        return None
    m = r.randint(1, 4)
    # lim x→a (m(x² − a²)) / (x − a) = 2am
    v = 2 * a * m
    num = poly_str([m, 0, -m * a * a])
    return make(r, 'Limit', f'lim(x→{a}) ({num}) / (x {signed(-a)}) limitinin değeri kaçtır?', v,
                num_distractors(r, v, max(4, abs(v) // 2), positive=False),
                f'Pay {m}(x {signed(-a)})(x {signed(a)}) olarak çarpanlarına ayrılır; (x {signed(-a)}) sadeleşir, x = {a} yazılır: {v}.')


@stem_limit(1)
def limit_sonsuz(r):
    a, b = r.randint(1, 9), r.randint(1, 9)
    p = r.choice([2, 3])
    f = Fraction(a, b)
    n = poly_str([a] + [r.randint(-5, 5) for _ in range(p)])
    d = poly_str([b] + [r.randint(-5, 5) for _ in range(p)])
    return make(r, 'Limit', f'lim(x→∞) ({n}) / ({d}) limitinin değeri kaçtır?', fmt_frac(f),
                frac_distractors(r, f) + ['0', '∞'], f'Dereceler eşit: en büyük dereceli terimlerin katsayıları oranı {a}/{b} = {fmt_frac(f)}.')


# --- Türev ---
@stem_limit(1)
def turev_deger(r):
    coefs = [r.randint(1, 4), r.randint(-6, 6), r.randint(-9, 9), r.randint(-9, 9)]
    k = r.randint(-3, 3)
    d = [3 * coefs[0], 2 * coefs[1], coefs[2]]
    v = peval(d, k)
    return make(r, 'Türev', f'f(x) = {poly_str(coefs)} olduğuna göre f\'({k}) kaçtır?', v,
                num_distractors(r, v, max(5, abs(v) // 3), positive=False),
                f'f\'(x) = {poly_str(d)} → f\'({k}) = {v}.')


@stem_limit(1)
def teget_egim(r):
    a, b, c = r.randint(1, 5), r.randint(-8, 8), r.randint(-9, 9)
    k = r.randint(-4, 4)
    v = 2 * a * k + b
    return make(r, 'Türev', f'f(x) = {poly_str([a, b, c])} eğrisine x = {k} noktasında çizilen teğetin eğimi kaçtır?', v,
                num_distractors(r, v, 5, positive=False), f'Eğim = f\'({k}) = 2·{a}·{k} + ({b}) = {v}.')


@stem_limit(1)
def ekstremum(r):
    a = r.choice([1, 2, 3, -1, -2])
    x0 = r.randint(-5, 6)
    k = r.randint(-9, 9)
    b, c = -2 * a * x0, a * x0 * x0 + k
    word = 'en küçük' if a > 0 else 'en büyük'
    return make(r, 'Türev', f'f(x) = {poly_str([a, b, c])} fonksiyonunun alabileceği {word} değer kaçtır?', k,
                num_distractors(r, k, 6, positive=False), f'f\'(x) = 0 → x = {x0}; f({x0}) = {k}.')


# --- İntegral ---
@stem_limit(1)
def belirli_integral(r):
    a, b = r.randint(0, 3), r.randint(1, 4)
    if a >= b:
        return None
    p, q = r.choice([2, 4, 6]), r.randint(-5, 5)
    # ∫ (p x + q) dx = p/2 x² + q x
    v = Fraction(p, 2) * (b * b - a * a) + q * (b - a)
    return make(r, 'İntegral', f'∫ [{a}, {b}] ({poly_str([p, q])}) dx integralinin değeri kaçtır?', fmt_frac(v),
                frac_distractors(r, v), f'İlkel: {p // 2}x² {signed(q)}x → [{a}, {b}] arası fark = {fmt_frac(v)}.'.replace('1x²', 'x²'))


@stem_limit(1)
def integral_kup(r):
    a, b = r.randint(0, 3), r.randint(1, 5)
    if a >= b:
        return None
    v = b ** 3 - a ** 3
    return make(r, 'İntegral', f'∫ [{a}, {b}] 3x² dx integralinin değeri kaçtır?', v,
                num_distractors(r, v, max(5, v // 5)), f'İlkel x³: {b}³ − {a}³ = {v}.')


@stem_limit(1)
def alan(r):
    k = r.randint(1, 6)
    # y = x² eğrisi, x ekseni ve x = k doğrusu arasındaki alan = k³/3
    v = Fraction(k ** 3, 3)
    return make(r, 'İntegral', f'y = x² eğrisi, x ekseni ve x = {k} doğrusu arasında kalan bölgenin alanı kaç birimkaredir?',
                fmt_frac(v), frac_distractors(r, v), f'∫ [0, {k}] x² dx = {k}³/3 = {fmt_frac(v)}.')


# --- Trigonometri ---
SPECIAL = {
    'sin 30°': '1/2', 'sin 45°': '√2/2', 'sin 60°': '√3/2', 'sin 90°': '1', 'sin 0°': '0',
    'cos 0°': '1', 'cos 30°': '√3/2', 'cos 45°': '√2/2', 'cos 60°': '1/2', 'cos 90°': '0',
    'tan 45°': '1', 'tan 60°': '√3', 'tan 30°': '√3/3', 'cot 45°': '1', 'cot 30°': '√3',
    'sin 120°': '√3/2', 'cos 120°': '−1/2', 'sin 150°': '1/2', 'cos 150°': '−√3/2', 'cos 180°': '−1',
    'sin 210°': '−1/2', 'cos 240°': '−1/2', 'sin 270°': '−1', 'sin 330°': '−1/2', 'cos 300°': '1/2',
    'tan 135°': '−1', 'cos 135°': '−√2/2', 'sin 225°': '−√2/2', 'tan 120°': '−√3', 'cos 210°': '−√3/2',
}
VALUES = sorted(set(SPECIAL.values()))


@stem_limit(1)
def trig_deger(r):
    k = r.choice(list(SPECIAL))
    v = SPECIAL[k]
    return make(r, 'Trigonometri', f'{k} değeri kaçtır?', v, r.sample([x for x in VALUES if x != v], 6),
                f'{k} = {v} (birim çember / bölge işareti).')


@stem_limit(1)
def periyot(r):
    f = r.choice(['sin', 'cos', 'tan'])
    k = r.randint(2, 9)
    base = 1 if f == 'tan' else 2
    p = Fraction(base, k)

    def pi(fr):
        if fr.numerator == 0:
            return '0'
        n = '' if fr.numerator == 1 else str(fr.numerator)
        return f'{n}π' if fr.denominator == 1 else f'{n}π/{fr.denominator}'
    c = r.randint(1, 5)
    return make(r, 'Trigonometri', f'f(x) = {c}·{f}({k}x) fonksiyonunun esas periyodu kaçtır?', pi(p),
                [pi(Fraction(base * 2, k)), pi(Fraction(base, k * 2)), pi(Fraction(k, base)), pi(Fraction(1, 1)),
                 pi(Fraction(2, 1)), pi(Fraction(base, k + 1)), pi(Fraction(c * base, k))],
                f'{f}(kx) için periyot {"π" if f == "tan" else "2π"}/|k| = {pi(p)}; katsayı periyodu değiştirmez.')


@stem_limit(1)
def radyan(r):
    deg = r.choice([30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330, 360, 720, 20, 36, 40, 72, 15])
    f = Fraction(deg, 180)

    def pi(fr):
        n = '' if fr.numerator == 1 else str(fr.numerator)
        return f'{n}π' if fr.denominator == 1 else f'{n}π/{fr.denominator}'
    return make(r, 'Trigonometri', f'{deg}° kaç radyandır?', pi(f),
                [pi(Fraction(deg, 90)), pi(Fraction(deg, 360)), pi(f + Fraction(1, 6)), pi(f * 2), pi(f + Fraction(1, 4))],
                f'{deg}° · π/180 = {pi(f)}.')


# --- Sayma ve olasılık ---
@stem_limit(1)
def kombinasyon(r):
    n = r.randint(5, 14)
    k = r.randint(2, min(5, n - 1))
    v = math.comb(n, k)
    return make(r, 'Kombinasyon', f'{n} kişilik bir gruptan {k} kişilik kaç farklı ekip seçilebilir?', v,
                [math.perm(n, k), math.comb(n, k - 1), math.comb(n + 1, k), math.comb(n - 1, k), v * 2],
                f'C({n}, {k}) = {v}.')


@stem_limit(1)
def permutasyon(r):
    n = r.randint(5, 10)
    k = r.randint(2, 4)
    v = math.perm(n, k)
    return make(r, 'Permütasyon', f'{n} farklı kitaptan {k} tanesi bir rafa kaç farklı şekilde dizilebilir?', v,
                [math.comb(n, k), math.perm(n, k - 1), math.perm(n - 1, k), n ** k, v // 2],
                f'P({n}, {k}) = {v}.')


WORDS = ['KALEM', 'ANKARA', 'ELMA', 'KİTAP', 'MASA', 'ÇİÇEK', 'BAHAR', 'ARABA', 'DENİZ', 'TEPE', 'KAPAK', 'ALTIN',
         'SEVGİ', 'MERAK', 'KARAR', 'LİMAN', 'DEFTER', 'ADANA', 'İZMİR', 'TOKAT', 'EKMEK', 'KELEBEK', 'SALATA', 'BALKON']


@stem_limit(1)
def kelime_dizilis(r):
    w = r.choice(WORDS)
    v = math.factorial(len(w))
    for ch in set(w):
        v //= math.factorial(w.count(ch))
    reps = ', '.join(f'{ch}: {w.count(ch)}' for ch in sorted(set(w)) if w.count(ch) > 1) or 'yok'
    return make(r, 'Permütasyon', f'{w} kelimesinin harfleri yer değiştirilerek anlamlı ya da anlamsız kaç farklı kelime yazılabilir?',
                v, num_distractors(r, v, max(6, v // 4)) + [math.factorial(len(w))],
                f'{len(w)}! / (tekrar edenlerin faktöriyelleri) = {v} (tekrarlar: {reps}).')


@stem_limit(1)
def zar(r):
    s = r.randint(3, 11)
    ways = sum(1 for a in range(1, 7) for b in range(1, 7) if a + b == s)
    p = Fraction(ways, 36)
    return make(r, 'Olasılık', f'İki zar birlikte atıldığında üst yüze gelen sayıların toplamının {s} olma olasılığı kaçtır?',
                fmt_frac(p), frac_distractors(r, p) + [f'{ways}/6', '1/6'], f'{ways} durum / 36 = {fmt_frac(p)}.')


@stem_limit(1)
def torba(r):
    k, m = r.randint(2, 8), r.randint(2, 8)
    if r.random() < 0.5:
        p = Fraction(math.comb(k, 2), math.comb(k + m, 2))
        q = f'Bir torbada {k} kırmızı ve {m} mavi bilye vardır. Rastgele çekilen 2 bilyenin ikisinin de kırmızı olma olasılığı kaçtır?'
        e = f'C({k}, 2) / C({k + m}, 2) = {fmt_frac(p)}.'
    else:
        p = Fraction(k * m, math.comb(k + m, 2))
        q = f'Bir torbada {k} kırmızı ve {m} mavi bilye vardır. Rastgele çekilen 2 bilyenin farklı renkte olma olasılığı kaçtır?'
        e = f'{k}·{m} / C({k + m}, 2) = {fmt_frac(p)}.'
    return make(r, 'Olasılık', q, fmt_frac(p), frac_distractors(r, p), e)


# --- Fonksiyonlar ---
@stem_limit(1)
def ters_fonksiyon(r):
    a = r.choice([2, 3, 4, 5, -2, -3])
    b = r.randint(-9, 9)
    x = r.randint(-6, 8)
    y = a * x + b
    return make(r, 'Fonksiyonlar', f'f(x) = {poly_str([a, b])} olduğuna göre f⁻¹({y}) kaçtır?', x,
                num_distractors(r, x, 5, positive=False) + [y], f'f(x) = {y} → x = ({y} − ({b}))/{a} = {x}.')


@stem_limit(1)
def bilesik(r):
    a, b, c, d = r.choice([1, 2, 3, -1]), r.randint(-6, 6), r.choice([2, 3, -2]), r.randint(-5, 5)
    k = r.randint(-3, 4)
    # (f∘g)(k), f(x) = ax + b, g(x) = cx + d
    v = a * (c * k + d) + b
    return make(r, 'Fonksiyonlar', f'f(x) = {poly_str([a, b])} ve g(x) = {poly_str([c, d])} olduğuna göre (f∘g)({k}) kaçtır?', v,
                num_distractors(r, v, 6, positive=False) + [c * (a * k + b) + d],
                f'g({k}) = {c * k + d}, f({c * k + d}) = {v}.')


GENERATORS = [
    (log_deger, 3), (log_denklem, 3), (log_carpim, 2), (ustel_denklem, 3),
    (polinom_deger, 3), (polinom_kalan, 3), (katsayi_toplami, 2),
    (kok_toplam_carpim, 4), (diskriminant, 2), (parabol_tepe, 3),
    (karmasik_carpim, 3), (karmasik_mutlak, 1), (i_kuvvet, 1),
    (aritmetik, 3), (geometrik, 2),
    (limit_kesir, 3), (limit_sonsuz, 2),
    (turev_deger, 4), (teget_egim, 3), (ekstremum, 3),
    (belirli_integral, 3), (integral_kup, 2), (alan, 1),
    (trig_deger, 2), (periyot, 2), (radyan, 1),
    (kombinasyon, 2), (permutasyon, 2), (kelime_dizilis, 1), (zar, 1), (torba, 2),
    (ters_fonksiyon, 2), (bilesik, 2),
]
