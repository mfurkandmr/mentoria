import 'package:flutter/material.dart';

import 'effects.dart';

/// Panellerdeki bir modül kısayolu (yoklama, finans, kitap havuzu...): adı,
/// simgesi, tek satır durumu ve açılış eylemi. Aynı bilgi hem eski liste
/// kartında ([ToolListCard]) hem kokpit ızgarasında ([ToolGrid]) kullanılır;
/// durum metni tek yerde hesaplanır.
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.icon,
    required this.title,
    required this.status,
    required this.open,
    this.needsAction = false,
  });

  /// Test ve erişim anahtarı (ör. "book-pool-card").
  final String id;
  final IconData icon;
  final String title;
  final String status;

  /// Bir iş bekliyor (onay, yoklama, yayın...): durum dikkat renginde.
  final bool needsAction;
  final void Function(BuildContext context) open;
}

/// Eski görünüm: kart içinde tek satırlık liste öğesi.
class ToolListCard extends StatelessWidget {
  const ToolListCard({super.key, required this.tool});

  final ToolInfo tool;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: ValueKey(tool.id),
      leading: Icon(tool.icon),
      title: Text(tool.title),
      subtitle: Text(tool.status),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => tool.open(context),
    ),
  );
}

/// Kompakt ızgara: dar ekranda 2, orta genişlikte 3, genişte 4 sütun. Aynı
/// satırdaki kutular aynı yükseklikte.
class ToolGrid extends StatelessWidget {
  const ToolGrid({super.key, required this.tools, this.warnColor});

  final List<ToolInfo> tools;

  /// İş bekleyen kutunun durum rengi (verilmezse temanın hata rengi).
  final Color? warnColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 900
          ? 4
          : c.maxWidth >= 560
          ? 3
          : 2;
      const gap = 10.0;
      return Column(
        children: [
          for (var i = 0; i < tools.length; i += cols) ...[
            if (i > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + cols; j++) ...[
                    if (j > i) const SizedBox(width: gap),
                    Expanded(
                      child: j < tools.length
                          ? _ToolTile(tool: tools[j], warnColor: warnColor)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, this.warnColor});

  final ToolInfo tool;
  final Color? warnColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final warn = warnColor ?? theme.colorScheme.error;
    return PressScale(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(tool.id),
          onTap: () => tool.open(context),
          child: Semantics(
            button: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        tool.icon,
                        size: 22,
                        color: theme.colorScheme.onSurface,
                      ),
                      const Spacer(),
                      if (tool.needsAction)
                        // Renk tek başına anlam taşımasın: nokta + metin rengi.
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: warn,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tool.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.status,
                    maxLines: 3,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tool.needsAction ? warn : muted,
                      fontWeight: tool.needsAction ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
