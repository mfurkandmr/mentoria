"""AYT Felsefe Grubu (felsefe, psikoloji, sosyoloji, mantık): mantıkta
doğruluk değerleri hesaplanır; diğerleri kavram ve kişi tablolarından."""
from common import define_gens, make, relation_gens, stem_limit

T = 'AYT_FELG'

VARS = ['p', 'q', 'r']


OPS = {'∧': lambda x, y: x and y, '∨': lambda x, y: x or y, '→': lambda x, y: (not x) or y, '↔': lambda x, y: x == y}


def rand_formula(r, depth=0):
    """(metin, değerlendirici) çifti; alt önermeler parantezli."""
    if depth >= 2 or (depth > 0 and r.random() < 0.4):
        v = r.choice(VARS)
        if r.random() < 0.3:
            return v + "'", lambda vals, v=v: not vals[v]
        return v, lambda vals, v=v: vals[v]
    op = r.choice(list(OPS))
    a, fa = rand_formula(r, depth + 1)
    b, fb = rand_formula(r, depth + 1)
    if a is None or b is None or a == b:
        return None, None
    text = f'({a} {op} {b})' if depth else f'{a} {op} {b}'
    return text, lambda vals, fa=fa, fb=fb, op=op: OPS[op](fa(vals), fb(vals))


def evaluate(fn, vals):
    return fn(vals)


@stem_limit(12)
def dogruluk(r):
    vals = {v: r.random() < 0.5 for v in VARS}
    want = r.random() < 0.5  # True: tek yanlışı bul / False: tek doğruyu bul
    pool_t, pool_f = [], []
    for _ in range(80):
        f, fn = rand_formula(r)
        if not f:
            continue
        (pool_t if evaluate(fn, vals) else pool_f).append(f)
    pool_t, pool_f = list(dict.fromkeys(pool_t)), list(dict.fromkeys(pool_f))
    odd, many = (pool_f, pool_t) if want else (pool_t, pool_f)
    if not odd or len(many) < 4:
        return None
    ans = r.choice(odd)
    shown = ', '.join(f'{v} ≡ {1 if vals[v] else 0}' for v in VARS)
    word = 'yanlıştır (0)' if want else 'doğrudur (1)'
    return make(r, 'Mantık', f'{shown} olduğuna göre aşağıdaki önermelerden hangisi {word}?', ans, r.sample(many, 4),
                f'{ans} önermesinin değeri {0 if want else 1}; diğerlerinin {1 if want else 0}. (\' olumsuzu, ∧ ve, ∨ veya, → ise, ↔ ancak ve ancak)')


LOGIC = {
    'Önerme': 'Doğru ya da yanlış olduğu söylenebilen, hüküm bildiren cümle',
    'Tümdengelim': 'Genelden özele doğru giden, öncüller doğruysa sonucu zorunlu olarak doğru olan akıl yürütme',
    'Tümevarım': 'Tek tek olgulardan genel bir sonuca ulaşan akıl yürütme',
    'Analoji': 'İki şey arasındaki benzerlikten yola çıkarak birinden ötekine sonuç çıkaran akıl yürütme',
    'Kıyas': 'İki öncülden zorunlu bir sonuç çıkaran tümdengelimsel akıl yürütme',
    'Tanım': 'Bir kavramın içlemini (özelliklerini) açıkça belirten ifade',
    'Totoloji': 'Bileşenlerin her doğruluk değeri için doğru olan bileşik önerme',
    'Çelişik önerme': 'Bileşenlerin her doğruluk değeri için yanlış olan bileşik önerme',
    'İçlem': 'Bir kavramın kapsadığı ortak özellikler',
    'Kaplam': 'Bir kavramın kapsadığı varlıkların tümü',
}
PSY_SCHOOLS = [
    ('Wilhelm Wundt', 'Yapısalcılık'), ('Edward Titchener', 'Yapısalcılık'), ('William James', 'İşlevselcilik'), ('John Dewey', 'İşlevselcilik'),
    ('John B. Watson', 'Davranışçılık'), ('B. F. Skinner', 'Davranışçılık'), ('Ivan Pavlov', 'Davranışçılık'),
    ('Max Wertheimer', 'Gestalt'), ('Wolfgang Köhler', 'Gestalt'), ('Kurt Koffka', 'Gestalt'),
    ('Sigmund Freud', 'Psikanaliz'), ('Abraham Maslow', 'Hümanist yaklaşım'), ('Carl Rogers', 'Hümanist yaklaşım'),
    ('Jean Piaget', 'Bilişsel yaklaşım'), ('Ulric Neisser', 'Bilişsel yaklaşım'),
]
DEFENSE = {
    'Yansıtma': 'Kişinin kabul edemediği duygu ve düşüncelerini başkalarına yüklemesi',
    'Mantığa bürüme': 'Başarısızlığa ya da davranışa gerçek dışı, mantıklı görünen gerekçeler bulma',
    'Bastırma': 'Rahatsız edici anı ve dürtüleri bilinçdışına itme',
    'Yüceltme': 'Kabul görmeyen dürtüleri toplumca değerli etkinliklere yönlendirme',
    'Yer değiştirme': 'Bir kişiye ya da nesneye duyulan öfkeyi daha zararsız bir hedefe yöneltme',
    'Karşıt tepki geliştirme': 'Hissedilen duygunun tam tersi gibi davranma',
    'Gerileme': 'Stres karşısında daha önceki gelişim dönemlerine özgü davranışlara dönme',
    'İnkâr': 'Acı veren bir gerçeği yok sayma',
    'Özdeşleşme': 'Beğenilen bir kişinin özelliklerini benimseyip onun gibi davranma',
    'Hayal kurma': 'Gerçekleşmeyen istekleri hayal dünyasında doyurma',
}
PSY_TERMS = {
    'Klasik koşullanma': 'Nötr bir uyarıcının doğal uyarıcıyla eşleştirilerek aynı tepkiyi doğurması',
    'Edimsel koşullanma': 'Davranışın sonucunda gelen pekiştirme ya da cezaya göre öğrenilmesi',
    'Pekiştireç': 'Bir davranışın tekrarlanma olasılığını artıran uyarıcı',
    'Algıda seçicilik': 'Çevredeki uyarıcılar arasından ilgi ve ihtiyaca göre bazılarını algılama',
    'Kısa süreli bellek': 'Bilgiyi sınırlı kapasiteyle kısa süre tutan bellek',
    'Motivasyon (güdülenme)': 'Davranışı başlatan, yönlendiren ve sürdüren iç güç',
    'Kişilik': 'Bireyi diğerlerinden ayıran, tutarlı düşünce, duygu ve davranış örüntüsü',
    'Zekâ': 'Öğrenme, problem çözme ve yeni durumlara uyum sağlama yeteneği',
}
PIAGET = [('Duyusal-motor dönem', 0, 2), ('İşlem öncesi dönem', 2, 7), ('Somut işlemler dönemi', 7, 11), ('Soyut işlemler dönemi', 11, 16)]


@stem_limit(1)
def piaget(r):
    name, lo, hi = r.choice(PIAGET)
    age = r.randint(lo, hi - 1) if hi - lo > 1 else lo
    if name.startswith('Duyusal') and age == 0:
        age = 1
    ays = f'{age} yaşındaki' if age else '1 yaşındaki'
    return make(r, 'Psikoloji', f'Piaget\'ye göre {ays} tipik bir çocuk hangi bilişsel gelişim dönemindedir?', name,
                [p[0] for p in PIAGET if p[0] != name] + ['Kimlik kazanma dönemi'],
                f'Dönemler: duyusal-motor (0-2), işlem öncesi (2-7), somut işlemler (7-11), soyut işlemler (11+).')


SOCIOLOGISTS = [
    ('"Sosyoloji" terimini ilk kullanan ve pozitivizmin kurucusu', 'Auguste Comte'),
    ('Mekanik ve organik dayanışma kavramlarını ortaya koyan', 'Emile Durkheim'),
    ('Anlayıcı (yorumlayıcı) sosyolojinin öncüsü', 'Max Weber'),
    ('Toplumsal değişmeyi sınıf çatışması ve ekonomik yapıyla açıklayan', 'Karl Marx'),
    ('Mukaddime adlı eserinde umran (toplum) bilimini ortaya koyan', 'İbn Haldun'),
    ('Türkiye\'de sosyolojinin kurumsallaşmasına öncülük eden, "hars ve medeniyet" ayrımını yapan', 'Ziya Gökalp'),
    ('Teşebbüs-i şahsi ve adem-i merkeziyet görüşlerini savunan', 'Prens Sabahattin'),
    ('Toplumları askerî ve endüstriyel toplum olarak sınıflandıran, sosyal Darvinizmin öncüsü', 'Herbert Spencer'),
]
SOC_TERMS = {
    'Statü': 'Bireyin toplumda bulunduğu konum',
    'Rol': 'Bir statüye bağlı olarak bireyden beklenen davranışlar',
    'Norm': 'Toplumda nasıl davranılması gerektiğini belirleyen kurallar',
    'Değer': 'Toplumun büyük çoğunluğunca doğru ve iyi kabul edilen ortak düşünce ve inançlar',
    'Dikey hareketlilik': 'Bireyin toplumsal tabakalar arasında yukarı ya da aşağı doğru yer değiştirmesi',
    'Yatay hareketlilik': 'Bireyin statüsü değişmeden benzer konumlar arasında yer değiştirmesi',
    'Sosyalleşme': 'Bireyin içinde yaşadığı toplumun kültürünü öğrenerek toplumun bir üyesi olması',
    'Kültürleşme': 'Farklı kültürlerin karşılaşarak birbirinden öğe alması',
    'Asimilasyon': 'Bir kültürün başka bir kültür içinde eriyip kendi özelliklerini kaybetmesi',
    'Toplumsal kurum': 'Toplumun temel ihtiyaçlarını karşılayan, kalıcı ve düzenli kurallar bütünü',
    'Toplumsal tabakalaşma': 'Toplumdaki bireylerin gelir, eğitim, meslek gibi ölçütlere göre katmanlara ayrılması',
}
PHILOSOPHERS = [
    ('René Descartes', 'Rasyonalizm'), ('Spinoza', 'Rasyonalizm'), ('Leibniz', 'Rasyonalizm'), ('Farabi', 'Rasyonalizm'),
    ('John Locke', 'Empirizm'), ('David Hume', 'Empirizm'), ('George Berkeley', 'Empirizm'), ('Francis Bacon', 'Empirizm'),
    ('Immanuel Kant', 'Kritisizm'), ('Henri Bergson', 'Entüisyonizm (sezgicilik)'), ('Gazali', 'Entüisyonizm (sezgicilik)'),
    ('Edmund Husserl', 'Fenomenoloji'), ('Jean-Paul Sartre', 'Varoluşçuluk'), ('Søren Kierkegaard', 'Varoluşçuluk'), ('Martin Heidegger', 'Varoluşçuluk'),
    ('Auguste Comte', 'Pozitivizm'), ('Jeremy Bentham', 'Faydacılık'), ('John Stuart Mill', 'Faydacılık'), ('Epikür', 'Hazcılık (hedonizm)'),
    ('Aristippos', 'Hazcılık (hedonizm)'), ('William James', 'Pragmatizm'), ('John Dewey', 'Pragmatizm'), ('Pyrrhon', 'Septisizm (şüphecilik)'),
]
BRANCHES = {
    'Epistemoloji (bilgi felsefesi)': 'Bilginin kaynağını, imkânını ve sınırlarını sorgulayan felsefe dalı',
    'Ontoloji (varlık felsefesi)': 'Varlığın ne olduğunu ve var olanın temel niteliklerini sorgulayan felsefe dalı',
    'Ahlak felsefesi (etik)': 'İyi, kötü, erdem ve ödev kavramlarını sorgulayan felsefe dalı',
    'Estetik (sanat felsefesi)': 'Güzelliği ve sanat eserinin değerini sorgulayan felsefe dalı',
    'Siyaset felsefesi': 'Devletin kaynağını, ideal düzeni ve iktidarın meşruluğunu sorgulayan felsefe dalı',
    'Bilim felsefesi': 'Bilimsel bilginin yöntemini, değerini ve sınırlarını sorgulayan felsefe dalı',
    'Din felsefesi': 'Tanrı\'nın varlığı ve din ile akıl ilişkisini sorgulayan felsefe dalı',
}


GENERATORS = [(dogruluk, 5), (piaget, 1)] \
    + define_gens('Mantık', LOGIC, fwd='Mantıkta "{k}" kavramı aşağıdakilerden hangisidir?', back='"{v}" mantıkta hangi kavramdır?') \
    + relation_gens('Psikoloji', PSY_SCHOOLS, fwd='{item} hangi psikoloji ekolüyle ilişkilendirilir?',
                    has='Aşağıdakilerden hangisi {group} ekolünün temsilcisidir?', weights=(2, 1, 0), has_limit=3) \
    + define_gens('Psikoloji', DEFENSE, fwd='"{k}" savunma mekanizması aşağıdakilerden hangisidir?',
                  back='"{v}" hangi savunma mekanizmasıdır?', weights=(2, 2)) \
    + define_gens('Psikoloji', PSY_TERMS, fwd='Psikolojide "{k}" kavramı aşağıdakilerden hangisidir?', back='"{v}" hangi kavramdır?') \
    + relation_gens('Sosyoloji', SOCIOLOGISTS, fwd='{item} düşünür kimdir?', weights=(2, 0, 0)) \
    + define_gens('Sosyoloji', SOC_TERMS, fwd='Sosyolojide "{k}" kavramı aşağıdakilerden hangisidir?', back='"{v}" hangi kavramdır?', weights=(2, 2)) \
    + relation_gens('Felsefe', PHILOSOPHERS, fwd='{item} hangi felsefi akımla ilişkilendirilir?',
                    has='Aşağıdaki düşünürlerden hangisi {group} akımıyla ilişkilendirilir?',
                    has_not='Aşağıdaki düşünürlerden hangisi {group} akımıyla ilişkilendirilmez?', weights=(3, 2, 2), has_limit=3, has_not_limit=8) \
    + define_gens('Felsefe', BRANCHES, fwd='{k} için aşağıdakilerden hangisi doğrudur?', back='"{v}" hangisidir?')
