// Koç / müdür: öğrencinin velisine kurumun WhatsApp numarasından mesaj
// (NOTLAR §89). Mesaj `koc_mesaji` şablonuyla, koçun adıyla gider; veli
// cevap yazarsa cevap kurumun WhatsApp Business uygulamasına düşer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/haptics.dart';
import '../../../core/design/motion.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../data/guardian_messaging_repository.dart';

Future<void> showGuardianMessageSheet(
  BuildContext context, {
  required String studentId,
  required String studentName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: AppMotion.overlayStyle(context),
  builder: (_) =>
      GuardianMessageSheet(studentId: studentId, studentName: studentName),
);

class GuardianMessageSheet extends ConsumerStatefulWidget {
  const GuardianMessageSheet({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  final String studentId;
  final String studentName;

  @override
  ConsumerState<GuardianMessageSheet> createState() =>
      _GuardianMessageSheetState();
}

class _GuardianMessageSheetState extends ConsumerState<GuardianMessageSheet> {
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(guardianMessagingRepositoryProvider)
          .sendMessage(studentId: widget.studentId, body: _body.text);
      ref.invalidate(guardianMessagesProvider(widget.studentId));
      if (!mounted) return;
      AppHaptics.confirm();
      _body.clear();
      setState(() => _busy = false);
      showMessage(context, tr('Mesaj veliye WhatsApp\'tan gönderiliyor.'));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = guardianMessageError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final history = ref.watch(guardianMessagesProvider(widget.studentId));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            tr('Veliye WhatsApp'),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            tr(
              '{name} öğrencisinin velisine kurumun WhatsApp numarasından, senin adınla gider. Veli cevap yazarsa cevap kurumun WhatsApp Business uygulamasına düşer.',
              {'name': widget.studentName},
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('guardian-msg-body'),
            controller: _body,
            minLines: 3,
            maxLines: 8,
            maxLength: 900,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('Mesaj'),
              hintText: tr('Veliye ne yazmak istersin?'),
              errorText: _error,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('guardian-msg-send'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _busy || _body.text.trim().isEmpty ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text(tr('Gönder')),
          ),
          const SizedBox(height: 20),
          Text(
            tr('Veliye giden son mesajlar'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          AsyncView(
            value: history,
            onRetry: () =>
                ref.invalidate(guardianMessagesProvider(widget.studentId)),
            builder: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      tr('Henüz veliye mesaj gitmedi.'),
                      style: text.bodySmall,
                    ),
                  )
                : Column(
                    children: [for (final m in list) _MessageTile(message: m)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final GuardianMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final failed = m.status == 'failed';
    final when = DateFormat('d MMM HH:mm', 'tr_TR').format(m.createdAt);
    return ListTile(
      key: ValueKey('guardian-msg-${m.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        m.kind == GuardianMessageKind.homework
            ? Icons.picture_as_pdf_outlined
            : Icons.chat_outlined,
        color: failed ? context.brand.danger : null,
      ),
      title: Text(
        m.kind == GuardianMessageKind.homework ? tr('Ödev PDF\'i') : m.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          when,
          if (m.sender != null) m.sender!,
          if (failed && m.error != null) m.error! else m.statusLabel,
        ].join(' · '),
      ),
    );
  }
}
