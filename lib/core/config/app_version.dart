import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import 'env.dart';

/// Uygulamanın sürümü ve derleme numarası. pubspec.yaml'daki `version` ile
/// aynı olmalı (`0.2.0+2` → [appVersion] '0.2.0', [appBuild] 2);
/// test/app_version_test.dart ikisinin eşleştiğini denetler.
const appVersion = '0.2.0';
const appBuild = 2;

/// Sunucudaki zorunlu güncelleme ayarı (`app_config`).
class UpdateGate {
  const UpdateGate({required this.minBuild, this.updateUrl, this.message});

  factory UpdateGate.fromJson(Map<String, dynamic> j) => UpdateGate(
    minBuild: j['min_build'] as int? ?? 1,
    updateUrl: j['update_url'] as String?,
    message: j['message'] as String?,
  );

  /// Bu derlemeden eski uygulamalar açılmaz.
  final int minBuild;
  final String? updateUrl;
  final String? message;

  /// [build] (varsayılan: bu uygulama) güncellenmek zorunda mı?
  bool requiredFor([int build = appBuild]) => build < minBuild;
}

/// Açılışta bir kez okunur. Demo, ayarsız çalıştırma ya da ağ hatasında null:
/// kontrol yapılamazsa uygulama açılır (kullanıcıyı kilitlemeyiz).
final updateGateProvider = FutureProvider<UpdateGate?>((ref) async {
  if (Env.isDemo || !Env.isConfigured) return null;
  try {
    final row = await ref
        .watch(supabaseClientProvider)
        .from('app_config')
        .select('min_build, update_url, message')
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    return row == null ? null : UpdateGate.fromJson(row);
  } catch (_) {
    return null;
  }
});
