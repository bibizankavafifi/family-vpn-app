import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VLESS VPN',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _keysUrl =
      'https://jsdelivr.net';

  final FlutterV2ray _flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      debugPrint('V2Ray status: ${status.state}');
    },
  );

  bool _isLoading = false;
  String _statusMessage = 'Нажмите кнопку для подключения';
  List<String> _keysList = [];
  int _currentIndex = 0;

  Future<void> _connectVpn({bool nextServer = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Загрузка списка ключей...';
    });

    try {
      if (_keysList.isEmpty || !nextServer) {
        final response = await http.get(Uri.parse(_keysUrl));
        if (response.statusCode != 200) {
          throw Exception('Ошибка загрузки: ${response.statusCode}');
        }

        final lines = const LineSplitter().convert(response.body);
        _keysList = lines
            .map((line) => line.trim())
            .where((line) => line.startsWith('vless://'))
            .toList();

        if (_keysList.isEmpty) {
          throw Exception('В файле не найдены ключи VLESS');
        }
        _currentIndex = 0;
      } else {
        _currentIndex = (_currentIndex + 1) % _keysList.length;
      }

      final String vlessLink = _keysList[_currentIndex];

      setState(() {
        _statusMessage = 'Инициализация V2Ray...';
      });

      await _flutterV2ray.initializeV2Ray();

      final V2RayURL parser = FlutterV2ray.parseFromURL(vlessLink);

      final bool granted = await _flutterV2ray.requestPermission();
      if (!granted) {
        throw Exception('Разрешение на VPN не получено');
      }

      setState(() {
        _statusMessage = 'Подключение к серверу #${_currentIndex + 1}...';
      });

      _flutterV2ray.startV2Ray(
        remark: parser.remark,
        config: parser.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      setState(() {
        _statusMessage =
            'VPN подключён (Сервер #${_currentIndex + 1} из ${_keysList.length})';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnectVpn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Отключение...';
    });
    try {
      _flutterV2ray.stopV2Ray();
      setState(() {
        _statusMessage = 'VPN отключён';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка отключения: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _statusMessage.startsWith('VPN подключён');

    return Scaffold(
      appBar: AppBar(title: const Text('VLESS VPN')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isConnected ? _disconnectVpn : () => _connectVpn()),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor:
                      isConnected ? Colors.green : Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isConnected ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (isConnected && _keysList.length > 1) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        await _disconnectVpn();
                        await _connectVpn(nextServer: true);
                      },
                icon: const Icon(Icons.skip_next),
                label: const Text('Следующий сервер'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
