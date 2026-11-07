import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../data/client_error_repository.dart';

/// Süper admin: web panelinden gelen hata kayıtları (NOTLAR §66). En son
/// görülen üstte; dokununca hata yığını açılır, kopyalanır ya da çözülünce
/// listeden kaldırılır.
class ClientErrorsScreen extends ConsumerWidget {
  const ClientErrorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(clientErrorsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Hata kayıtları'))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(clientErrorsProvider.future),
        child: AsyncView(
          value: errors,
          onRetry: () => ref.invalidate(clientErrorsProvider),
          builder: (list) => list.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      title: tr('Kayıtlı hata yok'),
                      message: tr(
                        'Web panelinde bir hata olursa burada görünür; aynı hata tekrarlarsa sayacı artar.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ErrorTile(error: list[i]),
                ),
        ),
      ),
    );
  }
}

class _ErrorTile extends ConsumerWidget {
  const _ErrorTile({required this.error});

  final ClientError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    final text = Theme.of(context).textTheme;
    final when = DateFormat('d.MM.yyyy HH:mm').format(e.lastSeen.toLocal());
    final meta = [
      tr('{n} kez', {'n': e.count}),
      when,
      e.appVersion,
      if (e.urlPath != null) e.urlPath!,
      if (e.userAgent != null) e.userAgent!,
    ].join(' · ');
    return Card(
      key: ValueKey('client-error-${e.id}'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          e.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(meta, style: text.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            [e.message, if (e.stack != null) e.stack!].join('\n\n'),
            style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: '${e.message}\n${e.appVersion}\n${e.stack ?? ''}',
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(tr('Kopyala')),
              ),
              FilledButton.tonalIcon(
                key: ValueKey('client-error-delete-${e.id}'),
                onPressed: () async {
                  await ref.read(clientErrorRepositoryProvider).delete(e.id);
                  ref.invalidate(clientErrorsProvider);
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(tr('Çözüldü, kaldır')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
