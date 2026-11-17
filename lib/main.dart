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
  // Замените на реальный URL вашего файла с ключами
  static const String _keysUrl =
      'https://raw.githubusercontent.com/ВАШ_ЛОГИН/ВАШ_РЕПОЗИТОРИЙ/main/keys.txt';

  final FlutterV2ray _flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      // Можно обновлять UI при изменении статуса
      debugPrint('V2Ray status: ${status.state}');
    },
  );

  bool _isLoading = false;
  String _statusMessage = 'Нажмите кнопку для подключения';

  Future<void> _connectVpn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Загрузка списка ключей...';
    });

    try {
      // 1. Скачиваем список ключей
      final response = await http.get(Uri.parse(_keysUrl));
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      // 2. Ищем первую строку, начинающуюся с vless://
      final lines = const LineSplitter().convert(response.body);
      String? vlessLink;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('vless://')) {
          vlessLink = trimmed;
          break;
        }
      }
      if (vlessLink == null) {
        throw Exception('В файле не найден ключ VLESS');
      }

      setState(() {
        _statusMessage = 'Инициализация V2Ray...';
      });

      // 3. Инициализируем ядро (достаточно один раз, но можно и при каждом подключении)
      await _flutterV2ray.initializeV2Ray();

      // 4. Разбираем ссылку
      final V2RayURL parser = FlutterV2ray.parseFromURL(vlessLink);

      // 5. Запрашиваем разрешение (для VPN-режима обязательно)
      final bool granted = await _flutterV2ray.requestPermission();
      if (!granted) {
        throw Exception('Разрешение на VPN не получено');
      }

      setState(() {
        _statusMessage = 'Подключение...';
      });

      // 6. Запускаем V2Ray в режиме VPN
      _flutterV2ray.startV2Ray(
        remark: parser.remark,
        config: parser.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false, // VPN-режим
      );

      setState(() {
        _statusMessage = 'VPN подключён';
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
    return Scaffold(
      appBar: AppBar(title: const Text('VLESS VPN')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Большая круглая кнопка
            SizedBox(
              width: 180,
              height: 180,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_statusMessage == 'VPN подключён'
                        ? _disconnectVpn
                        : _connectVpn),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: _statusMessage == 'VPN подключён'
                      ? Colors.green
                      : Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _statusMessage == 'VPN подключён'
                            ? 'ОТКЛЮЧИТЬ'
                            : 'ПОДКЛЮЧИТЬ',
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
          ],
        ),
      ),
    );
  }
}
