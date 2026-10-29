// hud_panel.dart — painel chanfrado (cantos cortados 10–14px) com borda 1px.
//
// É o "cartão" do HUD: tudo que contém dado tático vive dentro de um
// HudPanel. Glow é opcional (caro em mobile — §11.3, sem blur pesado).
import 'package:flutter/material.dart';

import 'package:icomos/core/theme/hud_tokens.dart';

/// Clipper de chanfro genérico: corta um triângulo em cada canto.
class ChamferClipper extends CustomClipper<Path> {
  ChamferClipper({this.bevel = HudBevel.small});
  final double bevel;

  @override
  Path getClip(Size size) {
    final double halfMinSide =
        (size.width < size.height ? size.width : size.height) / 2;
    final double b = bevel <= halfMinSide ? bevel : halfMinSide;
    return Path()
      ..moveTo(b, 0)
      ..lineTo(size.width - b, 0)
      ..lineTo(size.width, b)
      ..lineTo(size.width, size.height - b)
      ..lineTo(size.width - b, size.height)
      ..lineTo(b, size.height)
      ..lineTo(0, size.height - b)
      ..lineTo(0, b)
      ..close();
  }

  @override
  bool shouldReclip(ChamferClipper oldClipper) => oldClipper.bevel != bevel;
}

class HudPanel extends StatefulWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.bevel = HudBevel.small,
    this.glow = false,
    this.padding = const EdgeInsets.all(HudSpacing.l),
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double bevel;
  final bool glow;
  final EdgeInsetsGeometry padding;

  @override
  State<HudPanel> createState() => _HudPanelState();
}

class _HudPanelState extends State<HudPanel> {
  @override
  Widget build(BuildContext context) {
    final surface = widget.color ?? HudColors.panel;
    final border =
        widget.borderColor ?? HudColors.secondary.withValues(alpha: 0.55);
    return ClipPath(
      clipper: ChamferClipper(bevel: widget.bevel),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: 1),
          boxShadow: widget.glow ? HudGlow.of(HudColors.secondary) : null,
        ),
        child: widget.child,
      ),
    );
  }
}
