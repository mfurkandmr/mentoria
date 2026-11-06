import 'package:flutter/material.dart';

/// Kurumsal görünüm işareti: müdür / koç panelinin teması bunu taşır
/// (bkz. `cockpitTheme`). Ortak bileşenler (yükleniyor, boş durum, öğrenci
/// kartı) burada maskot ve süs renkleri yerine sade görünür.
///
/// Tema uzantısı olduğu için açılan pencere ve alt sayfalara da geçer.
@immutable
class CorporateLook extends ThemeExtension<CorporateLook> {
  const CorporateLook();

  @override
  CorporateLook copyWith() => this;

  @override
  CorporateLook lerp(CorporateLook? other, double t) => this;
}

/// Müdür / koç panelinin içinde mi?
bool isCorporate(BuildContext context) =>
    Theme.of(context).extension<CorporateLook>() != null;
