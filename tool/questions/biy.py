"""TYT Biyoloji: hesaplanan genetik / DNA soruları ve bilgi soruları."""
import itertools
from fractions import Fraction

from common import fmt_frac, make, num_distractors, stem_limit

T = 'TYT_BIY'

ORGANISMS = {  # 2n kromozom sayısı
    'İnsan': 46, 'Şempanze': 48, 'Köpek': 78, 'Kedi': 38, 'Sirke sineği': 8, 'Bezelye': 14,
    'Mısır': 20, 'Buğday': 42, 'Patates': 48, 'Domates': 24, 'Pirinç': 24, 'At': 64,
    'Eşek': 62, 'Sığır': 60, 'Koyun': 54, 'Tavşan': 44, 'Fare': 40, 'Tavuk': 78,
}

COMP = {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G'}


def dna_eslenik(r):
    seq = ''.join(r.choice('ATGC') for _ in range(6))
    comp = ''.join(COMP[b] for b in seq)
    wrong = {seq, comp[::-1], ''.join({'A': 'U', 'T': 'A', 'G': 'C', 'C': 'G'}[b] for b in seq),
             ''.join(COMP[b] if i % 2 else b for i, b in enumerate(seq)), comp[1:] + comp[0]} - {comp}
    return make(r, 'Nükleik asitler', f'DNA\'nın bir zincirindeki baz dizilimi 5\'-{seq}-3\' olduğuna göre karşı zincirin dizilimi (3\'→5\') hangisidir?',
                comp, sorted(wrong), 'A ile T, G ile C eşleşir.')


def mrna(r):
    seq = ''.join(r.choice('ATGC') for _ in range(6))
    m = ''.join({'A': 'U', 'T': 'A', 'G': 'C', 'C': 'G'}[b] for b in seq)
    wrong = {''.join(COMP[b] for b in seq), seq, m.replace('U', 'T'), m[::-1], seq.replace('T', 'U')} - {m}
    return make(r, 'Protein sentezi', f'Kalıp DNA zinciri {seq} ise bu zincirden sentezlenen mRNA dizilimi hangisidir?',
                m, sorted(wrong), 'RNA\'da T yerine U bulunur: A→U, T→A, G→C, C→G.')


def nukleotit(r):
    total = r.randint(10, 60) * 20
    a = r.randint(total // 10, total // 2 - 10)
    a -= a % 2
    g = (total - 2 * a) // 2
    if g <= 0:
        return None
    return make(r, 'Nükleik asitler', f'Toplam {total} nükleotit içeren çift zincirli bir DNA molekülünde {a} adenin bulunuyor. Bu DNA\'da kaç guanin vardır?',
                g, num_distractors(r, g, 20) + [total - a, a],
                f'A = T = {a}; G = C = ({total} − 2·{a}) / 2 = {g}.')


def hidrojen(r):
    a, g = r.randint(5, 80), r.randint(5, 80)
    h = 2 * a + 3 * g
    return make(r, 'Nükleik asitler', f'Çift zincirli bir DNA\'da {a} adenin ve {g} guanin bulunuyor. Bu DNA\'daki toplam hidrojen bağı sayısı kaçtır?',
                h, num_distractors(r, h, 15) + [3 * a + 2 * g, a + g],
                f'A-T arasında 2, G-C arasında 3 bağ: 2·{a} + 3·{g} = {h}.')


def kodon(r):
    aa = r.randint(20, 300)
    return make(r, 'Protein sentezi', f'{aa} amino asitlik bir proteinin sentezinde mRNA üzerinde (durdurma kodonu hariç) kaç kodon okunur?',
                aa, [aa * 3, aa + 1, aa * 2, aa - 1, aa * 3 + 3],
                'Her amino asidi bir kodon (üç nükleotit) belirler.')


def gamet_kromozom(r):
    org, n2 = r.choice(list(ORGANISMS.items()))
    return make(r, 'Hücre bölünmeleri', f'{org} türünün vücut hücrelerinde 2n = {n2} kromozom bulunur. Bu türün üreme hücrelerinde (gamet) kaç kromozom bulunur?',
                n2 // 2, [n2, n2 * 2, n2 // 2 + 1, n2 // 4 if n2 % 4 == 0 else n2 + 2, n2 - 2],
                f'Mayoz sonucu kromozom sayısı yarıya iner: n = {n2 // 2}.')


def mitoz(r):
    org, n2 = r.choice(list(ORGANISMS.items()))
    k = r.randint(1, 4)
    cells = 2 ** k
    return make(r, 'Hücre bölünmeleri', f'2n = {n2} kromozomlu bir {org.lower()} hücresi art arda {k} mitoz bölünme geçiriyor. Oluşan hücrelerin her birinde kaç kromozom bulunur?',
                n2, [n2 // 2, n2 * 2, n2 * cells, cells, n2 + k],
                'Mitozda kromozom sayısı korunur.')


def hucre_sayisi(r):
    k = r.randint(1, 6)
    return make(r, 'Hücre bölünmeleri', f'Bir hücre art arda {k} kez mitoz bölünme geçirirse sonunda kaç hücre oluşur?',
                2 ** k, [2 * k, 2 ** (k + 1), 2 ** k - 1, k, 4 ** k if k > 1 else 3],
                f'Her bölünmede hücre sayısı ikiye katlanır: 2^{k} = {2 ** k}.')


def _gametes(genotype):
    genes = [genotype[i:i + 2] for i in range(0, len(genotype), 2)]
    return [''.join(c) for c in itertools.product(*genes)]


def _offspring(p1, p2):
    out = []
    for g1 in _gametes(p1):
        for g2 in _gametes(p2):
            out.append(''.join(''.join(sorted(a + b, key=lambda x: (x.lower(), x.islower()))) for a, b in zip(g1, g2)))
    return out


def _gen(r, n):
    letters = 'AB'[:n]
    return ''.join(r.choice([l + l, l + l.lower(), l.lower() + l.lower()]) for l in letters)


def caprazlama_genotip(r):
    n = r.choice([1, 2, 2])
    p1, p2 = _gen(r, n), _gen(r, n)
    kids = _offspring(p1, p2)
    target = r.choice(kids)
    p = Fraction(kids.count(target), len(kids))
    wrong = {fmt_frac(Fraction(x, len(kids))) for x in range(1, len(kids) + 1)} - {fmt_frac(p)}
    return make(r, 'Kalıtım', f'{p1} × {p2} çaprazlamasında {target} genotipli bireylerin oluşma olasılığı kaçtır?',
                fmt_frac(p), sorted(wrong, key=lambda s: Fraction(s)),
                f'Gametler eşleştirilir; {len(kids)} olasılığın {kids.count(target)} tanesi {target}: {fmt_frac(p)}.')


def caprazlama_fenotip(r):
    n = r.choice([1, 2])
    p1, p2 = _gen(r, n), _gen(r, n)
    kids = _offspring(p1, p2)
    letters = 'AB'[:n]
    want = [r.choice([True, False]) for _ in letters]
    def ok(k):
        return all((k[2 * i].isupper()) == w for i, w in enumerate(want))
    c = sum(1 for k in kids if ok(k))
    p = Fraction(c, len(kids))
    desc = ' ve '.join(f'{l} {"baskın" if w else "çekinik"}' for l, w in zip(letters, want))
    wrong = {fmt_frac(Fraction(x, 16 if n == 2 else 4)) for x in range(0, 17 if n == 2 else 5)} - {fmt_frac(p)}
    return make(r, 'Kalıtım', f'{p1} × {p2} çaprazlamasında {desc} fenotipli bireylerin oluşma olasılığı kaçtır? (Genler bağımsız, tam baskınlık var)',
                fmt_frac(p), sorted(wrong, key=lambda s: Fraction(s)),
                f'Bağımsız genlerin olasılıkları çarpılır: {fmt_frac(p)}.')


def kan_grubu(r):
    types = {'AA': 'A', 'AO': 'A', 'BB': 'B', 'BO': 'B', 'AB': 'AB', 'OO': '0'}
    p1, p2 = r.choice(list(types)), r.choice(list(types))
    kids = [''.join(sorted(a + b, key='ABO'.index)) for a in p1 for b in p2]
    target = r.choice(['A', 'B', 'AB', '0'])
    c = sum(1 for k in kids if types[k] == target)
    p = Fraction(c, 4)
    show = {'AA': 'IᴬIᴬ', 'AO': 'Iᴬi', 'BB': 'IᴮIᴮ', 'BO': 'Iᴮi', 'AB': 'IᴬIᴮ', 'OO': 'ii'}
    return make(r, 'Kalıtım', f'{show[p1]} genotipli anne ile {show[p2]} genotipli babanın çocuğunun {target} kan grubundan olma olasılığı kaçtır?',
                fmt_frac(p), [x for x in ['0', '1/4', '1/2', '3/4', '1'] if x != fmt_frac(p)],
                f'Olası çocuk genotipleri: {", ".join(show[k] for k in kids)}; {c}/4 = {fmt_frac(p)}.')


def renk_korlugu(r):
    mother = r.choice(['XX', 'XXᵃ', 'XᵃXᵃ'])
    father = r.choice(['XY', 'XᵃY'])
    m_g = ['X', 'Xᵃ'] if mother == 'XXᵃ' else ([mother[:1]] * 2 if mother == 'XX' else ['Xᵃ', 'Xᵃ'])
    f_g = ['Xᵃ' if 'ᵃ' in father else 'X', 'Y']
    kids = [(a, b) for a in m_g for b in f_g]
    sons = [k for k in kids if k[1] == 'Y']
    target = r.choice(['erkek', 'kız'])
    if target == 'erkek':
        c = sum(1 for a, _ in sons if a == 'Xᵃ')
        p = Fraction(c, len(sons))
        q = 'doğacak bir erkek çocuğun renk körü olma'
    else:
        daughters = [k for k in kids if k[1] != 'Y']
        c = sum(1 for a, b in daughters if a == 'Xᵃ' and b == 'Xᵃ')
        p = Fraction(c, len(daughters))
        q = 'doğacak bir kız çocuğun renk körü olma'
    return make(r, 'Kalıtım', f'{mother} genotipli anne ile {father} genotipli babadan {q} olasılığı kaçtır? (Xᵃ: renk körlüğü geni)',
                fmt_frac(p), [x for x in ['0', '1/4', '1/2', '3/4', '1'] if x != fmt_frac(p)],
                'Renk körlüğü X\'e bağlı çekinik kalıtılır; erkekler X\'i anneden alır.')


FACTS = [
    ('Hücrede enerji (ATP) üretiminin büyük kısmının gerçekleştiği organel hangisidir?', 'Mitokondri', 'Hücre'),
    ('Bitki hücrelerinde fotosentezin gerçekleştiği organel hangisidir?', 'Kloroplast', 'Hücre'),
    ('Hücrede protein sentezinin yapıldığı organel hangisidir?', 'Ribozom', 'Hücre'),
    ('Hücre içi sindirimi sağlayan, sindirim enzimleri içeren organel hangisidir?', 'Lizozom', 'Hücre'),
    ('Salgı maddelerinin paketlenip hücre dışına gönderilmesini sağlayan organel hangisidir?', 'Golgi cisimciği', 'Hücre'),
    ('Hücrenin kalıtım materyalini taşıyan ve yönetim merkezi olan yapı hangisidir?', 'Çekirdek', 'Hücre'),
    ('Hayvan hücrelerinde bölünme sırasında iğ ipliklerinin oluşumunu sağlayan organel hangisidir?', 'Sentrozom', 'Hücre'),
    ('Bitki hücresini dıştan saran, selülozdan yapılmış yapı hangisidir?', 'Hücre duvarı', 'Hücre'),
    ('Madde alışverişini denetleyen, seçici geçirgen yapı hangisidir?', 'Hücre zarı', 'Hücre'),
    ('Eksikliğinde gece körlüğü görülen vitamin hangisidir?', 'A vitamini', 'Vitaminler'),
    ('Eksikliğinde raşitizm hastalığı görülen vitamin hangisidir?', 'D vitamini', 'Vitaminler'),
    ('Eksikliğinde skorbüt (diş eti kanaması) görülen vitamin hangisidir?', 'C vitamini', 'Vitaminler'),
    ('Kanın pıhtılaşmasında görev alan vitamin hangisidir?', 'K vitamini', 'Vitaminler'),
    ('Eksikliğinde beriberi hastalığı görülen vitamin hangisidir?', 'B₁ vitamini', 'Vitaminler'),
    ('Kan şekerini düşüren hormon hangisidir?', 'İnsülin', 'Hormonlar'),
    ('Kan şekerini yükselten, pankreastan salgılanan hormon hangisidir?', 'Glukagon', 'Hormonlar'),
    ('Büyüme hormonunu salgılayan bez hangisidir?', 'Hipofiz', 'Hormonlar'),
    ('Tiroksin hormonunu salgılayan bez hangisidir?', 'Tiroit bezi', 'Hormonlar'),
    ('Adrenalin hormonunu salgılayan bez hangisidir?', 'Böbrek üstü bezi', 'Hormonlar'),
    ('Kanda oksijen taşıyan protein hangisidir?', 'Hemoglobin', 'Dolaşım'),
    ('Vücudu mikroplara karşı savunan kan hücreleri hangileridir?', 'Akyuvarlar', 'Dolaşım'),
    ('Kanın pıhtılaşmasını sağlayan kan hücreleri hangileridir?', 'Kan pulcukları', 'Dolaşım'),
    ('Oksijence zengin kanı kalpten tüm vücuda taşıyan damar hangisidir?', 'Aort', 'Dolaşım'),
    ('Kalpten akciğerlere kan götüren damar hangisidir?', 'Akciğer atardamarı', 'Dolaşım'),
    ('Kimyasal sindirimin ilk başladığı organ hangisidir?', 'Ağız', 'Sindirim'),
    ('Proteinlerin kimyasal sindiriminin başladığı organ hangisidir?', 'Mide', 'Sindirim'),
    ('Besinlerin emiliminin en çok gerçekleştiği organ hangisidir?', 'İnce bağırsak', 'Sindirim'),
    ('Safra sıvısını üreten organ hangisidir?', 'Karaciğer', 'Sindirim'),
    ('Su ve minerallerin geri emiliminin büyük ölçüde gerçekleştiği organ hangisidir?', 'Kalın bağırsak', 'Sindirim'),
    ('Kanın süzülerek idrar oluşumunun gerçekleştiği organ hangisidir?', 'Böbrek', 'Boşaltım'),
    ('Böbreğin yapı ve görev birimi hangisidir?', 'Nefron', 'Boşaltım'),
    ('Akciğerlerde gaz alışverişinin gerçekleştiği yapılar hangileridir?', 'Alveoller', 'Solunum'),
    ('Sinir sisteminin yapı ve görev birimi hangisidir?', 'Nöron', 'Sinir sistemi'),
    ('Vücudun denge merkezi olan beyin bölümü hangisidir?', 'Beyincik', 'Sinir sistemi'),
    ('Solunum ve kalp atışını düzenleyen beyin bölümü hangisidir?', 'Omurilik soğanı', 'Sinir sistemi'),
    ('Canlıların sınıflandırılmasında en temel birim hangisidir?', 'Tür', 'Sınıflandırma'),
    ('Çekirdek zarı bulunmayan (prokaryot) canlıların oluşturduğu âlem hangisidir?', 'Bakteriler', 'Sınıflandırma'),
    ('Ekmek mayası hangi canlı grubuna aittir?', 'Mantarlar', 'Sınıflandırma'),
    ('Besin zincirinde inorganik maddelerden organik madde üreten canlılara ne ad verilir?', 'Üretici', 'Ekoloji'),
    ('Ölü canlıları ayrıştırarak maddeleri doğaya geri kazandıran canlılara ne ad verilir?', 'Ayrıştırıcı', 'Ekoloji'),
    ('Fotosentez sonucunda atmosfere verilen gaz hangisidir?', 'Oksijen', 'Fotosentez'),
    ('Fotosentezde kullanılan, havadan alınan gaz hangisidir?', 'Karbon dioksit', 'Fotosentez'),
    ('Bitkilerde suyun kökten yapraklara taşındığı iletim dokusu hangisidir?', 'Odun borusu', 'Bitki biyolojisi'),
    ('Bitkilerde besinlerin yapraktan diğer organlara taşındığı iletim dokusu hangisidir?', 'Soymuk borusu', 'Bitki biyolojisi'),
    ('Yaprakta gaz alışverişini sağlayan açıklıklara ne ad verilir?', 'Stoma', 'Bitki biyolojisi'),
    ('DNA\'da bulunup RNA\'da bulunmayan baz hangisidir?', 'Timin', 'Nükleik asitler'),
    ('RNA\'da bulunup DNA\'da bulunmayan baz hangisidir?', 'Urasil', 'Nükleik asitler'),
    ('DNA\'nın yapısındaki şeker hangisidir?', 'Deoksiriboz', 'Nükleik asitler'),
    ('Enzimlerin yapısı temel olarak hangi organik maddeden oluşur?', 'Protein', 'Organik bileşikler'),
    ('Bitkilerde depo polisakkariti hangisidir?', 'Nişasta', 'Organik bileşikler'),
    ('Hayvanlarda karaciğer ve kaslarda depolanan polisakkarit hangisidir?', 'Glikojen', 'Organik bileşikler'),
    ('Proteinlerin yapı birimi hangisidir?', 'Amino asit', 'Organik bileşikler'),
    ('Yağların yapı birimleri hangileridir?', 'Yağ asidi ve gliserol', 'Organik bileşikler'),
    ('Kalıtsal özelliklerin anne ve babadan yavrulara aktarılmasını inceleyen bilim dalı hangisidir?', 'Genetik', 'Kalıtım'),
    ('Kalıtımın temel kurallarını bezelyeler üzerinde çalışarak ortaya koyan bilim insanı kimdir?', 'Gregor Mendel', 'Kalıtım'),
]
ALL_ANSWERS = [f[1] for f in FACTS]


@stem_limit(1)
def bilgi(r):
    q, a, topic = r.choice(FACTS)
    same = [f[1] for f in FACTS if f[2] == topic and f[1] != a]
    other = [x for x in ALL_ANSWERS if x != a and x not in same]
    r.shuffle(same)
    r.shuffle(other)
    return make(r, topic, q, a, same + other, f'Doğru cevap: {a}.')


GENERATORS = [
    (dna_eslenik, 2), (mrna, 2), (nukleotit, 2), (hidrojen, 2), (kodon, 1), (gamet_kromozom, 1),
    (mitoz, 1), (hucre_sayisi, 1), (caprazlama_genotip, 3), (caprazlama_fenotip, 3),
    (kan_grubu, 2), (renk_korlugu, 2), (bilgi, 6),
]
