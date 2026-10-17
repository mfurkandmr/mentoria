/// Eğitim bölümünün bilgi kartları: her ders için formüller ve kısa bilgiler.
/// İçerik bu depoda özgün olarak yazılmıştır (telifsiz). Kart metinleri ders
/// içeriği olduğu için Türkçedir (tr() ile çevrilmez; konu adları gibi).
library;

class LearnCard {
  const LearnCard(this.title, this.body, {this.formula});

  final String title;
  final String body;

  /// Varsa kartın ortasında büyük gösterilen formül.
  final String? formula;
}

const learnCards = <String, List<LearnCard>>{
  'TYT_MAT': [
    LearnCard(
      'Üslü sayılar',
      'Tabanlar aynıysa çarpmada üsler toplanır, bölmede çıkarılır. Sıfırdan farklı her sayının sıfırıncı kuvveti 1\'dir.',
      formula: 'aᵐ · aⁿ = aᵐ⁺ⁿ   ·   aᵐ / aⁿ = aᵐ⁻ⁿ',
    ),
    LearnCard(
      'Köklü sayılar',
      'Kök içindeki tam kare çarpan dışarı çıkarılır. Toplama yalnızca kök içleri aynıysa yapılır.',
      formula: '√(a² · b) = a√b',
    ),
    LearnCard(
      'EBOB - EKOK',
      'İki sayının çarpımı, EBOB ile EKOK\'unun çarpımına eşittir. "Aynı anda yeniden" sorularında EKOK, "en büyük parça" sorularında EBOB aranır.',
      formula: 'a · b = EBOB · EKOK',
    ),
    LearnCard(
      'Bölünebilme',
      '2: son basamak çift · 3: rakamlar toplamı 3\'ün katı · 4: son iki basamak 4\'ün katı · 5: son basamak 0 ya da 5 · 9: rakamlar toplamı 9\'un katı · 10: son basamak 0.',
    ),
    LearnCard(
      'Pozitif bölen sayısı',
      'Sayıyı asal çarpanlarına ayır; her üssün bir fazlasını çarp.',
      formula: 'n = pᵃ · qᵇ  →  (a+1)(b+1)',
    ),
    LearnCard(
      'Oran - orantı',
      'x/y = a/b ise x = ak, y = bk yazılır; verilen toplam ya da farkla k bulunur.',
      formula: 'x : y = a : b  →  x = ak, y = bk',
    ),
    LearnCard(
      'Yüzde, kâr, indirim',
      'Kâr ve zarar maliyet üzerinden, indirim etiket fiyatı üzerinden hesaplanır.',
      formula: 'Satış = Maliyet · (100 + kâr%) / 100',
    ),
    LearnCard(
      'İşçi problemleri',
      'Bir işi a günde bitiren kişi bir günde işin 1/a\'sını yapar; birlikte çalışanların hızları toplanır.',
      formula: '1/a + 1/b = 1/t',
    ),
    LearnCard(
      'Hız problemleri',
      'Zıt yönde karşılaşmada hızlar toplanır, aynı yönde yetişmede hızlar çıkarılır.',
      formula: 'Yol = Hız · Zaman',
    ),
    LearnCard(
      'Permütasyon ve kombinasyon',
      'Sıranın önemli olduğu dizilişlerde permütasyon, yalnızca seçimin önemli olduğu durumlarda kombinasyon kullanılır.',
      formula: 'P(n, r) = n! / (n−r)!   ·   C(n, r) = n! / (r!(n−r)!)',
    ),
    LearnCard(
      'Olasılık',
      'İstenen durum sayısı tüm durum sayısına bölünür. Olasılık 0 ile 1 arasındadır.',
      formula: 'P(A) = s(A) / s(E)',
    ),
    LearnCard(
      'Kümeler',
      'Birleşimdeki eleman sayısı bulunurken kesişim bir kez çıkarılır.',
      formula: 's(A ∪ B) = s(A) + s(B) − s(A ∩ B)',
    ),
    LearnCard(
      'Üçgenler',
      'İç açılar toplamı 180°. Dik üçgende hipotenüsün karesi dik kenarların kareleri toplamıdır. Sık çıkan üçlüler: 3-4-5, 5-12-13, 8-15-17.',
      formula: 'a² + b² = c²',
    ),
    LearnCard(
      'Çokgenler',
      'n kenarlı dışbükey çokgende iç açılar toplamı (n − 2) · 180°, dış açılar toplamı her zaman 360°\'dir.',
      formula: '(n − 2) · 180°',
    ),
    LearnCard(
      'Daire',
      'π çoğu soruda 3 alınır.',
      formula: 'Alan = πr²   ·   Çevre = 2πr',
    ),
  ],
  'TYT_TUR': [
    LearnCard(
      'Hece',
      'Türkçede her hecede yalnızca bir ünlü bulunur; sözcükteki ünlü sayısı hece sayısını verir.',
    ),
    LearnCard(
      'Büyük ünlü uyumu',
      'Türkçe kökenli sözcüklerde ilk hecede kalın ünlü (a, ı, o, u) varsa sonrakiler de kalın, ince ünlü (e, i, ö, ü) varsa sonrakiler de ince olur. "kardeş, elma, anne" uymayan istisnalardır.',
    ),
    LearnCard(
      'Küçük ünlü uyumu',
      'Düz ünlüden (a, e, ı, i) sonra düz ünlü; yuvarlak ünlüden (o, ö, u, ü) sonra düz-geniş (a, e) ya da dar-yuvarlak (u, ü) ünlü gelir.',
    ),
    LearnCard(
      'Ünsüz benzeşmesi',
      'Sert ünsüzlerle (f, s, t, k, ç, ş, h, p — "fıstıkçı şahap") biten sözcüklere c, d, g ile başlayan ek gelirse bu ünsüzler sertleşir: kitap-ta, sokak-ta, ağaç-çı.',
    ),
    LearnCard(
      'Ünsüz yumuşaması',
      'p, ç, t, k ile biten sözcüklere ünlüyle başlayan ek gelince p→b, ç→c, t→d, k→ğ olur: kitap→kitabı, ağaç→ağacı. Tek heceli sözcüklerin çoğunda görülmez: top→topu, saç→saçı.',
    ),
    LearnCard(
      'Ünlü düşmesi',
      'İkinci hecesinde dar ünlü bulunan bazı sözcüklere ünlüyle başlayan ek gelince bu ünlü düşer: ağız→ağzı, burun→burnu, oğul→oğlu.',
    ),
    LearnCard(
      'Ünsüz türemesi',
      'Arapça kökenli bazı tek heceli sözcüklerde ek alınca ünsüz ikizleşir: hak→hakkı, his→hissi, ret→reddi.',
    ),
    LearnCard(
      'Eş ve zıt anlam',
      'Yazılışı farklı, anlamı aynı sözcükler eş anlamlıdır (cevap - yanıt). Anlamca karşıt olanlar zıt anlamlıdır (uzun - kısa).',
    ),
    LearnCard(
      'Birleşik sözcük',
      'İki ya da daha fazla sözcüğün birleşerek yeni bir anlam kazanmasıyla oluşur: hanımeli, ayakkabı, buzdolabı.',
    ),
    LearnCard(
      'Sözlük sırası',
      'Türk alfabesi 29 harftir: a b c ç d e f g ğ h ı i j k l m n o ö p r s ş t u ü v y z. Sözlükte ilk harf aynıysa ikinci harfe bakılır.',
    ),
    LearnCard(
      'Paragrafta ana düşünce',
      'Yazarın okura vermek istediği temel mesajdır; genellikle giriş ya da sonuç cümlesinde yer alır ve paragrafın tamamını kapsar.',
    ),
    LearnCard(
      '"de/da" bağlacı',
      'Bağlaç olan "de/da" her zaman ayrı yazılır ve sert ünsüzle başlamaz: "Ben de geldim." Bulunma eki olan -de/-da ise bitişik yazılır: "Evde."',
    ),
  ],
  'TYT_FIZ': [
    LearnCard(
      'Hız ve ivme',
      'Hız birim zamanda alınan yol, ivme birim zamandaki hız değişimidir.',
      formula: 'v = x / t   ·   a = Δv / t',
    ),
    LearnCard(
      'km/h → m/s',
      'km/h cinsinden hızı m/s\'ye çevirmek için 3,6\'ya böl; tersi için 3,6 ile çarp.',
      formula: '72 km/h = 20 m/s',
    ),
    LearnCard(
      'Newton\'un 2. yasası',
      'Net kuvvet, kütle ile ivmenin çarpımına eşittir. Ağırlık bir kuvvettir (g = 10 m/s²).',
      formula: 'F = m · a   ·   G = m · g',
    ),
    LearnCard(
      'İş ve güç',
      'Kuvvet doğrultusunda yer değiştirme varsa iş yapılır. Güç birim zamanda yapılan iştir.',
      formula: 'W = F · x   ·   P = W / t',
    ),
    LearnCard(
      'Enerji',
      'Hareketli cisimde kinetik, yükseltideki cisimde potansiyel enerji vardır; sürtünmesiz ortamda toplam enerji korunur.',
      formula: 'Ek = ½mv²   ·   Ep = mgh',
    ),
    LearnCard(
      'Katı basıncı',
      'Aynı kuvvet daha küçük yüzeye uygulanırsa basınç artar.',
      formula: 'P = F / A',
    ),
    LearnCard(
      'Sıvı basıncı',
      'Derinlik ve sıvının yoğunluğu arttıkça basınç artar; kabın şekline bağlı değildir.',
      formula: 'P = h · d · g',
    ),
    LearnCard(
      'Özkütle',
      'Maddenin ayırt edici özelliğidir; sıcaklık ve basınçla değişebilir.',
      formula: 'd = m / V',
    ),
    LearnCard(
      'Kaldırma kuvveti',
      'Sıvıya batan cisme, yer değiştirdiği sıvının ağırlığı kadar yukarı yönlü kuvvet etki eder.',
      formula: 'Fk = Vbatan · dsıvı · g',
    ),
    LearnCard(
      'Ohm yasası',
      'Bir iletkenden geçen akım, gerilimle doğru, dirençle ters orantılıdır.',
      formula: 'V = I · R',
    ),
    LearnCard(
      'Seri ve paralel direnç',
      'Seride dirençler toplanır. İki paralel dirençte eşdeğer direnç çarpım bölü toplamdır.',
      formula: 'Rseri = R₁ + R₂   ·   Rparalel = R₁R₂ / (R₁ + R₂)',
    ),
    LearnCard(
      'Isı',
      'Bir maddenin sıcaklığını değiştirmek için gereken ısı, kütleye, öz ısıya ve sıcaklık farkına bağlıdır.',
      formula: 'Q = m · c · ΔT',
    ),
    LearnCard(
      'Dalgalar',
      'Dalganın hızı ortama bağlıdır; frekansı kaynağa bağlıdır.',
      formula: 'v = λ · f   ·   T = 1 / f',
    ),
    LearnCard(
      'Serbest düşme',
      'Sürtünmesiz ortamda bırakılan cisim düzgün hızlanır.',
      formula: 'h = ½ · g · t²',
    ),
  ],
  'TYT_KIM': [
    LearnCard(
      'Atomun yapısı',
      'Atom numarası = proton sayısı. Nötr atomda elektron sayısı proton sayısına eşittir.',
      formula: 'Kütle no = proton + nötron',
    ),
    LearnCard(
      'İyonlar',
      'Elektron veren atom pozitif (katyon), elektron alan atom negatif (anyon) yüklenir. X²⁺ iyonunun elektron sayısı Z − 2\'dir.',
    ),
    LearnCard(
      'Periyodik sistem',
      'Katman sayısı periyodu, son katmandaki elektron sayısı A grubu numarasını verir. 1A alkali metaller, 7A halojenler, 8A soy gazlardır.',
    ),
    LearnCard(
      'Elektron dizilimi (Z ≤ 20)',
      'Katmanlar sırasıyla 2, 8, 8, 2 elektron alır. Örnek: ₁₁Na → 2 ) 8 ) 1 ) · 3. periyot, 1A.',
    ),
    LearnCard(
      'Mol kavramı',
      '1 mol tanecik 6,02·10²³ tanedir (Avogadro sayısı, çoğu soruda 6·10²³).',
      formula: 'n = m / M   ·   N = n · Nₐ',
    ),
    LearnCard(
      'Gazların hacmi',
      'Normal koşullarda (0 °C, 1 atm) 1 mol ideal gaz 22,4 L hacim kaplar.',
      formula: 'V = n · 22,4 L',
    ),
    LearnCard(
      'Molarite',
      'Çözeltinin 1 litresinde çözünmüş maddenin mol sayısıdır.',
      formula: 'M = n / V',
    ),
    LearnCard(
      'Kütlece yüzde',
      'Çözünen kütlesinin çözelti (çözücü + çözünen) kütlesine oranının 100 katıdır.',
      formula: '% = m(çözünen) / m(çözelti) · 100',
    ),
    LearnCard(
      'pH',
      'pH < 7 asidik, pH = 7 nötr, pH > 7 baziktir. 25 °C\'de pH + pOH = 14.',
      formula: 'pH = −log[H⁺]',
    ),
    LearnCard(
      'Kütlenin korunumu',
      'Kimyasal tepkimede girenlerin toplam kütlesi ürünlerin toplam kütlesine eşittir (Lavoisier).',
    ),
    LearnCard(
      'İyonik bileşik formülü',
      'Katyon ve anyonun yükleri toplamı sıfır olacak şekilde yazılır: Ca²⁺ + Cl⁻ → CaCl₂, Al³⁺ + O²⁻ → Al₂O₃.',
    ),
    LearnCard(
      'Sık kullanılan mol kütleleri',
      'H: 1 · C: 12 · N: 14 · O: 16 · Na: 23 · Mg: 24 · Al: 27 · S: 32 · Cl: 35,5 · K: 39 · Ca: 40 (g/mol).',
    ),
  ],
  'TYT_BIY': [
    LearnCard(
      'DNA baz eşleşmesi',
      'DNA\'da adenin timinle (2 hidrojen bağı), guanin sitozinle (3 hidrojen bağı) eşleşir. RNA\'da timin yerine urasil bulunur.',
      formula: 'A = T   ·   G = C',
    ),
    LearnCard(
      'Hidrojen bağı sayısı',
      'Çift zincirli DNA\'daki toplam hidrojen bağı, A-T ve G-C eşleşmelerinden hesaplanır.',
      formula: 'H bağı = 2·A + 3·G',
    ),
    LearnCard(
      'Protein sentezi',
      'DNA\'daki bilgi mRNA\'ya aktarılır (transkripsiyon), ribozomda proteine çevrilir (translasyon). Her amino asidi bir kodon (3 nükleotit) belirler.',
    ),
    LearnCard(
      'Mitoz',
      'Kromozom sayısı korunur; bir hücreden iki özdeş hücre oluşur. Büyüme, onarım ve eşeysiz üremeyi sağlar.',
      formula: '2n → 2n + 2n',
    ),
    LearnCard(
      'Mayoz',
      'Kromozom sayısı yarıya iner; bir hücreden dört farklı hücre oluşur. Üreme hücrelerini (gamet) oluşturur.',
      formula: '2n → 4 · n',
    ),
    LearnCard(
      'Mendel ve tek karakter',
      'Aa × Aa çaprazlamasında genotip oranı 1 AA : 2 Aa : 1 aa, fenotip oranı 3 baskın : 1 çekiniktir.',
    ),
    LearnCard(
      'Bağımsız genler',
      'Genler bağımsızsa her genin olasılığı ayrı hesaplanıp çarpılır. AaBb × AaBb fenotip oranı 9 : 3 : 3 : 1\'dir.',
    ),
    LearnCard(
      'Kan grupları',
      'Iᴬ ve Iᴮ eş baskın, i çekiniktir. 0 grubu ii, AB grubu IᴬIᴮ genotiplidir.',
    ),
    LearnCard(
      'X\'e bağlı kalıtım',
      'Renk körlüğü ve hemofili X\'e bağlı çekiniktir; erkekler tek X taşıdığından daha sık görülür. Erkek, X kromozomunu annesinden alır.',
    ),
    LearnCard(
      'Organeller',
      'Mitokondri: enerji (ATP) · Kloroplast: fotosentez · Ribozom: protein sentezi · Lizozom: hücre içi sindirim · Golgi: paketleme ve salgı.',
    ),
    LearnCard(
      'Fotosentez',
      'Kloroplastta ışık enerjisiyle karbon dioksit ve sudan glikoz üretilir, oksijen açığa çıkar.',
      formula: '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂',
    ),
    LearnCard(
      'Vitamin eksiklikleri',
      'A: gece körlüğü · B₁: beriberi · C: skorbüt · D: raşitizm · K: kanın pıhtılaşmasında sorun.',
    ),
  ],
  'TYT_TAR': [
    LearnCard(
      'İlk Türk devletleri',
      'Göktürkler "Türk" adını resmî devlet adı olarak ilk kullanan devlettir (552). Uygurlar yerleşik hayata geçen ilk Türk devletidir.',
    ),
    LearnCard(
      'Türk-İslam devletleri',
      'Karahanlılar İslamiyet\'i resmî din olarak kabul eden ilk Türk devletidir. Büyük Selçuklu Devleti Dandanakan Savaşı (1040) ile kuruldu.',
    ),
    LearnCard(
      'Malazgirt (1071)',
      'Alparslan\'ın Bizans\'ı yendiği savaştır; Anadolu\'nun kapıları Türklere açıldı.',
    ),
    LearnCard(
      'Osmanlı kuruluş dönemi',
      'Osman Bey (1299) · Bursa\'nın fethi, Orhan Bey (1326) · I. Kosova, I. Murad (1389) · Ankara Savaşı, Yıldırım Bayezid (1402).',
    ),
    LearnCard(
      'İstanbul\'un fethi (1453)',
      'II. Mehmet (Fatih) döneminde gerçekleşti; Orta Çağ\'ın sonu ve Yeni Çağ\'ın başlangıcı kabul edilir.',
    ),
    LearnCard(
      'Yükselme dönemi',
      'Çaldıran (1514), Mercidabık (1516), Ridaniye (1517) Yavuz Sultan Selim; Mohaç (1526) ve Preveze (1538) Kanuni Sultan Süleyman dönemindedir.',
    ),
    LearnCard(
      'Gerileme ve antlaşmalar',
      'Karlofça (1699) ilk büyük toprak kaybı; Pasarofça (1718) Lale Devri\'nin başlangıcı; Küçük Kaynarca (1774) Kırım\'ın bağımsızlığı.',
    ),
    LearnCard(
      'Yenileşme hareketleri',
      'Yeniçeri Ocağı\'nın kaldırılması (1826) · Tanzimat Fermanı (1839) · Islahat Fermanı (1856) · I. Meşrutiyet (1876) · II. Meşrutiyet (1908).',
    ),
    LearnCard(
      'Millî Mücadele',
      'Samsun (19 Mayıs 1919) · Amasya Genelgesi · Erzurum ve Sivas kongreleri (1919) · TBMM\'nin açılışı (23 Nisan 1920) · Sakarya (1921) · Büyük Taarruz (1922).',
    ),
    LearnCard(
      'Lozan (1923)',
      'Yeni Türk devletinin bağımsızlığını uluslararası alanda tanıtan barış antlaşmasıdır.',
    ),
    LearnCard(
      'Atatürk inkılapları',
      'Saltanat (1922) · Cumhuriyet (1923) · Halifelik ve Tevhid-i Tedrisat (1924) · Şapka (1925) · Medeni Kanun (1926) · Harf (1928) · Soyadı ve kadınlara milletvekilliği (1934).',
    ),
  ],
  'TYT_COG': [
    LearnCard(
      'Harita ölçeği',
      'Ölçek = harita uzunluğu / gerçek uzunluk. Paydası büyüdükçe ölçek küçülür, ayrıntı azalır. 1 km = 100.000 cm.',
      formula: 'Gerçek = Harita · Ölçek paydası',
    ),
    LearnCard(
      'Yerel saat',
      'Her 1° boylam farkı 4 dakika, 15° bir saattir. Doğudaki yerin saati ileridir.',
      formula: '1° = 4 dk',
    ),
    LearnCard(
      'Yükselti ve sıcaklık',
      'Troposferde her 200 m yükselişte sıcaklık yaklaşık 1 °C azalır.',
      formula: '−1 °C / 200 m',
    ),
    LearnCard(
      'Nüfus yoğunluğu',
      'Aritmetik nüfus yoğunluğu, toplam nüfusun yüzölçümüne bölünmesiyle bulunur.',
      formula: 'Yoğunluk = Nüfus / Alan',
    ),
    LearnCard(
      'Dönenceler',
      '21 Haziran: Güneş Yengeç Dönencesi\'ne dik gelir, Kuzey Yarım Küre\'de en uzun gündüz. 21 Aralık: Oğlak Dönencesi. 21 Mart ve 23 Eylül: Ekvator, gece-gündüz eşit.',
    ),
    LearnCard(
      'Türkiye\'nin konumu',
      '36°-42° kuzey enlemleri ile 26°-45° doğu boylamları arasındadır. Yerel saat farkı doğu ile batı arasında 76 dakikadır.',
    ),
    LearnCard(
      'İklim tipleri',
      'Akdeniz: yazlar sıcak-kurak, kışlar ılık-yağışlı (maki). Karadeniz: her mevsim yağışlı (orman). Karasal: yazlar sıcak-kurak, kışlar soğuk-kar yağışlı (bozkır).',
    ),
    LearnCard(
      'Türkiye\'de ilkler',
      'En yüksek dağ: Ağrı Dağı · En büyük göl: Van Gölü · Türkiye\'de doğup denize dökülen en uzun akarsu: Kızılırmak · Yüzölçümü en büyük il: Konya.',
    ),
    LearnCard(
      'Fay hatları',
      'Kuzey Anadolu, Doğu Anadolu ve Batı Anadolu fay hatları Türkiye\'nin başlıca deprem kuşaklarıdır.',
    ),
    LearnCard(
      'Tarım ürünleri',
      'Çay: Rize · Fındık: Karadeniz · Zeytin: Ege · Turunçgil: Akdeniz · Pamuk: Şanlıurfa · Büyükbaş hayvancılık: Doğu Anadolu.',
    ),
  ],
  'TYT_FEL': [
    LearnCard(
      'Felsefe dalları',
      'Bilgi (epistemoloji): bilginin kaynağı, sınırı · Varlık (ontoloji): varlığın özü · Ahlak (etik): iyi ve kötü · Sanat (estetik): güzel · Siyaset: ideal devlet · Bilim: bilimsel yöntem · Din: Tanrı, ruh.',
    ),
    LearnCard(
      'İlk Çağ doğa filozofları',
      'Arkhe (ana madde) arayışı: Thales: su · Anaksimenes: hava · Herakleitos: ateş ve değişim · Pythagoras: sayı · Demokritos: atom.',
    ),
    LearnCard(
      'Sokrates ve sofistler',
      'Protagoras: "İnsan her şeyin ölçüsüdür" (görecelik). Sokrates: "Kendini bil", doğru bilgiye diyalogla (doğurtma yöntemi) ulaşılır.',
    ),
    LearnCard(
      'Platon ve Aristoteles',
      'Platon: gerçek bilgi idealar dünyasındadır (idealizm). Aristoteles: bilgi duyulardan başlar, akılla tamamlanır (realizm); mantığın kurucusudur.',
    ),
    LearnCard(
      'Rasyonalizm',
      'Bilginin kaynağı akıldır. Descartes: "Düşünüyorum, öyleyse varım." Diğer temsilciler: Spinoza, Leibniz.',
    ),
    LearnCard(
      'Empirizm',
      'Bilginin kaynağı deneyimdir. Locke: zihin doğuştan boş bir levhadır (tabula rasa). Diğer temsilciler: Bacon, Hume, Berkeley.',
    ),
    LearnCard(
      'Kant',
      'Kritisizm (eleştiricilik): bilgi akıl ile deneyimin birlikte çalışmasıyla oluşur. Ahlakta ödev etiği: "Öyle davran ki davranışın evrensel bir yasa olabilsin."',
    ),
    LearnCard(
      'Pozitivizm ve pragmatizm',
      'Comte: yalnızca gözlem ve deneye dayalı bilgi geçerlidir. James ve Dewey: bir düşüncenin doğruluğu pratik yararıyla ölçülür.',
    ),
    LearnCard(
      'Varoluşçuluk',
      'Sartre: "Varoluş özden önce gelir." İnsan önce var olur, sonra seçimleriyle kendini tanımlar. Kierkegaard, Heidegger diğer temsilcilerdir.',
    ),
    LearnCard(
      'Ahlak görüşleri',
      'Hedonizm (Aristippos): en yüksek iyi hazdır · Epikürcülük: ölçülü, sürekli haz · Faydacılık (Bentham, Mill): en çok kişiye en çok mutluluk.',
    ),
    LearnCard(
      'Siyaset felsefesi',
      'Hobbes: güçlü devlet (Leviathan) · Machiavelli: devlet için her yol meşrudur · Rousseau: toplum sözleşmesi · Montesquieu: kuvvetler ayrılığı · Farabi: erdemli toplum.',
    ),
    LearnCard(
      'Bilim felsefesi',
      'Popper: bilimsel kuram yanlışlanabilir olmalıdır. Kuhn: bilim paradigma değişimleriyle (bilimsel devrimler) ilerler.',
    ),
  ],
  'TYT_DIN': [
    LearnCard(
      'İmanın şartları',
      'Allah\'a, meleklere, kitaplara, peygamberlere, ahiret gününe ve kadere inanmak (6 şart).',
    ),
    LearnCard(
      'İslam\'ın şartları',
      'Kelime-i şehadet getirmek, namaz kılmak, oruç tutmak, zekât vermek, hacca gitmek (5 şart).',
    ),
    LearnCard(
      'Dört büyük melek',
      'Cebrail: vahiy · Mikail: tabiat olayları · İsrafil: Sûr\'a üflemek · Azrail: can almak.',
    ),
    LearnCard(
      'Kutsal kitaplar',
      'Tevrat: Hz. Musa · Zebur: Hz. Davud · İncil: Hz. İsa · Kur\'an-ı Kerim: Hz. Muhammed.',
    ),
    LearnCard(
      'Kur\'an-ı Kerim',
      '114 sure; ilk sure Fatiha, en uzun sure Bakara, en kısa sure Kevser, son sure Nas. İlk vahiy Hira Mağarası\'nda (610), Alak Suresi\'nin ilk ayetleri.',
    ),
    LearnCard(
      'Hz. Muhammed\'in hayatı',
      'Doğum: 571 · İlk vahiy: 610 · Hicret: 622 · Bedir: 624 · Mekke\'nin fethi: 630 · Vefat: 632.',
    ),
    LearnCard(
      'Dört halife',
      'Hz. Ebubekir (Kur\'an kitap hâline getirildi) · Hz. Ömer · Hz. Osman (Kur\'an çoğaltıldı) · Hz. Ali.',
    ),
    LearnCard(
      'İbadetler',
      'Bedenle: namaz, oruç · Malla: zekât, kurban, fitre · Hem beden hem malla: hac.',
    ),
    LearnCard(
      'Hüküm kavramları',
      'Farz: kesin emir · Vacip: farza yakın · Sünnet: Hz. Peygamber\'in uygulaması · Mubah: serbest · Mekruh: hoş görülmeyen · Haram: kesin yasak.',
    ),
    LearnCard(
      'Mezhepler',
      'İtikadi: Maturidilik, Eşarilik · Fıkhi: Hanefilik, Şafiilik, Malikilik, Hanbelilik.',
    ),
    LearnCard(
      'Ahlak kavramları',
      'Kanaat: elindekiyle yetinmek · Tevazu: alçakgönüllülük · İhlas: ibadeti yalnız Allah için yapmak · Riya: gösteriş · Tevekkül: elinden geleni yapıp sonucu Allah\'a bırakmak.',
    ),
  ],
  'AYT_MAT': [
    LearnCard(
      'Logaritma',
      'Logaritma, üstel ifadenin tersidir. Çarpım toplama, bölüm çıkarmaya dönüşür; üs başa çarpan olarak iner.',
      formula: 'logₐ(x·y) = logₐx + logₐy   ·   logₐ(xⁿ) = n·logₐx',
    ),
    LearnCard(
      'Taban değiştirme',
      'Farklı tabanlı logaritmalar ortak bir tabana çevrilerek karşılaştırılır. logₐa = 1, logₐ1 = 0.',
      formula: 'logₐb = log b / log a',
    ),
    LearnCard(
      'Kalan teoremi',
      'P(x) polinomunun (x − a) ile bölümünden kalan P(a)\'dır. Katsayılar toplamı P(1), sabit terim P(0).',
      formula: 'P(x) = (x − a)·Q(x) + P(a)',
    ),
    LearnCard(
      'Kökler ve katsayılar',
      'ax² + bx + c = 0 denkleminde kökler toplamı ve çarpımı doğrudan katsayılardan bulunur. Δ > 0 ise iki farklı reel kök vardır.',
      formula: 'x₁ + x₂ = −b/a   ·   x₁·x₂ = c/a   ·   Δ = b² − 4ac',
    ),
    LearnCard(
      'Parabol',
      'f(x) = ax² + bx + c parabolünün tepe noktası T(r, k). a > 0 ise kollar yukarı, en küçük değer k\'dir.',
      formula: 'r = −b / 2a   ·   k = f(r)',
    ),
    LearnCard(
      'Karmaşık sayılar',
      'i² = −1 ve i\'nin kuvvetleri dörtte bir tekrar eder. z = a + bi için modül, orijine uzaklıktır.',
      formula: '|z| = √(a² + b²)   ·   i⁴ = 1',
    ),
    LearnCard(
      'Diziler',
      'Aritmetik dizide ardışık terimlerin farkı, geometrik dizide oranı sabittir.',
      formula: 'aₙ = a₁ + (n−1)d   ·   Sₙ = n(a₁ + aₙ)/2   ·   aₙ = a₁·rⁿ⁻¹',
    ),
    LearnCard(
      'Limit',
      '0/0 belirsizliğinde çarpanlara ayırıp sadeleştir. x → ∞ iken rasyonel ifadede dereceler eşitse sonuç baş katsayıların oranıdır.',
      formula: 'lim (x→a) (x² − a²)/(x − a) = 2a',
    ),
    LearnCard(
      'Türev kuralları',
      'Türev anlık değişim hızı ve teğetin eğimidir. f\'(x) = 0 olan noktalarda yerel en büyük ya da en küçük değer aranır.',
      formula: '(xⁿ)\' = n·xⁿ⁻¹   ·   (f·g)\' = f\'g + fg\'',
    ),
    LearnCard(
      'İntegral',
      'Belirli integral, eğri ile x ekseni arasındaki alanı verir: ilkel fonksiyonun üst ve alt sınırdaki değerlerinin farkı alınır.',
      formula: '∫xⁿ dx = xⁿ⁺¹/(n+1) + C',
    ),
    LearnCard(
      'Trigonometri',
      'sin²x + cos²x = 1. sin(kx) ve cos(kx) için periyot 2π/|k|, tan(kx) için π/|k|. 180° = π radyan.',
      formula: 'sin 30° = 1/2   ·   sin 45° = √2/2   ·   sin 60° = √3/2',
    ),
    LearnCard(
      'Permütasyon ve kombinasyon',
      'Sıralama önemliyse permütasyon, yalnızca seçim önemliyse kombinasyon kullanılır.',
      formula: 'P(n, r) = n!/(n−r)!   ·   C(n, r) = n!/(r!(n−r)!)',
    ),
  ],
  'AYT_FIZ': [
    LearnCard(
      'Newton\'un ikinci yasası',
      'Net kuvvet, kütle ile ivmenin çarpımıdır. Sürtünme kuvveti hareketi engelleyen yöndedir.',
      formula: 'F(net) = m·a   ·   f(s) = μ·N',
    ),
    LearnCard(
      'Momentum ve itme',
      'Dış kuvvet yoksa toplam momentum korunur. İtme, momentumdaki değişime eşittir.',
      formula: 'p = m·v   ·   F·Δt = Δp',
    ),
    LearnCard(
      'Atışlar',
      'Yatay atışta yatay hız sabittir; düşme süresi yalnızca yüksekliğe bağlıdır. Düşey atışta tepe noktasında hız sıfırdır.',
      formula: 'h = ½·g·t²   ·   h(max) = v²/2g',
    ),
    LearnCard(
      'Düzgün çembersel hareket',
      'Sürat sabit, hızın yönü sürekli değişir. Merkezcil ivme her an çemberin merkezine doğrudur.',
      formula: 'a = v²/r   ·   F = m·v²/r   ·   v = 2πr/T',
    ),
    LearnCard(
      'Basit harmonik hareket',
      'Denge noktasında hız en büyük, uç noktalarda ivme en büyüktür. Yay sarkacında periyot kütleye, basit sarkaçta ip uzunluğuna bağlıdır.',
      formula: 'T = 2π√(m/k)   ·   T = 2π√(L/g)',
    ),
    LearnCard(
      'Tork ve denge',
      'Dönme etkisi kuvvet ile dönme eksenine dik uzaklığın çarpımıdır. Dengede net kuvvet ve net tork sıfırdır.',
      formula: 'τ = F·d',
    ),
    LearnCard(
      'Elektrik alan ve Coulomb',
      'Yükler arasındaki kuvvet yüklerin çarpımıyla doğru, aradaki uzaklığın karesiyle ters orantılıdır.',
      formula: 'F = k·q₁·q₂/d²   ·   E = k·q/d²',
    ),
    LearnCard(
      'Kondansatör',
      'Sığa, levhaların alanı ve aradaki yalıtkanla artar, levhalar arası uzaklıkla azalır; gerilime bağlı değildir.',
      formula: 'Q = C·V   ·   E = ½·C·V²',
    ),
    LearnCard(
      'Manyetizma ve indüksiyon',
      'Akım taşıyan tele manyetik alanda kuvvet etki eder. Manyetik akı değişimi emk oluşturur.',
      formula: 'F = B·I·L   ·   ε = B·L·v',
    ),
    LearnCard(
      'Transformatör',
      'Alternatif akımla çalışır. Gerilimler sarım sayılarıyla doğru, akımlar ters orantılıdır.',
      formula: 'V₁/V₂ = N₁/N₂',
    ),
    LearnCard(
      'Fotoelektrik olay',
      'Sökülen elektronların enerjisi ışığın frekansına, sayısı ise ışığın şiddetine bağlıdır.',
      formula: 'E(foton) = h·f = W + E(k,max)',
    ),
    LearnCard(
      'Radyoaktivite',
      'Her yarı ömürde bozunmamış madde yarıya iner. Alfa: helyum çekirdeği · Beta: elektron · Gama: elektromanyetik dalga.',
      formula: 'm = m₀ / 2ⁿ',
    ),
  ],
  'AYT_KIM': [
    LearnCard(
      'İdeal gaz denklemi',
      'Normal şartlarda (0 °C, 1 atm) 1 mol gaz 22,4 L hacim kaplar. Sabit sıcaklıkta basınç ile hacim ters orantılıdır.',
      formula: 'P·V = n·R·T   ·   P₁V₁ = P₂V₂',
    ),
    LearnCard(
      'Molarite',
      'Bir litre çözeltide çözünen maddenin mol sayısıdır. Su eklenirse mol sayısı değişmez, derişim azalır.',
      formula: 'M = n / V   ·   M₁V₁ = M₂V₂',
    ),
    LearnCard(
      'Koligatif özellikler',
      'Uçucu olmayan madde eklenen çözeltide kaynama noktası yükselir, donma noktası düşer, buhar basıncı azalır.',
    ),
    LearnCard(
      'pH ve pOH',
      '25 °C\'de pH + pOH = 14. pH < 7 asidik, pH = 7 nötr, pH > 7 baziktir.',
      formula: 'pH = −log[H⁺]',
    ),
    LearnCard(
      'Denge sabiti',
      'Ürünlerin derişimleri çarpımının girenlerinkine oranıdır; katı ve saf sıvılar yazılmaz. Kc yalnızca sıcaklıkla değişir.',
      formula: 'aA + bB ⇌ cC  →  Kc = [C]ᶜ / ([A]ᵃ[B]ᵇ)',
    ),
    LearnCard(
      'Le Chatelier ilkesi',
      'Dengedeki sisteme yapılan etkiyi azaltacak yönde kayma olur. Ekzotermik tepkimede sıcaklık artarsa denge girenlere kayar.',
    ),
    LearnCard(
      'Tepkime hızı',
      'Hız derişim, sıcaklık, temas yüzeyi ve katalizörle artar. Katalizör aktifleşme enerjisini düşürür, ΔH\'yi değiştirmez.',
      formula: 'Hız = k·[A]ᵐ·[B]ⁿ',
    ),
    LearnCard(
      'Hess yasası',
      'Tepkime ters çevrilirse ΔH\'nin işareti değişir; katsayılarla çarpılırsa ΔH de aynı sayıyla çarpılır.',
      formula: 'ΔH(toplam) = ΔH₁ + ΔH₂ + …',
    ),
    LearnCard(
      'Elektrokimya',
      'Anotta yükseltgenme, katotta indirgenme olur. 1 Faraday (96 500 C) yük 1 mol elektrona karşılık gelir.',
      formula: 'n(metal) = yük (F) / iyon değerliği',
    ),
    LearnCard(
      'Organik bileşikler',
      'Alkan CₙH₂ₙ₊₂ (tekli bağ) · Alken CₙH₂ₙ (ikili bağ) · Alkin CₙH₂ₙ₋₂ (üçlü bağ) · Alkol –OH · Karboksilik asit –COOH.',
    ),
    LearnCard(
      'Periyodik özellikler',
      'Periyotta soldan sağa atom yarıçapı azalır, iyonlaşma enerjisi ve elektronegatiflik artar. Grupta aşağı inildikçe yarıçap artar.',
    ),
  ],
  'AYT_BIY': [
    LearnCard(
      'Bağımsız genler',
      'Her gen ayrı çaprazlanır, olasılıklar çarpılır. n heterozigot gen 2ⁿ çeşit gamet oluşturur.',
      formula: 'AaBb × AaBb  →  9 : 3 : 3 : 1',
    ),
    LearnCard(
      'Kan grupları',
      'A ve B alelleri eş baskın, 0 aleli çekiniktir. A0 × B0 çaprazlamasından dört kan grubu da çıkabilir.',
    ),
    LearnCard(
      'Eşeye bağlı kalıtım',
      'Renk körlüğü ve hemofili X kromozomunda taşınır. Erkek çocuk X\'ini anneden aldığı için hastalık erkeklerde daha sık görülür.',
    ),
    LearnCard(
      'Hardy-Weinberg dengesi',
      'Büyük, rastgele çiftleşen ve göç, mutasyon, seçilim olmayan popülasyonda alel frekansları kuşaktan kuşağa değişmez.',
      formula: 'p + q = 1   ·   p² + 2pq + q² = 1',
    ),
    LearnCard(
      'Protein sentezi',
      'Transkripsiyonda DNA\'dan mRNA yapılır, translasyonda ribozomda protein sentezlenir. Her amino asit üç nükleotitlik bir kodonla şifrelenir.',
      formula: 'n amino asit → n − 1 peptit bağı',
    ),
    LearnCard(
      'Hücresel solunum',
      'Glikoliz sitoplazmada, Krebs döngüsü mitokondri matriksinde, ETS mitokondri iç zarında gerçekleşir. Son elektron alıcısı oksijendir.',
    ),
    LearnCard(
      'Fotosentez',
      'Işığa bağımlı tepkimeler tilakoit zarlarında, Calvin döngüsü stromada gerçekleşir. Suyun parçalanmasıyla O₂ açığa çıkar.',
      formula: '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂',
    ),
    LearnCard(
      'Endokrin sistem',
      'İnsülin kan şekerini düşürür, glukagon yükseltir. Kalsitonin kandaki kalsiyumu düşürür, parathormon yükseltir.',
    ),
    LearnCard(
      'Sinir sistemi',
      'Beyincik denge ve kas uyumu, omurilik soğanı solunum ve kalp atışı, hipotalamus vücut sıcaklığı ve susuzluk merkezidir.',
    ),
    LearnCard(
      'Dolaşım',
      'Sol karıncık kanı aort ile vücuda, sağ karıncık akciğer atardamarı ile akciğerlere pompalar. Akciğer toplardamarı temiz kan taşır.',
    ),
    LearnCard(
      'Enerji akışı',
      'Besin zincirinde her basamağa önceki basamaktaki enerjinin yaklaşık %10\'u aktarılır; gerisi ısı olarak kaybolur.',
    ),
  ],
  'AYT_EDB': [
    LearnCard(
      'Tanzimat edebiyatı',
      'Şinasi, Namık Kemal, Ziya Paşa (I. kuşak: toplum için sanat) · Recaizade Mahmut Ekrem, Abdülhak Hamit, Samipaşazade Sezai (II. kuşak: sanat için sanat).',
    ),
    LearnCard(
      'Servet-i Fünun',
      'Sanat için sanat; ağır, süslü dil; aruz ölçüsü; bireysel konular. Tevfik Fikret, Cenap Şahabettin, Halit Ziya Uşaklıgil, Mehmet Rauf.',
    ),
    LearnCard(
      'Millî Edebiyat',
      'Sade Türkçe, hece ölçüsü, Anadolu ve millî konular. Ömer Seyfettin, Ziya Gökalp, Mehmet Emin Yurdakul; Beş Hececiler de bu çizgidedir.',
    ),
    LearnCard(
      'Cumhuriyet dönemi şiiri',
      'Garip (Orhan Veli, Oktay Rifat, Melih Cevdet): ölçü-kafiye ve söz sanatlarını reddeder. İkinci Yeni (Cemal Süreya, Edip Cansever, Turgut Uyar): imge ve kapalı anlatım.',
    ),
    LearnCard(
      'Divan nazım biçimleri',
      'Gazel: aa ba ca, aşk · Kaside: övgü, nesib-girizgâh-methiye-fahriye-dua · Mesnevi: aa bb cc, uzun konular · Rubai: aaxa, felsefi · Tuyuğ: Türklere özgü.',
    ),
    LearnCard(
      'Halk şiiri biçimleri',
      'Koşma: 11\'li hece, lirik · Semai ve varsağı: 8\'li hece · Mani: 7\'li hece, aaxa · Destan: toplumsal olaylar · Taşlama: eleştiri.',
    ),
    LearnCard(
      'Hece ölçüsü',
      'Dizedeki hece sayısı ünlü sayısına eşittir. Koşma 11, semai 8, mani 7 hecelidir.',
    ),
    LearnCard(
      'Söz sanatları I',
      'Teşbih: benzetme · İstiare: tek ögeyle benzetme · Teşhis: kişileştirme · İntak: konuşturma · Mübalağa: abartma · Tezat: karşıtlık.',
    ),
    LearnCard(
      'Söz sanatları II',
      'Tecahül-i arif: bilmezlikten gelme · Hüsn-i talil: güzel neden bulma · Telmih: hatırlatma · Kinaye: hem gerçek hem mecaz · Tevriye: uzak anlamı kastetme.',
    ),
    LearnCard(
      'Edebiyatımızda ilkler',
      'İlk yerli roman: Taaşşuk-ı Talat ve Fitnat · İlk tiyatro: Şair Evlenmesi · İlk edebî roman: İntibah · İlk realist roman: Araba Sevdası · İlk psikolojik roman: Eylül.',
    ),
    LearnCard(
      'Batı akımları',
      'Klasisizm: Racine, Molière · Romantizm: Victor Hugo · Realizm: Balzac, Flaubert · Natüralizm: Zola · Parnasizm: Leconte de Lisle · Sembolizm: Baudelaire, Mallarmé.',
    ),
    LearnCard(
      'Düşünce yazıları',
      'Deneme: kesin yargı yok, samimi · Makale: kanıta dayalı · Fıkra: güncel ve kısa · Sohbet: okurla konuşur gibi · Eleştiri: eseri değerlendirir.',
    ),
  ],
  'AYT_TAR1': [
    LearnCard(
      'İslam tarihi',
      '622 Hicret · 624 Bedir · 625 Uhud · 627 Hendek · 628 Hudeybiye · 630 Mekke\'nin fethi. Dört halife: Ebubekir, Ömer, Osman, Ali.',
    ),
    LearnCard(
      'Türk-İslam devletleri',
      'Karahanlılar: ilk Müslüman Türk devleti · Gazneliler: Hindistan seferleri · Büyük Selçuklu: Malazgirt (1071), Nizamiye Medreseleri.',
    ),
    LearnCard(
      'Osmanlı kuruluş ve yükselme',
      'Osman Bey (1299) · Orhan Bey: ilk düzenli ordu · I. Murad: Yeniçeri Ocağı · Fatih: İstanbul (1453) · Yavuz: halifelik · Kanuni: en geniş sınırlar.',
    ),
    LearnCard(
      'Osmanlı toprak sistemi',
      'Tımar: vergi geliri asker yetiştirme karşılığında verilir. Zamanla yerini iltizam ve malikane sistemine bırakır.',
    ),
    LearnCard(
      'Divan-ı Hümayun',
      'Sadrazam: padişahın vekili · Kazasker: adalet ve eğitim · Defterdar: maliye · Nişancı: tuğra ve tapu · Şeyhülislam: fetva.',
    ),
    LearnCard(
      'XVII. yüzyıl',
      'Zitvatorok (1606) ile Avusturya\'ya üstünlük kaybedilir. Kandiye\'nin fethi (1669) ve Bucaş (1672) ile en geniş sınırlara ulaşılır.',
    ),
    LearnCard(
      'XVIII. yüzyıl ıslahatları',
      'Lale Devri ve ilk matbaa (III. Ahmet) · Nizam-ı Cedit ordusu (III. Selim). Küçük Kaynarca (1774) ile Kırım\'ın bağımsızlığı kabul edilir.',
    ),
    LearnCard(
      'XIX. yüzyıl',
      'Sened-i İttifak (1808) · Yeniçeri Ocağı\'nın kaldırılması (1826) · Tanzimat (1839) · Islahat (1856) · I. Meşrutiyet (1876).',
    ),
    LearnCard(
      'Avrupa\'da dönüşüm',
      'Coğrafi Keşifler (1492 Amerika) · Rönesans ve Reform (1517 Luther) · Westphalia (1648) · Fransız İhtilali (1789): milliyetçilik ve eşitlik fikirleri.',
    ),
    LearnCard(
      'Osmanlı\'nın dağılması',
      'Balta Limanı (1838) ile ekonomik bağımlılık · Duyun-ı Umumiye (1881) · 31 Mart Vakası (1909) · Trablusgarp (1911) ve Balkan Savaşları.',
    ),
  ],
  'AYT_COG1': [
    LearnCard(
      'Nüfus yoğunlukları',
      'Aritmetik: nüfus / yüz ölçümü · Fizyolojik: nüfus / tarım alanı · Tarımsal: tarımla geçinen nüfus / tarım alanı.',
    ),
    LearnCard(
      'Doğal nüfus artışı',
      'Doğum ve ölüm oranları binde (‰) verilir; farkın onda biri yüzdelik artış hızıdır.',
      formula: '(‰ doğum − ‰ ölüm) / 10 = % artış',
    ),
    LearnCard(
      'Sıcaklık ve yükselti',
      'Yükseldikçe sıcaklık her 200 m\'de yaklaşık 1 °C azalır. Yıllık sıcaklık farkı en sıcak ve en soğuk ay ortalamaları arasındaki farktır.',
    ),
    LearnCard(
      'Nüfus piramitleri',
      'Geniş tabanlı piramit genç ve hızlı artan nüfusu, dar tabanlı piramit yaşlanan nüfusu gösterir.',
    ),
    LearnCard(
      'Biyomlar',
      'Tundra: yosun-liken · Tayga: iğne yapraklı · Step: kısa otlar · Savan: uzun otlar · Maki: Akdeniz çalıları · Yağmur ormanı: en zengin tür çeşitliliği.',
    ),
    LearnCard(
      'Türkiye\'de tarım ürünleri',
      'Fındık ve çay: Karadeniz · Zeytin ve incir: Ege · Muz ve turunçgil: Akdeniz · Antep fıstığı ve mercimek: Güneydoğu · Kayısı: Malatya.',
    ),
    LearnCard(
      'Türkiye\'de madenler',
      'Taşkömürü: Zonguldak · Petrol: Batman · Demir: Divriği · Krom: Guleman · Bakır: Murgul · Bor: Balıkesir-Eskişehir-Kütahya.',
    ),
    LearnCard(
      'Barajlar',
      'Fırat: Atatürk, Keban, Karakaya · Kızılırmak: Hirfanlı, Altınkaya · Sakarya: Sarıyar · Çoruh: Deriner, Yusufeli.',
    ),
    LearnCard(
      'Kalkınma projeleri',
      'GAP: Güneydoğu Anadolu · DAP: Doğu Anadolu · DOKAP: Doğu Karadeniz · KOP: Konya Ovası · ZBK: Zonguldak-Bartın-Karabük.',
    ),
    LearnCard(
      'Tarım türleri',
      'Ekstansif: doğaya bağlı, verimi düşük · Entansif: modern teknikli, verimi yüksek · Plantasyon: geniş alanda tek ürün.',
    ),
  ],
  'AYT_TAR2': [
    LearnCard(
      'İki savaş arası',
      '1917 Rus İhtilali · 1929 Dünya Ekonomik Bunalımı · 1922 Mussolini ve 1933 Hitler iktidara gelir: totaliter rejimler yükselir.',
    ),
    LearnCard(
      'II. Dünya Savaşı',
      '1939\'da başlar, 1945\'te biter. Türkiye savaşın sonuna kadar denge politikası izler. Savaş sonrası BM kurulur (1945).',
    ),
    LearnCard(
      'Soğuk Savaş başlıyor',
      'Truman Doktrini (1947) ve Marshall Planı ile ABD Avrupa\'yı destekler. NATO (1949) ve Varşova Paktı (1955) karşı karşıya gelir.',
    ),
    LearnCard(
      'Türkiye ve Batı',
      'Kore Savaşı\'na asker gönderen Türkiye 1952\'de NATO\'ya girer. 1963 Ankara Antlaşması ile AET\'ye ortak olur.',
    ),
    LearnCard(
      'Yumuşama dönemi',
      'Küba Füze Krizi (1962) sonrası iki blok gerginliği azaltır. Helsinki Nihai Senedi (1975) bu dönemin simgesidir.',
    ),
    LearnCard(
      'Kıbrıs meselesi',
      'Kıbrıs Cumhuriyeti 1960\'ta kurulur. Johnson Mektubu (1964), Kıbrıs Barış Harekâtı (1974) ve KKTC\'nin kurulması (1983).',
    ),
    LearnCard(
      'Türkiye\'de demokrasi',
      '1946 çok partili hayat · 1950 Demokrat Parti iktidarı · 1960, 1971, 1980 askerî müdahaleler · 1961 ve 1982 anayasaları.',
    ),
    LearnCard(
      'Soğuk Savaş\'ın sonu',
      'Gorbaçov\'un glasnost ve perestroykası · 1989 Berlin Duvarı\'nın yıkılması · 1991 SSCB\'nin dağılması ve Türk cumhuriyetlerinin bağımsızlığı.',
    ),
    LearnCard(
      'Küreselleşme',
      'Maastricht (1992) ile AB kurulur. Türkiye 1996\'da Gümrük Birliği\'ne girer, 1999\'da aday ülke olur. 2001 11 Eylül saldırıları.',
    ),
    LearnCard(
      'Dekolonizasyon',
      'Hindistan (1947), Çin Halk Cumhuriyeti (1949) ve Afrika ülkeleri bağımsızlığını kazanır. Bağlantısızlar Hareketi iki bloktan uzak durur.',
    ),
  ],
  'AYT_COG2': [
    LearnCard(
      'Yerel saat',
      'Dünya 1°\'lik boylamı 4 dakikada döner. Doğudaki yerin yerel saati ileridedir.',
      formula: '1° = 4 dakika   ·   15° = 1 saat',
    ),
    LearnCard(
      'Önemli boğazlar',
      'Cebelitarık: Akdeniz-Atlas · Hürmüz: Basra Körfezi-Umman · Malakka: Hint-Büyük Okyanus · Bering: Asya-Kuzey Amerika.',
    ),
    LearnCard(
      'Kanallar',
      'Süveyş Kanalı Akdeniz\'i Kızıldeniz\'e, Panama Kanalı Atlas Okyanusu\'nu Büyük Okyanus\'a bağlar; deniz yolunu büyük ölçüde kısaltır.',
    ),
    LearnCard(
      'Kıtaların yer şekilleri',
      'Asya: Himalayalar, Gobi · Afrika: Nil, Sahra, Atlas · Güney Amerika: Amazon, And · Kuzey Amerika: Mississippi, Kayalık Dağlar · Avrupa: Alpler, Tuna.',
    ),
    LearnCard(
      'Uluslararası örgütler',
      'NATO: ortak savunma · OPEC: petrol politikası · AB: ekonomik ve siyasi birlik · UNESCO: eğitim, bilim, kültür · Türk Devletleri Teşkilatı.',
    ),
    LearnCard(
      'Enerji kaynakları',
      'Yenilenebilir: güneş, rüzgâr, jeotermal, hidroelektrik, biyokütle · Yenilenemez: kömür, petrol, doğal gaz, uranyum.',
    ),
    LearnCard(
      'Doğal afetler',
      'Deprem: kırılmalar · Heyelan: yamaç kayması · Çığ: kar kütlesi kayması · Tsunami: deniz tabanı kaynaklı dev dalgalar · Erozyon: toprak taşınması.',
    ),
    LearnCard(
      'Afetlerden korunma',
      'Depreme dayanıklı yapı, fay hatlarından uzak yerleşim, ağaçlandırma (erozyon ve heyelan), dere yataklarına yapı yapmamak (sel).',
    ),
    LearnCard(
      'Küresel iklim değişimi',
      'Sera gazlarının artması küresel ısınmaya yol açar; buzullar erir, deniz seviyesi yükselir, kuraklık artar.',
    ),
    LearnCard(
      'Jeopolitik konum',
      'Türkiye; boğazları, Asya-Avrupa geçişi ve enerji koridorları üzerindeki konumuyla jeopolitik açıdan önemlidir.',
    ),
  ],
  'AYT_FELG': [
    LearnCard(
      'Mantık bağlaçları',
      '∧ (ve): ikisi de doğruysa doğru · ∨ (veya): biri doğruysa doğru · → (ise): yalnız 1 → 0 yanlış · ↔ (ancak ve ancak): değerler aynıysa doğru.',
    ),
    LearnCard(
      'Akıl yürütme',
      'Tümdengelim: genelden özele, sonuç zorunlu · Tümevarım: özelden genele · Analoji: benzerlikten sonuç çıkarma.',
    ),
    LearnCard(
      'Psikoloji ekolleri',
      'Yapısalcılık: Wundt · İşlevselcilik: James · Davranışçılık: Watson, Skinner · Gestalt: Wertheimer · Psikanaliz: Freud · Hümanist: Maslow, Rogers.',
    ),
    LearnCard(
      'Savunma mekanizmaları',
      'Yansıtma: kendi duygusunu başkasına yükleme · Mantığa bürüme: bahane bulma · Yüceltme: dürtüyü değerli işe yönlendirme · Yer değiştirme: öfkeyi başka hedefe yöneltme.',
    ),
    LearnCard(
      'Öğrenme',
      'Klasik koşullanma (Pavlov): uyarıcıların eşleşmesi · Edimsel koşullanma (Skinner): pekiştirme ve ceza ile öğrenme.',
    ),
    LearnCard(
      'Piaget\'nin dönemleri',
      'Duyusal-motor (0-2) · İşlem öncesi (2-7) · Somut işlemler (7-11) · Soyut işlemler (11+).',
    ),
    LearnCard(
      'Sosyolojinin kurucuları',
      'Comte: "sosyoloji" terimi, pozitivizm · Durkheim: mekanik ve organik dayanışma · Weber: anlayıcı sosyoloji · İbn Haldun: umran ilmi.',
    ),
    LearnCard(
      'Toplumsal yapı',
      'Statü: toplumdaki konum · Rol: statüden beklenen davranış · Norm: davranış kuralları · Dikey hareketlilik: tabakalar arası geçiş.',
    ),
    LearnCard(
      'Bilgi felsefesi',
      'Rasyonalizm: bilginin kaynağı akıl (Descartes) · Empirizm: deneyim (Locke) · Kritisizm: akıl ve deneyim birlikte (Kant) · Sezgicilik: Bergson.',
    ),
    LearnCard(
      'Ahlak felsefesi',
      'Hazcılık: Epikür · Faydacılık: Bentham, Mill · Ödev ahlakı: Kant · Varoluşçuluk: Sartre — insan önce var olur, sonra kendini yapar.',
    ),
  ],
  'AYT_DIN': [
    LearnCard(
      'Hint ve Çin dinleri',
      'Hinduizm: Vedalar, kast sistemi · Budizm: Buda, Nirvana · Taoizm: Lao Tzu · Konfüçyüsçülük: Konfüçyüs, atalara saygı · Şintoizm: Japonya, kami.',
    ),
    LearnCard(
      'Yahudilik',
      'Kutsal kitap Tevrat, yorumları Talmud. İbadet yeri sinagog; Cumartesi (Sebt) kutsal gündür.',
    ),
    LearnCard(
      'Hristiyanlık',
      'Kutsal kitap İncil, ibadet yeri kilise. Katoliklik (Papa, Vatikan), Ortodoksluk ve Protestanlık (Luther) başlıca mezheplerdir.',
    ),
    LearnCard(
      'İtikadi mezhepler',
      'İnanç konularındaki yorum farklılıklarıdır. Maturidilik (Ebu Mansur el-Maturidi) ve Eşarilik (Ebu\'l-Hasan el-Eşari).',
    ),
    LearnCard(
      'Fıkhi mezhepler',
      'İbadet ve muamelattaki yorumlardır. Hanefilik (Ebu Hanife), Şafiilik, Malikilik, Hanbelilik; Caferilik.',
    ),
    LearnCard(
      'Tasavvufi yorumlar',
      'Yesevilik: Ahmet Yesevi · Mevlevilik: Mevlana · Bektaşilik: Hacı Bektaş Veli · Nakşibendilik: Bahaeddin Nakşibend · Kadirilik: Abdülkadir Geylani.',
    ),
    LearnCard(
      'Allah\'ın sıfatları',
      'Zati: Vücud, Kıdem, Beka, Vahdaniyet, Muhalefetün li\'l-havadis, Kıyam bi-nefsihi · Subuti: Hayat, İlim, Semi, Basar, İrade, Kudret, Kelam, Tekvin.',
    ),
    LearnCard(
      'Kur\'an-ı Kerim',
      '114 sure, 30 cüz. İlk sure Fatiha, en uzun Bakara, son Nas. Hz. Ebubekir döneminde kitap hâline getirildi, Hz. Osman döneminde çoğaltıldı.',
    ),
    LearnCard(
      'Hadis kaynakları',
      'Kütüb-i Sitte: Buhari, Müslim, Ebu Davud, Tirmizi, Nesai ve İbn Mace\'nin derlediği altı temel hadis kitabı.',
    ),
    LearnCard(
      'Ahlak kavramları',
      'Takva: Allah\'tan sakınma · İhsan: Allah\'ı görüyormuş gibi kulluk · İsar: başkasını kendine tercih etme · Zühd: dünyaya gönül bağlamama.',
    ),
  ],
};
