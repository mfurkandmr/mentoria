import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';
import '../../learn/data/practice_repository.dart';
import '../../../core/constants/exam_subjects.dart';

enum NotificationKind {
  assignment(Icons.assignment_rounded),
  exam(Icons.insights_rounded),
  task(Icons.flag_rounded),
  note(Icons.sticky_note_2_rounded),

  /// Koça / kurum müdürüne: öğrenci hesabının silinmesini istedi.
  deletionRequest(Icons.person_remove_outlined, 'deletion_request'),

  /// Öğrenciye: koçuyla görüşmesine 24 saatten az kaldı.
  meeting(Icons.event_rounded),

  /// Öğrenciye: hata defterinde bugün tekrarı gelen sorular.
  review(Icons.replay_circle_filled_rounded),

  /// Veliye: çocuğunun haftalık özeti.
  weeklyReport(Icons.auto_awesome_rounded, 'weekly_report'),

  /// Öğrenciye: sabah 09.00'da Günün Sorusu.
  dailyQuestion(Icons.wb_sunny_rounded, 'daily_question'),

  /// Öğrenciye: bir arkadaşı düelloya çağırdı.
  duel(Icons.sports_kabaddi_rounded),

  /// Öğrenciye: düello sonuçlandı.
  duelResult(Icons.emoji_events_rounded, 'duel_result'),

  /// Öğrenciye: koçu haftalık planı hazırladı.
  plan(Icons.event_note_rounded);

  const NotificationKind(this.icon, [this._db]);
  final IconData icon;
  final String? _db;

  String get db => _db ?? name;

  /// Tanınmayan tür (daha yeni sunucu) için null.
  static NotificationKind? tryDb(String v) =>
      NotificationKind.values.where((k) => k.db == v).firstOrNull;
}

/// Uygulama içi bildirim. Metin, kullanıcının diline göre burada üretilir.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.data = const {},
    this.refId,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: NotificationKind.tryDb(j['kind'] as String)!,
    data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    refId: j['ref_id'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    readAt: j['read_at'] == null
        ? null
        : DateTime.parse(j['read_at'] as String).toLocal(),
  );

  final String id;
  final NotificationKind kind;
  final Map<String, dynamic> data;
  final String? refId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  String get title => switch (kind) {
    NotificationKind.assignment => tr('Yeni ödev: {title}', {
      'title': data['title'] ?? '',
    }),
    NotificationKind.exam => tr('Deneme sonucun geldi'),
    NotificationKind.task => tr('Yeni görev'),
    NotificationKind.note => tr('Koçundan yeni not'),
    NotificationKind.deletionRequest => tr('Hesap silme talebi'),
    NotificationKind.meeting => tr('Görüşme hatırlatması'),
    NotificationKind.review => tr('Tekrar zamanı! 🔁'),
    NotificationKind.weeklyReport => tr('{child} için haftalık Bal Raporu 🐝', {
      'child': data['child'] ?? '',
    }),
    NotificationKind.dailyQuestion => tr('Günün Sorusu hazır ☀️'),
    NotificationKind.duel => tr('{from} seni düelloya çağırdı ⚔️', {
      'from': data['from'] ?? '',
    }),
    NotificationKind.duelResult => switch (data['result']) {
      'won' => tr('Düelloyu kazandın! 🏆'),
      'lost' => tr('Düello sonucu: {name} kazandı', {
        'name': data['opponent'] ?? '',
      }),
      _ => tr('Düello berabere bitti 🤝'),
    },
    NotificationKind.plan => tr('Haftalık planın hazır 📅'),
  };

  String get body => switch (kind) {
    NotificationKind.assignment =>
      data['from'] == null
          ? tr('{n} maddelik yeni bir ödevin var', {'n': data['items']})
          : tr('{from} sana {n} maddelik ödev gönderdi', {
              'from': data['from'],
              'n': data['items'],
            }),
    NotificationKind.exam => [
      '${data['name'] ?? ''}',
      if (data['type'] != null)
        ExamType.values
            .firstWhere((t) => t.db == data['type'], orElse: () => ExamType.tyt)
            .label,
    ].join(' · '),
    NotificationKind.task => '${data['title'] ?? ''}',
    NotificationKind.note => '${data['body'] ?? ''}',
    NotificationKind.deletionRequest => tr(
      '{name} hesabının silinmesini istedi',
      {'name': data['student'] ?? ''},
    ),
    NotificationKind.meeting => _meetingBody(),
    NotificationKind.review => tr(
      'Hata defterinde {n} soru seni bekliyor. Unutmadan bir daha çöz!',
      {'n': data['count'] ?? 1},
    ),
    NotificationKind.weeklyReport => tr(
      'Bu hafta {q} soru çözdü, {m} dk odaklandı, {d} gün çalıştı.',
      {
        'q': data['questions'] ?? 0,
        'm': data['minutes'] ?? 0,
        'd': data['days'] ?? 0,
      },
    ),
    NotificationKind.dailyQuestion =>
      tr('Bugün {subject} sorusu seni bekliyor. Çöz, serini büyüt!', {
        'subject': data['subject'] == null
            ? ''
            : subjectByCode('${data['subject']}').name,
      }),
    NotificationKind.duel => tr(
      '{subject} · 10 soru. Aynı soruları çözün, kim daha iyi görelim!',
      {'subject': _subjectName(data['subject'])},
    ),
    NotificationKind.duelResult => tr(
      '{subject} düellosu sonuçlandı. Sonuca bak.',
      {'subject': _subjectName(data['subject'])},
    ),
    NotificationKind.plan => tr(
      '{from} {week} haftasının planını hazırladı. Göz at, yaptıkça işaretle!',
      {'from': data['from'] ?? '', 'week': _weekLabel(data['week'])},
    ),
  };

  /// "13 Ekim" (haftanın pazartesisi).
  static String _weekLabel(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    return d == null ? '' : DateFormat('d MMMM', localeTag).format(d);
  }

  static String _subjectName(Object? code) =>
      code == null ? '' : practiceSubjectLabel('$code');

  /// "Yarın 11:00 · Ayşe Koç ile görüşmen var"
  String _meetingBody() {
    final at = DateTime.tryParse('${data['at'] ?? ''}')?.toLocal();
    if (at == null) return tr('Koçunla görüşmen yaklaşıyor');
    final today = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final days = d.difference(DateTime(today.year, today.month, today.day));
    final day = switch (days.inDays) {
      0 => tr('Bugün'),
      1 => tr('Yarın'),
      _ => DateFormat('EEEE', localeTag).format(at),
    };
    final time = DateFormat('HH:mm').format(at);
    final coach = data['coach'];
    return coach == null
        ? tr('{day} {time} · koçunla görüşmen var', {'day': day, 'time': time})
        : tr('{day} {time} · {coach} ile görüşmen var', {
            'day': day,
            'time': time,
            'coach': coach,
          });
  }

  /// Dokununca gidilecek yer.
  String get route => switch (kind) {
    NotificationKind.assignment => '/student/homework',
    NotificationKind.exam => '/student/exams',
    NotificationKind.task || NotificationKind.note => '/student',
    NotificationKind.deletionRequest => '${data['route'] ?? '/'}',
    NotificationKind.meeting => '/student',
    NotificationKind.review => '/student/mistakes',
    NotificationKind.weeklyReport => '${data['route'] ?? '/parent'}',
    NotificationKind.dailyQuestion => '/student/daily',
    NotificationKind.duel || NotificationKind.duelResult => '/student/duels',
    NotificationKind.plan => '/student/plan',
  };

  AppNotification markRead() => AppNotification(
    id: id,
    kind: kind,
    data: data,
    refId: refId,
    createdAt: createdAt,
    readAt: readAt ?? DateTime.now(),
  );
}

abstract interface class NotificationRepository {
  /// Son bildirimler (yeniden eskiye); yenisi gelince akış güncellenir.
  Stream<List<AppNotification>> watch(String userId);
  Future<void> markAllRead(String userId);
  Future<void> markRead(String id);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<AppNotification>> watch(String userId) => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at')
      .limit(50)
      .map(
        (rows) => [
          for (final r in rows)
            if (NotificationKind.tryDb(r['kind'] as String) != null)
              AppNotification.fromJson(r),
        ],
      );

  @override
  Future<void> markAllRead(String userId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', userId)
      .isFilter('read_at', null);

  @override
  Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => SupabaseNotificationRepository(ref.watch(supabaseClientProvider)),
);

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      return ref.watch(notificationRepositoryProvider).watch(userId);
    });

final unreadNotificationCountProvider = Provider.family<int, String>(
  (ref, userId) =>
      ref
          .watch(notificationsProvider(userId))
          .value
          ?.where((n) => n.unread)
          .length ??
      0,
);
