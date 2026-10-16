import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/i18n.dart';

/// Göster / gizle düğmeli şifre alanı.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.focusNode,
    this.onVisibilityChanged,
  });

  final FocusNode? focusNode;

  /// Şifre gösterilip gizlendiğinde (Bızz gizlice bakar).
  final ValueChanged<bool>? onVisibilityChanged;

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: !_visible,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _visible ? tr('Şifreyi gizle') : tr('Şifreyi göster'),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _visible = !_visible);
            widget.onVisibilityChanged?.call(_visible);
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              key: ValueKey(_visible),
            ),
          ),
        ),
      ),
    );
  }
}
