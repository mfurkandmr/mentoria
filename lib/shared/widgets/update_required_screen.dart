import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_version.dart';
import '../../core/i18n/i18n.dart';
import 'bizz.dart';

/// Uygulama, sunucunun istediği en düşük sürümden eskiyse gösterilir; başka
/// hiçbir ekrana geçilmez (eski sürüm yeni sunucuyla bozuk çalışabilir).
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.gate});

  final UpdateGate gate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final url = gate.updateUrl;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Bizz(size: 120),
                  const SizedBox(height: 20),
                  Text(
                    tr('Yeni sürüm gerekli'),
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    gate.message?.trim().isNotEmpty == true
                        ? gate.message!
                        : tr(
                            'Uygulamanın bu sürümü artık desteklenmiyor. Devam etmek için en yeni sürümü yükle; verilerin kaybolmaz.',
                          ),
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (url != null)
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.system_update_rounded),
                      label: Text(tr('Güncelle')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    )
                  else
                    Text(
                      tr(
                        'Yeni sürümü kurumundan ya da koçundan isteyebilirsin.',
                      ),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    tr('Senin sürümün: {v}', {'v': '$appVersion ($appBuild)'}),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
