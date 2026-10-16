import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Koçun öğrenci listesindeki bir satır.
class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.fullName,
    required this.examCount,
    this.weekQuestions = 0,
    this.weekMinutes = 0,
    this.pendingTasks = 0,
    this.coachId,
    this.coachName,
    this.studentNumber,
    this.lastExamName,
    this.lastExamType,
    this.lastTotalNet,
    this.lastTakenOn,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> j) => StudentSummary(
    id: j['student_id'] as String,
    fullName: j['full_name'] as String,
    studentNumber: j['student_number'] as String?,
    examCount: j['exam_count'] as int,
    weekQuestions: j['week_questions'] as int? ?? 0,
    weekMinutes: j['week_minutes'] as int? ?? 0,
    pendingTasks: j['pending_tasks'] as int? ?? 0,
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    lastExamName: j['last_exam_name'] as String?,
    lastExamType: j['last_exam_type'] == null
        ? null
        : ExamType.fromDb(j['last_exam_type'] as String),
    lastTotalNet: (j['last_total_net'] as num?)?.toDouble(),
    lastTakenOn: j['last_taken_on'] == null
        ? null
        : DateTime.parse(j['last_taken_on'] as String),
  );

  final String id;
  final String fullName;
  final String? studentNumber;
  final int examCount;
  final int weekQuestions;
  final int weekMinutes;
  final int pendingTasks;
  final String? coachId;
  final String? coachName;
  final String? lastExamName;
  final ExamType? lastExamType;
  final double? lastTotalNet;
  final DateTime? lastTakenOn;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }

  /// Son 7 günde soru ya da çalışma kaydı var.
  bool get activeThisWeek => weekQuestions > 0 || weekMinutes > 0;
}

class InviteCode {
  const InviteCode({
    required this.code,
    required this.maxUses,
    required this.usedCount,
    required this.expiresAt,
  });

  factory InviteCode.fromJson(Map<String, dynamic> j) => InviteCode(
    code: j['code'] as String,
    maxUses: j['max_uses'] as int,
    usedCount: j['used_count'] as int,
    expiresAt: DateTime.parse(j['expires_at'] as String),
  );

  final String code;
  final int maxUses;
  final int usedCount;
  final DateTime expiresAt;

  int get remaining => maxUses - usedCount;
}

/// Okul numarası kaydedilemediğinde kullanıcıya gösterilecek neden.
class StudentNumberException implements Exception {
  const StudentNumberException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class CoachRepository {
  Future<List<StudentSummary>> fetchStudents();
  Future<void> setStudentNumber(String studentId, String? number);
  Future<String> createStudentInvite({int maxUses = 1});
  Future<List<InviteCode>> fetchActiveStudentInvites();

  /// Öğrencinin hesabını ve tüm verilerini kalıcı olarak siler
  /// (yalnızca öğrencinin koçu ya da kurum müdürü).
  Future<void> deleteStudent(String studentId);

  /// Öğrencilerin bekleyen hesap silme talepleri: öğrenci id → talep tarihi.
  Future<Map<String, DateTime>> fetchDeletionRequests();
}

class SupabaseCoachRepository implements CoachRepository {
  SupabaseCoachRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudentSummary>> fetchStudents() async {
    final rows = await _client.rpc('student_summaries') as List;
    return [
      for (final r in rows)
        StudentSummary.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<void> setStudentNumber(String studentId, String? number) async {
    try {
      await _client.rpc(
        'set_student_number',
        params: {'p_student': studentId, 'p_number': number},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('NUMBER_TAKEN')) {
        throw StudentNumberException(
          tr('Bu numara kurumda başka bir öğrenciye ait.'),
        );
      }
      if (e.message.contains('INVALID_NUMBER')) {
        throw StudentNumberException(
          tr(
            'Numara en fazla 20 karakter olmalı; yalnızca rakam, harf ve tire.',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<String> createStudentInvite({int maxUses = 1}) async {
    final code = await _client.rpc(
      'create_invite',
      params: {'p_target_role': 'student', 'p_max_uses': maxUses},
    );
    return code as String;
  }

  @override
  Future<void> deleteStudent(String studentId) =>
      _client.rpc('delete_student_account', params: {'p_student': studentId});

  @override
  Future<Map<String, DateTime>> fetchDeletionRequests() async {
    // RLS: yalnızca koçun / müdürün yönettiği öğrencilerin talepleri gelir.
    final rows = await _client
        .from('account_deletion_requests')
        .select('student_id, requested_at');
    return {
      for (final r in rows)
        r['student_id'] as String: DateTime.parse(
          r['requested_at'] as String,
        ).toLocal(),
    };
  }

  @override
  Future<List<InviteCode>> fetchActiveStudentInvites() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('invite_codes')
        .select('code, max_uses, used_count, expires_at')
        .eq('created_by', uid)
        .eq('target_role', 'student')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if (r['used_count'] as int < (r['max_uses'] as int))
          InviteCode.fromJson(r),
    ];
  }
}

final coachRepositoryProvider = Provider<CoachRepository>(
  (ref) => SupabaseCoachRepository(ref.watch(supabaseClientProvider)),
);

/// Koç → kendi öğrencileri, kurum müdürü → kurumdaki tüm öğrenciler.
final studentSummariesProvider = FutureProvider<List<StudentSummary>>(
  (ref) => ref.watch(coachRepositoryProvider).fetchStudents(),
);

final studentInvitesProvider = FutureProvider<List<InviteCode>>(
  (ref) => ref.watch(coachRepositoryProvider).fetchActiveStudentInvites(),
);

/// Öğrencilerin bekleyen hesap silme talepleri (öğrenci id → tarih).
final deletionRequestsProvider = FutureProvider<Map<String, DateTime>>(
  (ref) => ref.watch(coachRepositoryProvider).fetchDeletionRequests(),
);
