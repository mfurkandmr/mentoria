import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/widgets/tool_tile.dart';
import '../../../announcements/presentation/announcement_widgets.dart';
import '../../../attendance/presentation/attendance_screen.dart';
import '../../../coach/data/coach_repository.dart';
import '../../../exam_import/presentation/org_exams_screen.dart';
import '../../../finance/presentation/finance_screen.dart';
import '../../../schedule_generator/presentation/my_timetable.dart';
import '../../../sms/presentation/bulk_sms_screen.dart';
import '../../../student_books/presentation/book_pool_screen.dart';
import '../../../student_management/presentation/students_screen.dart';
import 'cockpit_theme.dart';

/// "Deneme trendleri" kısayolu (son 5 deneme; müdür ve koç).
ToolInfo trendsTool(String basePath) => ToolInfo(
  id: 'tool-trends',
  icon: Icons.show_chart,
  title: tr('Deneme trendleri'),
  status: tr('Son 5 denemede en çok yükselen ve düşenler'),
  open: (context) => context.push('$basePath/trends'),
);

/// "Okul numarası eksik" satırı (yalnızca eksik varsa).
class MissingNumbersNotice extends ConsumerWidget {
  const MissingNumbersNotice({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final noNumber = students.where((s) => s.studentNumber == null).length;
    if (noNumber == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: Tone.warn.tintOf(context),
        child: ListTile(
          key: const ValueKey('tool-missing-numbers'),
          leading: Icon(Icons.badge_outlined, color: Tone.warn.of(context)),
          title: Text(
            tr('{noNumber} öğrencinin okul numarası eksik', {
              'noNumber': noNumber,
            }),
          ),
          subtitle: Text(
            tr(
              'Deneme dosyaları numarayla eşleştirildiği için numaraları gir.',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Kurum araçları: eski paneldeki bütün modüller kompakt ızgarada (durum
/// satırları ana sayfa kartlarıyla aynı kaynaktan), altında duyurular.
/// Başarı sıralaması anahtarı kurum ayarlarında.
class OrgToolsSection extends ConsumerWidget {
  const OrgToolsSection({super.key, required this.onOpenStudents});

  /// "Okul numarası eksik" satırı Öğrenciler sekmesine geçer.
  final VoidCallback onOpenStudents;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    key: const ValueKey('section-tools'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CockpitHeading(tr('Kurum araçları')),
      MissingNumbersNotice(onTap: onOpenStudents),
      ToolGrid(
        warnColor: Tone.warn.of(context),
        tools: [
          attendanceTool(ref, '/admin'),
          financeTool(ref),
          studentsTool(ref, '/admin'),
          timetableAdminTool(ref),
          orgExamsTool(ref, '/admin'),
          trendsTool('/admin'),
          bookPoolTool(ref, '/admin'),
          bulkSmsTool(),
        ],
      ),
      const SizedBox(height: 10),
      const AnnouncementsHomeCard(),
    ],
  );
}
