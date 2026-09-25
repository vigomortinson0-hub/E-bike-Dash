import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const FedanBikeApp());
}

class FedanBikeApp extends StatelessWidget {
  const FedanBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fedan Bike',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: const BikeScreen(),
    );
  }
}

class BikeScreen extends StatefulWidget {
  const BikeScreen({super.key});

  @override
  State<BikeScreen> createState() => _BikeScreenState();
}

class _BikeScreenState extends State<BikeScreen> {
  double speed = 0.0;

  String gpsStatus = 'Ожидание GPS';
  String bluetoothStatus = 'Ожидание Bluetooth';

  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    startGps();
  }

  Future<void> startGps() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      setState(() {
        gpsStatus = 'GPS выключен';
      });
      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        gpsStatus = 'Нет разрешения GPS';
      });
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        speed = position.speed * 3.6;

        if (speed < 0.5) {
          speed = 0;
        }

        gpsStatus = 'GPS подключен';
      });
    });
  }

  Future<void> scanBluetooth() async {
    setState(() {
      bluetoothStatus = 'Поиск BMS...';
    });

    scanSubscription?.cancel();

    scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          final name = result.device.platformName;

          if (name.isNotEmpty) {
            debugPrint(
              'BLE: $name / ${result.device.remoteId}',
            );
          }

          if (name.toLowerCase().contains('jk') ||
              name.toLowerCase().contains('jkbms')) {
            setState(() {
              bluetoothStatus = 'Найдена JK BMS';
            });
          }
        }
      },
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 8),
    );

    if (mounted) {
      setState(() {
        bluetoothStatus = 'Сканирование завершено';
      });
    }
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FEDAN BIKE'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Text(
              'СКОРОСТЬ',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              speed.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 82,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Text(
              'км/ч',
              style: TextStyle(
                fontSize: 22,
              ),
            ),

            const SizedBox(height: 40),

            infoRow(
              'GPS',
              gpsStatus,
            ),

            const SizedBox(height: 15),

            infoRow(
              'BMS',
              bluetoothStatus,
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: scanBluetooth,
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 14,
                ),
                child: Text(
                  'НАЙТИ BMS',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const Spacer(),

            const Text(
              'JK BMS • 16S LiFePO₄',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D21),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
