import '../../../core/i18n/i18n.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../finance/data/finance_repository.dart' show formatMoney;

/// "Bekleyen işler" ekranının tek sorusu: benden ne bekleniyor?
/// Yalnızca koçun / müdürün yapması gereken işler; sayısı sıfır olan iş
/// listeye girmez.

/// Risk sinyali en fazla iki seviye.
enum PendingLevel { risk, warn }

/// İşin geldiği yer (simge, hata satırı ve testler için).
enum PendingSource {
  attendance,
  books,
  orgExams,
  deletion,
  roster,
  finance,
  org;

  /// "… bilgisi alınamadı" satırındaki ad.
  String get label => switch (this) {
    PendingSource.attendance => tr('Yoklama'),
    PendingSource.books => tr('Kitap havuzu'),
    PendingSource.orgExams => tr('Kurum sınavları'),
    PendingSource.deletion => tr('Hesap silme talepleri'),
    PendingSource.roster => tr('Öğrenci listesi'),
    PendingSource.finance => tr('Finans'),
    PendingSource.org => tr('Kurum hesabı'),
  };
}

/// Bir bekleyen iş: rakam + ne olduğu + neden önemli olduğu.
class PendingItem {
  const PendingItem({
    required this.id,
    required this.source,
    required this.level,
    required this.title,
    required this.reason,
    this.route,
    this.count,
    this.unit,
  });

  /// Test ve erişim anahtarı (ör. "pending-books").
  final String id;
  final PendingSource source;
  final PendingLevel level;

  /// Satırın başındaki rakam; yoksa simge gösterilir.
  final int? count;

  /// Rakamın altındaki birim ("gün").
  final String? unit;

  /// Rakamla birlikte okunan cümle ("kitap talebi onay bekliyor").
  final String title;

  /// Sebep cümlesi: neden şimdi yapılmalı.
  final String reason;

  /// Panelin kökünden göreli adres ("/books"); yoksa satır yalnızca
  /// bilgi verir (ör. kurum hesabı uyarıları destek ekibiyle çözülür).
  final String? route;
}

/// KVKK: silme talebi en geç bu kadar günde sonuçlanmalı.
const deletionDeadlineDays = 30;

/// Kurum düzeyindeki eşik uyarısı (kredi, lisans, hesap kapalı).
typedef PendingOrgAlert = ({PendingLevel level, String title, String message});

/// Kaynaklardan bekleyen işleri üretir: önce riskler, sonra dikkat
/// gerekenler; aynı seviyede verilen sırayla. Verisi gelmeyen kaynak
/// için `null` geçilir, o kaynaktan iş çıkmaz.
List<PendingItem> pendingItems({
  required DateTime now,
  AttendanceCounts? attendance,
  int? pendingBooks,
  int? draftExams,
  Map<String, DateTime>? deletions,
  Map<String, String> names = const {},
  int? unassigned,
  int? flagged,
  int? missingNumbers,
  int? overdueCount,
  double overdueAmount = 0,
  List<PendingOrgAlert> orgAlerts = const [],
}) {
  final out = <PendingItem>[];
  final today = DateTime(now.year, now.month, now.day);

  // Kurum hesabı (müdür): kapalı hesap, lisans, kredi.
  for (final (i, a) in orgAlerts.indexed) {
    out.add(
      PendingItem(
        id: 'pending-org-$i',
        source: PendingSource.org,
        level: a.level,
        title: a.title,
        reason: a.message,
      ),
    );
  }

  // Hesap silme talepleri: öğrenci başına bir satır, en eskisi önce.
  final requests = (deletions ?? const <String, DateTime>{}).entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final e in requests) {
    final at = DateTime(e.value.year, e.value.month, e.value.day);
    final days = today.difference(at).inDays.clamp(0, 9999);
    final left = deletionDeadlineDays - days;
    out.add(
      PendingItem(
        id: 'pending-deletion-${e.key}',
        source: PendingSource.deletion,
        level: PendingLevel.risk,
        count: days,
        unit: tr('gün'),
        title: tr('{name} hesabının silinmesini istedi', {
          'name': names[e.key] ?? tr('Bir öğrenci'),
        }),
        reason: left > 0
            ? tr(
                'KVKK gereği talep 30 gün içinde sonuçlanmalı; {n} gün kaldı.',
                {'n': left},
              )
            : tr('KVKK gereği 30 günlük cevap süresi doldu.'),
        route: '/students/${e.key}',
      ),
    );
  }

  // Geciken taksitler (müdür).
  if ((overdueCount ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-finance',
        source: PendingSource.finance,
        level: PendingLevel.risk,
        count: overdueCount,
        title: tr('taksidin vadesi geçti'),
        reason: tr('Toplam {v} henüz tahsil edilmedi.', {
          'v': formatMoney(overdueAmount),
        }),
        route: '/finance',
      ),
    );
  }

  // Bugünkü yoklama.
  if (attendance != null && attendance.total > 0) {
    final open = attendance.total - attendance.marked;
    if (open > 0) {
      out.add(
        PendingItem(
          id: 'pending-attendance',
          source: PendingSource.attendance,
          level: PendingLevel.warn,
          count: open,
          title: attendance.marked == 0
              ? tr('öğrencinin bugünkü yoklaması alınmadı')
              : tr('öğrenci bugünkü yoklamada işaretsiz'),
          reason: tr(
            'Gelmeyenlerin velisine WhatsApp mesajı ancak yoklama kaydedilince gider.',
          ),
          route: '/attendance',
        ),
      );
    }
  }

  if ((draftExams ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-org-exams',
        source: PendingSource.orgExams,
        level: PendingLevel.warn,
        count: draftExams,
        title: tr('kurum sınavının sonucu yayın bekliyor'),
        reason: tr(
          'Optikler yüklendi; yayınlanana kadar öğrenci ve veliler sonucu göremez.',
        ),
        route: '/org-exams',
      ),
    );
  }

  if ((pendingBooks ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-books',
        source: PendingSource.books,
        level: PendingLevel.warn,
        count: pendingBooks,
        title: tr('kitap talebi onay bekliyor'),
        reason: tr('Onaylanınca kitap havuza girer ve öğrenciler seçebilir.'),
        route: '/books',
      ),
    );
  }

  if ((flagged ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-flagged',
        source: PendingSource.roster,
        level: PendingLevel.warn,
        count: flagged,
        title: tr('öğrencinin okul numarası şüpheli'),
        reason: tr(
          'Deneme sonuçları numarayla eşleştiği için yanlış öğrenciye gidebilir.',
        ),
        route: '/roster',
      ),
    );
  }

  if ((missingNumbers ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-numbers',
        source: PendingSource.roster,
        level: PendingLevel.warn,
        count: missingNumbers,
        title: tr('öğrencinin okul numarası eksik'),
        reason: tr(
          'Deneme dosyaları numarayla eşleştirilir; numarasız öğrencinin sonucu eşleşmez.',
        ),
        route: '/roster',
      ),
    );
  }

  if ((unassigned ?? 0) > 0) {
    out.add(
      PendingItem(
        id: 'pending-unassigned',
        source: PendingSource.roster,
        level: PendingLevel.warn,
        count: unassigned,
        title: tr('öğrenci bir sınıfa atanmamış'),
        reason: tr(
          'Sınıfsız öğrenci sınıf listelerinde ve ders programında yer almaz.',
        ),
        route: '/roster',
      ),
    );
  }

  // Riskler önce; aynı seviyede yukarıdaki sıra korunur.
  final risk = [
    for (final i in out)
      if (i.level == PendingLevel.risk) i,
  ];
  final warn = [
    for (final i in out)
      if (i.level == PendingLevel.warn) i,
  ];
  return [...risk, ...warn];
}
