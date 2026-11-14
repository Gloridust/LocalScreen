import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../context_ext.dart';

/// Single-line text input in the Lumen style.
class LsTextField extends StatelessWidget {
  /// Creates a text field.
  const LsTextField({
    super.key,
    this.controller,
    this.hint,
    this.leadingIcon,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.errorText,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? hint;
  final IconData? leadingIcon;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Shown below the field in `danger`, and tints the outline.
  final String? errorText;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    OutlineInputBorder border(Color color, [double? width]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ls.radius.md),
      borderSide: BorderSide(color: color, width: width ?? ls.size.hairline),
    );
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      maxLength: maxLength,
      style: ls.text.body.copyWith(color: c.textPrimary),
      cursorColor: c.accent,
      cursorWidth: ls.size.focusRing,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ls.brightness == Brightness.dark ? c.bg : c.surface,
        hintText: hint,
        hintStyle: ls.text.body.copyWith(color: c.textTertiary),
        counterText: '',
        errorText: errorText,
        errorStyle: ls.text.caption.copyWith(color: c.danger),
        prefixIcon: leadingIcon == null
            ? null
            : Icon(leadingIcon, size: ls.size.icon, color: c.textTertiary),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ls.space.lg,
          vertical: (ls.size.controlHeight - ls.text.body.fontSize! * ls.text.body.height!) / 2,
        ),
        enabledBorder: border(hasError ? c.danger.withValues(alpha: 0.6) : c.outline),
        focusedBorder: border(hasError ? c.danger : c.accent, ls.size.focusRing - 0.5),
        errorBorder: border(c.danger.withValues(alpha: 0.6)),
        focusedErrorBorder: border(c.danger, ls.size.focusRing - 0.5),
        border: border(c.outline),
      ),
    );
  }
}
