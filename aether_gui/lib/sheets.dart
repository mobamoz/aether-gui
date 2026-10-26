import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'theme.dart';

void showLogSheet(BuildContext context, AetherController c) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('لاگ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: c.logs.join('\n'))),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('کپی'),
              ),
            ]),
          ),
          Expanded(
            child: c.logs.isEmpty
                ? const Center(child: Text('هنوز چیزی ثبت نشده. بعد از اتصال، خروجی Aether این‌جا می‌آید.'))
                : Directionality(
                    textDirection: TextDirection.ltr,
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: c.logs.length,
                      itemBuilder: (_, i) => SelectableText(
                        c.logs[c.logs.length - 1 - i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    ),
  );
}

void showSettingsSheet(BuildContext context, AetherController c) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: _Settings(c),
      ),
    ),
  );
}

class _Settings extends StatefulWidget {
  const _Settings(this.c);
  final AetherController c;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late final _port = TextEditingController(text: '${widget.c.port}');
  late final _keep = TextEditingController(text: '${widget.c.keepalive}');
  late final _extra = TextEditingController(text: widget.c.extra);

  @override
  void dispose() { _port.dispose(); _keep.dispose(); _extra.dispose(); super.dispose(); }

  Widget _drop(String label, String value, Map<String, String> items, void Function(String) onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        const Text('تنظیمات پیشرفته', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Palette.ink)),
        const SizedBox(height: 4),
        const Text('تغییرات از اتصال بعدی اعمال می‌شود.', style: TextStyle(color: Palette.slate)),
        const SizedBox(height: 18),
        _drop('حالت اسکن', c.scan,
            {'turbo': 'سریع', 'balanced': 'متعادل', 'thorough': 'دقیق', 'stealth': 'مخفی'}, (v) => c.set(() => c.scan = v)),
        _drop('پروفایل استتار (noize)', c.noize,
            {'firewall': 'firewall', 'gfw': 'gfw', 'balanced': 'balanced', 'aggressive': 'aggressive'},
            (v) => c.set(() => c.noize = v)),
        _drop('نسخه‌ی IP برای اسکن', c.ipMode,
            {'-4': 'فقط IPv4', '-6': 'فقط IPv6', '--dual': 'هر دو'}, (v) => c.set(() => c.ipMode = v)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('MASQUE روی HTTP/2'),
          subtitle: const Text('برای شبکه‌هایی که UDP را مسدود یا کند می‌کنند'),
          value: c.h2,
          onChanged: c.protocol == 'masque' ? (v) => c.set(() => c.h2 = v) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تکه‌تکه کردن ClientHello'),
          subtitle: const Text('فقط وقتی HTTP/2 روشن است'),
          value: c.fragment,
          onChanged: (c.protocol == 'masque' && c.h2) ? (v) => c.set(() => c.fragment = v) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('اتصال سریع'),
          subtitle: const Text('از آخرین گیت‌وی سالم استفاده کن و دوباره اسکن نکن'),
          value: c.quick,
          onChanged: (v) => c.set(() => c.quick = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('DNS از داخل تونل'),
          subtitle: const Text('درخواست‌های DNS بدون نیاز به UDP از مسیر پروکسی می‌روند'),
          value: c.mapdns,
          onChanged: (v) => c.set(() => c.mapdns = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'پورت SOCKS5', border: OutlineInputBorder()),
              onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 1023 && n < 65536) c.set(() => c.port = n); },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _keep,
              enabled: c.protocol == 'wg',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Keepalive (WireGuard)', border: OutlineInputBorder()),
              onChanged: (v) { final n = int.tryParse(v); if (n != null && n >= 0) c.set(() => c.keepalive = n); },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _extra,
            decoration: const InputDecoration(
              labelText: 'Extra flags',
              helperText: 'e.g. --peer 162.159.192.1:2408',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => c.set(() => c.extra = v),
          ),
        ),
      ]),
    );
  }
}
