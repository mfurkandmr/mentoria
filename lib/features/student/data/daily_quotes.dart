import '../../../core/i18n/i18n.dart';

/// Günün sözü. Kamuya mal olmuş kişilerin özlü sözleri ve Bızz'ın kendi
/// cümleleri. Her gün sıradaki söz gösterilir (yılın gününe göre).
class Quote {
  const Quote(this.trText, this.enText, this.author);

  final String trText;
  final String enText;
  final String author;

  String get text => currentLanguage == AppLanguage.en ? enText : trText;

  /// Yazarın gösterilecek adı (bazı adların İngilizcesi farklıdır).
  String get by => switch (author) {
    'Bızz' => 'Bızz 🐝',
    'Atasözü' => tr('Atasözü'),
    'Latin atasözü' => tr('Latin atasözü'),
    'Aristoteles' => tr('Aristoteles'),
    'Konfüçyüs' => tr('Konfüçyüs'),
    'Sokrates' => tr('Sokrates'),
    'Mevlânâ' => tr('Mevlânâ'),
    _ => author,
  };
}

const dailyQuotes = <Quote>[
  Quote(
    'Hayatta en hakiki mürşit ilimdir.',
    'The truest guide in life is knowledge.',
    'Mustafa Kemal Atatürk',
  ),
  Quote(
    'Damlaya damlaya göl olur.',
    'Drop by drop, a lake is formed.',
    'Atasözü',
  ),
  Quote(
    'Bin kilometrelik yolculuk tek bir adımla başlar.',
    'A journey of a thousand miles begins with a single step.',
    'Lao Tzu',
  ),
  Quote(
    'Ne kadar yavaş gittiğin önemli değil, yeter ki durma.',
    'It does not matter how slowly you go, as long as you do not stop.',
    'Konfüçyüs',
  ),
  Quote(
    'Biz her şeyi tekrar tekrar yaptığımız şeyleriz. Mükemmellik bir eylem değil, alışkanlıktır.',
    'We are what we repeatedly do. Excellence, then, is not an act but a habit.',
    'Aristoteles',
  ),
  Quote(
    'Zorluklar, başarının değerini artıran süslerdir.',
    'Difficulties are the ornaments that raise the value of success.',
    'Molière',
  ),
  Quote(
    'Şans, hazırlığın fırsatla buluştuğu yerdir.',
    'Luck is what happens when preparation meets opportunity.',
    'Seneca',
  ),
  Quote(
    'Dün akıllıydım, dünyayı değiştirmek istedim. Bugün bilgeyim, kendimi değiştiriyorum.',
    'Yesterday I was clever, so I wanted to change the world. Today I am wise, so I am changing myself.',
    'Mevlânâ',
  ),
  Quote(
    'İlim ilim bilmektir, ilim kendin bilmektir.',
    'Knowledge is to know knowledge; knowledge is to know yourself.',
    'Yunus Emre',
  ),
  Quote(
    'Dehanın yüzde biri ilham, yüzde doksan dokuzu terdir.',
    'Genius is one percent inspiration and ninety-nine percent perspiration.',
    'Thomas Edison',
  ),
  Quote(
    'Başarısız olmadım, sadece işe yaramayan on bin yol buldum.',
    'I have not failed. I have just found ten thousand ways that won\'t work.',
    'Thomas Edison',
  ),
  Quote(
    'Yarına bırakma; bugün yapabileceğin işi yap.',
    'Never leave till tomorrow that which you can do today.',
    'Benjamin Franklin',
  ),
  Quote(
    'Öğrenmenin kökleri acı, meyveleri tatlıdır.',
    'The roots of education are bitter, but the fruit is sweet.',
    'Aristoteles',
  ),
  Quote(
    'Bir şeyi basitçe açıklayamıyorsan, onu yeterince anlamamışsındır.',
    'If you can\'t explain it simply, you don\'t understand it well enough.',
    'Albert Einstein',
  ),
  Quote(
    'Sabır acıdır ama meyvesi tatlıdır.',
    'Patience is bitter, but its fruit is sweet.',
    'Jean-Jacques Rousseau',
  ),
  Quote(
    'Okumak, zihin için ne ise egzersiz de beden için odur.',
    'Reading is to the mind what exercise is to the body.',
    'Joseph Addison',
  ),
  Quote(
    'Küçük işleri büyük bir sevgiyle yap.',
    'Do small things with great love.',
    'Atasözü',
  ),
  Quote(
    'Zaman, en iyi öğretmendir; ne yazık ki tüm öğrencilerini öldürür.',
    'Time is the best teacher; unfortunately, it kills all its students.',
    'Hector Berlioz',
  ),
  Quote(
    'Ağaç ne kadar yükselmek isterse, kökleri o kadar derine iner.',
    'The higher a tree wants to grow, the deeper its roots must go.',
    'Friedrich Nietzsche',
  ),
  Quote(
    'Düşmek ayıp değil, kalkmamak ayıptır.',
    'Falling is no shame; not getting up is.',
    'Atasözü',
  ),
  Quote('Bilgi güçtür.', 'Knowledge is power.', 'Francis Bacon'),
  Quote(
    'Eğitimin amacı, boş bir zihni açık bir zihinle değiştirmektir.',
    'The goal of education is to replace an empty mind with an open one.',
    'Malcolm Forbes',
  ),
  Quote(
    'Yapabileceğine inan, yolun yarısını almışsın demektir.',
    'Believe you can and you\'re halfway there.',
    'Theodore Roosevelt',
  ),
  Quote(
    'Gelecek, bugünden ona hazırlananlara aittir.',
    'The future belongs to those who prepare for it today.',
    'Malcolm X',
  ),
  Quote(
    'Her ustanın bir zamanlar acemi olduğunu unutma.',
    'Every master was once a beginner.',
    'Ralph Waldo Emerson',
  ),
  Quote(
    'Başlamak için harika olmak zorunda değilsin; harika olmak için başlamak zorundasın.',
    'You don\'t have to be great to start, but you have to start to be great.',
    'Zig Ziglar',
  ),
  Quote(
    'Bugün bir soru fazla çöz; yarın bir adım önde ol.',
    'Solve one more question today; be one step ahead tomorrow.',
    'Bızz',
  ),
  Quote(
    'Arılar çiçek çiçek dolaşır, bal öyle birikir. Sen de soru soru ilerle.',
    'Bees visit flower after flower — that\'s how honey builds up. Go question by question.',
    'Bızz',
  ),
  Quote(
    'Yanlışların, doğrulara giden yolun haritasıdır.',
    'Your mistakes are the map to the right answers.',
    'Bızz',
  ),
  Quote(
    'Yorulduğunda dinlen, ama vazgeçme.',
    'Rest when you\'re tired, but don\'t quit.',
    'Bızz',
  ),
  Quote(
    'Bir pomodoro daha; sonra hak ettiğin molayı ver.',
    'One more pomodoro — then take the break you\'ve earned.',
    'Bızz',
  ),
  Quote(
    'Netler bir günde artmaz; ama her gün biraz artar.',
    'Nets don\'t rise in a day — but they rise a little every day.',
    'Bızz',
  ),
  Quote(
    'Kendini dünkü hâlinle kıyasla, başkalarıyla değil.',
    'Compare yourself to who you were yesterday, not to others.',
    'Bızz',
  ),
  Quote(
    'Zor konular, en çok bal çıkan çiçeklerdir.',
    'The hardest topics are the flowers with the most honey.',
    'Bızz',
  ),
  Quote(
    'Tekrar, öğrenmenin annesidir.',
    'Repetition is the mother of learning.',
    'Latin atasözü',
  ),
  Quote('Akıl için yol birdir.', 'There is one road for reason.', 'Atasözü'),
  Quote(
    'Sanatsız kalan bir milletin hayat damarlarından biri kopmuş olur.',
    'A nation without art has lost one of its lifelines.',
    'Mustafa Kemal Atatürk',
  ),
  Quote(
    'Hiçbir şey bilmediğimi biliyorum; öğrenmeye oradan başlıyorum.',
    'I know that I know nothing — and that is where learning begins.',
    'Sokrates',
  ),
  Quote(
    'Disiplin, hedeflerle başarı arasındaki köprüdür.',
    'Discipline is the bridge between goals and accomplishment.',
    'Jim Rohn',
  ),
  Quote(
    'Bugünün emeği, yarının gururudur.',
    'Today\'s effort is tomorrow\'s pride.',
    'Bızz',
  ),
];

/// Bugünün sözü (yılın gününe göre döner; herkes aynı gün aynı sözü görür).
Quote quoteOfTheDay([DateTime? now]) {
  final d = now ?? DateTime.now();
  final dayOfYear = d.difference(DateTime(d.year)).inDays;
  return dailyQuotes[(dayOfYear + d.year) % dailyQuotes.length];
}
