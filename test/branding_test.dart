import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/theme/app_fonts.dart';
import 'package:mentoria/core/branding/branding.dart';
import 'package:mentoria/core/branding/branding_providers.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/core/theme/app_colors.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/core/theme/brand_theme.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/auth/data/auth_repository.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/auth/presentation/login_screen.dart';
import 'package:mentoria/features/tenants/data/tenant_repository.dart';
import 'package:mentoria/features/tenants/presentation/platform_screen.dart';
import 'package:mentoria/features/tenants/presentation/tenant_editor_screen.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _student = Profile(
  id: 's1',
  fullName: 'Elif Yılmaz',
  role: UserRole.student,
);

/// Uygulamanın markayı nasıl uyguladığının küçük bir kopyası (MentoriaApp ile
/// aynı: activeBrandingProvider → BrandTheme → AppTheme).
class _BrandedApp extends ConsumerWidget {
  const _BrandedApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = BrandTheme.fromBranding(ref.watch(activeBrandingProvider));
    return MaterialApp(
      title: brand.appName,
      theme: AppTheme.light(brand),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text(context.brand.appName, key: const Key('name')),
              FilledButton(onPressed: () {}, child: const Text('btn')),
            ],
          ),
        ),
      ),
    );
  }
}

Color _buttonColor(WidgetTester tester) {
  final ctx = tester.element(find.text('btn'));
  return Theme.of(ctx).colorScheme.primary;
}

/// fetchMyTenant hiç bitmeyen ya da hata veren depo (yükleniyor / hata).
class _SlowRepo extends InMemoryTenantRepository {
  _SlowRepo({this.fail = false})
    : super(tenants: demoTenants(), myTenantId: 'demo-yildiz');
  final bool fail;
  final _never = Completer<Branding?>();

  @override
  Future<Branding?> fetchMyTenant() =>
      fail ? Future.error(Exception('ağ yok')) : _never.future;
}

Future<Widget> _routed(
  String _,
  Widget screen, {
  List<Override> extra = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: extra,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('Branding', () {
    test('HEX çevirileri', () {
      expect(Branding.parseHex('#ffc531'), const Color(0xFFFFC531));
      expect(Branding.parseHex('0EA5E9'), const Color(0xFF0EA5E9));
      expect(Branding.parseHex('kırmızı'), isNull);
      expect(Branding.parseHex('#12345'), isNull);
      expect(Branding.toHex(const Color(0xFF0EA5E9)), '#0EA5E9');
    });

    test('slug üretimi ve kuralı veritabanıyla aynı', () {
      expect(Branding.slugify('Bal Akademi İzmir'), 'bal-akademi-izmir');
      expect(Branding.slugify('  Öğretmen Çağı! '), 'ogretmen-cagi');
      expect(Branding.slugPattern.hasMatch('yildiz'), isTrue);
      expect(Branding.slugPattern.hasMatch('ab'), isFalse);
      expect(Branding.slugPattern.hasMatch('-yildiz'), isFalse);
      expect(Branding.slugPattern.hasMatch('Yıldız'), isFalse);
    });

    test('eksik/bozuk sunucu verisinde Mentoria değerlerine düşer', () {
      final b = Branding.fromJson({
        'id': 't1',
        'name': '',
        'primary_color': 'x',
      });
      expect(b.name, 'Mentoria');
      expect(b.primary, AppColors.honey);
      expect(b.secondary, AppColors.grape);
      expect(b.font, AppFont.nunito, reason: 'yazı tipi yoksa varsayılan');
    });

    test(
      'yazı tipi sunucudan okunur, bilinmeyen anahtar varsayılana düşer',
      () {
        expect(
          Branding.fromJson({'font_family': 'playfair_display'}).font,
          AppFont.playfairDisplay,
        );
        expect(
          Branding.fromJson({'font_family': 'comic_sans'}).font,
          AppFont.nunito,
        );
        expect(
          Branding.mentoria
              .copyWith(font: AppFont.spaceMono)
              .toJson()['font_family'],
          'space_mono',
        );
        // Anahtarlar veritabanı kısıtıyla birebir aynı
        // (supabase/migrations/20261018120000_tenant_fonts_v2.sql).
        expect(AppFont.values.map((f) => f.key), [
          'nunito',
          'poppins',
          'merriweather',
          'playfair_display',
          'roboto_slab',
          'oswald',
          'baloo_2',
          'patrick_hand',
          'space_mono',
          'exo_2',
        ]);
        // Her yazı tipinin ayrı bir tarzı ve adı var.
        expect(AppFont.values.map((f) => f.trKind).toSet(), hasLength(10));
        expect(AppFont.values.map((f) => f.family).toSet(), hasLength(10));
      },
    );
  });

  group('BrandTheme', () {
    test('varsayılan renkler Mentoria paletini birebir korur', () {
      final t = BrandTheme.fromBranding(Branding.mentoria);
      expect(t.isDefaultBrand, isTrue);
      expect(t.primaryDeep, AppColors.honeyDark);
      expect(t.ink, AppColors.night);
      expect(t.canvas, AppColors.cream);
    });

    test('dershane renklerinden okunur bir palet türetilir', () {
      final t = BrandTheme.fromBranding(demoTenants()[1]);
      expect(t.isDefaultBrand, isFalse);
      expect(t.appName, 'Yıldız Dershanesi');
      expect(t.primary, const Color(0xFF0EA5E9));
      // Açık mavi üstünde koyu yazı, koyu kırmızı üstünde beyaz yazı.
      expect(t.onPrimary.computeLuminance(), lessThan(0.2));
      expect(t.onSecondary, Colors.white);
      expect(
        HSLColor.fromColor(t.primaryDeep).lightness,
        lessThan(HSLColor.fromColor(t.primary).lightness),
      );
    });

    test('kurumun yazı tipi temaya uygulanır', () {
      final yildiz = BrandTheme.fromBranding(demoTenants()[1]);
      expect(yildiz.font, AppFont.poppins);
      expect(
        AppTheme.light(yildiz).textTheme.bodyMedium?.fontFamily,
        contains('Poppins'),
      );
      expect(
        AppTheme.dark(BrandTheme.mentoria()).textTheme.bodyMedium?.fontFamily,
        contains('Nunito'),
      );
    });

    test('tema eklenmemiş bağlamda Mentoria döner', () {
      expect(BrandTheme.mentoria().appName, 'Mentoria');
    });
  });

  group('çalışma anında markalama', () {
    testWidgets('giriş yapan kullanıcının dershanesi uygulanır', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => _student),
            tenantRepositoryProvider.overrideWithValue(
              InMemoryTenantRepository(
                tenants: demoTenants(),
                myTenantId: 'demo-yildiz',
              ),
            ),
          ],
          child: const _BrandedApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yıldız Dershanesi'), findsOneWidget);
      expect(_buttonColor(tester), const Color(0xFF0EA5E9));
    });

    testWidgets('yüklenirken Mentoria teması', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => _student),
            tenantRepositoryProvider.overrideWithValue(_SlowRepo()),
          ],
          child: const _BrandedApp(),
        ),
      );
      await tester.pump();
      expect(find.text('Mentoria'), findsOneWidget);
      expect(_buttonColor(tester), AppColors.honey);
    });

    testWidgets('hata olursa Mentoria teması', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) async => _student),
            tenantRepositoryProvider.overrideWithValue(_SlowRepo(fail: true)),
          ],
          child: const _BrandedApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mentoria'), findsOneWidget);
      expect(_buttonColor(tester), AppColors.honey);
    });

    testWidgets('giriş yapılmamışken kayıtlı dershane kodunun markası', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'tenant_slug': 'yildiz'});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentProfileProvider.overrideWith((ref) async => null),
            tenantRepositoryProvider.overrideWithValue(
              InMemoryTenantRepository(
                tenants: demoTenants(),
                myTenantId: null,
              ),
            ),
          ],
          child: const _BrandedApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yıldız Dershanesi'), findsOneWidget);
    });

    testWidgets('davet koduyla gelen markası her şeyin önünde', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
          tenantRepositoryProvider.overrideWithValue(
            InMemoryTenantRepository(tenants: demoTenants(), myTenantId: null),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _BrandedApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mentoria'), findsOneWidget);
      container.read(inviteBrandingProvider.notifier).set(demoTenants()[1]);
      await tester.pumpAndSettle();
      expect(find.text('Yıldız Dershanesi'), findsOneWidget);
    });
  });

  group('giriş ve süper admin', () {
    testWidgets('dershane kodu girilince giriş ekranı o dershaneyi gösterir', (
      tester,
    ) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        await _routed(
          'student',
          const LoginScreen(),
          extra: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentProfileProvider.overrideWith((ref) async => null),
            tenantRepositoryProvider.overrideWithValue(
              InMemoryTenantRepository(
                tenants: demoTenants(),
                myTenantId: null,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dershane kodun var mı?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'yok-boyle');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu kodla aktif bir dershane bulunamadı.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).last, 'yildiz');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Yıldız Dershanesi'), findsOneWidget);
      expect(prefs.getString('tenant_slug'), 'yildiz');
    });

    testWidgets('süper admin dershaneleri listeler ve yenisini açar', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTenantRepository(
        tenants: demoTenants(),
        myTenantId: 'demo-tenant',
        superAdmin: true,
      );
      await tester.pumpWidget(
        await _routed(
          'admin',
          const PlatformScreen(),
          extra: [tenantRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bal Akademi'), findsOneWidget);
      expect(find.text('Yıldız Dershanesi'), findsOneWidget);

      await tester.pumpWidget(
        await _routed(
          'admin',
          const TenantEditorScreen(),
          extra: [tenantRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dershane adı'),
        'Deniz Kolej',
      );
      await tester.pumpAndSettle();
      // Slug addan otomatik üretilir.
      expect(find.widgetWithText(TextFormField, 'deniz-kolej'), findsOneWidget);
      // Renk seçimi önizlemeyi değiştirir.
      await tester.tap(find.bySemanticsLabel('#14B8A6').first);
      await tester.pumpAndSettle();

      final create = find.text('Dershaneyi oluştur');
      await tester.scrollUntilVisible(
        create,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Kurum müdürü daveti'), findsOneWidget);
      final created = (await repo.listTenants()).firstWhere(
        (t) => t.slug == 'deniz-kolej',
      );
      expect(created.primary, const Color(0xFF14B8A6));
    });

    test('demo logo yüklemesi veri adresi döndürür', () async {
      final repo = InMemoryTenantRepository(
        tenants: demoTenants(),
        myTenantId: null,
      );
      final url = await repo.uploadLogo(
        't',
        Uint8List.fromList([1, 2, 3]),
        'png',
      );
      expect(url, startsWith('data:image/png'));
    });
    testWidgets('kurum müdürü kendi kurumunun adını ve rengini değiştirir', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryTenantRepository(
        tenants: demoTenants(),
        myTenantId: 'demo-tenant',
      );
      await tester.pumpWidget(
        await _routed(
          'admin',
          const TenantEditorScreen(selfService: true),
          extra: [
            currentProfileProvider.overrideWith(
              (ref) async => const Profile(
                id: 'a1',
                fullName: 'Mehmet Demir',
                role: UserRole.admin,
              ),
            ),
            tenantRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kurum görünümü'), findsOneWidget);
      // Müdür slug, aktiflik ve davet kodunu göremez.
      expect(find.text('Dershane kodu (slug)'), findsNothing);
      expect(find.text('Aktif'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bal Akademi'),
        'Bal Akademi İzmir',
      );
      await tester.tap(find.bySemanticsLabel('#22B07D').first);
      await tester.pumpAndSettle();
      final playfair = find.text('Playfair Display');
      await tester.scrollUntilVisible(
        playfair,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(playfair);
      await tester.pumpAndSettle();
      final save = find.text('Kaydet');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      final mine = await repo.fetchMyTenant();
      expect(mine?.name, 'Bal Akademi İzmir');
      expect(mine?.primary, const Color(0xFF22B07D));
      expect(mine?.slug, 'bal-akademi');
      expect(mine?.font, AppFont.playfairDisplay);
    });
  });
}
