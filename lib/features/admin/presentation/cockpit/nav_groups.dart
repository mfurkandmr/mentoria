import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/widgets/tool_tile.dart';
import '../../../coach/presentation/invite_sheet.dart';
import '../../../exam_import/presentation/org_exams_screen.dart';
import '../../../sms/presentation/bulk_sms_screen.dart';
import 'cockpit_theme.dart';
import 'org_tools_section.dart';

/// Alt çubuktaki gruplanmış sekmelerin araçları (NOTLAR §64). Ana
/// sayfadaki "Kurum araçları" aynı [ToolInfo]'ları kullanır; burada
/// konuya göre toplanır.

/// Sınavlar: deneme yükleme, yüklenen denemeler, optik, kurum sınavları,
/// deneme trendleri (müdürde ayrıca deneme planı).
List<ToolInfo> examTools(WidgetRef ref, String basePath) => [
  ToolInfo(
    id: 'tool-import',
    icon: Icons.upload_file_outlined,
    title: tr('Deneme yükle'),
    status: tr('Deneme sonuç dosyasını yükle, öğrencilere dağıt'),
    open: (c) => c.push('$basePath/import'),
  ),
  ToolInfo(
    id: 'tool-exam-batches',
    icon: Icons.inventory_2_outlined,
    title: tr('Yüklenen denemeler'),
    status: tr('Son 7 gündeki yüklemeler silinebilir'),
    open: (c) => c.push('$basePath/exams'),
  ),
  orgExamsTool(ref, basePath),
  ToolInfo(
    id: 'tool-optic',
    icon: Icons.document_scanner_outlined,
    title: tr('Optik oku'),
    status: tr('Optik formları telefonla oku'),
    open: (c) => c.push('$basePath/optic'),
  ),
  trendsTool(basePath),
  if (basePath == '/admin')
    ToolInfo(
      id: 'tool-exam-plans',
      icon: Icons.event_note_outlined,
      title: tr('Deneme planı'),
      status: tr('Yaklaşan kurum denemelerini planla'),
      open: (c) => c.push('/admin/exam-plans'),
    ),
];

/// İletişim: müdürde velilere SMS ve duyurular; koçta duyurular ve
/// öğrenci daveti.
List<ToolInfo> messageTools(String basePath) => [
  if (basePath == '/admin') bulkSmsTool(),
  ToolInfo(
    id: 'tool-announcements',
    icon: Icons.campaign_outlined,
    title: tr('Duyurular'),
    status: tr('Toplu duyuru gönder, gelen duyuruları gör'),
    open: (c) => c.push('$basePath/announcements'),
  ),
  if (basePath == '/coach')
    ToolInfo(
      id: 'tool-invite',
      icon: Icons.person_add_alt_1_outlined,
      title: tr('Öğrenci davet et'),
      status: tr('Davet kodu oluştur ve öğrencine gönder'),
      open: openInviteSheet,
    ),
];

/// Yalnızca araçlardan oluşan sekme (Sınavlar, İletişim): kısa açıklama ve
/// kutu ızgarası. Altta gezinme çubuğu için boşluk bırakır.
class ToolGroupTab extends StatelessWidget {
  const ToolGroupTab({
    super.key,
    required this.description,
    required this.tools,
  });

  final String description;
  final List<ToolInfo> tools;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      cockpitNavHeight + 16 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text(description, style: cockpitLabel(context)),
      ),
      ToolGrid(warnColor: Tone.warn.of(context), tools: tools),
    ],
  );
}
