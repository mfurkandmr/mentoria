import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Günlük yoklama: koç kendi öğrencilerini, müdür kurumun bütün
/// öğrencilerini işaretler. "Gelmedi" işaretlenenlerin velisine SMS gider
/// (sunucuda `sms_outbox`; SMS sağlayıcısı bağlanana kadar sırada bekler).
enum AttendanceStatus {
  present('present', Icons.check_circle_rounded),
  absent('absent', Icons.cancel_rounded),
  late('late', Icons.schedule_rounded),
  excused('excused', Icons.event_busy_rounded);

  const AttendanceStatus(this.db, this.icon);

  final String db;
  final IconData icon;

  static AttendanceStatus? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }

  String get label => switch (this) {
    present => tr('Geldi'),
    absent => tr('Gelmedi'),
    late => tr('Geç geldi'),
    excused => tr('İzinli'),
  };
}

/// Yoklama listesindeki bir öğrenci ve o günkü durumu.
class AttendanceRow {
  const AttendanceRow({
    required this.studentId,
    required this.fullName,
    this.studentNumber,
    this.status,
    this.smsAt,
    this.hasPhone = false,
    this.guardianName,
    this.guardianPhone,
  });

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
    studentId: j['student_id'] as String,
    fullName: j['full_name'] as String? ?? '',
    studentNumber: j['student_number'] as String?,
    status: AttendanceStatus.fromDb(j['status'] as String?),
    smsAt: j['sms_at'] == null
        ? null
        : DateTime.parse(j['sms_at'] as String).toLocal(),
    hasPhone: j['has_phone'] as bool? ?? false,
    guardianName: j['guardian_name'] as String?,
    guardianPhone: j['guardian_phone'] as String?,
  );

  final String studentId;
  final String fullName;
  final String? studentNumber;
  final AttendanceStatus? status;

  /// "Gelmedi" SMS'i bu gün için sıraya alındı mı.
  final DateTime? smsAt;

  /// Velinin telefonu var mı (yoklama için girilen ya da kurum finansındaki;
  /// finanstaki numara koça gösterilmez).
  final bool hasPhone;

  /// Yoklama için girilen veli (yoksa null).
  final String? guardianName;
  final String? guardianPhone;
}

/// `send_absence_sms` sonucu.
class AbsenceSmsResult {
  const AbsenceSmsResult({
    required this.queued,
    required this.noPhone,
    required this.skipped,
  });

  final int queued;
  final int noPhone;
  final int skipped;
}

/// Gün özeti (ana sayfa kartı için).
class AttendanceCounts {
  const AttendanceCounts(this.rows);

  final List<AttendanceRow> rows;

  int get total => rows.length;
  int get marked => rows.where((r) => r.status != null).length;
  int count(AttendanceStatus s) => rows.where((r) => r.status == s).length;
}

String attendanceDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

abstract interface class AttendanceRepository {
  /// Yönettiğim öğrenciler ve [day] günündeki durumları (ada göre).
  Future<List<AttendanceRow>> fetchDay(DateTime day);

  /// Öğrenci → durum (null: işareti kaldır). Son 30 gün, ileri tarih yok.
  Future<void> save(DateTime day, Map<String, AttendanceStatus?> marks);

  /// Yoklama SMS'inin gideceği veli; [phone] "+905XXXXXXXXX" ya da null
  /// (null: kayıtlı numarayı sil).
  Future<void> setGuardianPhone(
    String studentId, {
    String? name,
    String? phone,
  });

  /// Öğrencinin kayıtlı velisi (ad, telefon); yoksa null.
  Future<(String?, String)?> fetchGuardian(String studentId);

  /// "Gelmedi" işaretli öğrencilerin velisine SMS (aynı gün bir kez).
  Future<AbsenceSmsResult> sendAbsenceSms(
    DateTime day,
    List<String> studentIds,
  );
}

class SupabaseAttendanceRepository implements AttendanceRepository {
  SupabaseAttendanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AttendanceRow>> fetchDay(DateTime day) async {
    final rows = await fetchAllPages(
      (from, to) => _client
          .rpc<PostgrestList>(
            'attendance_day',
            params: {'p_day': attendanceDay(day)},
          )
          .order('full_name', ascending: true)
          .order('student_id', ascending: true)
          .range(from, to),
    );
    return [
      for (final r in rows)
        AttendanceRow.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<void> save(DateTime day, Map<String, AttendanceStatus?> marks) async {
    // Sunucu tek çağrıda en çok 1000 işaret alır. Parça yarıda kalırsa
    // aynı kayıt yeniden gönderilebilir (işaretler üzerine yazılır).
    final entries = marks.entries.toList();
    for (var i = 0; i < entries.length; i += 1000) {
      await _client.rpc(
        'save_attendance',
        params: {
          'p_day': attendanceDay(day),
          'p_marks': {
            for (final e in entries.skip(i).take(1000)) e.key: e.value?.db,
          },
        },
      );
    }
  }

  @override
  Future<void> setGuardianPhone(
    String studentId, {
    String? name,
    String? phone,
  }) async {
    await _client.rpc(
      'set_guardian_phone',
      params: {'p_student': studentId, 'p_name': name, 'p_phone': phone},
    );
  }

  @override
  Future<(String?, String)?> fetchGuardian(String studentId) async {
    final r = await _client
        .from('student_guardian_phones')
        .select('guardian_name, phone')
        .eq('student_id', studentId)
        .maybeSingle();
    return r == null
        ? null
        : (r['guardian_name'] as String?, r['phone'] as String);
  }

  @override
  Future<AbsenceSmsResult> sendAbsenceSms(
    DateTime day,
    List<String> studentIds,
  ) async {
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'send_absence_sms',
            params: {'p_day': attendanceDay(day), 'p_students': studentIds},
          )
          as Map,
    );
    return AbsenceSmsResult(
      queued: r['queued'] as int? ?? 0,
      noPhone: r['no_phone'] as int? ?? 0,
      skipped: r['skipped'] as int? ?? 0,
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => SupabaseAttendanceRepository(ref.watch(supabaseClientProvider)),
);

/// Öğrenci düzenleme penceresinde veli adı / telefonu.
final guardianProvider = FutureProvider.autoDispose
    .family<(String?, String)?, String>(
      (ref, id) => ref.watch(attendanceRepositoryProvider).fetchGuardian(id),
    );

/// Gün → yoklama listesi. Anahtar gece yarısına yuvarlanmış tarih olmalı.
final attendanceDayProvider =
    FutureProvider.family<List<AttendanceRow>, DateTime>(
      (ref, day) => ref.watch(attendanceRepositoryProvider).fetchDay(day),
    );
