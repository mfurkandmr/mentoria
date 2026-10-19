import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';

/// Duyurunun hedef kitlesi. İlk dördünü kurum müdürü, son ikisini koç seçer.
enum AnnouncementAudience {
  everyone('everyone'),
  students('students'),
  parents('parents'),
  coaches('coaches'),
  myStudents('my_students'),
  myParents('my_parents');

  const AnnouncementAudience(this.db);
  final String db;

  static AnnouncementAudience? tryDb(String? v) =>
      values.where((a) => a.db == v).firstOrNull;

  String get label => switch (this) {
    everyone => tr('Herkes'),
    students => tr('Öğrenciler'),
    parents => tr('Veliler'),
    coaches => tr('Koçlar'),
    myStudents => tr('Öğrencilerim'),
    myParents => tr('Öğrencilerimin velileri'),
  };

  /// "Kurumdaki tüm öğrenci, veli ve koçlar"
  String get description => switch (this) {
    everyone => tr('Kurumdaki tüm öğrenci, veli ve koçlar'),
    students => tr('Kurumdaki tüm öğrenciler'),
    parents => tr('Kurumdaki öğrencilerin velileri'),
    coaches => tr('Kurumdaki tüm koçlar'),
    myStudents => tr('Koçu olduğun öğrenciler'),
    myParents => tr('Koçu olduğun öğrencilerin velileri'),
  };

  /// Role göre seçilebilen kitleler.
  static List<AnnouncementAudience> forRole(UserRole role) => switch (role) {
    UserRole.admin => const [everyone, students, parents, coaches],
    UserRole.coach => const [myStudents, myParents],
    _ => const [],
  };
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    this.senderName,
    this.sentByMe = false,
    this.recipients,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    audience:
        AnnouncementAudience.tryDb(j['audience'] as String?) ??
        AnnouncementAudience.everyone,
    senderName: j['sender_name'] as String?,
    sentByMe: j['sent_by_me'] as bool? ?? false,
    recipients: j['recipients'] as int?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );

  final String id;
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final String? senderName;
  final bool sentByMe;

  /// Yalnızca gönderene ve kurum müdürüne.
  final int? recipients;
  final DateTime createdAt;
}

/// Gönderim sırasında sunucunun verdiği hatalar.
enum AnnouncementError { invalid, limit, noRecipients, notAllowed, unknown }

class AnnouncementException implements Exception {
  const AnnouncementException(this.error);
  final AnnouncementError error;

  String get message => switch (error) {
    AnnouncementError.invalid => tr(
      'Başlık 2-80, metin 1-600 karakter olmalı.',
    ),
    AnnouncementError.limit => tr(
      '24 saatte en fazla 10 duyuru gönderebilirsin.',
    ),
    AnnouncementError.noRecipients => tr(
      'Bu kitlede henüz kimse yok, duyuru gönderilmedi.',
    ),
    AnnouncementError.notAllowed => tr('Bu duyuruyu gönderme yetkin yok.'),
    AnnouncementError.unknown => tr('Duyuru gönderilemedi.'),
  };

  static AnnouncementException from(Object e) {
    final s = e.toString();
    if (s.contains('ANNOUNCE_INVALID')) {
      return const AnnouncementException(AnnouncementError.invalid);
    }
    if (s.contains('ANNOUNCE_LIMIT')) {
      return const AnnouncementException(AnnouncementError.limit);
    }
    if (s.contains('ANNOUNCE_NO_RECIPIENTS')) {
      return const AnnouncementException(AnnouncementError.noRecipients);
    }
    if (s.contains('NOT_ALLOWED')) {
      return const AnnouncementException(AnnouncementError.notAllowed);
    }
    return const AnnouncementException(AnnouncementError.unknown);
  }
}

abstract interface class AnnouncementRepository {
  /// Bana gelenler ve gönderdiklerim (müdür: kurumdaki tüm gönderilenler).
  Future<List<Announcement>> fetch();

  /// Gönderir; alıcı sayısını döner. Hata: [AnnouncementException].
  Future<int> send(AnnouncementAudience audience, String title, String body);
}

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  SupabaseAnnouncementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Announcement>> fetch() async {
    final rows = await _client.rpc('my_announcements') as List;
    return [
      for (final r in rows) Announcement.fromJson(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<int> send(
    AnnouncementAudience audience,
    String title,
    String body,
  ) async {
    try {
      return await _client.rpc(
            'send_announcement',
            params: {
              'p_audience': audience.db,
              'p_title': title,
              'p_body': body,
            },
          )
          as int;
    } catch (e) {
      throw AnnouncementException.from(e);
    }
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => SupabaseAnnouncementRepository(ref.watch(supabaseClientProvider)),
);

final announcementsProvider = FutureProvider.autoDispose<List<Announcement>>(
  (ref) => ref.watch(announcementRepositoryProvider).fetch(),
);
