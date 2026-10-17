"""AYT Biyoloji: genetik olasılıkları, Hardy-Weinberg, protein sentezi ve
enerji piramidi hesaplanır; sistemler ve hormonlar tablodan."""
import itertools
from fractions import Fraction

from common import define_gens, fact_gen, fmt_frac, make, num_distractors, relation_gens, stem_limit

T = 'AYT_BIY'

GENES = 'ABCD'


def offspring(p1, p2):
    """'Aa', 'aa' → {genotip: olasılık}."""
    out = {}
    for x in p1:
        for y in p2:
            g = ''.join(sorted(x + y))  # büyük harf önce
            out[g] = out.get(g, 0) + Fraction(1, 4)
    return out


def frac_opts(r, f):
    cands = [f * 2, f / 2, 1 - f, f + Fraction(1, 8), f + Fraction(1, 4), f - Fraction(1, 16), Fraction(1, 2), Fraction(1, 4),
             Fraction(3, 16), Fraction(9, 16), Fraction(1, 16), Fraction(3, 8), Fraction(1, 8), Fraction(3, 4)]
    out = []
    for c in cands:
        if 0 < c <= 1 and c != f and fmt_frac(c) not in out:
            out.append(fmt_frac(c))
    r.shuffle(out)
    return out


@stem_limit(1)
def genotip_olasilik(r):
    n = r.choice([2, 2, 3])
    p1 = [r.choice(['AA', 'Aa', 'aa', 'Aa', 'Aa']).replace('A', GENES[i]).replace('a', GENES[i].lower()) for i in range(n)]
    p2 = [r.choice(['AA', 'Aa', 'aa', 'Aa', 'Aa']).replace('A', GENES[i]).replace('a', GENES[i].lower()) for i in range(n)]
    target, prob = [], Fraction(1)
    for i in range(n):
        dist = offspring(p1[i], p2[i])
        g = r.choice(list(dist))
        target.append(g)
        prob *= dist[g]
    if prob in (0, 1):
        return None
    return make(r, 'Kalıtım', f'{"".join(p1)} × {"".join(p2)} çaprazlamasında oluşacak bir bireyin {"".join(target)} genotipinde olma olasılığı kaçtır? (Genler bağımsız)',
                fmt_frac(prob), frac_opts(r, prob), 'Her gen ayrı çaprazlanır, olasılıklar çarpılır: ' +
                ' · '.join(fmt_frac(offspring(p1[i], p2[i])[target[i]]) for i in range(n)) + f' = {fmt_frac(prob)}.')


@stem_limit(1)
def fenotip_olasilik(r):
    n = r.choice([2, 3])
    p1 = [r.choice(['AA', 'Aa', 'aa', 'Aa']).replace('A', GENES[i]).replace('a', GENES[i].lower()) for i in range(n)]
    p2 = [r.choice(['Aa', 'aa', 'Aa']).replace('A', GENES[i]).replace('a', GENES[i].lower()) for i in range(n)]
    want, prob, parts = [], Fraction(1), []
    for i in range(n):
        dist = offspring(p1[i], p2[i])
        dom = r.random() < 0.5
        pr = sum(v for g, v in dist.items() if (g[0].isupper()) == dom)
        want.append(GENES[i] + '_' if dom else GENES[i].lower() * 2)
        prob *= pr
        parts.append(fmt_frac(pr))
    if prob in (0, 1):
        return None
    return make(r, 'Kalıtım', f'{"".join(p1)} × {"".join(p2)} çaprazlamasında oluşacak bir bireyin {"".join(want)} fenotipinde olma olasılığı kaçtır? (Büyük harfli alel baskın, genler bağımsız)',
                fmt_frac(prob), frac_opts(r, prob), f'Gen gen olasılıklar: {" · ".join(parts)} = {fmt_frac(prob)}.')


@stem_limit(1)
def gamet(r):
    n = r.randint(2, 5)
    g = ''.join(r.choice([L + L, L + L.lower(), L.lower() * 2]) for L in GENES[:n] + 'E'[:max(0, n - 4)])
    het = sum(1 for i in range(0, len(g), 2) if g[i] != g[i + 1])
    v = 2 ** het
    return make(r, 'Kalıtım', f'{g} genotipli bir birey kaç çeşit gamet oluşturabilir? (Genler bağımsız)', v,
                [x for x in [v * 2, max(1, v // 2), het, 2 * het, v + 1, 3 ** het] if x != v],
                f'Heterozigot gen sayısı {het} → 2^{het} = {v} çeşit gamet.')


BLOOD = {'A': ['AA', 'A0'], 'B': ['BB', 'B0'], 'AB': ['AB'], '0': ['00']}


def blood_pheno(g):
    s = set(g)
    if s == {'A', 'B'}:
        return 'AB'
    if 'A' in s:
        return 'A'
    if 'B' in s:
        return 'B'
    return '0'


@stem_limit(1)
def kan_grubu(r):
    g1 = r.choice(['AA', 'A0', 'BB', 'B0', 'AB', '00'])
    g2 = r.choice(['A0', 'B0', 'AB', '00', 'AA'])
    dist = {}
    for x in g1:
        for y in g2:
            p = blood_pheno(x + y)
            dist[p] = dist.get(p, 0) + Fraction(1, 4)
    want = r.choice(['A', 'B', 'AB', '0'])
    pr = dist.get(want, Fraction(0))
    return make(r, 'Kalıtım', f'Genotipleri {g1} ve {g2} olan anne ve babanın çocuğunun {want} kan grubundan olma olasılığı kaçtır?',
                fmt_frac(pr), [x for x in frac_opts(r, pr) + ['0'] if x != fmt_frac(pr)],
                'Olası çocuklar: ' + ', '.join(f'{k}: {fmt_frac(v)}' for k, v in sorted(dist.items())) + '.')


@stem_limit(1)
def renk_korlugu(r):
    mother = r.choice(['XᴬXᴬ', 'XᴬXᵃ', 'XᵃXᵃ'])
    father = r.choice(['XᴬY', 'XᵃY'])
    mom = [mother[:2], mother[2:]]
    kids = [(m, f) for m in mom for f in ([father[:2], 'Y'])]
    sons = [m for m, f in kids if f == 'Y']
    daughters = [(m, f) for m, f in kids if f != 'Y']
    if r.random() < 0.5:
        pr = Fraction(sum(1 for m in sons if m == 'Xᵃ'), len(sons))
        q = 'doğacak bir erkek çocuğun renk körü olma olasılığı'
    else:
        pr = Fraction(sum(1 for m, f in daughters if m == 'Xᵃ' and f == 'Xᵃ'), len(daughters))
        q = 'doğacak bir kız çocuğun renk körü olma olasılığı'
    return make(r, 'Eşeye bağlı kalıtım', f'Anne {mother}, baba {father} genotipindedir. Bu aileden {q} kaçtır? (ᵃ: renk körlüğü aleli, çekinik)',
                fmt_frac(pr), [x for x in ['0', '1/4', '1/2', '3/4', '1', '1/8'] if x != fmt_frac(pr)],
                'Erkek çocuk X\'ini anneden alır; kız çocuğun renk körü olması için iki X de ᵃ taşımalıdır.')


@stem_limit(1)
def hardy_weinberg(r):
    q = Fraction(r.randint(1, 9), 10)
    p = 1 - q
    kind = r.choice(['het', 'dom', 'q'])
    qq = q * q
    if kind == 'q':
        return make(r, 'Popülasyon genetiği', f'Hardy-Weinberg dengesindeki bir popülasyonda çekinik fenotipli bireylerin oranı {fmt_frac(qq)} ise çekinik alel frekansı (q) kaçtır?',
                    fmt_frac(q), [fmt_frac(x) for x in [qq, p, q / 2, Fraction(1, 2), 2 * p * q] if x != q and 0 < x < 1],
                    f'q² = {fmt_frac(qq)} → q = {fmt_frac(q)}.')
    v = 2 * p * q if kind == 'het' else p * p + 2 * p * q
    word = 'heterozigot bireylerin' if kind == 'het' else 'baskın fenotipli bireylerin'
    return make(r, 'Popülasyon genetiği', f'Hardy-Weinberg dengesindeki bir popülasyonda çekinik alel frekansı q = {fmt_frac(q)} ise {word} oranı kaçtır?',
                fmt_frac(v), [fmt_frac(x) for x in [p * p, qq, 2 * p * q, p * p + 2 * p * q, p, q, 1 - qq * 2] if x != v and 0 < x < 1],
                f'p = {fmt_frac(p)}; p² + 2pq + q² = 1 → oran {fmt_frac(v)}.')


COMP = {'A': 'U', 'T': 'A', 'G': 'C', 'C': 'G'}


@stem_limit(1)
def mrna(r):
    dna = ''.join(r.choice('ATGC') for _ in range(9))
    m = ''.join(COMP[x] for x in dna)
    wrong = [m.replace('U', 'T'), ''.join({'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G'}[x] for x in dna), dna.replace('T', 'U'),
             m[::-1], m[:-1] + ('A' if m[-1] != 'A' else 'G')]
    return make(r, 'Protein sentezi', f'Kalıp DNA zincirinin baz dizilimi 3\'-{dna}-5\' ise bu kalıptan sentezlenen mRNA dizilimi hangisidir?',
                f"5'-{m}-3'", [f"5'-{w}-3'" for w in wrong if w != m], 'A→U, T→A, G→C, C→G eşleşir; mRNA\'da timin yerine urasil bulunur.')


@stem_limit(1)
def kodon_sayisi(r):
    aa = r.randint(50, 600)
    if r.random() < 0.5:
        v = 3 * aa + 3
        return make(r, 'Protein sentezi', f'{aa} amino asitlik bir polipeptidi şifreleyen mRNA\'da (bitiş kodonu dâhil) en az kaç nükleotit bulunur?',
                    v, [3 * aa, aa, 3 * aa + 1, 6 * aa + 6, 2 * aa + 3], f'Her amino asit 3 nükleotit + bitiş kodonu 3: {3 * aa} + 3 = {v}.')
    v = aa - 1
    return make(r, 'Protein sentezi', f'{aa} amino asitten oluşan tek zincirli bir polipeptitte kaç peptit bağı bulunur?', v,
                [aa, aa + 1, aa - 2, 2 * aa, aa // 2], f'n amino asit → n − 1 peptit bağı: {v}.')


@stem_limit(1)
def enerji_piramidi(r):
    e = r.choice([10 ** k for k in range(4, 8)]) * r.choice([1, 2, 5])
    lvl = r.randint(2, 4)
    names = {2: 'birincil tüketicilere (otçullar)', 3: 'ikincil tüketicilere', 4: 'üçüncül tüketicilere'}
    v = e // 10 ** (lvl - 1)
    return make(r, 'Ekoloji', f'Üreticilerin bağladığı enerji {e} kJ ise %10 kuralına göre {names[lvl]} aktarılan enerji yaklaşık kaç kJ\'dir?',
                f'{v} kJ', [f'{x} kJ' for x in [v * 10, v // 10 if v >= 10 else v * 100, e, v * 2, v * 5] if x != v],
                f'Her basamakta yaklaşık %10 aktarılır: {e}·(1/10)^{lvl - 1} = {v} kJ.')


HORMONES = [
    ('İnsülin', 'Pankreas'), ('Glukagon', 'Pankreas'), ('Tiroksin', 'Tiroit bezi'), ('Kalsitonin', 'Tiroit bezi'),
    ('Parathormon', 'Paratiroit bezi'), ('Adrenalin', 'Böbrek üstü bezi'), ('Kortizol', 'Böbrek üstü bezi'), ('Aldosteron', 'Böbrek üstü bezi'),
    ('Büyüme hormonu (STH)', 'Hipofiz bezi'), ('Prolaktin', 'Hipofiz bezi'), ('TSH', 'Hipofiz bezi'), ('FSH', 'Hipofiz bezi'), ('LH', 'Hipofiz bezi'),
    ('Melatonin', 'Epifiz bezi'), ('Östrojen', 'Yumurtalık'), ('Progesteron', 'Yumurtalık'), ('Testosteron', 'Testis'),
]
HORMONE_DO = {
    'İnsülin': 'Kan şekerini düşürür', 'Glukagon': 'Kan şekerini yükseltir', 'Kalsitonin': 'Kandaki kalsiyum düzeyini düşürür',
    'Parathormon': 'Kandaki kalsiyum düzeyini yükseltir', 'ADH (antidiüretik hormon)': 'Böbreklerde suyun geri emilimini artırır',
    'Tiroksin': 'Metabolizma hızını düzenler', 'Melatonin': 'Uyku-uyanıklık döngüsünü düzenler', 'Prolaktin': 'Süt üretimini uyarır',
    'Oksitosin': 'Doğumda rahim kasılmalarını uyarır', 'Aldosteron': 'Böbreklerde sodyum geri emilimini artırır',
    'Büyüme hormonu (STH)': 'Kemik ve kas büyümesini uyarır',
}
ORGANS = [  # (yapı, sistem)
    ('Nefron', 'Boşaltım sistemi'), ('Üreter', 'Boşaltım sistemi'), ('İdrar kesesi', 'Boşaltım sistemi'), ('Böbrek', 'Boşaltım sistemi'),
    ('Alveol', 'Solunum sistemi'), ('Bronş', 'Solunum sistemi'), ('Gırtlak', 'Solunum sistemi'), ('Soluk borusu', 'Solunum sistemi'),
    ('Villus', 'Sindirim sistemi'), ('Pankreas kanalı', 'Sindirim sistemi'), ('Yemek borusu', 'Sindirim sistemi'), ('Safra kesesi', 'Sindirim sistemi'),
    ('Kalp kapakçığı', 'Dolaşım sistemi'), ('Aort', 'Dolaşım sistemi'), ('Kılcal damar', 'Dolaşım sistemi'), ('Lenf düğümü', 'Dolaşım sistemi'),
    ('Beyincik', 'Sinir sistemi'), ('Omurilik soğanı', 'Sinir sistemi'), ('Hipotalamus', 'Sinir sistemi'), ('Akson', 'Sinir sistemi'),
    ('Kornea', 'Duyu organları'), ('Kohlea (salyangoz)', 'Duyu organları'), ('Retina', 'Duyu organları'), ('Tat tomurcuğu', 'Duyu organları'),
]
BRAIN = {
    'Beyincik': 'Vücudun dengesini ve kas hareketlerinin uyumunu sağlar',
    'Omurilik soğanı': 'Solunum, kalp atışı ve yutkunma gibi hayati refleksleri yönetir',
    'Hipotalamus': 'Vücut sıcaklığını, açlık ve susuzluk duygusunu düzenler',
    'Talamus': 'Koku dışındaki duyu impulslarını beyin kabuğuna aktarır',
    'Beyin kabuğu (korteks)': 'Düşünme, öğrenme, hafıza ve istemli hareketleri yönetir',
    'Omurilik': 'Refleks merkezidir; impulsları beyne ve beyinden organlara iletir',
    'Pons': 'Beyin ile beyincik arasındaki bağlantıyı sağlar, solunumu düzenlemeye yardım eder',
}
DEFS = {
    'Glikoliz': 'Glikozun sitoplazmada pirüvata parçalanması',
    'Krebs döngüsü': 'Hücresel solunumda mitokondri matriksinde gerçekleşen döngüsel tepkimeler',
    'Kalvin döngüsü': 'Fotosentezin ışıktan bağımsız tepkimeleri; kloroplastın stromasında CO₂ bağlanması',
    'Fermantasyon': 'Oksijensiz ortamda glikozun kısmen yıkılarak az ATP üretilmesi',
    'Fotoliz': 'Işık enerjisiyle suyun parçalanması',
    'Translasyon': 'mRNA\'daki şifreye göre ribozomda protein sentezlenmesi',
    'Transkripsiyon': 'DNA\'daki bilginin mRNA\'ya aktarılması',
    'Replikasyon': 'DNA\'nın kendini eşlemesi',
    'Mutasyon': 'Kalıtım materyalinde kalıcı değişiklik',
    'Krossing-over': 'Mayozda homolog kromozomlar arasında parça değişimi',
    'Doğal seçilim': 'Çevreye uyumlu bireylerin daha çok hayatta kalıp üremesi',
    'Simbiyoz': 'Farklı türlerin sürekli bir arada yaşaması',
    'Homeostazi': 'Vücudun iç ortamını belirli sınırlar içinde sabit tutması',
}
FACTS = [
    ('Hücresel solunumda oksijenli solunumun son elektron alıcısı nedir?', 'Oksijen', ['Karbondioksit', 'NAD⁺', 'FAD', 'Pirüvat', 'Glikoz']),
    ('Fotosentezde ışığa bağımlı tepkimeler kloroplastın neresinde gerçekleşir?', 'Granalarda (tilakoit zarlarında)', ['Stromada', 'Dış zarda', 'Ribozomda', 'Mitokondride', 'Sitoplazmada']),
    ('İnsanda kanı vücuda pompalayan kalp odacığı hangisidir?', 'Sol karıncık', ['Sağ karıncık', 'Sol kulakçık', 'Sağ kulakçık', 'Aort kapakçığı', 'Akciğer atardamarı']),
    ('Akciğerlerden kalbe temiz kan getiren damar hangisidir?', 'Akciğer toplardamarı', ['Akciğer atardamarı', 'Aort', 'Üst ana toplardamar', 'Alt ana toplardamar', 'Koroner atardamar']),
    ('Proteinlerin kimyasal sindirimi ilk olarak nerede başlar?', 'Midede', ['Ağızda', 'İnce bağırsakta', 'Kalın bağırsakta', 'Yemek borusunda', 'Karaciğerde']),
    ('Karbonhidratların kimyasal sindirimi ilk olarak nerede başlar?', 'Ağızda', ['Midede', 'İnce bağırsakta', 'Kalın bağırsakta', 'Yemek borusunda', 'Pankreasta']),
    ('Yağların sindirimine yardım eden safra nerede üretilir?', 'Karaciğerde', ['Safra kesesinde', 'Pankreasta', 'Midede', 'Dalakta', 'İnce bağırsakta']),
    ('Kanın pıhtılaşmasında görev alan kan hücresi hangisidir?', 'Trombosit', ['Alyuvar', 'Akyuvar', 'Lenfosit', 'Nötrofil', 'Monosit']),
    ('Bağışıklık sisteminde antikor üreten hücreler hangileridir?', 'B lenfositlerinden gelişen plazma hücreleri', ['Alyuvarlar', 'Trombositler', 'T yardımcı hücreler', 'Makrofajlar', 'Sinir hücreleri']),
    ('Bitkilerde suyun kökten yapraklara taşınmasını sağlayan doku hangisidir?', 'Odun borusu (ksilem)', ['Soymuk borusu (floem)', 'Epidermis', 'Kambiyum', 'Parankima', 'Mantar doku']),
    ('Bitkilerde fotosentez ürünlerini taşıyan doku hangisidir?', 'Soymuk borusu (floem)', ['Odun borusu (ksilem)', 'Epidermis', 'Kök tüyü', 'Mantar doku', 'Stoma']),
    ('Bitkilerde gaz alışverişini sağlayan yapı hangisidir?', 'Stoma', ['Kök tüyü', 'Ksilem', 'Kambiyum', 'Kutikula', 'Floem']),
    ('Sinir hücresinde impulsu hücre gövdesinden uzaklaştıran uzantı hangisidir?', 'Akson', ['Dendrit', 'Miyelin kılıf', 'Sinaps', 'Ranvier boğumu', 'Hücre gövdesi']),
    ('Gözde ışığa duyarlı reseptörlerin bulunduğu tabaka hangisidir?', 'Retina', ['Kornea', 'İris', 'Mercek', 'Koroit', 'Sert tabaka']),
    ('Kulakta dengeyi sağlayan yapılar nerededir?', 'İç kulakta', ['Dış kulakta', 'Orta kulakta', 'Kulak kepçesinde', 'Östaki borusunda', 'Kulak zarında']),
]


GENERATORS = [
    (genotip_olasilik, 3), (fenotip_olasilik, 3), (gamet, 2), (kan_grubu, 2), (renk_korlugu, 1), (hardy_weinberg, 2),
    (mrna, 2), (kodon_sayisi, 2), (enerji_piramidi, 1), (fact_gen('Sistemler', FACTS), 1),
] + relation_gens('Endokrin sistem', HORMONES, fwd='{item} hormonu hangi bez tarafından salgılanır?',
                  has='Aşağıdaki hormonlardan hangisi {group} tarafından salgılanır?',
                  has_not='Aşağıdaki hormonlardan hangisi {group} tarafından salgılanmaz?', weights=(1, 1, 1), has_limit=3, has_not_limit=6) \
  + define_gens('Endokrin sistem', HORMONE_DO, fwd='{k} hormonunun etkisi aşağıdakilerden hangisidir?',
                back='"{v}" etkisi olan hormon hangisidir?') \
  + relation_gens('Sistemler', ORGANS, fwd='{item} hangi sisteme ait bir yapıdır?',
                  has='Aşağıdaki yapılardan hangisi {group} içinde yer alır?',
                  has_not='Aşağıdaki yapılardan hangisi {group} içinde yer almaz?', has_limit=3, has_not_limit=6) \
  + define_gens('Sinir sistemi', BRAIN, fwd='{k} bölümünün görevi aşağıdakilerden hangisidir?',
                back='"{v}" görevi merkezi sinir sisteminin hangi bölümüne aittir?') \
  + define_gens('Kavramlar', DEFS, fwd='"{k}" kavramı aşağıdakilerden hangisidir?',
                back='"{v}" hangi kavramla açıklanır?')
