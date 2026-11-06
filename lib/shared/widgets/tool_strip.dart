import 'package:flutter/material.dart';

import 'effects.dart';
import 'tool_tile.dart';

/// Gruplanmış sekmenin en üstündeki yatay araç şeridi (ör. Öğrenciler
/// sekmesinde sınıflar, yoklama, ders programı, kitap havuzu). Kutular
/// [ToolGrid] ile aynı bilgi ve durum satırı; sığmayanlar yana kayar.
class ToolStrip extends StatelessWidget {
  const ToolStrip({super.key, required this.tools, this.warnColor});

  final List<ToolInfo> tools;

  /// İş bekleyen kutunun durum rengi (verilmezse temanın hata rengi).
  final Color? warnColor;

  static const _tileWidth = 168.0;
  static const _height = 112.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = warnColor ?? theme.colorScheme.error;
    final muted = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Kartların gölgesi kesilmesin.
        clipBehavior: Clip.none,
        itemCount: tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final tool = tools[i];
          return SizedBox(
            width: _tileWidth,
            child: PressScale(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('strip-${tool.id}'),
                  onTap: () => tool.open(context),
                  child: Semantics(
                    button: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
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
                          const SizedBox(height: 8),
                          Text(
                            tool.title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Text(
                              tool.status,
                              maxLines: 2,
                              overflow: TextOverflow.fade,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tool.needsAction ? warn : muted,
                                fontWeight: tool.needsAction
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
