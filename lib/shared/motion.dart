import 'package:flutter/widgets.dart';

/// Sürekli (sonsuz) animasyonların genel anahtarı.
///
/// Testlerde `pumpAndSettle` takılmasın diye kapatılır; ayrıca cihazda
/// "hareketi azalt" açıksa animasyonlar durur.
class Motion {
  Motion._();

  static bool enabled = true;

  static bool of(BuildContext context) =>
      enabled && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}
