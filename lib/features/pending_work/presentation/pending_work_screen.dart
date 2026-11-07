import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/presentation/cockpit/cockpit_motion.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/org_settings_card.dart' show orgAlerts;
import '../../admin/presentation/cockpit/section_states.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../coach/data/coach_repository.dart';
import '../../credits/data/org_credits_repository.dart';
import '../../exam_import/data/exam_admin_repository.dart';
import '../../finance/data/finance_repository.dart';
import '../../student_books/data/books_repository.dart';
import '../../student_management/data/student_management_repository.dart';
import '../domain/pending_work.dart';

/// Bütün kaynaklardan derlenen bekleyen işler. [failed]: verisi
/// alınamayan kaynaklar; [loading]: henüz gelmeyen kaynak sayısı.
class PendingWork {
  const PendingWork({
    required this.items,
    required this.failed,
    required this.loading,
    required this.loaded,
  });

  final List<PendingItem> items;
  final List<PendingSource> failed;
  final int loading;

  /// Verisi gelen kaynak sayısı.
  final int loaded;

  int get urgent => items.where((i) => i.level == PendingLevel.risk).length;

  /// Hiçbir kaynak gelmedi, hâlâ bekleniyor.
  bool get isLoading => loaded == 0 && loading > 0;

  /// Hiçbir kaynak gelmedi, hepsi hata verdi.
  bool get isError => loaded == 0 && loading == 0 && failed.isNotEmpty;
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// `true`: müdür (kurum geneli + finans + kurum hesabı), `false`: koç.
final pendingWorkProvider = Provider.family<PendingWork, bool>((ref, admin) {
  final failed = <PendingSource>{};
  var loading = 0, loaded = 0;

  /// Kaynağın verisi; yoksa yükleniyor / hata olarak sayılır.
  T? take<T>(AsyncValue<T> v, PendingSource s) {
    if (v.hasValue) {
      loaded++;
      return v.value;
    }
    if (v.hasError) {
      failed.add(s);
    } else {
      loading++;
    }
    return null;
  }

  final attendance = take(
    ref.watch(attendanceDayProvider(_today())),
    PendingSource.attendance,
  );
  final books = take(ref.watch(bookPoolProvider), PendingSource.books);
  final exams = take(ref.watch(orgExamsProvider), PendingSource.orgExams);
  final deletions = take(
    ref.watch(deletionRequestsProvider),
    PendingSource.deletion,
  );
  final summaries = take(
    ref.watch(studentSummariesProvider),
    PendingSource.roster,
  );
  final managed = take(
    ref.watch(managedStudentsProvider),
    PendingSource.roster,
  );

  MonthSummary? money;
  final alerts = <PendingOrgAlert>[];
  if (admin) {
    final fees = take(ref.watch(financeFeesProvider), PendingSource.finance);
    final expenses = take(
      ref.watch(financeExpensesProvider),
      PendingSource.finance,
    );
    if (fees != null && expenses != null) {
      final today = _today();
      money = monthSummary(
        fees,
        expenses,
        DateTime(today.year, today.month),
        today: today,
      );
    }
    final org = take(ref.watch(orgProvider), PendingSource.org);
    final credits = take(ref.watch(orgCreditsProvider), PendingSource.org);
    if (org != null || credits != null) {
      for (final a in orgAlerts(
        org: org,
        credits: credits,
        students: summaries?.length ?? 0,
      )) {
        alerts.add((
          level: a.tone == Tone.risk ? PendingLevel.risk : PendingLevel.warn,
          title: a.title,
          message: a.message,
        ));
      }
    }
  }

  final items = pendingItems(
    now: DateTime.now(),
    attendance: attendance == null ? null : AttendanceCounts(attendance),
    pendingBooks: books?.where((b) => b.status == PoolStatus.pending).length,
    draftExams: exams?.where((e) => e.isDraft && e.sheetCount > 0).length,
    deletions: deletions,
    names: {for (final s in summaries ?? const []) s.id: s.fullName},
    unassigned: managed?.where((s) => !s.hasClass).length,
    flagged: managed?.where((s) => s.flag != null).length,
    missingNumbers: summaries?.where((s) => s.studentNumber == null).length,
    overdueCount: money?.overdueCount,
    overdueAmount: money?.overdueAmount ?? 0,
    orgAlerts: alerts,
  );
  return PendingWork(
    items: items,
    failed: failed.toList(),
    loading: loading,
    loaded: loaded,
  );
});

/// Bütün kaynakları yeniden yükler.
void refreshPendingWork(WidgetRef ref, {required bool admin}) {
  ref.invalidate(attendanceDayProvider(_today()));
  ref.invalidate(bookPoolProvider);
  ref.invalidate(orgExamsProvider);
  ref.invalidate(deletionRequestsProvider);
  ref.invalidate(studentSummariesProvider);
  ref.invalidate(managedStudentsProvider);
  if (admin) {
    ref.invalidate(financeFeesProvider);
    ref.invalidate(financeExpensesProvider);
    ref.invalidate(orgProvider);
    ref.invalidate(orgCreditsProvider);
  }
}

/// Kokpit üst çubuğundaki giriş: bekleyen iş sayısı rozetle. Acil iş varsa
/// rozet risk renginde, yoksa vurgu renginde; iş yoksa rozet görünmez.
class PendingWorkButton extends ConsumerWidget {
  const PendingWorkButton({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(pendingWorkProvider(basePath == '/admin'));
    final n = w.items.length;
    final scheme = Theme.of(context).colorScheme;
    final urgent = w.urgent > 0;
    return IconButton(
      key: const ValueKey('pending-button'),
      tooltip: n == 0
          ? tr('Bekleyen işler')
          : tr('Bekleyen işler: {n}', {'n': n}),
      onPressed: () => context.push('$basePath/pending'),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        backgroundColor: urgent ? Tone.risk.of(context) : scheme.primary,
        textColor: urgent ? Colors.white : scheme.onPrimary,
        child: const Icon(Icons.inbox_outlined),
      ),
    );
  }
}

/// Bekleyen işler: "benden ne bekleniyor?" Koç kendi öğrencilerini, müdür
/// bütün kurumu (finans ve kurum hesabı dahil) görür.
class PendingWorkScreen extends ConsumerStatefulWidget {
  const PendingWorkScreen({super.key, this.basePath = '/admin'});

  final String basePath;

  @override
  ConsumerState<PendingWorkScreen> createState() => _PendingWorkScreenState();
}

/// İlk görünen satır sayısı; fazlası "Tümünü gör" ile açılır.
const pendingPreviewCount = 5;

/// Bu genişlikten itibaren özet kutuları ve filtre tek satırda.
const _wideBreakpoint = 720.0;

/// İçeriğin en fazla genişliği (tablet / web'de ortalanır).
const _maxContentWidth = 840.0;

class _PendingWorkScreenState extends ConsumerState<PendingWorkScreen> {
  bool _urgentOnly = false;
  bool _expanded = false;

  bool get _admin => widget.basePath == '/admin';

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(pendingWorkProvider(_admin));
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bekleyen işler'))),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshPendingWork(ref, admin: _admin);
          await ref.read(studentSummariesProvider.future).catchError((_) {
            return const <StudentSummary>[];
          });
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= _wideBreakpoint;
            return ListView(
              key: const ValueKey('pending-scroll'),
              physics: cockpitScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: _body(context, w, wide),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PendingWork w, bool wide) {
    if (w.isLoading) return const _Loading();
    if (w.isError) {
      return Card(
        key: const ValueKey('pending-error'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SectionError(
            message: tr(
              'Bekleyen işler yüklenemedi. Bağlantını kontrol edip tekrar dene.',
            ),
            onRetry: () => refreshPendingWork(ref, admin: _admin),
          ),
        ),
      );
    }

    final filter = SlidingSegments<bool>(
      value: _urgentOnly,
      onChanged: (v) => setState(() {
        _urgentOnly = v;
        _expanded = false;
      }),
      segments: {
        false: (
          key: const ValueKey('pending-filter-all'),
          label: tr('Tümü'),
          count: '${w.items.length}',
        ),
        true: (
          key: const ValueKey('pending-filter-urgent'),
          label: tr('Acil'),
          count: '${w.urgent}',
        ),
      },
    );
    final summary = [
      Expanded(
        child: _SummaryBox(
          key: const ValueKey('pending-summary-urgent'),
          label: tr('Acil'),
          value: w.urgent,
          tone: w.urgent > 0 ? Tone.risk : null,
          caption: w.urgent > 0
              ? tr('Süre ya da para söz konusu; önce bunlar')
              : tr('Süre ya da para bekleyen iş yok'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _SummaryBox(
          key: const ValueKey('pending-summary-all'),
          label: tr('Bekleyen'),
          value: w.items.length,
          caption: w.items.isEmpty
              ? tr('Yapılacak iş kalmadı')
              : tr('Hepsi aşağıda, önce acil olanlar'),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ...summary,
              const SizedBox(width: 16),
              SizedBox(width: 260, child: filter),
            ],
          )
        else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: summary,
            ),
          ),
          const SizedBox(height: 14),
          filter,
        ],
        const SizedBox(height: 14),
        _list(context, w),
      ],
    );
  }

  Widget _list(BuildContext context, PendingWork w) {
    final shown = _urgentOnly
        ? [
            for (final i in w.items)
              if (i.level == PendingLevel.risk) i,
          ]
        : w.items;

    // Boş: hiç bekleyen iş yok ve bütün kaynaklar geldi.
    if (w.items.isEmpty && w.failed.isEmpty && w.loading == 0) {
      return _Message(
        key: const ValueKey('pending-empty'),
        icon: Icons.inbox_outlined,
        title: tr('Bekleyen işin yok, her şey güncel.'),
        message: tr(
          'Yeni bir iş çıkınca burada ve üst çubuktaki rozette görünür.',
        ),
      );
    }

    // Filtre boş: acil iş yok ama başka bekleyen var.
    if (_urgentOnly && shown.isEmpty) {
      return _Message(
        key: const ValueKey('pending-filter-empty'),
        icon: Icons.filter_alt_off_outlined,
        title: tr('Acil iş yok.'),
        message: tr('Diğer {n} bekleyen iş Tümü sekmesinde.', {
          'n': w.items.length,
        }),
        action: TextButton(
          onPressed: () => setState(() => _urgentOnly = false),
          child: Text(tr('Tümünü göster')),
        ),
      );
    }

    final visible = _expanded || shown.length <= pendingPreviewCount
        ? shown
        : shown.take(pendingPreviewCount).toList();
    final rows = <Widget>[
      for (final i in visible) _PendingRow(item: i, basePath: widget.basePath),
      // Kısmi hata: gelmeyen kaynak listede ayrı satır (filtrede de).
      if (!_urgentOnly)
        for (final s in w.failed)
          _FailedRow(
            source: s,
            onRetry: () => refreshPendingWork(ref, admin: _admin),
          ),
    ];

    return Card(
      key: const ValueKey('pending-list'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kısmi yükleme: bazı kaynaklar henüz gelmedi.
          if (w.loading > 0) const LinearProgressIndicator(minHeight: 2),
          if (shown.isEmpty && w.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                tr('Gelen kaynaklarda bekleyen iş yok.'),
                style: cockpitLabel(context),
              ),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            rows[i],
          ],
          if (visible.length < shown.length) ...[
            const Divider(height: 1),
            TextButton(
              key: const ValueKey('pending-show-all'),
              onPressed: () => setState(() => _expanded = true),
              child: Text(tr('Tümünü gör ({n})', {'n': shown.length})),
            ),
          ],
        ],
      ),
    );
  }
}

/// Özet kutusu: gölgesiz, ince çerçeveli; rakam ve açıklama cümlesi.
class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.tone,
  });

  final String label;
  final int value;
  final String caption;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.cockpit;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: cockpitLabel(context)),
            const SizedBox(height: 4),
            AnimatedCount(
              value: value,
              format: (v) => '$v',
              style: cockpitNumber(context)?.copyWith(color: tone?.of(context)),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sık satır: solda 3 px risk şeridi, rakam (+ birim), ne olduğu ve sebep.
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item, required this.basePath});

  final PendingItem item;
  final String basePath;

  static IconData _icon(PendingSource s) => switch (s) {
    PendingSource.attendance => Icons.how_to_reg_outlined,
    PendingSource.books => Icons.local_library_outlined,
    PendingSource.orgExams => Icons.fact_check_outlined,
    PendingSource.deletion => Icons.person_remove_outlined,
    PendingSource.roster => Icons.badge_outlined,
    PendingSource.finance => Icons.account_balance_wallet_outlined,
    PendingSource.org => Icons.apartment_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.cockpit;
    final tone = item.level == PendingLevel.risk ? Tone.risk : Tone.warn;
    final route = item.route;
    final number = item.count;
    return Semantics(
      button: route != null,
      child: InkWell(
        key: ValueKey(item.id),
        onTap: route == null ? null : () => context.push('$basePath$route'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Renk tek başına anlam taşımasın: acil satırların sebebi
              // de metinde yazar.
              Container(width: 3, color: tone.of(context)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    13,
                    10,
                    route == null ? 16 : 6,
                    10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: number == null
                            ? Icon(_icon(item.source), color: tone.of(context))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$number',
                                    style: text.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      color: tone.of(context),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  if (item.unit != null)
                                    Text(
                                      item.unit!,
                                      style: text.labelSmall?.copyWith(
                                        color: c.muted,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              style: text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.reason,
                              style: text.bodySmall?.copyWith(color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      if (route != null)
                        Icon(Icons.chevron_right, color: c.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verisi alınamayan kaynak: listenin geri kalanı görünür, bu satır
/// eksik olanı söyler.
class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.source, required this.onRetry});

  final PendingSource source;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.cockpit;
    return Padding(
      key: ValueKey('pending-failed-${source.name}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Icon(Icons.cloud_off_outlined, color: c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('{source} bilgisi alınamadı', {'source': source.label}),
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  tr('Buradaki bekleyen işler listede eksik olabilir.'),
                  style: text.bodySmall?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(tr('Tekrar dene'))),
        ],
      ),
    );
  }
}

/// Boş ve filtre-boş hali: simge, başlık, açıklama, isteğe bağlı eylem.
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.cockpit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: c.muted),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.muted),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// Yükleniyor: özet kutuları ve satırların yerini tutan gri kutular.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final c = context.cockpit;
    Widget box() => Expanded(
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
      ),
    );
    return Column(
      key: const ValueKey('pending-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [box(), const SizedBox(width: 10), box()]),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SectionSkeleton(rows: 4, rowHeight: 36),
          ),
        ),
      ],
    );
  }
}
