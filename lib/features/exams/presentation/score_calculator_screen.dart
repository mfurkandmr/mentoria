import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../account/data/account_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../learn/data/practice_repository.dart';
import '../data/exam_repository.dart';
import '../data/yks_score.dart';

String _fmt(double v, [int digits = 2]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String _subjectLabel(String code) => code.startsWith('TYT_')
    ? 'TYT ${subjectByCode(code).name}'
    : practiceSubjectLabel(code);

/// YKS puan hesaplayıcı: son denemelerin netleriyle dolar, netler ve diploma
/// notu değiştirilebilir; hedef puana göre hangi dersten kaç net gerektiğini
/// söyler. Puanlar tahminidir.
class ScoreCalculatorScreen extends ConsumerStatefulWidget {
  const ScoreCalculatorScreen({super.key});

  @override
  ConsumerState<ScoreCalculatorScreen> createState() =>
      _ScoreCalculatorScreenState();
}

class _ScoreCalculatorScreenState extends ConsumerState<ScoreCalculatorScreen> {
  ScoreType? _type;
  Map<String, double>? _nets;
  final _controllers = <String, TextEditingController>{};
  late final _diploma = TextEditingController();
  late final _target = TextEditingController();
  bool _placedLastYear = false;

  static const _kDiploma = 'yks_diploma';
  static const _kPlaced = 'yks_placed_last_year';
  String get _kTarget => 'yks_target_${_type!.name}';

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final d = prefs?.getDouble(_kDiploma);
      if (d != null) _diploma.text = _fmt(d);
      _placedLastYear = prefs?.getBool(_kPlaced) ?? false;
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _diploma.dispose();
    _target.dispose();
    super.dispose();
  }

  void _load(Map<String, double> nets) {
    _nets = {...nets};
    for (final code in {
      for (final t in ScoreType.values) ...scoreSubjects(t),
    }) {
      (_controllers[code] ??= TextEditingController()).text = nets[code] == null
          ? ''
          : _fmt(nets[code]!).replaceAll(RegExp(r',?0+$'), '');
    }
  }

  void _loadTarget() {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final t = prefs?.getDouble(_kTarget);
      _target.text = t == null ? '' : _fmt(t, 0);
    } catch (_) {
      _target.text = '';
    }
  }

  void _save(String key, Object? value) {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      switch (value) {
        case null:
          prefs?.remove(key);
        case double v:
          prefs?.setDouble(key, v);
        case bool v:
          prefs?.setBool(key, v);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentProfileProvider).value;
    final exams = me == null ? null : ref.watch(examsForStudentProvider(me.id));
    final field = ref.watch(profileDetailsProvider).value?.field;
    if (me == null || exams == null || exams.isLoading && !exams.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Puan hesapla'))),
        body: const Center(child: BizzLoader()),
      );
    }
    final fromExams = netsFromExams(exams.value ?? const []);
    if (_nets == null) _load(fromExams);
    if (_type == null) {
      _type = ScoreType.forField(field);
      _loadTarget();
    }
    final type = _type!;
    final nets = _nets!;
    final diploma = _parse(_diploma.text);
    final scores = {
      for (final t in ScoreType.values)
        t: computeScore(
          t,
          nets,
          diploma: diploma,
          placedLastYear: _placedLastYear,
        ),
    };
    final score = scores[type]!;
    final target = _parse(_target.text);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Puan hesapla'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SegmentedButton<ScoreType>(
            showSelectedIcon: false,
            segments: [
              for (final t in ScoreType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _loadTarget();
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brand.primaryDeep,
                  Color.lerp(brand.primaryDeep, brand.secondary, 0.7)!,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Tahmini {type} yerleştirme puanın', {'type': type.label}),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(score.placement, 3),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  diploma == null
                      ? tr(
                          'Ham puan {raw} · diploma notunu girersen OBP eklenir',
                          {'raw': _fmt(score.raw, 3)},
                        )
                      : tr('Ham puan {raw} · OBP katkısı +{obp}', {
                          'raw': _fmt(score.raw, 3),
                          'obp': _fmt(score.obpBonus, 2),
                        }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ScoreType.values)
                if (t != type)
                  ActionChip(
                    label: Text('${t.label} ${_fmt(scores[t]!.placement, 1)}'),
                    onPressed: () => setState(() {
                      _type = t;
                      _loadTarget();
                    }),
                  ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: tr('Hedef puan'),
            subtitle: tr(
              'Hedef bölümünün geçen yılki taban puanını yazabilirsin',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('{type} hedef puanı', {'type': type.label}),
                    hintText: '450',
                  ),
                  onChanged: (v) => setState(() => _save(_kTarget, _parse(v))),
                ),
                if (target != null) ...[
                  const SizedBox(height: 12),
                  _TargetAdvice(
                    type: type,
                    nets: nets,
                    gap: target - score.placement,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: tr('Netlerin'),
            subtitle: tr(
              'Son denemelerinden dolduruldu; değiştirip deneyebilirsin',
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _load(fromExams)),
              child: Text(tr('Sıfırla')),
            ),
            child: Column(
              children: [
                for (final code in scoreSubjects(type))
                  _NetRow(
                    code: code,
                    controller: _controllers[code]!,
                    onChanged: (v) => setState(() {
                      final n = _parse(v);
                      if (n == null) {
                        nets.remove(code);
                      } else {
                        nets[code] = n;
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: tr('Diploma notu (OBP)'),
            child: Column(
              children: [
                TextField(
                  controller: _diploma,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('Diploma notu (50-100)'),
                    hintText: '85',
                  ),
                  onChanged: (v) => setState(() => _save(_kDiploma, _parse(v))),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Geçen yıl bir programa yerleştim')),
                  subtitle: Text(tr('OBP katkısı yarıya iner')),
                  value: _placedLastYear,
                  onChanged: (v) => setState(() {
                    _placedLastYear = v;
                    _save(_kPlaced, v);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Puanlar tahminidir. ÖSYM puanları adayların ortalaması ve standart sapmasıyla hesaplar; gerçek puanın birkaç puan farklı olabilir.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NetRow extends StatelessWidget {
  const _NetRow({
    required this.code,
    required this.controller,
    required this.onChanged,
  });
  final String code;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _subjectLabel(code),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 92,
          child: TextField(
            key: ValueKey('net-$code'),
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              suffixText: '/${maxNet(code)}',
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _TargetAdvice extends StatelessWidget {
  const _TargetAdvice({
    required this.type,
    required this.nets,
    required this.gap,
  });
  final ScoreType type;
  final Map<String, double> nets;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (gap <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: brand.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          tr('Hedefinin {p} puan üstündesin 🎉', {'p': _fmt(-gap, 1)}),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    final gains = gainsFor(type, nets, gap).where((g) => g.reachable).take(3);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Hedefe {p} puan kaldı', {'p': _fmt(gap, 1)}),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          if (gains.isEmpty)
            Text(
              tr(
                'Tek bir dersten kapanmıyor; birkaç derste birden net artırmalısın.',
              ),
            )
          else ...[
            Text(tr('Tek başına şu derslerden biriyle kapanır:')),
            const SizedBox(height: 4),
            for (final g in gains)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: brand.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr('{subject}: +{n} net (1 net ≈ {c} puan)', {
                          'subject': _subjectLabel(g.subject),
                          'n': _fmt(g.netsNeeded, 1),
                          'c': _fmt(g.coefficient, 2),
                        }),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
