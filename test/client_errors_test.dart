// Web hata kaydı (NOTLAR §66): gönderici (tekrar, sınır, kimliksiz
// parametreler) ve süper admin hata listesi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/config/app_version.dart';
import 'package:mentoria/core/crash/web_error_reporter.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/client_errors/data/client_error_repository.dart';
import 'package:mentoria/features/client_errors/presentation/client_errors_screen.dart';

void main() {
  group('WebErrorReporter', () {
    test('aynı hata bir kez, oturumda en fazla 20 hata', () async {
      final sent = <Map<String, dynamic>>[];
      final r = WebErrorReporter((p) async => sent.add(p), path: () => '/app');
      final st = StackTrace.fromString('at main.dart.js:1:2\nat x');
      r.report(StateError('a'), st);
      r.report(StateError('a'), st);
      expect(sent, hasLength(1));
      for (var i = 0; i < 50; i++) {
        r.report(StateError('hata $i'), st);
      }
      await Future<void>.delayed(Duration.zero);
      expect(sent, hasLength(WebErrorReporter.maxPerSession));
    });

    test('gönderim hatası uygulamayı bozmaz', () async {
      final r = WebErrorReporter(
        (_) async => throw Exception('ağ yok'),
        path: () => '/app',
      );
      r.report(StateError('x'), null);
      await Future<void>.delayed(Duration.zero);
      expect(r.sentCount, 1);
    });

    test('kimliksiz parametreler: adres yalnızca yol, sürüm, kısaltma', () {
      final p = WebErrorReporter.params(
        message: 'm' * 3000,
        stack: 's' * 20000,
        path: '/app/join/ABCD?code=X#token=Y',
      );
      expect(p['p_url_path'], '/app/join/ABCD');
      expect(p['p_platform'], 'web');
      expect(p['p_app_version'], '$appVersion+$appBuild');
      expect((p['p_message'] as String).length, 1000);
      expect((p['p_stack'] as String).length, 8000);
      expect(
        p.keys.any((k) => k.contains('user_id') || k.contains('email')),
        isFalse,
      );
    });
  });

  testWidgets('hata kayıtları listesi: ayrıntı ve "çözüldü"', (tester) async {
    final repo = InMemoryClientErrorRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clientErrorRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ClientErrorsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('client-error-1')), findsOneWidget);
    expect(find.textContaining('3 kez'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('client-error-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('client-error-delete-1')));
    // Boş durumdaki maskot sürekli hareket eder: pumpAndSettle bitmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('client-error-1')), findsNothing);
    expect(find.text('Kayıtlı hata yok'), findsOneWidget);
  });
}
