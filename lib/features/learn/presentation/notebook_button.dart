import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../mistakes/data/mistake_repository.dart';
import '../data/practice_repository.dart';

/// Hata defteri kartının notu: soru, doğru cevap ve kısa çözüm (en çok 500
/// karakter; sunucudaki sınır).
String notebookNote(PracticeQuestion q) {
  final text =
      '${q.text}\n'
      '${tr('Doğru cevap')}: ${'ABCDE'[q.answer]}) ${q.options[q.answer]}\n'
      '${q.explanation}';
  return text.length <= 500 ? text : '${text.substring(0, 497)}...';
}

/// Yanlış yapılan soruyu tek dokunuşla Hata Defteri'ne ekler; soru 1, 3, 7
/// ve 21 gün sonra yeniden sorulur.
class AddToNotebookButton extends ConsumerStatefulWidget {
  const AddToNotebookButton({
    super.key,
    required this.studentId,
    required this.question,
  });

  final String studentId;
  final PracticeQuestion question;

  @override
  ConsumerState<AddToNotebookButton> createState() =>
      _AddToNotebookButtonState();
}

class _AddToNotebookButtonState extends ConsumerState<AddToNotebookButton> {
  bool _saving = false;
  bool _added = false;

  Future<void> _add() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(mistakeRepositoryProvider)
          .addCard(
            widget.studentId,
            MistakeDraft(
              subjectCode: widget.question.subject,
              note: notebookNote(widget.question),
            ),
          );
      ref.invalidate(mistakeCardsProvider(widget.studentId));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _added = true);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_added) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.bookmark_added_rounded),
        label: Text(tr('Deftere eklendi · yarın yeniden sorulacak')),
      );
    }
    return OutlinedButton.icon(
      onPressed: _saving ? null : _add,
      icon: const Icon(Icons.bookmark_add_rounded),
      label: Text(tr('Hata Defteri\'ne ekle')),
    );
  }
}
