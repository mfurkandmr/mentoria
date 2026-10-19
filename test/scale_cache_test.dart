import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/core/cache/static_cache.dart';
import 'package:mentoria/core/cache/timed_cache.dart';
import 'package:mentoria/features/student/data/home_seed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HomeSeed', () {
    final since = DateTime(2026, 10, 1);
    setUp(HomeSeed.reset);

    test('paket yoksa null (normal sorguya dönülür)', () async {
      expect(await HomeSeed.take('s1', 'logs'), isNull);
    });

    test('her parça bir kez verilir', () async {
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [1, 2],
          'goals': null,
        },
      );
      expect((await HomeSeed.take('s1', 'logs', since: since))?.value, [1, 2]);
      expect(await HomeSeed.take('s1', 'logs', since: since), isNull);
      // Değeri null olan parça da "var" sayılır.
      final goals = await HomeSeed.take('s1', 'goals');
      expect(goals, isNotNull);
      expect(goals!.value, isNull);
      expect(await HomeSeed.take('s1', 'exams'), isNull);
    });

    test('başka öğrenci ya da başka tarih aralığı paketi kullanmaz', () async {
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [1],
        },
      );
      expect(await HomeSeed.take('s2', 'logs'), isNull);
      expect(await HomeSeed.take('s1', 'logs', since: DateTime(2020)), isNull);
      // Yanlış istek parçayı tüketmez.
      expect(await HomeSeed.take('s1', 'logs', since: since), isNotNull);
    });

    test('paket hata verirse null', () async {
      HomeSeed.prime('s1', since, () async => throw Exception('yok'));
      expect(await HomeSeed.take('s1', 'logs'), isNull);
    });

    test('yeniden prime edilince parçalar yeniden verilir', () async {
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [1],
        },
      );
      await HomeSeed.take('s1', 'logs');
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [2],
        },
      );
      expect((await HomeSeed.take('s1', 'logs'))?.value, [2]);
    });
  });

  group('StaticCache', () {
    setUp(StaticCache.clearMemory);

    test('aynı oturumda tek istek, sonra cihazdan', () async {
      SharedPreferences.setMockInitialValues({});
      StaticCache.init(await SharedPreferences.getInstance());
      var calls = 0;
      Future<List<Map<String, dynamic>>> load() async {
        calls++;
        return [
          {'id': 1, 'code': 'TYT_MAT'},
        ];
      }

      final a = StaticCache.rows('subjects_t', load);
      final b = StaticCache.rows('subjects_t', load);
      expect(await a, await b);
      expect(calls, 1);

      // Uygulama yeniden açıldı: bellek boş, cihazda var.
      StaticCache.clearMemory();
      expect(
        (await StaticCache.rows('subjects_t', load)).single['code'],
        'TYT_MAT',
      );
      expect(calls, 1);
    });

    test('süresi dolmuşsa yeniden çeker', () async {
      SharedPreferences.setMockInitialValues({});
      StaticCache.init(await SharedPreferences.getInstance());
      var calls = 0;
      Future<List<Map<String, dynamic>>> load() async {
        calls++;
        return const [];
      }

      await StaticCache.rows('old_t', load);
      StaticCache.clearMemory();
      await StaticCache.rows('old_t', load, maxAge: Duration.zero);
      expect(calls, 2);
    });

    test('hata olursa sonraki çağrı yeniden dener', () async {
      SharedPreferences.setMockInitialValues({});
      StaticCache.init(await SharedPreferences.getInstance());
      var fail = true;
      Future<List<Map<String, dynamic>>> load() async {
        if (fail) throw Exception('ağ yok');
        return [
          {'id': 1},
        ];
      }

      await expectLater(StaticCache.rows('err_t', load), throwsException);
      fail = false;
      expect(await StaticCache.rows('err_t', load), hasLength(1));
    });
  });

  group('HomeSeed cihaz önbelleği', () {
    final since = DateTime(2026, 10, 1);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      HomeSeed.init(await SharedPreferences.getInstance());
      await HomeSeed.clearDisk();
    });

    test(
      'ikinci açılışta önce cihazdaki paket, taze gelince onFresh',
      () async {
        HomeSeed.prime(
          's1',
          since,
          () async => {
            'logs': [1],
          },
        );
        expect((await HomeSeed.take('s1', 'logs', since: since))?.value, [1]);
        await Future<void>.delayed(Duration.zero);

        // Uygulama yeniden açıldı: sunucu henüz cevap vermedi.
        HomeSeed.reset();
        final server = Completer<Map<String, dynamic>>();
        var refreshed = 0;
        HomeSeed.prime(
          's1',
          DateTime(2026, 10, 2), // gün değişmiş olsa da cihazdaki gösterilir
          () => server.future,
          onFresh: () => refreshed++,
        );
        expect(
          (await HomeSeed.take(
            's1',
            'logs',
            since: DateTime(2026, 10, 2),
          ))?.value,
          [1],
        );

        server.complete({
          'logs': [2],
        });
        await Future<void>.delayed(Duration.zero);
        expect(refreshed, 1);
        expect(
          (await HomeSeed.take(
            's1',
            'logs',
            since: DateTime(2026, 10, 2),
          ))?.value,
          [2],
        );
      },
    );

    test('sunucuya ulaşılamazsa cihazdaki gösterilmeye devam eder', () async {
      HomeSeed.prime('s1', since, () async => {'goals': 'eski'});
      await HomeSeed.take('s1', 'goals');
      await Future<void>.delayed(Duration.zero);
      HomeSeed.reset();
      var refreshed = 0;
      HomeSeed.prime(
        's1',
        since,
        () async => throw Exception('internet yok'),
        onFresh: () => refreshed++,
      );
      expect((await HomeSeed.take('s1', 'goals'))?.value, 'eski');
      await Future<void>.delayed(Duration.zero);
      expect(refreshed, 0);
    });

    test('aşağı çekip yenilemede cihazdaki atlanır', () async {
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [1],
        },
      );
      await HomeSeed.take('s1', 'logs');
      await Future<void>.delayed(Duration.zero);
      HomeSeed.skipDiskOnce();
      final server = Completer<Map<String, dynamic>>();
      HomeSeed.prime('s1', since, () => server.future);
      final pending = HomeSeed.take('s1', 'logs', since: since);
      server.complete({
        'logs': [3],
      });
      expect((await pending)?.value, [3]);
    });

    test('başka öğrencinin paketi kullanılmaz, çıkışta silinir', () async {
      HomeSeed.prime(
        's1',
        since,
        () async => {
          'logs': [1],
        },
      );
      await HomeSeed.take('s1', 'logs');
      await Future<void>.delayed(Duration.zero);
      final server = Completer<Map<String, dynamic>>();
      HomeSeed.prime('s2', since, () => server.future);
      final pending = HomeSeed.take('s2', 'logs', since: since);
      server.complete({
        'logs': [9],
      });
      expect((await pending)?.value, [9]);

      await HomeSeed.clearDisk();
      final again = Completer<Map<String, dynamic>>();
      HomeSeed.prime('s1', since, () => again.future);
      final p2 = HomeSeed.take('s1', 'logs', since: since);
      again.complete({
        'logs': [5],
      });
      expect((await p2)?.value, [5]);
    });
  });

  test('toplu deneme yükleme: herkese aynı paket, kendi sonuçları', () async {
    final repo = InMemoryExamRepository();
    final batch = newBatchId();
    final failed = await repo.createExamBatch(
      draft: ExamDraft(
        examType: ExamType.tyt,
        name: 'Özdebir TYT-3',
        takenOn: DateTime(2026, 10, 18),
        results: const [],
        imported: true,
        batchId: batch,
      ),
      rows: [
        (
          'a',
          const [
            SubjectResult(code: 'TYT_MAT', correct: 30, wrong: 5, blank: 5),
          ],
        ),
        (
          'b',
          const [
            SubjectResult(code: 'TYT_MAT', correct: 10, wrong: 5, blank: 25),
          ],
        ),
      ],
    );
    expect(failed, isEmpty);
    expect(repo.examsOf('a').single.results.single.correct, 30);
    expect(repo.examsOf('b').single.results.single.correct, 10);
    final batches = await repo.fetchMyBatches();
    expect(batches.single.studentCount, 2);
  });

  group('TimedCache', () {
    test('süre içinde aynı anahtar tek istek, temizleyince yeniden', () async {
      final cache = TimedCache<int, String>();
      var calls = 0;
      Future<String> load() async => 'sayfa ${++calls}';
      expect(await cache.get(0, load), 'sayfa 1');
      expect(await cache.get(0, load), 'sayfa 1');
      expect(await cache.get(20, load), 'sayfa 2');
      cache.clear();
      expect(await cache.get(0, load), 'sayfa 3');
    });

    test('süre dolunca yeniden çeker', () async {
      final cache = TimedCache<int, int>(ttl: Duration.zero);
      var calls = 0;
      await cache.get(0, () async => ++calls);
      await cache.get(0, () async => ++calls);
      expect(calls, 2);
    });

    test('hata saklanmaz', () async {
      final cache = TimedCache<int, int>();
      await expectLater(
        cache.get(0, () async => throw Exception('ağ yok')),
        throwsException,
      );
      expect(await cache.get(0, () async => 7), 7);
    });
  });
}
