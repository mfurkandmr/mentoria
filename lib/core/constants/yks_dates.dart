/// YKS'nin ilk oturumu (TYT) tarihleri.
///
/// ÖSYM tarihi açıkladığında ilgili yılı güncelleyip `official: true` yap.
/// Tahminler son yılların düzenine göredir (Haziran'ın üçüncü cumartesisi;
/// 2025: 21 Haziran, 2026: 20 Haziran).
class YksDate {
  const YksDate(this.tyt, {this.official = false});

  /// TYT oturumunun başlangıcı (yerel saat).
  final DateTime tyt;

  /// false: tahmini tarih (arayüzde "tahmini" etiketi gösterilir).
  final bool official;
}

final yksDates = <int, YksDate>{
  2026: YksDate(DateTime(2026, 6, 20, 10, 15), official: true),
  2027: YksDate(DateTime(2027, 6, 19, 10, 15)),
  2028: YksDate(DateTime(2028, 6, 17, 10, 15)),
  2029: YksDate(DateTime(2029, 6, 16, 10, 15)),
};

/// Öğrencinin hedeflediği (ya da sıradaki) YKS.
/// [examYear] verilmezse bugünden sonraki ilk sınav seçilir.
({int year, YksDate date})? nextYks({int? examYear, DateTime? now}) {
  final today = now ?? DateTime.now();
  if (examYear != null && yksDates[examYear] != null) {
    final d = yksDates[examYear]!;
    if (d.tyt.isAfter(today)) return (year: examYear, date: d);
  }
  final upcoming =
      yksDates.entries.where((e) => e.value.tyt.isAfter(today)).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (upcoming.isEmpty) return null;
  return (year: upcoming.first.key, date: upcoming.first.value);
}

/// Hazırlık döneminin başlangıcı (sınavdan önceki 1 Eylül) — ilerleme halkası için.
DateTime seasonStart(DateTime exam) => DateTime(exam.year - 1, 9, 1);
