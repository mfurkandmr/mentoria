# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Mentoria: a coach-supported tracking and statistics app for Turkish YKS (university entrance) students. Flutter (Android · iOS · Web) + Supabase + Firebase Cloud Messaging. Code comments, docs, and UI source strings are written in Turkish — keep that convention. Product plan: `docs/PROJE_PLANI.md` (the root-level `PROJE_PLANI.md` is an older copy); detailed notes on white label, avatars, push, and DB status: `NOTLAR.md` (read it before touching tenants/avatars/push).

## Commands

```bash
flutter run --dart-define-from-file=env.json          # real Supabase (copy env.example.json → env.json)
flutter run --dart-define=DEMO=true                    # no backend, in-memory sample data
flutter run --dart-define=DEMO=true --dart-define=DEMO_ROLE=coach   # student (default) | coach | admin | parent
flutter run --dart-define=DEMO=true --dart-define=DEMO_TENANT=yildiz  # white-label preview
flutter test                                           # all Dart tests
flutter test test/exams/exam_logic_test.dart           # single file
flutter test --plain-name "koddaki her tr() metninin"  # single test by name
flutter test test/tool/bizz_preview_test.dart          # renders mascot expressions → build/bizz_preview.png
dart analyze
dart format .
dart run flutter_launcher_icons                        # after changing assets/brand/icon/*
cd supabase/tests && npm install && npm test           # SQL/RLS tests on PGlite (no Supabase needed)
```

`env.json` holds `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (read in `lib/core/config/env.dart`). Other dart-defines: `APP_LINK_BASE` (root for shareable invite/tenant links). Ready-made run configs exist in `.vscode/launch.json` and `.idea/runConfigurations/`.

**Path gotcha:** the project path contains `Masaüstü`; `flutter analyze` can crash on non-ASCII paths and also on a drive root (e.g. `M:\`). Use `dart analyze`, or `subst N: "…\Masaüstü"` and run from `N:\Mentoria`.

## Architecture

**Feature-first layout:** `lib/features/<feature>/{data,presentation}`. `lib/core/` holds env, router, theme, branding, i18n, settings, constants (subjects, net calculation, YKS dates). `lib/shared/` holds common widgets (Bızz mascot, effects, logo).

**Repository + Riverpod pattern:** each `data/*_repository.dart` defines an `abstract interface class XRepository`, a `SupabaseXRepository` implementation, and a `xRepositoryProvider` (built from `supabaseClientProvider` in `features/auth/data/auth_repository.dart`). `lib/dev/demo_repositories.dart` has `InMemoryXRepository` counterparts, and `lib/dev/demo_mode.dart` `buildDemoOverrides()` swaps them in via `ProviderScope` overrides. **When adding a repository method, implement it in both the Supabase and InMemory versions** — widget tests (`features_flow_test`, `exams_flow_test`, `branding_test`, `avatar_test`) run against the in-memory ones.

**Startup (`lib/main.dart`):** Supabase is only initialized when `Env.isConfigured && !Env.isDemo`; without keys the router sends to `/setup`. `sharedPreferencesProvider` is overridden with the preloaded instance. Firebase init failure is tolerated.

**Routing (`lib/core/router/app_router.dart`, go_router):** always starts at `/intro`. The redirect handles demo mode (forces the demo role's home), password recovery, auth routes (`/login`, `/signup`, `/join/:code` invite links, `/t/:slug` tenant links), and role gating — each role is confined to its home prefix (`RoleGateScreen.homeFor`), `/platform` is super-admin only. Client-side gating is cosmetic; real security is RLS.

**Roles & invites:** student, coach, admin (institution manager), parent, plus super-admin (`platform_admins`, set only via SQL). Signup is invite-only (`create_invite` / `check_invite` RPCs): admin → coach/student, coach → student, student → parent. Student signup checks the org's `seat_limit` and `license_expires_at`.

**White label (tenants):** `tenants` is the branding unit; `organizations` (seats/licence) belong to a tenant. `tenant_id` is never sent by the client — the `set_tenant_id` trigger fills it, and RESTRICTIVE isolation policies are AND-ed with existing RLS. In the app, `activeBrandingProvider` picks invite → logged-in user's tenant → saved slug, falling back to Mentoria. `BrandTheme` (ThemeExtension) derives the palette; **widgets read colors via `context.brand.*`, not `AppColors`** (which is only the default palette source). Intentionally fixed colors: Bızz mascot, sky header, streak flame, confetti/medals.

**i18n:** source strings are Turkish, wrapped in `tr('...')` (placeholders: `tr('{n} soru', {'n': 5})`). Every new `tr()` string needs an English entry in `lib/core/i18n/strings_en.dart` — `test/i18n_test.dart` scans `lib/` and fails on missing ones. DB topic names stay Turkish. Language change rebuilds the whole tree via `KeyedSubtree` in `app.dart`.

**Avatars:** unlock rules live in the DB (`avatar_items.unlock_rule`), not the app; only the server writes unlocks (`claim_avatar_unlocks()`). New part = SVG at `assets/avatar/<category>/<asset_name>.svg` + an `avatar_items` row; `test/avatar_test.dart` checks every migration-listed asset exists.

**Push:** `notifications` insert → `push_on_notification` trigger → `send-push` Edge Function (`supabase/functions/send-push/index.ts`, pg_net) → FCM HTTP v1. In-app cards cover the foreground case.

## Supabase

- Migrations in `supabase/migrations/` (timestamped, applied in order — the numbered list in `README.md` is outdated, the folder is the source of truth); seeds in `supabase/seed.sql` and `seed_ayt_ydt_topics.sql`.
- Each newer migration has a `supabase/rollbacks/<name>.down.sql`, kept outside `migrations/` so the CLI ignores it; roll back in reverse order. New schema changes should ship with a rollback file.
- `supabase/tests/*.mjs` apply all migrations + seeds to PGlite with mocked `auth` schema/roles and assert RLS, tenant isolation, and rollback/re-apply. Add new test files to the `test` script in `supabase/tests/package.json`.
- Dev project: `lmbykdvvxormfiaomysn` (Frankfurt). `SECURITY DEFINER` RPCs (e.g. `student_summaries`) bypass RLS and must filter by the caller's relationship themselves.
