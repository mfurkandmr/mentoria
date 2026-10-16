import 'dart:ui';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Bir dershanenin markası (white label). Tema katmanı renkleri ve
/// uygulama adını buradan üretir; dershane yoksa Mentoria varsayılanı.
class Branding {
  const Branding({
    required this.name,
    required this.primary,
    required this.secondary,
    this.tenantId,
    this.slug,
    this.logoUrl,
    this.isActive = true,
    this.font = AppFont.fallback,
  });

  factory Branding.fromJson(Map<String, dynamic> j) => Branding(
    tenantId: j['id'] as String?,
    name: (j['name'] as String?)?.trim().isNotEmpty == true
        ? (j['name'] as String).trim()
        : mentoria.name,
    slug: j['slug'] as String?,
    logoUrl: j['logo_url'] as String?,
    primary: parseHex(j['primary_color'] as String?) ?? mentoria.primary,
    secondary: parseHex(j['secondary_color'] as String?) ?? mentoria.secondary,
    isActive: j['is_active'] as bool? ?? true,
    font: AppFont.fromKey(j['font_family'] as String?),
  );

  /// Varsayılan Mentoria markası (yüklenirken ve hata olursa da kullanılır).
  static const mentoria = Branding(
    name: 'Mentoria',
    primary: AppColors.honey,
    secondary: AppColors.grape,
  );

  final String? tenantId;
  final String name;
  final String? slug;
  final String? logoUrl;
  final Color primary;
  final Color secondary;
  final bool isActive;

  /// Kurumun yazı tipi (müdür seçer).
  final AppFont font;

  /// Dershaneye bağlı değil (Mentoria'nın kendisi).
  bool get isDefault => tenantId == null;

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  /// Renkler Mentoria'nınkiyle aynı mı (tema birebir korunur).
  bool get usesDefaultColors =>
      primary.toARGB32() == mentoria.primary.toARGB32() &&
      secondary.toARGB32() == mentoria.secondary.toARGB32();

  Branding copyWith({
    String? name,
    String? slug,
    String? logoUrl,
    bool clearLogo = false,
    Color? primary,
    Color? secondary,
    bool? isActive,
    AppFont? font,
  }) => Branding(
    tenantId: tenantId,
    name: name ?? this.name,
    slug: slug ?? this.slug,
    logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    isActive: isActive ?? this.isActive,
    font: font ?? this.font,
  );

  Map<String, Object?> toJson() => {
    'id': tenantId,
    'name': name,
    'slug': slug,
    'logo_url': logoUrl,
    'primary_color': toHex(primary),
    'secondary_color': toHex(secondary),
    'is_active': isActive,
    'font_family': font.key,
  };

  /// "#FFC531" / "ffc531" → Color. Geçersizse null.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final h = hex.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
    return Color(0xFF000000 | int.parse(h, radix: 16));
  }

  /// Color → "#FFC531".
  static String toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Dershane kodu kuralı (veritabanındaki CHECK ile aynı).
  static final slugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$');

  /// "Bal Akademi İzmir" → "bal-akademi-izmir"
  static String slugify(String text) {
    const from = 'ÇĞİIÖŞÜçğıöşüÂâÎîÛû';
    const to = 'cgiiosucgiosuaaiiuu';
    final buf = StringBuffer();
    for (final ch in text.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    final s = buf
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.length > 32
        ? s.substring(0, 32).replaceAll(RegExp(r'-+$'), '')
        : s;
  }
}
