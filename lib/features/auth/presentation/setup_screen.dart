import 'package:flutter/material.dart';

import '../../../shared/widgets/bizz.dart';
import '../../../core/i18n/i18n.dart';

/// Supabase anahtarları verilmeden çalıştırıldığında gösterilir.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const Bizz(size: 140),
                const SizedBox(height: 8),
                const MentoriaWordmark(),
                const SizedBox(height: 24),
                Text(
                  tr('Supabase bağlantısı eksik'),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Uygulama Supabase anahtarları olmadan başlatıldı. VS Code veya Android Studio\'da "Mentoria" çalıştırma ayarını seç ya da terminalde şu komutu kullan:',
                  ),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'flutter run --dart-define-from-file=env.json',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
