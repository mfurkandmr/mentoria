import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// sessionClient(ref) ile aynı kurgu: istemci nesnesi hep aynı, kimlik değişir.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'koc-a';
  void set(String? v) => state = v;
}

final _uid = NotifierProvider<_Uid, String?>(_Uid.new);
final _client = Provider<Object>((ref) => const Object());

// Gerçek repository'ler gibi: her kuruluşta yeni nesne, `==` tanımsız.
class _Repo {
  _Repo(this.client);
  final Object client;
}

Object _sessionClient(Ref ref) {
  ref.watch(_uid);
  return ref.watch(_client);
}

/// Repository'ler `sessionClient(ref)` ile istemci almalı: oturumdaki kullanıcı
/// değişince (çıkış, başka hesapla giriş) onlara bağlı bütün sağlayıcılar
/// sıfırlanır. `supabaseClientProvider`'ı doğrudan izleyen bir repository,
/// ortak bilgisayarda önceki hesabın verisini (öğrenci listesi, finans) yeni
/// hesaba gösterir.
void main() {
  test('repository sağlayıcıları oturuma bağlı istemciyi izler', () {
    // Bilinçli istisnalar: istemcinin kendisi ve oturumdan bağımsız sürüm
    // kapısı.
    const allowed = {
      'lib/features/auth/data/auth_repository.dart',
      'lib/core/config/app_version.dart',
    };
    final offenders = <String>[];
    var repos = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      final src = f.readAsStringSync();
      repos += 'sessionClient(ref)'.allMatches(src).length;
      if (allowed.contains(path)) continue;
      if (RegExp(r'\.watch\(\s*supabaseClientProvider\s*\)').hasMatch(src)) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
    expect(repos, greaterThan(30));
  });

  test('kullanıcı değişince repository ve verisi yeniden kurulur', () {
    var builds = 0;
    final repo = Provider<_Repo>((ref) {
      builds++;
      return _Repo(_sessionClient(ref));
    });
    var fetches = 0;
    final data = FutureProvider<int>((ref) async {
      ref.watch(repo);
      return ++fetches;
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(data, (_, _) {});
    expect(builds, 1);
    expect(fetches, 1);

    // Aynı kimlik (token yenilemesi): hiçbir şey yeniden çekilmez.
    c.read(_uid.notifier).set('koc-a');
    c.read(data);
    expect(builds, 1);
    expect(fetches, 1);

    // Başka hesapla giriş: önceki hesabın verisi atılır.
    c.read(_uid.notifier).set('koc-b');
    c.read(data);
    expect(builds, 2);
    expect(fetches, 2);
  });
}
