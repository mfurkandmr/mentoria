import '../../../core/cache/static_cache.dart';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';

/// Tekrar aralıkları (gün): 1 → 3 → 7 → 21. Sunucudaki `review_mistake`
/// ile aynı.
const mistakeGaps = [1, 3, 7, 21];

/// Hata defterindeki bir soru.
class MistakeCard {
  const MistakeCard({
    required this.id,
    required this.studentId,
    required this.subjectCode,
    required this.dueOn,
    required this.createdAt,
    this.topicId,
    this.photoPath,
    this.note,
    this.stage = 0,
    this.fails = 0,
    this.masteredAt,
  });

  factory MistakeCard.fromJson(
    Map<String, dynamic> j,
    String Function(int subjectId) codeOf,
  ) => MistakeCard(
    id: j['id'] as String,
    studentId: j['student_id'] as String,
    subjectCode: codeOf(j['subject_id'] as int),
    topicId: j['topic_id'] as int?,
    photoPath: j['photo_path'] as String?,
    note: j['note'] as String?,
    stage: j['stage'] as int? ?? 0,
    fails: j['fails'] as int? ?? 0,
    dueOn: DateTime.parse(j['due_on'] as String),
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    masteredAt: j['mastered_at'] == null
        ? null
        : DateTime.parse(j['mastered_at'] as String).toLocal(),
  );

  final String id;
  final String studentId;
  final String subjectCode;
  final int? topicId;
  final String? photoPath;
  final String? note;

  /// 0..3: tekrar basamağı; 4: öğrenildi.
  final int stage;
  final int fails;
  final DateTime dueOn;
  final DateTime createdAt;
  final DateTime? masteredAt;

  bool get mastered => masteredAt != null;

  ExamSubject? get subject {
    try {
      return subjectByCode(subjectCode);
    } catch (_) {
      return null;
    }
  }

  /// Bugün (ya da daha önce) tekrar zamanı gelmiş mi.
  bool isDue(DateTime now) =>
      !mastered &&
      !DateTime(
        dueOn.year,
        dueOn.month,
        dueOn.day,
      ).isAfter(DateTime(now.year, now.month, now.day));

  /// Tekrar sonucu (sunucudaki `review_mistake` ile aynı kural).
  MistakeCard reviewed({required bool solved, required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    if (!solved) {
      return _copy(
        stage: 0,
        fails: fails + 1,
        dueOn: today.add(const Duration(days: 1)),
      );
    }
    if (stage >= 3) return _copy(stage: 4, masteredAt: now);
    final next = stage + 1;
    return _copy(
      stage: next,
      dueOn: today.add(Duration(days: mistakeGaps[next])),
    );
  }

  MistakeCard _copy({
    int? stage,
    int? fails,
    DateTime? dueOn,
    DateTime? masteredAt,
  }) => MistakeCard(
    id: id,
    studentId: studentId,
    subjectCode: subjectCode,
    topicId: topicId,
    photoPath: photoPath,
    note: note,
    stage: stage ?? this.stage,
    fails: fails ?? this.fails,
    dueOn: dueOn ?? this.dueOn,
    createdAt: createdAt,
    masteredAt: masteredAt ?? this.masteredAt,
  );
}

/// Yeni hata kaydı.
class MistakeDraft {
  const MistakeDraft({
    required this.subjectCode,
    this.topicId,
    this.note,
    this.photo,
    this.photoExtension = 'jpg',
  });

  final String subjectCode;
  final int? topicId;
  final String? note;
  final Uint8List? photo;
  final String photoExtension;
}

abstract interface class MistakeRepository {
  Future<List<MistakeCard>> fetchCards(String studentId);
  Future<void> addCard(String studentId, MistakeDraft draft);
  Future<MistakeCard> review(MistakeCard card, {required bool solved});
  Future<void> deleteCard(MistakeCard card);

  /// Fotoğrafın baytları (özel kova; yalnızca görme yetkisi olanlar).
  Future<Uint8List?> loadPhoto(String path);
}

class SupabaseMistakeRepository implements MistakeRepository {
  SupabaseMistakeRepository(this._client);

  final SupabaseClient _client;
  static const bucket = 'mistake-photos';

  Map<String, int>? _idByCode;
  Map<int, String>? _codeById;

  Future<void> _loadSubjects() async {
    if (_idByCode != null) return;
    final rows = await StaticCache.subjects(_client);
    _idByCode = {for (final r in rows) r['code'] as String: r['id'] as int};
    _codeById = {for (final e in _idByCode!.entries) e.value: e.key};
  }

  @override
  Future<List<MistakeCard>> fetchCards(String studentId) async {
    await _loadSubjects();
    final rows = await _client
        .from('mistake_cards')
        .select()
        .eq('student_id', studentId)
        .order('due_on')
        .order('created_at', ascending: false);
    return [
      for (final r in rows) MistakeCard.fromJson(r, (id) => _codeById![id]!),
    ];
  }

  @override
  Future<void> addCard(String studentId, MistakeDraft d) async {
    await _loadSubjects();
    String? path;
    final photo = d.photo;
    if (photo != null) {
      final ext = d.photoExtension.toLowerCase().replaceFirst('jpg', 'jpeg');
      path = '$studentId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            photo,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
    }
    try {
      await _client.from('mistake_cards').insert({
        'student_id': studentId,
        'subject_id': _idByCode![d.subjectCode],
        'topic_id': d.topicId,
        'note': (d.note?.trim().isEmpty ?? true) ? null : d.note!.trim(),
        'photo_path': path,
      });
    } catch (_) {
      // Kart kaydedilemediyse yetim fotoğraf kalmasın.
      if (path != null) await _client.storage.from(bucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<MistakeCard> review(MistakeCard card, {required bool solved}) async {
    await _loadSubjects();
    final row = await _client.rpc(
      'review_mistake',
      params: {'p_card': card.id, 'p_solved': solved},
    );
    return MistakeCard.fromJson(
      Map<String, dynamic>.from(row as Map),
      (id) => _codeById![id]!,
    );
  }

  @override
  Future<void> deleteCard(MistakeCard card) async {
    await _client.from('mistake_cards').delete().eq('id', card.id);
    final path = card.photoPath;
    if (path != null) await _client.storage.from(bucket).remove([path]);
  }

  @override
  Future<Uint8List?> loadPhoto(String path) =>
      _client.storage.from(bucket).download(path);
}

final mistakeRepositoryProvider = Provider<MistakeRepository>(
  (ref) => SupabaseMistakeRepository(ref.watch(supabaseClientProvider)),
);

final mistakeCardsProvider = FutureProvider.family<List<MistakeCard>, String>(
  (ref, studentId) =>
      ref.watch(mistakeRepositoryProvider).fetchCards(studentId),
);

final mistakePhotoProvider = FutureProvider.family<Uint8List?, String>(
  (ref, path) => ref.watch(mistakeRepositoryProvider).loadPhoto(path),
);
