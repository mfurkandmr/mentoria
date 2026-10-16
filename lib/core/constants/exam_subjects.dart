import '../i18n/i18n.dart';

/// YKS sınav türleri ve ders/soru dağılımı.
///
/// `code` değerleri Supabase'deki `subjects.code` ile birebir aynıdır.
enum ExamType {
  tyt('TYT'),
  ayt('AYT'),
  ydt('YDT');

  const ExamType(this.label);
  final String label;

  /// Veritabanındaki enum değeri.
  String get db => label;

  static ExamType fromDb(String value) =>
      ExamType.values.firstWhere((t) => t.db == value);
}

/// AYT alanları (YDT için `dil`).
enum FieldType {
  say('SAY', 'Sayısal'),
  ea('EA', 'Eşit Ağırlık'),
  soz('SOZ', 'Sözel'),
  dil('DIL', 'Dil');

  const FieldType(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static FieldType? fromDb(String? value) =>
      value == null ? null : FieldType.values.firstWhere((f) => f.db == value);
}

class ExamSubject {
  const ExamSubject(
    this.code,
    this.examType,
    this.trName,
    this.questionCount, {
    this.trGroup,
  });

  final String code;
  final ExamType examType;
  final String trName;
  final int questionCount;

  /// TYT'deki test başlığı (Türkçe, Sosyal Bilimler, ...).
  final String? trGroup;

  String get name => tr(trName);
  String? get group => trGroup == null ? null : tr(trGroup!);
}

const examSubjects = <ExamSubject>[
  ExamSubject('TYT_TUR', ExamType.tyt, 'Türkçe', 40, trGroup: 'Türkçe'),
  ExamSubject('TYT_TAR', ExamType.tyt, 'Tarih', 5, trGroup: 'Sosyal Bilimler'),
  ExamSubject(
    'TYT_COG',
    ExamType.tyt,
    'Coğrafya',
    5,
    trGroup: 'Sosyal Bilimler',
  ),
  ExamSubject(
    'TYT_FEL',
    ExamType.tyt,
    'Felsefe',
    5,
    trGroup: 'Sosyal Bilimler',
  ),
  ExamSubject(
    'TYT_DIN',
    ExamType.tyt,
    'Din Kültürü',
    5,
    trGroup: 'Sosyal Bilimler',
  ),
  ExamSubject(
    'TYT_MAT',
    ExamType.tyt,
    'Matematik',
    40,
    trGroup: 'Temel Matematik',
  ),
  ExamSubject('TYT_FIZ', ExamType.tyt, 'Fizik', 7, trGroup: 'Fen Bilimleri'),
  ExamSubject('TYT_KIM', ExamType.tyt, 'Kimya', 7, trGroup: 'Fen Bilimleri'),
  ExamSubject('TYT_BIY', ExamType.tyt, 'Biyoloji', 6, trGroup: 'Fen Bilimleri'),
  ExamSubject('AYT_MAT', ExamType.ayt, 'Matematik', 40),
  ExamSubject('AYT_FIZ', ExamType.ayt, 'Fizik', 14),
  ExamSubject('AYT_KIM', ExamType.ayt, 'Kimya', 13),
  ExamSubject('AYT_BIY', ExamType.ayt, 'Biyoloji', 13),
  ExamSubject('AYT_EDB', ExamType.ayt, 'Türk Dili ve Edebiyatı', 24),
  ExamSubject('AYT_TAR1', ExamType.ayt, 'Tarih-1', 10),
  ExamSubject('AYT_COG1', ExamType.ayt, 'Coğrafya-1', 6),
  ExamSubject('AYT_TAR2', ExamType.ayt, 'Tarih-2', 11),
  ExamSubject('AYT_COG2', ExamType.ayt, 'Coğrafya-2', 11),
  ExamSubject('AYT_FELG', ExamType.ayt, 'Felsefe Grubu', 12),
  ExamSubject('AYT_DIN', ExamType.ayt, 'Din Kültürü', 6),
  ExamSubject('YDT_YD', ExamType.ydt, 'Yabancı Dil', 80),
];

const _aytFieldCodes = <FieldType, List<String>>{
  FieldType.say: ['AYT_MAT', 'AYT_FIZ', 'AYT_KIM', 'AYT_BIY'],
  FieldType.ea: ['AYT_MAT', 'AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
  FieldType.soz: [
    'AYT_EDB',
    'AYT_TAR1',
    'AYT_COG1',
    'AYT_TAR2',
    'AYT_COG2',
    'AYT_FELG',
    'AYT_DIN',
  ],
};

/// Bir denemede girilecek dersler. AYT için alan zorunludur.
List<ExamSubject> subjectsFor(ExamType type, [FieldType? field]) {
  switch (type) {
    case ExamType.tyt:
    case ExamType.ydt:
      return examSubjects.where((s) => s.examType == type).toList();
    case ExamType.ayt:
      final codes = _aytFieldCodes[field ?? FieldType.say]!;
      return codes.map(subjectByCode).toList();
  }
}

/// AYT'de seçilebilen alanlar.
const aytFields = [FieldType.say, FieldType.ea, FieldType.soz];

ExamSubject subjectByCode(String code) =>
    examSubjects.firstWhere((s) => s.code == code);

/// YKS net hesabı: 4 yanlış 1 doğruyu götürür.
double calculateNet(int correct, int wrong) => correct - wrong / 4;
