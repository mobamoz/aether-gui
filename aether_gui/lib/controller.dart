import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LinkState { disconnected, connecting, connected, error }

class AetherController extends ChangeNotifier {
  static const _method = MethodChannel('aether/vpn');
  static const _events = EventChannel('aether/events');

  LinkState state = LinkState.disconnected;
  String message = '';
  int upBps = 0, downBps = 0;
  final List<String> logs = [];

  // Settings (persisted)
  String protocol = 'masque'; // masque | wg | gool
  String scan = 'balanced'; // turbo | balanced | thorough | stealth
  String noize = 'firewall';
  String ipMode = '-4'; // -4 | -6 | --dual
  bool h2 = false;
  bool fragment = false;
  bool quick = true;
  bool mapdns = true;
  int port = 1819;
  int keepalive = 25;
  String extra = '';

  SharedPreferences? _p;
  StreamSubscription? _sub;

  Future<void> init() async {
    final p = _p = await SharedPreferences.getInstance();
    protocol = p.getString('protocol') ?? protocol;
    scan = p.getString('scan') ?? scan;
    noize = p.getString('noize') ?? noize;
    ipMode = p.getString('ipMode') ?? ipMode;
    h2 = p.getBool('h2') ?? h2;
    fragment = p.getBool('fragment') ?? fragment;
    quick = p.getBool('quick') ?? quick;
    mapdns = p.getBool('mapdns') ?? mapdns;
    port = p.getInt('port') ?? port;
    keepalive = p.getInt('keepalive') ?? keepalive;
    extra = p.getString('extra') ?? extra;
    _sub = _events.receiveBroadcastStream().listen(_onEvent);
  }

  void set(VoidCallback change) {
    change();
    final p = _p;
    if (p != null) {
      p.setString('protocol', protocol);
      p.setString('scan', scan);
      p.setString('noize', noize);
      p.setString('ipMode', ipMode);
      p.setBool('h2', h2);
      p.setBool('fragment', fragment);
      p.setBool('quick', quick);
      p.setBool('mapdns', mapdns);
      p.setInt('port', port);
      p.setInt('keepalive', keepalive);
      p.setString('extra', extra);
    }
    notifyListeners();
  }

  List<String> buildArgs() => [
        '--bind', '127.0.0.1:$port',
        ipMode,
        '--$protocol',
        '--scan', scan,
        '--noize', noize,
        if (protocol == 'masque' && h2) '--h2',
        if (protocol == 'masque' && h2 && fragment) '--fragment',
        if (protocol == 'wg' && keepalive > 0) ...['--keepalive', '$keepalive'],
        quick ? '--quick-reconnect' : '--no-quick-reconnect',
        ...extra.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
      ];

  void _onEvent(dynamic ev) {
    final m = Map<String, dynamic>.from(ev as Map);
    switch (m['type']) {
      case 'state':
        state = LinkState.values.firstWhere((s) => s.name == m['state'], orElse: () => LinkState.disconnected);
        message = (m['message'] as String?) ?? '';
        if (state != LinkState.connected) { upBps = 0; downBps = 0; }
      case 'log':
        logs.add(m['line'] as String);
        if (logs.length > 500) logs.removeAt(0);
      case 'stats':
        upBps = (m['up'] as num).toInt();
        downBps = (m['down'] as num).toInt();
    }
    notifyListeners();
  }

  Future<void> connect() async {
    state = LinkState.connecting;
    message = '';
    notifyListeners();
    try {
      await _method.invokeMethod('start', {'args': buildArgs(), 'port': port, 'mapdns': mapdns});
    } on PlatformException catch (e) {
      state = e.code == 'permission_denied' ? LinkState.disconnected : LinkState.error;
      message = e.message ?? '';
      notifyListeners();
    }
  }

  Future<void> disconnect() => _method.invokeMethod('stop');

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}
