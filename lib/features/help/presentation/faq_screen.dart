import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../core/branding/branding_providers.dart';
import '../../auth/data/profile.dart';
import '../data/faq.dart';

/// Profildeki giriş: rolün sıkça sorulan sorularını açar.
class FaqCard extends StatelessWidget {
  const FaqCard({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: context.brand.primary.withValues(alpha: 0.18),
        foregroundColor: context.brand.ink,
        child: const Icon(Icons.help_outline_rounded),
      ),
      title: Text(
        tr('Sıkça sorulan sorular'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(_panelName(role)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => FaqScreen(role: role))),
    ),
  );
}

String _panelName(UserRole role) => switch (role) {
  UserRole.student => tr('Öğrenci paneli hakkında'),
  UserRole.coach => tr('Koç paneli hakkında'),
  UserRole.admin => tr('Kurum müdürü paneli hakkında'),
  UserRole.parent => tr('Veli paneli hakkında'),
};

/// Rolün sıkça sorulan soruları; aranabilir.
class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final superAdmin = ref.watch(isSuperAdminProvider).value == true;
    final q = _fold(_query.trim());
    final sections = [
      for (final s in faqFor(widget.role, superAdmin: superAdmin))
        FaqSection(s.title, s.icon, [
          for (final i in s.items)
            if (q.isEmpty ||
                _fold(i.question).contains(q) ||
                _fold(i.answer).contains(q))
              i,
        ]),
    ].where((s) => s.items.isNotEmpty).toList();
    final brand = context.brand;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sıkça sorulan sorular'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            _panelName(widget.role),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('Soru ara'),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('Temizle'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                title: tr('Sonuç yok'),
                message: tr('Başka bir kelimeyle aramayı dene.'),
                bizzSize: 90,
              ),
            ),
          for (final s in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
              child: Row(
                children: [
                  Icon(s.icon, size: 20, color: brand.primaryDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (n, i) in s.items.indexed) ...[
                    if (n > 0) const Divider(height: 1),
                    ExpansionTile(
                      key: PageStorageKey('${s.title}/${i.question}'),
                      initiallyExpanded: q.isNotEmpty,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        i.question,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Text(i.answer, style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            switch (widget.role) {
              UserRole.student => tr(
                'Sorunun cevabını bulamadın mı? Koçuna sorabilirsin.',
              ),
              UserRole.coach => tr(
                'Sorunun cevabını bulamadın mı? Kurum müdürüne ulaşabilirsin.',
              ),
              UserRole.admin => tr(
                'Sorunun cevabını bulamadın mı? Platform yöneticisine ulaşabilirsin.',
              ),
              UserRole.parent => tr(
                'Sorunun cevabını bulamadın mı? Çocuğunun dershanesine ulaşabilirsin.',
              ),
            },
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
