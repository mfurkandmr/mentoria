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


def relation_gens(topic, rel, fwd=None, has=None, has_not=None, weights=(1, 1, 1),
                  has_limit=6, has_not_limit=12, extra_groups=(), explain=None):
    """(öğe, grup) tablosundan üç soru kalıbı üretir:

    fwd     "... {item} ..." → doğru cevap grubu (çeldirici: diğer gruplar)
    has     "... {group} ..." → gruba ait bir öğe (çeldirici: başka grupların öğeleri)
    has_not "... {group} ..." → gruba ait olmayan öğe (diğer 4 şık gruptan)

    Şablonlar None ise o kalıp kullanılmaz. Dönüş: [(üretici, ağırlık), ...].
    """
    groups = {}
    for item, g in rel:
        groups.setdefault(g, []).append(item)
    all_groups = list(groups) + [g for g in extra_groups if g not in groups]
    explain = explain or (lambda item, g: f'{item}: {g}.')
    out = []

    if fwd:
        @stem_limit(1)
        def gen_fwd(r):
            item, g = r.choice(rel)
            others = [x for x in all_groups if x != g]
            r.shuffle(others)
            return make(r, topic, fwd.format(item=item), g, others, explain(item, g))
        out.append((gen_fwd, weights[0]))

    if has:
        @stem_limit(has_limit)
        def gen_has(r):
            g = r.choice(list(groups))
            item = r.choice(groups[g])
            others = [x for x, gg in rel if gg != g and x not in groups[g]]
            others = r.sample(others, min(4, len(others)))
            return make(r, topic, has.format(group=g), item, others, explain(item, g))
        out.append((gen_has, weights[1]))

    if has_not:
        big = [g for g, v in groups.items() if len(v) >= 4]
        if big:
            @stem_limit(has_not_limit)
            def gen_has_not(r):
                g = r.choice(big)
                inside = r.sample(groups[g], 4)
                outside = [x for x, gg in rel if gg != g and x not in groups[g]]
                item = r.choice(outside)
                other_g = next(gg for x, gg in rel if x == item)
                return make(r, topic, has_not.format(group=g), item, inside,
                            f'{item}: {other_g}. Diğerleri: {g}.')
            out.append((gen_has_not, weights[2]))
    return out


def define_gens(topic, defs, fwd, back, weights=(1, 1)):
    """{kavram: tanım} → "tanımı nedir" ve "hangi kavramdır" soruları."""
    keys = list(defs)

    @stem_limit(1)
    def gen_fwd(r):
        k = r.choice(keys)
        return make(r, topic, fwd.format(k=k), defs[k], [defs[x] for x in r.sample(keys, len(keys)) if x != k],
                    f'{k}: {defs[k]}')

    @stem_limit(1)
    def gen_back(r):
        k = r.choice(keys)
        return make(r, topic, back.format(v=defs[k]), k, [x for x in r.sample(keys, len(keys)) if x != k],
                    f'{k}: {defs[k]}')
    return [(gen_fwd, weights[0]), (gen_back, weights[1])]


def chrono_gens(topic, events, limit=60, weights=(3, 2, 2, 2)):
    """(olay, yıl) tablosu → yıl, yüzyıl, en önce, en sonra soruları."""
    count = {}
    for _, y in events:
        count[y] = count.get(y, 0) + 1
    unique = [(e, y) for e, y in events if count[y] == 1]

    @stem_limit(1)
    def yil(r):
        e, y = r.choice(events)
        return make(r, topic, f'{e} hangi yılda gerçekleşmiştir?', y,
                    num_distractors(r, y, 12 if y > 1900 else 25 if y > 1700 else 60), f'{e}: {y}.')

    @stem_limit(1)
    def yuzyil(r):
        e, y = r.choice(events)
        c = (y - 1) // 100 + 1
        return make(r, topic, f'{e} hangi yüzyılda gerçekleşmiştir?', f'{c}. yüzyıl',
                    [f'{x}. yüzyıl' for x in [c - 1, c + 1, c - 2, c + 2, c + 3] if x > 0],
                    f'{y} yılı {c}. yüzyıldadır.')

    def _order(first):
        @stem_limit(limit)
        def gen(r):
            picks = r.sample(unique, 5)
            pick = (min if first else max)(picks, key=lambda p: p[1])
            word = 'önce' if first else 'sonra'
            return make(r, topic, f'Aşağıdaki gelişmelerden hangisi diğerlerinden {word} gerçekleşmiştir?',
                        pick[0], [p[0] for p in picks if p != pick],
                        'Yıllar: ' + ', '.join(f'{e} ({y})' for e, y in sorted(picks, key=lambda p: p[1])) + '.')
        return gen
    return [(yil, weights[0]), (yuzyil, weights[1]), (_order(True), weights[2]), (_order(False), weights[3])]


def fact_gen(topic, facts):
    """[(soru, doğru, [çeldiriciler])] → tek kalıp."""
    @stem_limit(1)
    def gen(r):
        q, a, others = r.choice(facts)
        return make(r, topic, q, a, r.sample(others, len(others)), f'Doğru cevap: {a}.')
    return gen
