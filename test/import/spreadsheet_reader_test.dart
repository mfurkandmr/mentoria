import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/import/data/exam_file_parser.dart';
import 'package:mentoria/features/import/data/spreadsheet_reader.dart'
    show formatNumber;

/// Örnek dosyalar: test/fixtures/import/make_fixtures.py ile üretilir.
Uint8List fixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

void main() {
  const students = {
    '01042': ('Elif Yılmaz', 34 - 4 / 4 + 26 - 5 / 4),
    '1077': ('Zeynep Arslan', 28 - 6 / 4 + 18 - 8 / 4),
    '2001': ('Çağrı Işık', 30 - 5 / 4 + 22 - 3 / 4),
    '9999': ('Bilinmeyen Öğrenci', 20 - 10 / 4 + 10 - 10 / 4),
  };

  // Aynı sonuç tablosu her biçimde aynı öğrencileri ve netleri vermeli.
  for (final file in [
    'sonuc.xlsx',
    'sonuc.xls',
    'sonuc_1254.csv',
    'sonuc_tab.txt',
    'sonuc_html.xls',
  ]) {
    test('$file: okunur, sütunlar eşleşir, netler doğru', () {
      final sheets = readSpreadsheet(fixture(file));
      final rows = sheets.values.first;
      final parsed = parseSheet(rows, ExamType.tyt);
      expect(parsed, isNotNull, reason: 'başlık satırı bulunmalı');
      expect(parsed!.mapping.mappedSubjectCount, 2);
      expect(parsed.mapping.numberCol, 0);
      expect(parsed.mapping.nameCol, 1);

      final built = {
        for (final r in buildRows(parsed, parsed.mapping)) r.number: r,
      };
      for (final e in students.entries) {
        final row = built[e.key];
        expect(row, isNotNull, reason: '${e.key} bulunmalı');
        expect(row!.name, e.value.$1, reason: 'Türkçe karakterler korunur');
        // 22,5 / 22.5 doğru sayısı tam sayıya yuvarlanır (ders sonucu tamsayı).
        expect(row.results, hasLength(2));
        if (e.key != '2001') expect(row.totalNet, e.value.$2);
      }
    });
  }

  test('xlsx: başlık satırı tablonun üstündeki başlıktan sonra bulunur', () {
    final rows = readSpreadsheet(fixture('sonuc.xlsx'))['Sonuçlar']!;
    expect(rows.first.single, 'TG TYT Deneme 9 · Sonuç Listesi');
    expect(parseSheet(rows, ExamType.tyt)!.headerRow, 2);
  });

  test('xlsx: birden çok sayfa adıyla gelir', () {
    expect(readSpreadsheet(fixture('sonuc.xlsx')).keys, ['Sonuçlar', 'Bilgi']);
  });

  test('xls: uzun paylaşılan metin tablosu (CONTINUE) eksiksiz okunur', () {
    final long = readSpreadsheet(fixture('sonuc.xls'))['Uzun']!;
    expect(long, hasLength(1500));
    expect(long.first, ['Öğrenci 0000 şçğüöı', '0']);
    expect(long[777], ['Öğrenci 0777 şçğüöı', '777']);
    expect(long.last, ['Öğrenci 1499 şçğüöı', '1499']);
  });

  test('csv: Windows-1254, noktalı virgül, tırnak içinde virgül', () {
    final rows = readSpreadsheet(fixture('sonuc_1254.csv')).values.single;
    expect(rows[3][1], 'Çağrı Işık');
    expect(rows.last, ['5000', 'Soyad, Ad', '1', '2', '3', '4']);
  });

  test('sayı hücreleri metne düzgün çevrilir', () {
    expect(formatNumber(34), '34');
    expect(formatNumber(22.5), '22.5');
    expect(formatNumber(0.1 + 0.2), '0.3');
    expect(formatNumber(12345678901), '12345678901');
  });

  group('okunamayan dosyalar ayrı sebeple bildirilir', () {
    SpreadsheetProblem problemOf(Uint8List b) {
      try {
        readSpreadsheet(b);
      } on SpreadsheetException catch (e) {
        return e.problem;
      }
      fail('hata bekleniyordu');
    }

    test('resim → tablo değil', () {
      expect(
        problemOf(fixture('resim.png')),
        SpreadsheetProblem.notSpreadsheet,
      );
    });
    test('boş dosya → boş', () {
      expect(problemOf(Uint8List(0)), SpreadsheetProblem.empty);
      expect(
        problemOf(Uint8List.fromList('\n\n ; ;\n'.codeUnits)),
        SpreadsheetProblem.empty,
      );
    });
    test('Excel olmayan zip (Word vb.) → tablo değil', () {
      final zip = Archive()
        ..addFile(ArchiveFile('word/document.xml', 5, 'hello'.codeUnits));
      expect(
        problemOf(Uint8List.fromList(ZipEncoder().encode(zip)!)),
        SpreadsheetProblem.notSpreadsheet,
      );
    });
    test('yarıda kesilmiş xlsx → bozuk', () {
      final b = fixture('sonuc.xlsx');
      expect(
        problemOf(Uint8List.sublistView(b, 0, b.length ~/ 2)),
        SpreadsheetProblem.corrupt,
      );
    });
  });

  group('başlık çeşitleri', () {
    test('optik okuyucu kısaltmaları', () {
      final rows = [
        [
          'NO',
          'ADI SOYADI',
          'TRK D',
          'TRK Y',
          'MAT D',
          'MAT Y',
          'FİZ D',
          'FİZ Y',
        ],
        ['12', 'Ali Veli', '30', '5', '20', '4', '5', '1'],
      ];
      final p = parseSheet(rows, ExamType.tyt)!;
      expect(p.mapping.mappedSubjectCount, 3);
      expect(
        buildRows(p, p.mapping).single.results.map((r) => r.code),
        containsAll(['TYT_TUR', 'TYT_MAT', 'TYT_FIZ']),
      );
    });

    test('"Doğru Sayısı" biçimi', () {
      final rows = [
        ['Öğrenci No', 'Türkçe Doğru Sayısı', 'Türkçe Yanlış Sayısı'],
        ['7', '25', '8'],
      ];
      final p = parseSheet(rows, ExamType.tyt)!;
      final r = buildRows(p, p.mapping).single.results.single;
      expect((r.code, r.correct, r.wrong), ('TYT_TUR', 25, 8));
    });
  });
}
