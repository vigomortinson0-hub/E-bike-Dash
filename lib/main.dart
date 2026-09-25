import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const EBikeApp());
}

class EBikeApp extends StatelessWidget {
  const EBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // Настоящий AMOLED Black
      ),
      home: const DashScreen(),
    );
  }
}

class DashScreen extends StatefulWidget {
  const DashScreen({super.key});

  @override
  State<DashScreen> createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  double _speed = 0.0;
  int _soc = 0;
  double _voltage = 0.0;
  double _current = 0.0;
  bool _isConnected = false;
  
  StreamSubscription<Position>? _positionStream;
  BluetoothDevice? _bmsDevice;
  StreamSubscription<List<int>>? _bmsDataStream;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Экрану запрещено гаснуть
    _initGPS();
  }

  void _initGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      setState(() {
        _speed = pos.speed > 0 ? pos.speed * 3.6 : 0.0; // Перевод м/с в км/ч
      });
    });
  }

  void _connectBMS() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName.contains("JK") || r.device.platformName.contains("JK-BD4A24S4P")) {
          FlutterBluePlus.stopScan();
          _bmsDevice = r.device;
          await _bmsDevice!.connect();
          setState(() => _isConnected = true);
          
          List<BluetoothService> services = await _bmsDevice!.discoverServices();
          for (var service in services) {
            for (var characteristic in service.characteristics) {
              if (characteristic.properties.notify || characteristic.properties.indicate) {
                await characteristic.setNotifyValue(true);
                _bmsDataStream = characteristic.lastValueStream.listen(_parseBMSData);
              }
            }
          }
          break;
        }
      }
    });
  }

  void _parseBMSData(List<int> data) {
    if (data.length > 20) {
      setState(() {
        // Парсинг байт JK BMS
        _soc = data[141]; 
        _voltage = ((data[118] << 8) | data[119]) / 100.0;
        _current = ((data[126] << 8) | data[127]) / 100.0;
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _bmsDataStream?.cancel();
    _bmsDevice?.disconnect();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          bool isLandscape = orientation == Orientation.landscape;
          return SafeArea(
            child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
          );
        },
      ),
    );
  }

  // Вертикальный режим
  Widget _buildPortraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSpeedDisplay(120),
        _buildBmsDataRow(),
        _buildConnectButton(),
      ],
    );
  }

  // Горизонтальный режим
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(child: Center(child: _buildSpeedDisplay(140))),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBmsDataRow(),
              const SizedBox(height: 20),
              _buildConnectButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDisplay(double fontSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _speed.toStringAsFixed(0),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        const Text(
          "КМ/Ч",
          style: TextStyle(fontSize: 20, color: Colors.grey, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildBmsDataRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatTile("${_soc}%", "ЗАРЯД", Colors.greenAccent),
        _buildStatTile("${_voltage.toStringAsFixed(1)}В", "ВОЛЬТЫ", Colors.cyanAccent),
        _buildStatTile("${_current.toStringAsFixed(1)}А", "ТОК", Colors.orangeAccent),
      ],
    );
  }

  Widget _buildStatTile(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return TextButton.icon(
      onPressed: _connectBMS,
      icon: Icon(
        _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
        color: _isConnected ? Colors.greenAccent : Colors.redAccent,
      ),
      label: Text(
        _isConnected ? "JK BMS Подключен" : "Поиск JK BMS",
        style: TextStyle(color: _isConnected ? Colors.greenAccent : Colors.redAccent),
      ),
    );
  }
}
