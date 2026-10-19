import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../notifications/presentation/notification_widgets.dart';
import '../../auth/presentation/role_gate_screen.dart';
import '../data/announcement_repository.dart';

/// Ana sayfada gösterilecek "yeni" duyuru süresi.
const _freshFor = Duration(days: 14);

/// Duyuru listesi: gelenler ve (koç / müdür için) gönderilenler.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    final canSend =
        role != null && AnnouncementAudience.forRole(role).isNotEmpty;
    final value = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Duyurular'))),
      floatingActionButton: canSend
          ? FloatingActionButton.extended(
              onPressed: () => showComposeAnnouncement(context, role),
              icon: const Icon(Icons.campaign_rounded),
              label: Text(tr('Yeni duyuru')),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(announcementsProvider.future),
        child: AsyncView(
          value: value,
          onRetry: () => ref.invalidate(announcementsProvider),
          builder: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  EmptyState(
                    title: tr('Henüz duyuru yok'),
                    message: canSend
                        ? tr(
                            'Deneme günü, tatil ya da önemli bir hatırlatma: tek seferde herkese ulaştır.',
                          )
                        : tr(
                            'Kurumun ya da koçun duyuru yapınca burada görürsün.',
                          ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => FadeSlideIn(
                delay: FadeSlideIn.stagger(i.clamp(0, 8), 40),
                child: AnnouncementTile(announcement: items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.announcement,
    this.maxLines,
  });

  final Announcement announcement;

  /// null: metnin tamamı.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final text = Theme.of(context).textTheme;
    final meta = a.sentByMe
        ? (a.recipients == null
              ? tr('Sen · {audience}', {'audience': a.audience.label})
              : tr('Sen · {audience} · {n} kişi', {
                  'audience': a.audience.label,
                  'n': a.recipients,
                }))
        : [
            ?a.senderName,
            if (a.recipients != null)
              tr('{audience} · {n} kişi', {
                'audience': a.audience.label,
                'n': a.recipients,
              }),
          ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: context.brand.secondary,
              foregroundColor: context.brand.ink,
              child: const Icon(Icons.campaign_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.body,
                    maxLines: maxLines,
                    overflow: maxLines == null ? null : TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (meta.isNotEmpty) meta,
                      NotificationTile.timeAgo(a.createdAt),
                    ].join(' · '),
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana sayfa kartı. Gönderebilenlerde (koç, müdür) her zaman "Yeni duyuru"
/// düğmesiyle görünür; diğerlerinde yalnızca son 14 günde duyuru geldiyse.
class AnnouncementsHomeCard extends ConsumerWidget {
  const AnnouncementsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) return const SizedBox.shrink();
    final canSend = AnnouncementAudience.forRole(role).isNotEmpty;
    final items = ref.watch(announcementsProvider).value ?? const [];
    final fresh = items
        .where((a) => DateTime.now().difference(a.createdAt) < _freshFor)
        .toList();
    final latest =
        (canSend ? fresh : fresh.where((a) => !a.sentByMe)).firstOrNull;
    if (!canSend && latest == null) return const SizedBox.shrink();
    final listRoute = '${RoleGateScreen.homeFor(role)}/announcements';
    return SectionCard(
      title: tr('Duyurular'),
      subtitle: canSend
          ? tr('Tek seferde öğrencilere, velilere ya da koçlara')
          : null,
      trailing: TextButton(
        onPressed: () => context.push(listRoute),
        child: Text(tr('Tümü')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest != null)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(listRoute),
              child: AnnouncementTile(announcement: latest, maxLines: 3),
            ),
          if (canSend) ...[
            if (latest != null) const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => showComposeAnnouncement(context, role),
              icon: const Icon(Icons.campaign_rounded),
              label: Text(tr('Yeni duyuru')),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showComposeAnnouncement(BuildContext context, UserRole role) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => ComposeAnnouncementSheet(role: role),
    );

class ComposeAnnouncementSheet extends ConsumerStatefulWidget {
  const ComposeAnnouncementSheet({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<ComposeAnnouncementSheet> createState() =>
      _ComposeAnnouncementSheetState();
}

class _ComposeAnnouncementSheetState
    extends ConsumerState<ComposeAnnouncementSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late AnnouncementAudience _audience = AnnouncementAudience.forRole(
    widget.role,
  ).first;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().length >= 2 && _body.text.trim().isNotEmpty;

  Future<void> _send() async {
    final ok = await confirm(
      context,
      title: tr('Duyuru gönderilsin mi?'),
      message: tr(
        '"{title}" duyurusu {audience} kitlesine bildirim olarak gidecek. Gönderdikten sonra geri alınamaz.',
        {
          'title': _title.text.trim(),
          'audience': _audience.label.toLowerCase(),
        },
      ),
      action: tr('Gönder'),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final n = await ref
          .read(announcementRepositoryProvider)
          .send(_audience, _title.text.trim(), _body.text.trim());
      ref.invalidate(announcementsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Duyuru {n} kişiye gönderildi 📣', {'n': n})),
        ),
      );
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final audiences = AnnouncementAudience.forRole(widget.role);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Yeni duyuru'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text(
              tr('Kime?'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in audiences)
                  ChoiceChip(
                    label: Text(a.label),
                    selected: a == _audience,
                    onSelected: _sending
                        ? null
                        : (_) => setState(() => _audience = a),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_audience.description, style: text.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 80,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Başlık'),
                hintText: tr('Örn. Cumartesi TYT denemesi'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLength: 600,
              minLines: 3,
              maxLines: 6,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Duyuru metni'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _valid && !_sending ? _send : null,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(tr('Gönder')),
            ),
          ],
        ),
      ),
    );
  }
}
