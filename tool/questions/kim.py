"""TYT Kimya: element tablosu ve hesap şablonları."""
from fractions import Fraction

from common import fmt_num, make, num_distractors, stem_limit

T = 'TYT_KIM'

# (Z, sembol, ad, grup (A), periyot, kütle numarası (en yaygın izotop))
ELEMENTS = [
    (1, 'H', 'Hidrojen', '1A', 1, 1), (2, 'He', 'Helyum', '8A', 1, 4),
    (3, 'Li', 'Lityum', '1A', 2, 7), (4, 'Be', 'Berilyum', '2A', 2, 9),
    (5, 'B', 'Bor', '3A', 2, 11), (6, 'C', 'Karbon', '4A', 2, 12),
    (7, 'N', 'Azot', '5A', 2, 14), (8, 'O', 'Oksijen', '6A', 2, 16),
    (9, 'F', 'Flor', '7A', 2, 19), (10, 'Ne', 'Neon', '8A', 2, 20),
    (11, 'Na', 'Sodyum', '1A', 3, 23), (12, 'Mg', 'Magnezyum', '2A', 3, 24),
    (13, 'Al', 'Alüminyum', '3A', 3, 27), (14, 'Si', 'Silisyum', '4A', 3, 28),
    (15, 'P', 'Fosfor', '5A', 3, 31), (16, 'S', 'Kükürt', '6A', 3, 32),
    (17, 'Cl', 'Klor', '7A', 3, 35), (18, 'Ar', 'Argon', '8A', 3, 40),
    (19, 'K', 'Potasyum', '1A', 4, 39), (20, 'Ca', 'Kalsiyum', '2A', 4, 40),
]
OTHER_SYMBOLS = [('Fe', 'Demir'), ('Cu', 'Bakır'), ('Zn', 'Çinko'), ('Ag', 'Gümüş'),
                 ('Au', 'Altın'), ('Hg', 'Cıva'), ('Pb', 'Kurşun'), ('Sn', 'Kalay'),
                 ('Br', 'Brom'), ('I', 'İyot'), ('Mn', 'Mangan'), ('Cr', 'Krom'),
                 ('Ni', 'Nikel'), ('Co', 'Kobalt'), ('Pt', 'Platin'), ('U', 'Uranyum')]
ALL_SYMBOLS = [(e[1], e[2]) for e in ELEMENTS] + OTHER_SYMBOLS

MASS = {'H': 1, 'C': 12, 'N': 14, 'O': 16, 'Na': 23, 'Mg': 24, 'Al': 27, 'S': 32,
        'Cl': 35.5, 'K': 39, 'Ca': 40}
COMPOUNDS = {  # formül → (atomlar, ad)
    'H₂O': ({'H': 2, 'O': 1}, 'Su'), 'CO₂': ({'C': 1, 'O': 2}, 'Karbon dioksit'),
    'CO': ({'C': 1, 'O': 1}, 'Karbon monoksit'), 'NH₃': ({'N': 1, 'H': 3}, 'Amonyak'),
    'CH₄': ({'C': 1, 'H': 4}, 'Metan'), 'NaCl': ({'Na': 1, 'Cl': 1}, 'Sodyum klorür'),
    'HCl': ({'H': 1, 'Cl': 1}, 'Hidrojen klorür'), 'NaOH': ({'Na': 1, 'O': 1, 'H': 1}, 'Sodyum hidroksit'),
    'CaCO₃': ({'Ca': 1, 'C': 1, 'O': 3}, 'Kalsiyum karbonat'), 'H₂SO₄': ({'H': 2, 'S': 1, 'O': 4}, 'Sülfürik asit'),
    'MgO': ({'Mg': 1, 'O': 1}, 'Magnezyum oksit'), 'CaO': ({'Ca': 1, 'O': 1}, 'Kalsiyum oksit'),
    'Al₂O₃': ({'Al': 2, 'O': 3}, 'Alüminyum oksit'), 'SO₂': ({'S': 1, 'O': 2}, 'Kükürt dioksit'),
    'SO₃': ({'S': 1, 'O': 3}, 'Kükürt trioksit'), 'KCl': ({'K': 1, 'Cl': 1}, 'Potasyum klorür'),
    'C₂H₆': ({'C': 2, 'H': 6}, 'Etan'), 'C₃H₈': ({'C': 3, 'H': 8}, 'Propan'),
    'N₂O': ({'N': 2, 'O': 1}, 'Diazot monoksit'), 'NO₂': ({'N': 1, 'O': 2}, 'Azot dioksit'),
    'MgCl₂': ({'Mg': 1, 'Cl': 2}, 'Magnezyum klorür'), 'CaCl₂': ({'Ca': 1, 'Cl': 2}, 'Kalsiyum klorür'),
    'KOH': ({'K': 1, 'O': 1, 'H': 1}, 'Potasyum hidroksit'), 'HNO₃': ({'H': 1, 'N': 1, 'O': 3}, 'Nitrik asit'),
}
WHOLE = {k: v for k, v in COMPOUNDS.items() if all(isinstance(MASS[a], int) for a in v[0])}


def mw(atoms):
    return sum(MASS[a] * n for a, n in atoms.items())


@stem_limit(1)
def sembol_ad(r):
    sym, name = r.choice(ALL_SYMBOLS)
    others = [n for s, n in r.sample(ALL_SYMBOLS, 8) if s != sym]
    return make(r, 'Element sembolleri', f'"{sym}" sembolü hangi elemente aittir?', name, others,
                f'{sym} = {name}.')


@stem_limit(1)
def ad_sembol(r):
    sym, name = r.choice(ALL_SYMBOLS)
    others = [s for s, n in r.sample(ALL_SYMBOLS, 8) if s != sym]
    return make(r, 'Element sembolleri', f'{name} elementinin sembolü aşağıdakilerden hangisidir?', sym, others,
                f'{name} = {sym}.')


def proton_notron(r):
    z, sym, name, *_rest = r.choice(ELEMENTS)
    a = _rest[2]
    if z == 1:
        return None
    n = a - z
    return make(r, 'Atom yapısı', f'Kütle numarası {a}, atom numarası {z} olan {sym} atomunun nötron sayısı kaçtır?',
                n, num_distractors(r, n, 3, positive=False) + [a, a + z],
                f'Nötron = kütle numarası − proton = {a} − {z} = {n}.')


def iyon_elektron(r):
    z, sym, name, grup, *_ = r.choice(ELEMENTS)
    charge = {'1A': 1, '2A': 2, '3A': 3, '6A': -2, '7A': -1, '5A': -3}.get(grup)
    if charge is None:
        return None
    e = z - charge
    ch = (f'{abs(charge) if abs(charge) > 1 else ""}{"+" if charge > 0 else "−"}')
    return make(r, 'Atom yapısı', f'Atom numarası {z} olan {sym} elementinin {sym}{ch} iyonunda kaç elektron vardır?',
                e, num_distractors(r, e, 3) + [z, z + charge],
                f'{"Elektron verir" if charge > 0 else "Elektron alır"}: {z} {"−" if charge > 0 else "+"} {abs(charge)} = {e}.')


def grup_bul(r):
    z, sym, name, grup, periyot, _ = r.choice(ELEMENTS)
    groups = ['1A', '2A', '3A', '4A', '5A', '6A', '7A', '8A']
    return make(r, 'Periyodik sistem', f'Atom numarası {z} olan {name} elementi periyodik sistemin hangi grubundadır?',
                grup, [g for g in groups if g != grup], f'Elektron dizilimi: {_dizilim(z)}; son katmanda {_last(z)} elektron → {grup}.')


def periyot_bul(r):
    z, sym, name, grup, periyot, _ = r.choice(ELEMENTS)
    return make(r, 'Periyodik sistem', f'Atom numarası {z} olan {sym} elementi kaçıncı periyottadır?',
                periyot, [1, 2, 3, 4, 5, 6], f'Katman sayısı = periyot: {_dizilim(z)} → {periyot}. periyot.')


def _dizilim(z):
    shells, left = [], z
    for cap in [2, 8, 8, 2]:
        take = min(cap, left)
        if take:
            shells.append(take)
        left -= take
    return ' ) '.join(str(s) for s in shells) + ' )'


def _last(z):
    left, last = z, 0
    for cap in [2, 8, 8, 2]:
        take = min(cap, left)
        if take:
            last = take
        left -= take
    return last


def katman(r):
    z, sym, name, *_ = r.choice(ELEMENTS)
    last = _last(z)
    return make(r, 'Periyodik sistem', f'{name} ({z}{sym}) atomunun son katmanında kaç elektron bulunur?',
                last, [1, 2, 3, 4, 5, 6, 7, 8], f'Dizilim {_dizilim(z)}; son katman {last} elektron.')


def formul_kutle(r):
    f, (atoms, name) = r.choice(list(WHOLE.items()))
    m = mw(atoms)
    return make(r, 'Mol kavramı', f'{f} ({name}) bileşiğinin mol kütlesi kaç g/mol\'dür? (' + ', '.join(f'{a}: {MASS[a]}' for a in atoms) + ')',
                m, num_distractors(r, m, 6) + [sum(MASS[a] for a in atoms)],
                ' + '.join(f'{n}·{MASS[a]}' for a, n in atoms.items()) + f' = {m} g/mol.')


def mol(r):
    f, (atoms, name) = r.choice(list(WHOLE.items()))
    m = mw(atoms)
    n = r.choice([Fraction(1, 2), 1, 2, 3, 4, 5, Fraction(1, 4), Fraction(3, 2)])
    g = m * n
    if g != int(g):
        return None
    g = int(g)
    return make(r, 'Mol kavramı', f'{g} gram {f} kaç moldür? ({f}: {m} g/mol)',
                fmt_num(Fraction(n)), [fmt_num(Fraction(x)) for x in [n * 2, n + 1, Fraction(1, 2) if n != Fraction(1, 2) else 2, n * 4, Fraction(n, 3)] if x != n],
                f'n = m / M = {g} / {m} = {fmt_num(Fraction(n))} mol.')


def tanecik(r):
    n = r.choice([Fraction(1, 2), 1, 2, 3, Fraction(1, 4), 5])
    total = n * 6
    return make(r, 'Mol kavramı', f'{fmt_num(Fraction(n))} mol CO₂ molekülünde kaç tane molekül vardır? (Avogadro sayısı: 6·10²³)',
                f'{fmt_num(Fraction(total))}·10²³', [f'{fmt_num(Fraction(x))}·10²³' for x in [total * 2, total + 6, total * 3, n, Fraction(total, 2)] if x != total],
                f'N = n · NA = {fmt_num(Fraction(n))} · 6·10²³ = {fmt_num(Fraction(total))}·10²³.')


def molarite(r):
    v = r.choice([Fraction(1, 2), 1, 2, Fraction(1, 4), 4, Fraction(1, 5)])
    m_ = r.choice([Fraction(1, 2), 1, 2, 3, Fraction(1, 10), Fraction(1, 5)])
    n = m_ * v
    def s(x):
        return fmt_num(float(x))
    return make(r, 'Çözeltiler', f'{s(n)} mol NaOH ile hazırlanan {s(v)} L çözeltinin molar derişimi kaç M\'dir?',
                s(m_), [s(x) for x in [n * v, m_ * 2, m_ + 1, Fraction(m_, 2), v] if x != m_],
                f'M = n / V = {s(n)} / {s(v)} = {s(m_)} M.')


def yuzde_derisim(r):
    solute = r.randint(1, 20) * 5
    total = r.choice([100, 200, 250, 400, 500])
    if solute >= total:
        return None
    p = Fraction(solute * 100, total)
    if p.denominator != 1:
        return None
    p = int(p)
    return make(r, 'Çözeltiler', f'{solute} g şeker {total - solute} g suda çözünüyor. Çözeltinin kütlece yüzde derişimi kaçtır?',
                f'%{p}', [f'%{x}' for x in num_distractors(r, p, 6) + [round(solute * 100 / (total - solute))]],
                f'Kütlece % = çözünen / çözelti · 100 = {solute} / {total} · 100 = %{p}.')


def gaz_hacim(r):
    n = r.choice([Fraction(1, 2), 1, 2, 3, Fraction(1, 4), 4])
    v = n * Fraction(224, 10)
    return make(r, 'Gazlar', f'Normal koşullarda {fmt_num(float(n))} mol ideal gaz kaç litre hacim kaplar?',
                fmt_num(float(v)), [fmt_num(float(x)) for x in [v * 2, v + Fraction(224, 10), n * 22, Fraction(v, 2) if n != Fraction(1, 2) else 44.8 * 2, n * 24] if x != v],
                f'NK\'da 1 mol gaz 22,4 L: {fmt_num(float(n))} · 22,4 = {fmt_num(float(v))} L.')


def ph(r):
    x = r.randint(1, 6)
    return make(r, 'Asitler ve bazlar', f'[H⁺] = 10⁻{x} M olan bir çözeltinin pH değeri kaçtır?',
                x, [14 - x if 14 - x != x else 7, -x, x + 1, x - 1 if x > 1 else 8, 10 * x],
                f'pH = −log[H⁺] = {x}; pH < 7 olduğundan asidiktir.')


def poh(r):
    x = r.randint(1, 6)
    return make(r, 'Asitler ve bazlar', f'25 °C\'de pOH değeri {x} olan bir çözeltinin pH değeri kaçtır?',
                14 - x, [x, 7, 14 + x, 14 - x + 1, 14 - x - 1],
                f'pH + pOH = 14 → pH = 14 − {x} = {14 - x}.')


def iyonik_formul(r):
    cations = [('Na', 1), ('K', 1), ('Mg', 2), ('Ca', 2), ('Al', 3)]
    anions = [('Cl', 1, 'klorür'), ('O', 2, 'oksit'), ('F', 1, 'florür'), ('S', 2, 'sülfür')]
    names = {'Na': 'Sodyum', 'K': 'Potasyum', 'Mg': 'Magnezyum', 'Ca': 'Kalsiyum', 'Al': 'Alüminyum'}
    (c, cq), (a, aq, an) = r.choice(cations), r.choice(anions)
    from math import gcd
    g = gcd(cq, aq)
    nc, na = aq // g, cq // g
    sub = '₀₁₂₃₄₅₆₇₈₉'
    def f(nc, na):
        return f'{c}{sub[nc] if nc > 1 else ""}{a}{sub[na] if na > 1 else ""}'
    right = f(nc, na)
    wrong = {f(x, y) for x in range(1, 4) for y in range(1, 4)} - {right}
    return make(r, 'Kimyasal türler', f'{names[c]} ({c}{"+" if cq == 1 else str(cq) + "+"}) ile {a} ({a}{"−" if aq == 1 else str(aq) + "−"}) iyonlarından oluşan {names[c].lower()} {an} bileşiğinin formülü hangisidir?',
                right, sorted(wrong), f'Yükler denkleştirilir: {nc}·(+{cq}) + {na}·(−{aq}) = 0 → {right}.')


@stem_limit(1)
def bilesik_ad(r):
    f, (atoms, name) = r.choice(list(COMPOUNDS.items()))
    others = [n for k, (a, n) in r.sample(list(COMPOUNDS.items()), 8) if k != f]
    return make(r, 'Kimyasal türler', f'{f} formüllü bileşiğin adı aşağıdakilerden hangisidir?', name, others,
                f'{f}: {name}.')


def kutle_korunum(r):
    a, b = r.randint(5, 60), r.randint(5, 60)
    left = r.randint(0, min(a, b) - 1)
    c = a + b - left
    return make(r, 'Kimyasal tepkimeler', f'{a} g X ile {b} g Y tepkimeye giriyor; tepkime sonunda {left} g Y artıyor ve yalnızca Z oluşuyor. Kaç gram Z oluşur?',
                c, num_distractors(r, c, 6) + [a + b],
                f'Kütle korunur: {a} + ({b} − {left}) = {c} g.')


GENERATORS = [
    (sembol_ad, 2), (ad_sembol, 2), (proton_notron, 2), (iyon_elektron, 2), (grup_bul, 2),
    (periyot_bul, 1), (katman, 1), (formul_kutle, 2), (mol, 2), (tanecik, 1), (molarite, 2),
    (yuzde_derisim, 2), (gaz_hacim, 1), (ph, 1), (poh, 1), (iyonik_formul, 2), (bilesik_ad, 2),
    (kutle_korunum, 2),
]
