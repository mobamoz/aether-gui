import 'package:flutter/material.dart';
import 'controller.dart';
import 'theme.dart';

/// The connect control: a sphere of light that ripples while linking and stays calm once connected.
class Orb extends StatelessWidget {
  const Orb({super.key, required this.state, required this.t, required this.onTap});
  final LinkState state;
  final Animation<double> t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lit = state != LinkState.disconnected;
    return Semantics(
      button: true,
      label: state == LinkState.connected ? 'قطع اتصال' : 'اتصال',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: t,
              builder: (_, __) => CustomPaint(size: const Size(300, 300), painter: _OrbPainter(t.value, state)),
            ),
            Icon(Icons.power_settings_new_rounded, size: 56, color: lit ? Colors.white : Palette.slate),
          ]),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.s);
  final double t;
  final LinkState s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.30;
    late Color a, b;
    switch (s) {
      case LinkState.connected: a = Palette.sky; b = Palette.zenith;
      case LinkState.connecting: a = const Color(0xFFFFDCC4); b = Palette.dawn;
      case LinkState.error: a = const Color(0xFFF3C4C4); b = Palette.alert;
      case LinkState.disconnected: a = Colors.white; b = const Color(0xFFC3D2EA);
    }
    final rings = s == LinkState.connecting ? 3 : (s == LinkState.connected ? 2 : 0);
    for (var i = 0; i < rings; i++) {
      final p = (t + i / rings) % 1.0;
      canvas.drawCircle(
        c,
        r * (1 + 0.55 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = b.withOpacity((1 - p) * 0.45),
      );
    }
    canvas.drawCircle(
      c, r * 1.15,
      Paint()
        ..color = b.withOpacity(s == LinkState.disconnected ? 0.12 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    final shader = RadialGradient(center: const Alignment(-0.3, -0.4), radius: 1.0, colors: [a, b])
        .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
