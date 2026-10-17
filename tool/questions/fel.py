"""TYT Felsefe: filozof-görüş-akım tabloları ve felsefe dalları."""
from common import make, stem_limit

T = 'TYT_FEL'

# filozof → (akım / yaklaşım, öne çıkan görüş)
PHILOSOPHERS = {
    'Thales': ('İlk Çağ doğa felsefesi', 'Evrenin ana maddesi (arkhe) sudur.'),
    'Anaksimenes': ('İlk Çağ doğa felsefesi', 'Evrenin ana maddesi (arkhe) havadır.'),
    'Herakleitos': ('İlk Çağ doğa felsefesi', 'Her şey akar, değişmeyen tek şey değişimdir.'),
    'Parmenides': ('İlk Çağ doğa felsefesi', 'Değişim bir yanılsamadır; varlık birdir ve değişmez.'),
    'Demokritos': ('Atomculuk', 'Her şey bölünemeyen küçük parçacıklardan, atomlardan oluşur.'),
    'Pythagoras': ('İlk Çağ doğa felsefesi', 'Evrenin ana ilkesi sayıdır.'),
    'Protagoras': ('Sofistler', 'İnsan her şeyin ölçüsüdür.'),
    'Sokrates': ('Ahlak felsefesi', 'Kendini bil; erdem bilgidir.'),
    'Platon': ('İdealizm', 'Gerçek bilgi idealar dünyasına aittir.'),
    'Aristoteles': ('Realizm', 'Bilgi, duyularla algılanan nesnelerden hareketle akılla elde edilir; mantığın kurucusudur.'),
    'Epikuros': ('Hazcılık (Epikürcülük)', 'Mutluluk, acıdan kaçınarak sürekli ve ölçülü hazlara ulaşmaktır.'),
    'Aristippos': ('Hedonizm', 'En yüksek iyi, anlık bedensel hazdır.'),
    'Farabi': ('İslam felsefesi', 'Erdemli toplum, bilge bir yöneticinin yönettiği toplumdur.'),
    'İbn Sina': ('İslam felsefesi', 'Varlık, zorunlu varlık ve mümkün varlık olarak ikiye ayrılır.'),
    'Gazali': ('Sezgicilik', 'Kesin bilgiye akılla değil, sezgi ve iç aydınlanmayla ulaşılır.'),
    'Descartes': ('Rasyonalizm', 'Düşünüyorum, öyleyse varım.'),
    'Spinoza': ('Rasyonalizm', 'Tanrı ve doğa tek bir tözdür.'),
    'Leibniz': ('Rasyonalizm', 'Evren, monad adı verilen bölünmez birimlerden oluşur.'),
    'John Locke': ('Empirizm', 'İnsan zihni doğuştan boş bir levhadır (tabula rasa).'),
    'Berkeley': ('Öznel idealizm', 'Var olmak algılanmaktır.'),
    'David Hume': ('Empirizm', 'Bütün bilgilerimiz izlenimlerden türer; nedensellik bir alışkanlıktır.'),
    'Francis Bacon': ('Empirizm', 'Bilgi güçtür; doğru bilgiye tümevarım yoluyla ulaşılır.'),
    'Kant': ('Kritisizm (Eleştiricilik)', 'Bilgi, akıl ile deneyimin birlikte çalışmasıyla oluşur.'),
    'Hegel': ('Diyalektik idealizm', 'Tarih, mutlak ruhun diyalektik gelişimidir.'),
    'Karl Marx': ('Diyalektik materyalizm', 'Toplumu belirleyen temel etken ekonomik ilişkilerdir.'),
    'Auguste Comte': ('Pozitivizm', 'Gerçek bilgi, gözlem ve deneye dayanan bilimsel bilgidir.'),
    'Henri Bergson': ('Sezgicilik', 'Hayatın özü olan yaşam atılımı ancak sezgiyle kavranır.'),
    'William James': ('Pragmatizm', 'Bir düşüncenin doğruluğu pratikteki yararıyla ölçülür.'),
    'John Dewey': ('Pragmatizm', 'Bilgi, sorunları çözmeye yarayan bir araçtır (araççılık).'),
    'Edmund Husserl': ('Fenomenoloji', 'Doğru bilgiye "şeylerin kendisine dönerek" özün sezgisiyle ulaşılır.'),
    'Jean-Paul Sartre': ('Varoluşçuluk', 'Varoluş özden önce gelir.'),
    'Kierkegaard': ('Varoluşçuluk', 'Birey, kendi seçimleriyle varoluşunu kurar.'),
    'Jeremy Bentham': ('Faydacılık', 'En fazla sayıda insana en fazla mutluluğu sağlayan eylem doğrudur.'),
    'John Stuart Mill': ('Faydacılık', 'Eylemin değeri, yol açtığı mutluluğa göre belirlenir.'),
    'Thomas Hobbes': ('Siyaset felsefesi', 'İnsan insanın kurdudur; güçlü bir devlet gereklidir.'),
    'Machiavelli': ('Siyaset felsefesi', 'Devletin sürekliliği için her yol meşrudur.'),
    'Jean-Jacques Rousseau': ('Toplum sözleşmesi', 'İnsan doğuştan iyidir; toplum onu bozar.'),
    'Montesquieu': ('Siyaset felsefesi', 'Yasama, yürütme ve yargı birbirinden ayrılmalıdır.'),
    'Karl Popper': ('Bilim felsefesi', 'Bilimsel bir kuram yanlışlanabilir olmalıdır.'),
    'Thomas Kuhn': ('Bilim felsefesi', 'Bilim, paradigma değişimleriyle (bilimsel devrimlerle) ilerler.'),
    'Nietzsche': ('Nihilizm eleştirisi', 'Üstün insan, kendi değerlerini yaratan insandır.'),
}

# Birbirine yakın akımlar aynı soruda çeldirici olmasın.
FAMILY = {
    'Öznel idealizm': 'idealizm', 'İdealizm': 'idealizm', 'Diyalektik idealizm': 'idealizm',
    'Hazcılık (Epikürcülük)': 'haz', 'Hedonizm': 'haz',
    'Siyaset felsefesi': 'siyaset', 'Toplum sözleşmesi': 'siyaset',
    'İlk Çağ doğa felsefesi': 'doga', 'Atomculuk': 'doga',
}


def fam(school):
    return FAMILY.get(school, school)


WORKS = {
    'Devlet': 'Platon', "Nikomakhos'a Etik": 'Aristoteles', 'Yöntem Üzerine Konuşma': 'Descartes',
    'Saf Aklın Eleştirisi': 'Kant', 'Leviathan': 'Thomas Hobbes', 'Hükümdar (Prens)': 'Machiavelli',
    'Toplum Sözleşmesi': 'Jean-Jacques Rousseau', 'Ütopya': 'Thomas More', 'Kanunların Ruhu': 'Montesquieu',
    'Kapital': 'Karl Marx', 'Bilimsel Devrimlerin Yapısı': 'Thomas Kuhn', 'Böyle Buyurdu Zerdüşt': 'Nietzsche',
    'Varlık ve Hiçlik': 'Jean-Paul Sartre', 'Novum Organum': 'Francis Bacon', 'Güneş Ülkesi': 'Campanella',
    "El-Medinetü'l-Fazıla (Erdemli Toplum)": 'Farabi', 'İnsan Anlığı Üzerine Bir Deneme': 'John Locke',
}
WORK_AUTHORS = sorted(set(WORKS.values()) | {'Sokrates', 'Hegel', 'Spinoza', 'David Hume', 'Auguste Comte'})

BRANCHES = {
    'Bilgi felsefesi (epistemoloji)': ['Doğru bilgi mümkün müdür?', 'Bilginin kaynağı nedir?',
                                        'Bilginin sınırı var mıdır?', 'Bilginin değeri nedir?',
                                        'Doğruluğun ölçütü nedir?'],
    'Varlık felsefesi (ontoloji)': ['Varlık var mıdır?', 'Varlığın özü nedir?', 'Evrenin ana maddesi nedir?',
                                     'Varlık tek midir, çok mudur?', 'Gerçekten var olan nedir?'],
    'Ahlak felsefesi (etik)': ['İyi nedir?', 'Evrensel bir ahlak yasası var mıdır?', 'Özgürlük ve sorumluluk nedir?',
                               'İnsanın ahlaki eylemlerinin amacı nedir?', 'Vicdan nedir?'],
    'Sanat felsefesi (estetik)': ['Güzel nedir?', 'Sanat eseri nedir?', 'Sanatın amacı nedir?',
                                  'Doğadaki güzellikle sanattaki güzellik aynı mıdır?', 'Yaratıcılık nedir?'],
    'Siyaset felsefesi': ['İdeal devlet nasıl olmalıdır?', 'Egemenliğin kaynağı nedir?', 'Devlet neden vardır?',
                          'Yönetimin meşruiyeti neye dayanır?', 'Bireyin devlet karşısındaki hakları nelerdir?'],
    'Bilim felsefesi': ['Bilimsel yöntem nedir?', 'Bilimsel bilginin değeri nedir?', 'Bilim nasıl ilerler?',
                        'Bilimsel kuramlar nasıl sınanır?', 'Bilimin sınırları var mıdır?'],
    'Din felsefesi': ['Tanrı\'nın varlığı kanıtlanabilir mi?', 'Ruh ölümsüz müdür?', 'Kötülük problemi nedir?',
                      'Vahiy ile akıl arasındaki ilişki nedir?', 'Dinî deneyim nedir?'],
}

CONCEPTS = [
    ('Bilgi edinmede aklı temel alan görüş hangisidir?', 'Rasyonalizm'),
    ('Bilginin kaynağının deney ve gözlem olduğunu savunan görüş hangisidir?', 'Empirizm'),
    ('Kesin bilginin mümkün olmadığını, her şeyden şüphe edilmesi gerektiğini savunan görüş hangisidir?', 'Septisizm (Şüphecilik)'),
    ('Bilginin kaynağı olarak sezgiyi öne çıkaran görüş hangisidir?', 'Sezgicilik'),
    ('Bir düşüncenin doğruluğunu pratik yararıyla ölçen görüş hangisidir?', 'Pragmatizm'),
    ('Yalnızca olguları ve bilimsel bilgiyi geçerli sayan görüş hangisidir?', 'Pozitivizm'),
    ('Varlığın temelinin madde olduğunu savunan görüş hangisidir?', 'Materyalizm'),
    ('Varlığın temelinin düşünce ya da idea olduğunu savunan görüş hangisidir?', 'İdealizm'),
    ('Varlığın hem maddeden hem ruhtan oluştuğunu savunan görüş hangisidir?', 'Düalizm'),
    ('Ahlaki eylemin amacının haz olduğunu savunan görüş hangisidir?', 'Hedonizm'),
    ('Ahlaki eylemin amacının fayda olduğunu savunan görüş hangisidir?', 'Faydacılık'),
    ('İnsanın önce var olup sonra kendi özünü yarattığını savunan akım hangisidir?', 'Varoluşçuluk'),
]
CONCEPT_ANSWERS = [c[1] for c in CONCEPTS] + ['Nihilizm', 'Determinizm', 'Kritisizm']


@stem_limit(1)
def gorus_kim(r):
    p = r.choice(list(PHILOSOPHERS))
    view = PHILOSOPHERS[p][1]
    others = [x for x in PHILOSOPHERS if x != p and PHILOSOPHERS[x][1] != view]
    r.shuffle(others)
    return make(r, 'Filozoflar', f'"{view}" görüşü aşağıdaki filozoflardan hangisine aittir?', p, others,
                f'Görüşün sahibi: {p} ({PHILOSOPHERS[p][0]}).')


@stem_limit(1)
def akim(r):
    p = r.choice(list(PHILOSOPHERS))
    school = PHILOSOPHERS[p][0]
    others = sorted({s for s, _ in PHILOSOPHERS.values() if fam(s) != fam(school)})
    r.shuffle(others)
    return make(r, 'Akımlar', f'{p} hangi felsefi akım ya da yaklaşımla özdeşleşmiştir?', school, others,
                f'{p}: {school}.')


@stem_limit(1)
def dal(r):
    b = r.choice(list(BRANCHES))
    q = r.choice(BRANCHES[b])
    return make(r, 'Felsefe dalları', f'"{q}" sorusu hangi felsefe dalının temel sorularındandır?', b,
                [x for x in BRANCHES if x != b], f'Bu soru {b} kapsamındadır.')


@stem_limit(20)
def dal_disinda(r):
    b = r.choice(list(BRANCHES))
    inside = r.sample(BRANCHES[b], 4)
    other_b = r.choice([x for x in BRANCHES if x != b])
    out = r.choice(BRANCHES[other_b])
    return make(r, 'Felsefe dalları', f'Aşağıdaki sorulardan hangisi {b} alanının sorularından biri değildir?', out, inside,
                f'"{out}" sorusu {other_b} alanına aittir.')


@stem_limit(1)
def kavram(r):
    q, a = r.choice(CONCEPTS)
    others = [x for x in CONCEPT_ANSWERS if x != a]
    r.shuffle(others)
    return make(r, 'Kavramlar', q, a, others, f'Doğru cevap: {a}.')


@stem_limit(1)
def eser_kim(r):
    w = r.choice(list(WORKS))
    a = WORKS[w]
    others = [x for x in WORK_AUTHORS if x != a]
    r.shuffle(others)
    return make(r, 'Eserler', f'"{w}" adlı eser hangi düşünüre aittir?', a, others, f'{w}: {a}.')


@stem_limit(1)
def kimin_eseri(r):
    w = r.choice(list(WORKS))
    a = WORKS[w]
    others = [x for x in WORKS if x != w]
    r.shuffle(others)
    return make(r, 'Eserler', f'Aşağıdaki eserlerden hangisi {a} tarafından yazılmıştır?', w, others, f'{w}: {a}.')


@stem_limit(25)
def doga_filozofu_degil(r):
    inside = r.sample([p for p, (s, _) in PHILOSOPHERS.items() if fam(s) == 'doga'], 4)
    out = r.choice([p for p, (s, _) in PHILOSOPHERS.items() if fam(s) != 'doga'])
    return make(r, 'Akımlar', 'Aşağıdakilerden hangisi İlk Çağ doğa filozoflarından biri değildir?', out, inside,
                f'{out}, {PHILOSOPHERS[out][0]} ile anılır.')


GENERATORS = [(gorus_kim, 4), (akim, 3), (dal, 3), (dal_disinda, 2), (kavram, 1), (eser_kim, 1),
              (kimin_eseri, 1), (doga_filozofu_degil, 1)]
