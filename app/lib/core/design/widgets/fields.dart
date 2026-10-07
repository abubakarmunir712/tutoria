import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// A text field with a leading icon and the app's rounded look. Pass [obscure] for passwords:
/// the field then shows an eye button to reveal what was typed.
class TTextField extends StatefulWidget {
  const TTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  /// Shown above the field. Optional: the mockups rely on the hint alone.
  final String? label;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  State<TTextField> createState() => _TTextFieldState();
}

class _TTextFieldState extends State<TTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      style: TText.body.copyWith(
        color: TColors.ink,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon, size: 22),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 22,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!, style: TText.label),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// A dropdown that matches [TTextField].
class TDropdownField<T> extends StatelessWidget {
  const TDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    required this.icon,
    this.label,
    this.validator,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final IconData icon;
  final String? label;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: TColors.muted),
      borderRadius: BorderRadius.circular(TRadius.md),
      dropdownColor: TColors.white,
      style: TText.body.copyWith(
        color: TColors.ink,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 22),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: TText.label),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
