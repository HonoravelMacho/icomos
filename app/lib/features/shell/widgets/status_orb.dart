// status_orb.dart — orbe de status de conexão + etiqueta monoespaçada.
//
// Estados: ONLINE / OFFLINE / MESH / AGUARDANDO PEER (§11.3). Reduzido
// (reduce-motion) → sem pulsação, apenas cor estática.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/hud_tokens.dart';

class StatusOrb extends StatefulWidget {
  const StatusOrb({super.key, required this.status, this.showLabel = true});
  final HudConnection status;
  final bool showLabel;

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb> {
  bool _pulseOn = true; // pulsação discreta; alternada por timer
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (widget.status == HudConnection.offline) return;
      if (mounted) setState(() => _pulseOn = !_pulseOn);
    });
  }

  @override
  void didUpdateWidget(covariant StatusOrb old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.status.color;
    final dimmed = !_pulseOn && widget.status != HudConnection.offline;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // reduce-motion: alpha fixo, nada alterna.
    final alpha = reduceMotion ? 1.0 : (dimmed ? 0.45 : 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: alpha * 0.35),
            border: Border.all(color: c.withValues(alpha: alpha), width: 1.4),
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: HudSpacing.s),
          Text(
            widget.status.label,
            style: TextStyle(
              fontFamily: HudFonts.data,
              fontSize: 11,
              letterSpacing: 1.5,
              color: c.withValues(alpha: alpha),
            ),
          ),
        ],
      ],
    );
  }
}
