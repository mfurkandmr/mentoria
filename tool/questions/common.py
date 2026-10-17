"""Soru üreticisi ortak araçları.

Her soru: {"id", "t" (konu), "q" (soru), "o" (5 şık), "a" (doğru şık 0..4),
"e" (kısa çözüm)}. Tüm sorular bu depoda özgün olarak üretilir (telifsiz).
"""
import math
import random
from fractions import Fraction

LETTERS = 'ABCDE'


def fmt_num(x):
    """Türkçe ondalık: 2.5 → '2,5'; tam sayılar olduğu gibi."""
    if isinstance(x, Fraction):
        return fmt_frac(x)
    if isinstance(x, float):
        if abs(x - round(x)) < 1e-9:
            return str(int(round(x)))
        return ('%.2f' % x).rstrip('0').rstrip('.').replace('.', ',')
    return str(x)


def fmt_frac(f):
    f = Fraction(f)
    if f.denominator == 1:
        return str(f.numerator)
    return f'{f.numerator}/{f.denominator}'


def make(rng, topic, q, correct, distractors, explanation):
    """5 şıklı soru; doğru şık rastgele yerde. Şıklar benzersiz olmalı."""
    correct = str(correct)
    opts = []
    for d in distractors:
        d = str(d)
        if d != correct and d not in opts:
            opts.append(d)
    if len(opts) < 4:
        return None
    opts = opts[:4]
    pos = rng.randrange(5)
    opts.insert(pos, correct)
    return {'t': topic, 'q': q, 'o': opts, 'a': pos, 'e': explanation}


def num_distractors(rng, value, spread=None, count=8, positive=True, integer=True):
    """Doğru sayıya yakın, makul yanlış şıklar."""
    out = []
    spread = spread or max(2, abs(value) // 5 + 2)
    tries = 0
    while len(out) < count and tries < 200:
        tries += 1
        d = value + rng.choice([-1, 1]) * rng.randint(1, spread)
        if positive and d <= 0:
            continue
        if d != value and d not in out:
            out.append(d)
    rng.shuffle(out)
    return out


def build(subject, target, generators, seed, max_same_stem=1):
    """[generators] (ağırlıklı) sırayla çalıştırılır; benzersiz [target] soru.

    max_same_stem: aynı soru köküne izin verilen en çok soru (farklı
    şıklarla). Sayısal sorularda 1 (kök hep farklı).
    """
    rng = random.Random(seed)
    seen_keys, stems, out = set(), {}, []
    pool = []
    for gen, weight in generators:
        pool += [gen] * weight
    attempts = 0
    while len(out) < target and attempts < target * 400:
        attempts += 1
        gen = rng.choice(pool)
        item = gen(rng)
        if item is None:
            continue
        key = item['q'] + '|' + '|'.join(sorted(item['o']))
        if key in seen_keys:
            continue
        limit = getattr(gen, 'max_same_stem', max_same_stem)
        if stems.get(item['q'], 0) >= limit:
            continue
        seen_keys.add(key)
        stems[item['q']] = stems.get(item['q'], 0) + 1
        out.append(item)
    if len(out) < target:
        raise SystemExit(f'{subject}: yalnızca {len(out)} / {target} soru üretilebildi')
    for i, item in enumerate(out, 1):
        item['id'] = f'{subject}-{i:04d}'
    return out


def stem_limit(n):
    """Aynı kök farklı şıklarla en çok n kez kullanılabilir (kategori soruları)."""
    def deco(fn):
        fn.max_same_stem = n
        return fn
    return deco


def gcd(a, b):
    return math.gcd(a, b)


def lcm(a, b):
    return a * b // math.gcd(a, b)


_UNITS = ['', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz']
_TENS = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış', 'yetmiş', 'seksen', 'doksan']


def _last_word(n):
    n = abs(int(n))
    if n == 0:
        return 'sıfır'
    if n % 10:
        return _UNITS[n % 10]
    if n % 100:
        return _TENS[(n // 10) % 10]
    if n % 1000:
        return 'yüz'
    if n % 1000000:
        return 'bin'
    return 'milyon'


def _last_vowel(w):
    return [c for c in w if c in 'aeıioöuü'][-1]


def ek_dir(n):
    """13 → "13'tür", 20 → "20'dir" (sayı + -dir eki, ünlü ve ünsüz uyumlu)."""
    w = _last_word(n)
    v = {'a': 'ı', 'ı': 'ı', 'e': 'i', 'i': 'i', 'o': 'u', 'u': 'u', 'ö': 'ü', 'ü': 'ü'}[_last_vowel(w)]
    c = 't' if w[-1] in 'fstkçşhp' else 'd'
    return f"{n}'{c}{v}r"


def ek_i(n):
    """Belirtme / iyelik: %20 → "%20'si", %15 → "%15'i"."""
    w = _last_word(n)
    v = {'a': 'ı', 'ı': 'ı', 'e': 'i', 'i': 'i', 'o': 'u', 'u': 'u', 'ö': 'ü', 'ü': 'ü'}[_last_vowel(w)]
    return f"{n}'{'s' if w[-1] in 'aeıioöuü' else ''}{v}"
