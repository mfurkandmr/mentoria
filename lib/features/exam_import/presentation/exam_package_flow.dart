import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../data/exam_admin_repository.dart';
import '../domain/exam_definition.dart';
import '../domain/exam_package.dart';
import 'import_wizard_screen.dart';
import '../../../core/design/motion.dart';

/// Paket hatası → kullanıcı metni.
String examPackageProblemText(ExamPackageProblem p) => switch (p.kind) {
  ExamPackageProblemKind.unsupportedType => tr(
    'Sınav türü anlaşılmadı: "{d}". Sınav adında TYT, AYT ya da YDT geçmeli.',
    {'d': p.detail},
  ),
  ExamPackageProblemKind.sections => tr(
    'Bölüm listesi ders sırasıyla uyuşmuyor: {d}',
    {'d': p.detail},
  ),
  ExamPackageProblemKind.keyLength => tr(
    'Cevap anahtarı soru sayısını tutmuyor: {d}',
    {'d': p.detail},
  ),
  ExamPackageProblemKind.answerConflict => tr(
    'Kazanım tablosundaki cevap anahtarla çelişiyor (soru {d}).',
    {'d': p.detail},
  ),
  ExamPackageProblemKind.bookletMap => tr(
    'B kitapçığının soru yerleri eksik ya da tekrarlı.',
  ),
  ExamPackageProblemKind.bookletConflict => tr(
    'B anahtarı A ile çelişiyor (soru {d}).',
    {'d': p.detail},
  ),
  ExamPackageProblemKind.opticLine => tr(
    'Optik çıktısının {d}. satırı okunamadı.',
    {'d': p.detail},
  ),
};

/// Otomatik kitapçık kararlarını kullanıcıya anlatır.
List<String> guessedBookletNotes(OpticImportRows r) => [
  for (final g in r.guessedBooklets)
    tr(
      '{n} ({no}): kitapçık boştu. {b} sayıldı; {b} anahtarıyla {c} doğru, öbürüyle {o} doğru.',
      {'n': g.$2, 'no': g.$1, 'b': g.$3, 'c': g.$4, 'o': g.$5},
    ),
];

Future<void> _showProblems(BuildContext context, List<String> problems) =>
    showDialog<void>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => AlertDialog(
        title: Text(tr('Dosyalar kullanılamadı')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in problems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(p),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Tamam')),
          ),
        ],
      ),
    );

/// Dosyaları içeriklerine göre tanır, sınavı taslak olarak kurar ve optik
/// çıktısı da seçildiyse doğrulama raporuna geçer.
Future<void> createExamFromFiles(
  BuildContext context,
  WidgetRef ref,
  String basePath,
) async {
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  // Üç dosya birlikte seçilir (seçici çoklu seçime izin verir).
  final files = await FilePicker.pickFiles(type: FileType.any);
  if (files.isEmpty || !context.mounted) return;

  String? keyText;
  SheetRows? table;
  String? opticText;
  String opticName = 'optik.txt';
  for (final f in files) {
    final bytes = Uint8List.fromList(await f.readAsBytes());
    final text = decodeText(bytes);
    if (looksLikeAnswerKey(text)) {
      keyText = text;
    } else if (looksLikeFixedWidthOptic(text)) {
      opticText = text;
      opticName = f.name;
    } else {
      try {
        final rows = (await readSpreadsheetInBackground(bytes)).values.first;
        if (looksLikeOutcomeTable(rows)) table = rows;
      } catch (_) {
        // Tanınmayan dosya: aşağıda eksik diye bildirilir.
      }
    }
  }
  if (!context.mounted) return;
  if (keyText == null || table == null) {
    await _showProblems(context, [
      if (keyText == null)
        tr('Cevap anahtarı dosyası bulunamadı ("A KITAPÇIĞI" satırı olmalı).'),
      if (table == null)
        tr('Kazanım tablosu bulunamadı ("soru_no" başlığı olmalı).'),
    ]);
    return;
  }

  final ExamPackage package;
  List<OpticLine>? lines;
  try {
    package = buildExamPackage(
      parseAnswerKey(keyText),
      parseOutcomeTable(table),
    );
    if (opticText != null) {
      final total = package.exam.subjects.fold<int>(
        0,
        (s, x) => s + x.questionCount,
      );
      lines = parseFixedWidthOptic(opticText, total);
    }
  } on ExamPackageException catch (e) {
    await _showProblems(context, [
      for (final p in e.problems) examPackageProblemText(p),
    ]);
    return;
  }

  final repo = ref.read(examAdminRepositoryProvider);
  final String id;
  ExamDefinition exam;
  try {
    // Kazanımlar havuza eklenir (aynısı varsa atlanır), sorulara bağlanır.
    final seen = <(String, String)>{};
    await repo.importOutcomes([
      for (final q in package.exam.questions)
        if (q.outcome != null && seen.add((q.subject, foldTr(q.outcome!))))
          OutcomeImportRow(subject: q.subject, topic: q.outcome!),
    ]);
    exam = linkOutcomes(package.exam, await repo.fetchOutcomes());
    id = await repo.saveExam(exam);
    exam = exam.copyWith(id: id);
    ref.invalidate(learningOutcomesProvider);
    ref.invalidate(orgExamsProvider);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Sınav kaydedilemedi. Tekrar dene.'));
    }
    return;
  }

  if (lines != null) {
    final import = opticRowsFor(lines, exam, package.bookletOrders);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ImportWizardScreen(
          examId: id,
          rows: import.rows,
          template: import.template,
          fileName: opticName,
          notes: guessedBookletNotes(import),
        ),
      ),
    );
    ref.invalidate(orgExamsProvider);
    ref.invalidate(orgExamProvider(id));
  }
  router.push('$basePath/org-exams/$id');
}
