import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF4F6FA)),
      home: const HomePage(),
    ));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final _urls = [
    'https://' + '://githubusercontent.com',
    'https://' + 'cdn.jsdelivr.net/gh/bibizankavafifi/my-vpn@main/keys.txt',
  ];

  final _v2ray = FlutterV2ray(onStatusChanged: (_) {});
  bool _loading = false;
  String _status = 'Нажмите для подключения';
  List<String> _keys = [];
  int _idx = 0;

  Future<List<String>> _loadKeys() async {
    for (final url in _urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final list = const LineSplitter().convert(res.body).map((e) => e.trim()).where((e) => e.startsWith('vless://')).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    throw Exception('Не удалось загрузить ключи');
  }

  Future<void> _connect({bool next = false}) async {
    setState(() { _loading = true; _status = 'Загрузка...'; });
    try {
      if (_keys.isEmpty) { _keys = await _loadKeys(); _idx = 0; }
      else if (next) { _idx = (_idx + 1) % _keys.length; }

      await _v2ray.initializeV2Ray();
      final parser = FlutterV2ray.parseFromURL(_keys[_idx]);
      if (!await _v2ray.requestPermission()) throw Exception('Нет разрешения VPN');

      _v2ray.startV2Ray(remark: parser.remark, config: parser.getFullConfiguration(), proxyOnly: false);
      setState(() => _status = 'VPN подключён • Сервер #${_idx + 1} из ${_keys.length}');
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() { _loading = true; _status = 'Отключение...'; });
    try { _v2ray.stopV2Ray(); setState(() => _status = 'VPN отключён'); }
    catch (e) { setState(() => _status = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final active = _status.startsWith('VPN подключён');
    final color = active ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_rounded, color: color, size: 26),
                const SizedBox(width: 8),
                const Text('VLESS VPN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _loading ? null : (active ? _disconnect : () => _connect()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 185, height: 185,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color,
                    boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 28, spreadRadius: 5, offset: const Offset(0, 8))],
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.power_settings_new_rounded, size: 52, color: Colors.white),
                          const SizedBox(height: 8),
                          Text(active ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        ]),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
                child: Column(children: [
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (active && _keys.length > 1) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () async { await _disconnect(); await _connect(next: true); },
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Сменить сервер'),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
