import '../../../core/theme/app_fonts.dart';
import 'font_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../admin/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/app_links.dart';
import '../../../core/branding/branding.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../data/tenant_repository.dart';

/// Hazır renk paleti (seçmeyi kolaylaştırır; ayrıca HEX girilebilir).
const _presets = <int>[
  0xFFFFC531,
  0xFFF5A300,
  0xFFFF7A45,
  0xFFE5484D,
  0xFFE84393,
  0xFF6C5CE7,
  0xFF3B5BDB,
  0xFF0EA5E9,
  0xFF14B8A6,
  0xFF22B07D,
  0xFF2B2350,
  0xFF374151,
];

/// Logo için en fazla 1 MB (Storage kovasındaki sınırla aynı).
const _maxLogoBytes = 1024 * 1024;

/// Dershane ekleme / düzenleme. Renk ve logo değişikliği canlı önizlemede
/// anında görünür.
///  * Süper admin: yeni dershane, slug, aktiflik, müdür davet kodu.
///  * Kurum müdürü ([selfService]): yalnızca kendi kurumunun adı, renkleri ve
///    logosu ("Kurum görünümü").
class TenantEditorScreen extends ConsumerStatefulWidget {
  const TenantEditorScreen({
    super.key,
    this.tenantId,
    this.selfService = false,
  });

  /// null: yeni dershane (süper admin).
  final String? tenantId;

  /// Kurum müdürünün kendi markasını düzenlemesi.
  final bool selfService;

  @override
  ConsumerState<TenantEditorScreen> createState() => _TenantEditorScreenState();
}

class _TenantEditorScreenState extends ConsumerState<TenantEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _seats = TextEditingController(text: '50');
  Color _primary = Branding.mentoria.primary;
  Color _secondary = Branding.mentoria.secondary;
  AppFont _font = AppFont.fallback;
  String? _logoUrl;
  Uint8List? _logoBytes;
  String? _logoExt;
  bool _active = true;
  bool _slugEdited = false;
  bool _saving = false;
  Branding? _original;

  bool get _isNew => widget.tenantId == null && !widget.selfService;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_isNew && !_slugEdited) _slug.text = Branding.slugify(_name.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _seats.dispose();
    super.dispose();
  }

  void _load(Branding t) {
    if (_original != null) return;
    _original = t;
    _name.text = t.name;
    _slug.text = t.slug ?? '';
    _primary = t.primary;
    _secondary = t.secondary;
    _font = t.font;
    _logoUrl = t.logoUrl;
    _active = t.isActive;
  }

  Branding get _draft => Branding(
    name: _name.text.trim().isEmpty ? tr('Dershane adı') : _name.text.trim(),
    slug: _slug.text.trim(),
    primary: _primary,
    secondary: _secondary,
    logoUrl: _logoUrl,
    tenantId: widget.tenantId ?? _original?.tenantId ?? 'preview',
    isActive: _active,
    font: _font,
  );

  Future<void> _pickLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isEmpty) return;
      final f = files.first;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxLogoBytes) {
        showMessage(context, tr('Logo en fazla 1 MB olabilir.'));
        return;
      }
      setState(() {
        _logoBytes = Uint8List.fromList(bytes);
        _logoExt = f.name.split('.').last.toLowerCase();
      });
    } catch (_) {
      if (mounted) showMessage(context, tr('Logo seçilemedi.'));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(tenantRepositoryProvider);
    if (widget.selfService) return _saveOwn(repo);
    try {
      String? adminCode;
      var id = widget.tenantId;
      if (_isNew) {
        final created = await repo.createTenant(
          TenantDraft(
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            primaryHex: Branding.toHex(_primary),
            secondaryHex: Branding.toHex(_secondary),
            seatLimit: int.tryParse(_seats.text) ?? 50,
          ),
        );
        id = created.tenantId;
        adminCode = created.adminCode;
      }
      if (_logoBytes != null) {
        _logoUrl = await repo.uploadLogo(id!, _logoBytes!, _logoExt ?? 'png');
      }
      // Yeni dershanede logo ya da varsayılan dışı yazı tipi seçildiyse
      // oluşturduktan sonra güncellenir.
      if (!_isNew || _logoBytes != null || _font != AppFont.fallback) {
        await repo.updateTenant(
          Branding(
            tenantId: id,
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            logoUrl: _logoUrl,
            primary: _primary,
            secondary: _secondary,
            isActive: _active,
            font: _font,
          ),
        );
      }
      ref.invalidate(tenantsProvider);
      // Kendi dershanesini düzenliyorsa tema hemen güncellensin.
      ref.invalidate(tenantBrandingProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      celebrate(context);
      if (adminCode != null) {
        await showAdminCodeDialog(context, adminCode, _name.text.trim());
      } else {
        showMessage(context, tr('Dershane kaydedildi.'));
      }
      if (mounted && context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = '$e';
      showMessage(
        context,
        msg.contains('SLUG_TAKEN') || msg.contains('duplicate')
            ? tr('Bu dershane kodu kullanılıyor, başka bir kod seç.')
            : tr('Kaydedilemedi. Tekrar dene.'),
      );
    }
  }

  /// Kurum müdürü: kendi markasını kaydeder; değişiklik koç ve öğrencilerin
  /// ekranına da yansır.
  Future<void> _saveOwn(TenantRepository repo) async {
    try {
      final id = _original!.tenantId!;
      if (_logoBytes != null) {
        _logoUrl = await repo.uploadLogo(id, _logoBytes!, _logoExt ?? 'png');
        _logoBytes = null;
      }
      await repo.updateMyBranding(
        Branding(
          tenantId: id,
          name: _name.text.trim(),
          primary: _primary,
          secondary: _secondary,
          logoUrl: _logoUrl,
          font: _font,
        ),
      );
      ref.invalidate(tenantBrandingProvider);
      ref.invalidate(orgProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      celebrate(context);
      showMessage(
        context,
        tr(
          'Kurum görünümü kaydedildi. Koç ve öğrencilerin uygulamayı yenileyince görür.',
        ),
      );
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(
        context,
        '$e'.contains('NOT_ALLOWED')
            ? tr('Bunu yalnızca kurum müdürü değiştirebilir.')
            : tr('Kaydedilemedi. Tekrar dene.'),
      );
    }
  }

  Future<void> _newAdminCode() async {
    try {
      final code = await ref
          .read(tenantRepositoryProvider)
          .createAdminInvite(widget.tenantId!);
      if (mounted) await showAdminCodeDialog(context, code, _name.text.trim());
    } catch (_) {
      if (mounted) showMessage(context, tr('Kod oluşturulamadı.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selfService) {
      final mine = ref.watch(tenantBrandingProvider);
      final t = mine.value;
      if (t == null || t.isDefault) {
        return Scaffold(
          appBar: AppBar(title: Text(tr('Kurum görünümü'))),
          body: mine.isLoading
              ? const BizzLoader()
              : Center(child: Text(tr('Dershane bulunamadı'))),
        );
      }
      _load(t);
    } else if (!_isNew) {
      final list = ref.watch(tenantsProvider);
      final t = list.value
          ?.where((x) => x.tenantId == widget.tenantId)
          .firstOrNull;
      if (t == null) {
        return Scaffold(
          appBar: AppBar(),
          body: list.isLoading
              ? const BizzLoader()
              : Center(child: Text(tr('Dershane bulunamadı'))),
        );
      }
      _load(t);
    }
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selfService
              ? tr('Kurum görünümü')
              : _isNew
              ? tr('Yeni dershane')
              : tr('Dershaneyi düzenle'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Preview(branding: _draft, logoBytes: _logoBytes),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Dershane adı')),
              validator: (v) => (v ?? '').trim().length < 2
                  ? tr('En az 2 karakter olmalı.')
                  : null,
            ),
            if (!widget.selfService)
              TextFormField(
                controller: _slug,
                maxLength: 32,
                autocorrect: false,
                onChanged: (_) => _slugEdited = true,
                decoration: InputDecoration(
                  labelText: tr('Dershane kodu (slug)'),
                  helperText: tr(
                    'Girişte ve linklerde kullanılır: küçük harf, rakam, tire.',
                  ),
                ),
                validator: (v) =>
                    Branding.slugPattern.hasMatch((v ?? '').trim())
                    ? null
                    : tr('3-32 karakter: küçük harf, rakam ve tire.'),
              ),
            if (_isNew)
              TextFormField(
                controller: _seats,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: tr('Öğrenci lisansı (koltuk)'),
                ),
              ),
            const SizedBox(height: 16),
            _ColorField(
              label: tr('Ana renk'),
              color: _primary,
              onChanged: (c) => setState(() => _primary = c),
            ),
            const SizedBox(height: 16),
            _ColorField(
              label: tr('İkincil renk'),
              color: _secondary,
              onChanged: (c) => setState(() => _secondary = c),
            ),
            const SizedBox(height: 20),
            FontPicker(
              selected: _font,
              onChanged: (f) => setState(() => _font = f),
            ),
            const SizedBox(height: 20),
            Text(
              tr('Logo'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'PNG, JPG ya da WebP · en fazla 1 MB · kare ve şeffaf zeminli önerilir',
              ),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(tr('Logo seç')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                if (_logoUrl != null || _logoBytes != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _logoUrl = null;
                            _logoBytes = null;
                          }),
                    child: Text(tr('Logoyu kaldır')),
                  ),
                ],
              ],
            ),
            if (widget.selfService) ...[
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: Text(tr('Kurum linkini kopyala')),
                subtitle: Text(AppLinks.tenant(_slug.text.trim())),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: AppLinks.tenant(_slug.text.trim())),
                  );
                  showMessage(context, tr('Link kopyalandı'));
                },
              ),
            ],
            if (!_isNew && !widget.selfService) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(tr('Aktif')),
                subtitle: Text(
                  tr(
                    'Pasif dershanenin kullanıcıları giriş yapsa da verilerine erişemez.',
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: Text(tr('Dershane linkini kopyala')),
                subtitle: Text(AppLinks.tenant(_slug.text.trim())),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: AppLinks.tenant(_slug.text.trim())),
                  );
                  showMessage(context, tr('Link kopyalandı'));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(tr('Kurum müdürü davet kodu oluştur')),
                onTap: _newAdminCode,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isNew ? tr('Dershaneyi oluştur') : tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçilen renklerle uygulamanın küçük bir önizlemesi (gerçek tema ile).
class _Preview extends StatelessWidget {
  const _Preview({required this.branding, this.logoBytes});

  final Branding branding;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.fromBranding(branding);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? AppTheme.dark(brand) : AppTheme.light(brand);
    return Semantics(
      label: tr('Tema önizlemesi'),
      child: AnimatedTheme(
        data: theme,
        child: Builder(
          builder: (context) {
            final text = Theme.of(context).textTheme;
            final logo = logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(logoBytes!, height: 36),
                  )
                : const BrandLogo(fontSize: 26, showName: false);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      logo,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          branding.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Bugün'),
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedLinearProgress(
                            value: 0.62,
                            color: brand.primaryDeep,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(tr('Matematik')),
                                backgroundColor: brand.secondary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              Chip(label: Text(tr('Türkçe'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () {}, child: Text(tr('Soru ekle'))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final _hex = TextEditingController(text: Branding.toHex(widget.color));

  @override
  void didUpdateWidget(_ColorField old) {
    super.didUpdateWidget(old);
    final hex = Branding.toHex(widget.color);
    if (Branding.parseHex(_hex.text)?.toARGB32() != widget.color.toARGB32()) {
      _hex.text = hex;
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final outline = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in _presets)
              Semantics(
                button: true,
                selected: widget.color.toARGB32() == v,
                label: Branding.toHex(Color(v)),
                child: GestureDetector(
                  onTap: () => widget.onChanged(Color(v)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(v),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: widget.color.toARGB32() == v ? 3 : 1,
                        color: widget.color.toARGB32() == v
                            ? outline
                            : outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: widget.color.toARGB32() == v
                        ? Icon(
                            Icons.check_rounded,
                            color: BrandTheme.readableOn(Color(v)),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 180,
          child: TextField(
            controller: _hex,
            maxLength: 7,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'HEX',
              counterText: '',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            onChanged: (v) {
              final c = Branding.parseHex(v);
              if (c != null) widget.onChanged(c);
            },
          ),
        ),
      ],
    );
  }
}

/// Yeni müdür davet kodu ve linki (kopyalanabilir).
Future<void> showAdminCodeDialog(
  BuildContext context,
  String code,
  String tenantName,
) {
  final link = AppLinks.invite(code);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Kurum müdürü daveti')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              '{name} dershanesinin müdürü bu kodla ya da linkle kayıt olur. Kod 14 gün geçerli ve tek kullanımlık.',
              {'name': tenantName},
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            code,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(link, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            showMessage(context, tr('Link kopyalandı'));
          },
          child: Text(tr('Linki kopyala')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.pop(context);
          },
          child: Text(tr('Kodu kopyala')),
        ),
      ],
    ),
  );
}
