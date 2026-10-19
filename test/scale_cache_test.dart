import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/cache/static_cache.dart';
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
}
