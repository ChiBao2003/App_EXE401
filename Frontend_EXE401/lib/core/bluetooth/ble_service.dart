import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleService extends ChangeNotifier {
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _device;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  // UUIDs (sẽ được cập nhật khi biết UUID thực của thiết bị)
  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String charUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  BleConnectionState get state => _state;
  BluetoothDevice? get device => _device;
  bool get isConnected => _state == BleConnectionState.connected;
  bool get isScanning => _state == BleConnectionState.scanning;

  void _setState(BleConnectionState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_state == BleConnectionState.scanning) return;

    // Xin quyền trước khi quét (Android bắt buộc)
    if (!kIsWeb && Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    _setState(BleConnectionState.scanning);

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          final name = r.device.platformName.toUpperCase();
          // Tự động bắt thiết bị có tên EINK hoặc CLOCK
          if (name.contains('EINK') || name.contains('CLOCK')) {
            stopScan();
            _connect(r.device);
            break;
          }
        }
      });
    } catch (e) {
      _setState(BleConnectionState.disconnected);
    }

    // Auto stop after 10s if not found
    Future.delayed(const Duration(seconds: 11), () {
      if (_state == BleConnectionState.scanning) {
        stopScan();
        _setState(BleConnectionState.disconnected);
      }
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> _connect(BluetoothDevice device) async {
    _setState(BleConnectionState.connecting);
    try {
      await device.connect(autoConnect: false);
      _device = device;
      _setState(BleConnectionState.connected);

      _connectionSubscription = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _device = null;
          _setState(BleConnectionState.disconnected);
        }
      });
    } catch (e) {
      _setState(BleConnectionState.disconnected);
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _setState(BleConnectionState.disconnected);
  }

  Future<bool> sendData(List<int> data) async {
    if (!isConnected || _device == null) return false;
    try {
      List<BluetoothService> services = await _device!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains('ffe0')) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString().toLowerCase().contains('ffe1')) {
              await c.write(data);
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('BLE send error: $e');
    }
    return false;
  }

  /// Gửi thời gian hiện tại lên đồng hồ
  Future<bool> syncTime() async {
    final now = DateTime.now();
    final data = [
      0xAA, // Header
      now.year - 2000,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.weekday,
      0xFF, // Footer
    ];
    return sendData(data);
  }

  @override
  void dispose() {
    stopScan();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
