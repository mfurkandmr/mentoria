import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/i18n.dart';
import 'common.dart';

/// Ana ekranda geri tuşuna yanlışlıkla basınca uygulama kapanmasın:
/// önce [onBack] denenir (ör. ilk sekmeye dön), sonra "tekrar bas" uyarısı.
/// Oturum kapanmaz; çıkış yalnızca profildeki "Çıkış yap" ile yapılır.
class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child, this.onBack});

  final Widget child;

  /// Geri tuşunu kendisi karşıladıysa true döner.
  final bool Function()? onBack;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBack;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (widget.onBack?.call() ?? false) return;
      final now = DateTime.now();
      if (_lastBack != null &&
          now.difference(_lastBack!) < const Duration(seconds: 2)) {
        SystemNavigator.pop();
        return;
      }
      _lastBack = now;
      showMessage(context, tr('Çıkmak için tekrar geri bas'));
    },
    child: widget.child,
  );
}
