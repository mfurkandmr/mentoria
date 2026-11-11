import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/panel.dart';
import '../data/tutoring_repository.dart';

/// "Bugün", "Yarın" ya da "13 Kasım Perşembe".
String tutoringDateLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return tr('Bugün');
  if (diff == 1) return tr('Yarın');
  return DateFormat('d MMMM EEEE', localeTag).format(d);
}

IconData tutoringIcon(TutoringKind k) => switch (k) {
  TutoringKind.questionSolving => Icons.quiz_outlined,
  TutoringKind.privateLesson => Icons.person_outline,
  TutoringKind.etut => Icons.groups_outlined,
};

/// Talep durumunun rozeti.
class TutoringStatusPill extends StatelessWidget {
  const TutoringStatusPill(this.status, {super.key});

  final TutoringStatus status;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final (icon, color) = switch (status) {
      TutoringStatus.pending => (Icons.hourglass_top_rounded, b.secondary),
      TutoringStatus.approved => (Icons.check_circle_outline, b.success),
      TutoringStatus.rejected => (Icons.cancel_outlined, b.danger),
      TutoringStatus.cancelled => (Icons.block_outlined, b.ink),
    };
    return InfoPill(icon: icon, text: status.label, color: color);
  }
}

/// Bir talep satırı: tarih · saat · ders, öğretmen ya da öğrenci, konu.
class TutoringRequestTile extends StatelessWidget {
  const TutoringRequestTile({
    super.key,
    required this.request,
    this.showStudent = false,
    this.showTeacher = true,
    this.trailing,
  });

  final TutoringRequest request;
  final bool showStudent;
  final bool showTeacher;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(tutoringIcon(r.kind)),
      title: Text(
        [
          if (showStudent) r.studentName ?? '',
          '${tutoringDateLabel(r.date)} ${r.timeLabel}',
        ].where((s) => s.isNotEmpty).join(' · '),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          [r.kind.label, ?r.branch].join(' · '),
          if (showTeacher && r.teacherName != null) r.teacherName!,
          if (showStudent && r.className != null) r.className!,
          if (r.topic != null) tr('Konu: {t}', {'t': r.topic!}),
          if (r.status == TutoringStatus.rejected && r.rejectReason != null)
            tr('Gerekçe: {t}', {'t': r.rejectReason!}),
        ].join('\n'),
      ),
      isThreeLine: r.topic != null || showStudent,
      trailing: trailing ?? TutoringStatusPill(r.status),
    );
  }
}
