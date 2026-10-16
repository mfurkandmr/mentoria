import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/import/data/exam_file_parser.dart';

void main() {
  group('başlık çözümleme', () {
    test('tek hücrede ders + tür', () {
      expect(parseHeader('Türkçe D', ExamType.tyt), (
        'TYT_TUR',
        CountKind.correct,
      ));
      expect(parseHeader('TÜRKÇE YANLIŞ', ExamType.tyt), (
        'TYT_TUR',
        CountKind.wrong,
      ));
      expect(parseHeader('Temel Matematik Doğru', ExamType.tyt), (
        'TYT_MAT',
        CountKind.correct,
      ));
      expect(parseHeader('DİN KÜLTÜRÜ B', ExamType.tyt), (
        'TYT_DIN',
        CountKind.blank,
      ));
      expect(parseHeader('Tarih-1 Y', ExamType.ayt), (
        'AYT_TAR1',
        CountKind.wrong,
      ));
      expect(parseHeader('TYT Fizik D', ExamType.tyt), (
        'TYT_FIZ',
        CountKind.correct,
      ));
    });

    test('net sütunu ve alakasız başlıklar eşleşmez', () {
      expect(parseHeader('Türkçe N', ExamType.tyt), isNull);
      expect(parseHeader('Türkçe Net', ExamType.tyt), isNull);
      expect(parseHeader('Sıra', ExamType.tyt), isNull);
      expect(parseHeader('Edebiyat D', ExamType.tyt), isNull); // AYT dersi
    });

    test('numara normalleştirme', () {
      expect(normalizeNumber(' 01042 '), '1042');
      expect(normalizeNumber('0'), '0');
      expect(normalizeNumber('a-12'), 'A-12');
    });
  });

  test('tek satır başlıklı sayfa', () {
    final SheetRows rows = [
      ['Bal Akademi TYT Deneme 3 Sonuçları'],
      [],
      [
        'Sıra',
        'Öğrenci No',
        'Adı Soyadı',
        'Türkçe D',
        'Türkçe Y',
        'Türkçe N',
        'Matematik D',
        'Matematik Y',
        'Matematik N',
      ],
      ['1', '1042', 'Elif Yılmaz', '33', '4', '32', '24', '6', '22,5'],
      ['2', '0077', 'Can Kaya', '25', '8', '23', '15', '10', '12,5'],
      [],
      ['', '', 'Ortalama', '29', '6', '', '19,5', '8', ''],
    ];
    final sheet = parseSheet(rows, ExamType.tyt)!;
    expect(sheet.headerRow, 2);
    expect(sheet.mapping.numberCol, 1);
    expect(sheet.mapping.nameCol, 2);
    expect(sheet.mapping.mappedSubjectCount, 2);

    final parsed = buildRows(sheet, sheet.mapping);
    // Ortalama satırı numarasız olduğu için atlanır.
    expect(parsed.map((r) => r.number), ['1042', '0077']);
    expect(parsed.first.totalNet, (33 - 1) + (24 - 1.5));
    // Boş sütunu yoksa kalan soru boş sayılır.
    expect(parsed.first.results.first.blank, 40 - 33 - 4);
  });

  test('iki satırlı (birleştirilmiş) başlıklı sayfa', () {
    final SheetRows rows = [
      [
        'Öğrenci No',
        'Ad Soyad',
        'TÜRKÇE',
        '',
        '',
        'SOSYAL BİLİMLER',
        '',
        '',
        'TARİH',
        '',
        'MATEMATİK',
        '',
        '',
      ],
      ['', '', 'D', 'Y', 'N', 'D', 'Y', 'N', 'D', 'Y', 'D', 'Y', 'B'],
      [
        '1042',
        'Elif Yılmaz',
        '30',
        '8',
        '28',
        '14',
        '2',
        '13,5',
        '4',
        '1',
        '20',
        '4',
        '16',
      ],
    ];
    final sheet = parseSheet(rows, ExamType.tyt)!;
    expect(sheet.headerRow, 1);
    expect(sheet.mapping.numberCol, 0);
    expect(sheet.mapping.nameCol, 1);
    // Sosyal Bilimler toplamı tek derse dağıtılamaz → eşleşmez.
    expect(
      sheet.mapping.subjects.keys,
      containsAll(['TYT_TUR', 'TYT_TAR', 'TYT_MAT']),
    );
    expect(sheet.mapping.subjects.containsKey('TYT_COG'), isFalse);

    final row = buildRows(sheet, sheet.mapping).single;
    final mat = row.results.firstWhere((r) => r.code == 'TYT_MAT');
    expect(mat.blank, 16); // B sütunu varsa ondan okunur
    expect(row.totalNet, 28 + 3.75 + 19);
  });

  test('gerçek .xlsx dosyası okunur', () {
    final book = Excel.createExcel();
    final sheet = book['Sonuçlar'];
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Ad Soyad'),
      TextCellValue('Fizik D'),
      TextCellValue('Fizik Y'),
    ]);
    sheet.appendRow([
      const IntCellValue(5),
      TextCellValue('Zeynep Arslan'),
      const IntCellValue(10),
      const DoubleCellValue(2),
    ]);
    final bytes = Uint8List.fromList(book.save()!);

    final sheets = readSpreadsheet(bytes);
    final rows = sheets['Sonuçlar']!;
    expect(rows[1], ['5', 'Zeynep Arslan', '10', '2']);

    final parsed = parseSheet(rows, ExamType.ayt)!;
    expect(parsed.mapping.numberCol, 0);
    expect(parsed.mapping.mappedSubjectCount, 1);
    final row = buildRows(parsed, parsed.mapping).single;
    expect(row.number, '5');
    expect(row.results.single.code, 'AYT_FIZ');
    expect(row.totalNet, 9.5);
  });

  test('soru sayısını aşan satır işaretlenir', () {
    final SheetRows rows = [
      ['No', 'Fizik D', 'Fizik Y', 'Kimya D', 'Kimya Y'],
      ['1', '6', '3', '5', '1'],
    ];
    final sheet = parseSheet(rows, ExamType.tyt)!;
    final row = buildRows(sheet, sheet.mapping).single;
    expect(row.problem, contains('Fizik'));
  });
}
