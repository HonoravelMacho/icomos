// neon_button.dart — botão de ação do HUD: chanfro + glow + tom neon.
//
// Acesso auditado por contraste; focusрение keyboard: foco material intacto.
import 'package:flutter/material.dart';

import '../../../core/theme/hud_tokens.dart';
import 'hud_panel.dart';

class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NeonVariant.primary,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final NeonVariant variant;
  final IconData? icon;
  final bool expanded;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

enum NeonVariant { primary, ghost, danger }

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false; // confirmação por press longa vira Fase 4 (PANIC).

  @override
  Widget build(BuildContext context) {
    final colors = switch (widget.variant) {
      NeonVariant.primary => HudColors.primary,
      NeonVariant.ghost => HudColors.secondary,
      NeonVariant.danger => HudColors.danger,
    };
    final enabled = widget.onPressed != null;
    final label = Text(
      widget.label,
      style: TextStyle(
        fontFamily: HudFonts.title,
        color: enabled ? colors : HudColors.muted,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        fontSize: 15,
      ),
    );

    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: colors),
          const SizedBox(width: HudSpacing.s),
        ],
        label,
      ],
    );

    // InkWell exige ancestral Material (debugCheckHasMaterial); a base é
    // transparente — o visual continua sendo 100% HUD (decoração abaixo).
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HudSpacing.l,
            vertical: HudSpacing.m,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? colors.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: enabled ? colors : HudColors.muted,
              width: 1,
            ),
            boxShadow: enabled ? HudGlow.of(colors, blur: 10) : null,
          ),
          child: inner,
        ),
      ),
    );

    return ClipPath(
      clipper: ChamferClipper(bevel: HudBevel.small),
      child: Semantics(button: true, label: widget.label, child: button),
    );
  }
}
