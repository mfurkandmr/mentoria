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
};
