import 'package:flutter/material.dart';

import '../tokens.dart';

enum TButtonStyle {
  /// Solid brand blue: the main action on a light screen.
  primary,

  /// Sunshine yellow: the main action on a blue screen (splash, hero panels).
  cta,

  /// Blue outline: a secondary action.
  outline,

  /// Pale blue fill: a quiet action.
  soft,
}

/// Tutoria's button. Full-width by default; pass [expanded] false to hug the label.
class TButton extends StatelessWidget {
  const TButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = TButtonStyle.primary,
    this.icon,
    this.iconAfter = false,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TButtonStyle style;
  final IconData? icon;

  /// Puts the icon after the label (an arrow on a "Continue" button) instead of before it.
  final bool iconAfter;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      TButtonStyle.primary => (TColors.blue600, Colors.white, null),
      TButtonStyle.cta => (TColors.yellow, TColors.ink, null),
      TButtonStyle.outline => (
        Colors.transparent,
        TColors.blue600,
        TColors.blue600,
      ),
      TButtonStyle.soft => (TColors.blue100, TColors.blue600, null),
    };
    final enabled = onPressed != null && !loading;

    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        else ...[
          if (icon != null && !iconAfter) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TText.button.copyWith(color: fg),
            ),
          ),
          if (icon != null && iconAfter) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 22, color: fg),
          ],
        ],
      ],
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            style == TButtonStyle.cta ? TRadius.pill : TRadius.md + 2,
          ),
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 2),
        ),
        elevation: style == TButtonStyle.primary || style == TButtonStyle.cta
            ? 0
            : 0,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              style == TButtonStyle.cta ? TRadius.pill : TRadius.md + 2,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
