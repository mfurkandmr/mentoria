import 'dart:async';

import '../../features/avatar/presentation/leaderboard_screen.dart';
import '../../features/avatar/presentation/avatar_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/exit_guard.dart';
import '../../features/tenants/presentation/platform_screen.dart';
import '../../features/tenants/presentation/tenant_editor_screen.dart';
import '../../features/tenants/presentation/tenant_link_screen.dart';
import '../branding/branding_providers.dart';
import '../../features/assignments/presentation/assign_homework_screen.dart';
import '../../features/assignments/presentation/student_homework_screen.dart';
import '../../features/announcements/presentation/announcement_widgets.dart';
import '../../features/notifications/presentation/notification_widgets.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/intro/intro_screen.dart';
import '../../features/garden/presentation/garden_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/duel/presentation/duel_screens.dart';
import '../../features/exams/presentation/score_calculator_screen.dart';
import '../../features/plan/presentation/plan_widgets.dart';
import '../../features/learn/presentation/daily_question_screen.dart';
import '../../features/mistakes/presentation/mistakes_screen.dart';
import '../../features/parent/presentation/parent_child_screen.dart';
import '../../features/parent/presentation/parent_home_screen.dart';
import '../../features/ranking/presentation/success_ranking_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/invite_signup_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/role_gate_screen.dart';
import '../../features/auth/presentation/setup_screen.dart';
import '../../features/coach/presentation/coach_home_screen.dart';
import '../../features/coach/presentation/student_detail_screen.dart';
import '../../features/exams/presentation/add_exam_screen.dart';
import '../../features/exams/presentation/exam_batches_screen.dart';
import '../../features/exams/presentation/exams_screen.dart';
import '../../features/student/presentation/student_home_screen.dart';
import '../../features/student/presentation/student_shell.dart';
import '../../features/tracking/presentation/questions_view.dart';
import '../../features/tracking/presentation/study_view.dart';
import '../../features/tracking/presentation/topics_view.dart';
import '../config/env.dart';
import '../constants/exam_subjects.dart';

const _authRoutes = {'/login', '/signup'};

/// Oturum açmadan girilebilen yerler: giriş, kayıt, davet linki
/// (`/join/KOD`) ve dershane linki (`/t/slug`).
bool _isAuthRoute(String loc) =>
    _authRoutes.contains(loc) ||
    loc.startsWith('/join/') ||
    loc.startsWith('/t/');
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/intro',
    refreshListenable: Listenable.merge([refresh, passwordRecovery]),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Açılış animasyonu her durumda oynar; bitince '/' a geçer.
      if (loc == '/intro') return null;

      // Demo modunda giriş yok; doğrudan seçilen rolün ekranları.
      if (Env.isDemo) {
        final home = switch (Env.demoRole) {
          'coach' => '/coach',
          'admin' => '/admin',
          'parent' => '/parent',
          _ => '/student',
        };
        if (loc.startsWith('/platform') && Env.demoRole == 'admin') return null;
        return loc.startsWith(home) ? null : home;
      }

      if (!Env.isConfigured) return loc == '/setup' ? null : '/setup';

      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      // Şifre sıfırlama bağlantısından gelindi: önce yeni şifre.
      if (loggedIn && passwordRecovery.value) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (!loggedIn) return _isAuthRoute(loc) ? null : '/login';
      if (_isAuthRoute(loc) || loc == '/setup') return '/';

      // Kullanıcı başka bir rolün ekranına girmeye çalışırsa kendi ekranına dön.
      // (Asıl güvenlik veritabanındaki RLS kurallarında.)
      final profile = ref.read(currentProfileProvider).value;
      if (profile != null && loc != '/') {
        final home = RoleGateScreen.homeFor(profile.role);
        // Dershane yönetimi yalnızca süper adminlere açık.
        if (loc.startsWith('/platform')) {
          return ref.read(isSuperAdminProvider).value == true ? null : home;
        }
        if (!loc.startsWith(home)) return home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/intro',
        pageBuilder: (_, _) => const NoTransitionPage(child: IntroScreen()),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, state) =>
            InviteSignupScreen(initialCode: state.uri.queryParameters['code']),
      ),
      // Davet linki: https://.../#/join/ABCD2345 ya da mentoria://app/join/ABCD2345
      GoRoute(
        path: '/join/:code',
        builder: (_, state) =>
            InviteSignupScreen(initialCode: state.pathParameters['code']),
      ),
      // Dershane linki: giriş ekranı o dershanenin markasıyla açılır.
      GoRoute(
        path: '/t/:slug',
        builder: (_, state) =>
            TenantLinkScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/platform',
        builder: (_, _) => const PlatformScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const TenantEditorScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                TenantEditorScreen(tenantId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(path: '/', builder: (_, _) => const RoleGateScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/student/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/student/homework',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const StudentHomeworkScreen(),
      ),
      GoRoute(
        path: '/student/avatar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const AvatarEditorScreen(),
      ),
      GoRoute(
        path: '/student/leaderboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/student/success',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SuccessRankingScreen(),
      ),
      GoRoute(
        path: '/student/mistakes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const MistakesScreen(),
      ),
      GoRoute(
        path: '/student/plan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const StudentPlanScreen(),
      ),
      GoRoute(
        path: '/student/score',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ScoreCalculatorScreen(),
      ),
      GoRoute(
        path: '/student/duels',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DuelsScreen(),
      ),
      GoRoute(
        path: '/student/daily',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DailyQuestionScreen(),
      ),
      GoRoute(
        path: '/student/garden',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const GardenScreen(),
      ),
      GoRoute(
        path: '/student/announcements',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/student/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentShell(shell: shell),
        branches: [
          _branch('/student', const StudentHomeScreen()),
          _branch('/student/learn', const LearnScreen()),
          _branch('/student/exams', const ExamsScreen()),
          _branch('/student/questions', const QuestionsScreen()),
          _branch('/student/topics', const TopicsScreen()),
          _branch('/student/timer', const StudyScreen()),
        ],
      ),
      _managerRoutes('/coach', const CoachHomeScreen()),
      _managerRoutes('/admin', const AdminHomeScreen()),
      GoRoute(
        path: '/parent',
        builder: (_, _) => const ExitGuard(child: ParentHomeScreen()),
        routes: [
          GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: 'announcements',
            builder: (_, _) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: 'child/:id',
            builder: (_, state) => ParentChildScreen(
              childId: state.pathParameters['id']!,
              initialTab:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Koç ve kurum müdürünün ortak rotaları (öğrenci detayı, deneme girişi,
/// deneme yükleme, profil).
GoRoute _managerRoutes(String base, Widget home) => GoRoute(
  path: base,
  builder: (_, _) => ExitGuard(child: home),
  routes: [
    GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: 'import', builder: (_, _) => const ImportScreen()),
    // Toplu duyuru: gönderilenler ve gelenler.
    GoRoute(
      path: 'announcements',
      builder: (_, _) => const AnnouncementsScreen(),
    ),
    // Yüklenen denemeler: son 7 gündekiler silinebilir.
    GoRoute(
      path: 'exams',
      builder: (_, _) => ExamBatchesScreen(basePath: base),
    ),
    // Başarı sıralaması (müdür kapalıyken de önizler).
    GoRoute(path: 'success', builder: (_, _) => const SuccessRankingScreen()),
    // Kurum müdürü: logo, renk ve kurum adı (white label).
    GoRoute(
      path: 'branding',
      builder: (_, _) => const TenantEditorScreen(selfService: true),
    ),
    GoRoute(
      path: 'homework',
      builder: (_, state) => AssignHomeworkScreen(
        initialStudentId: state.uri.queryParameters['student'],
      ),
    ),
    GoRoute(
      path: 'students/:id',
      builder: (_, state) => StudentDetailScreen(
        studentId: state.pathParameters['id']!,
        basePath: base,
      ),
      routes: [
        GoRoute(
          path: 'exams/new',
          builder: (_, state) => AddExamScreen(
            studentId: state.pathParameters['id']!,
            initialType: ExamType.values.firstWhere(
              (t) => t.db == state.uri.queryParameters['type'],
              orElse: () => ExamType.tyt,
            ),
          ),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

/// Oturum açılıp kapandığında router'ın yönlendirmeyi yeniden çalıştırmasını sağlar.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    if (Env.isConfigured) {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.passwordRecovery) {
          passwordRecovery.value = true;
        }
        notifyListeners();
      });
    }
  }

  StreamSubscription<AuthState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
