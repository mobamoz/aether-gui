import 'package:flutter/material.dart';
import 'controller.dart';
import 'orb.dart';
import 'sheets.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage(this.c, {super.key});
  final AetherController c;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() { _t.dispose(); super.dispose(); }

  static String _speed(int b) {
    if (b < 1024) return '$b B/s';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / 1048576).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.state;
        final (title, sub) = switch (s) {
          LinkState.disconnected => ('متصل نیستی', 'برای شروع، روی دایره بزن'),
          LinkState.connecting => ('در حال یافتن مسیر', 'گیت‌وی‌ها اسکن می‌شوند و عبور واقعی ترافیک بررسی می‌شود'),
          LinkState.connected => ('متصل شدی', 'کل ترافیک گوشی از تونل رد می‌شود'),
          LinkState.error => ('اتصال برقرار نشد', c.message.isEmpty ? 'لاگ را ببین و دوباره تلاش کن' : c.message),
        };
        final busy = s == LinkState.connecting || s == LinkState.connected;

        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  switch (s) {
                    LinkState.connected => const Color(0xFF8FB8F5),
                    LinkState.connecting => const Color(0xFFFFE3D0),
                    LinkState.error => const Color(0xFFF6D6D6),
                    LinkState.disconnected => const Color(0xFFD9E6F7),
                  },
                  Palette.cloud,
                ],
                stops: const [0, 0.6],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(children: [
                    const Text('Aether',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Palette.ink, letterSpacing: 0.4)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'لاگ',
                      icon: const Icon(Icons.notes_rounded, color: Palette.ink),
                      onPressed: () => showLogSheet(context, c),
                    ),
                  ]),
                ),
                const Spacer(),
                Orb(
                  state: s,
                  t: _t,
                  onTap: () => busy ? c.disconnect() : c.connect(),
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Palette.ink)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                  child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.slate)),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: s == LinkState.connected ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Stat(icon: Icons.south_rounded, label: 'دریافت', value: _speed(c.downBps)),
                    const SizedBox(width: 40),
                    _Stat(icon: Icons.north_rounded, label: 'ارسال', value: _speed(c.upBps)),
                  ]),
                ),
                const Spacer(),
                _Panel(c: c, locked: busy),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Icon(icon, size: 16, color: Palette.zenith),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Palette.slate, fontSize: 13)),
        ]),
        const SizedBox(height: 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.ink)),
        ),
      ]);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.c, required this.locked});
  final AetherController c;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('پروتکل', style: TextStyle(fontWeight: FontWeight.w600, color: Palette.ink)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'masque', label: Text('MASQUE')),
                ButtonSegment(value: 'wg', label: Text('WireGuard')),
                ButtonSegment(value: 'gool', label: Text('gool')),
              ],
              selected: {c.protocol},
              onSelectionChanged: locked ? null : (v) => c.set(() => c.protocol = v.first),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => showSettingsSheet(context, c),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('تنظیمات پیشرفته'),
          ),
        ]),
      );
}
