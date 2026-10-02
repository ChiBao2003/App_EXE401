import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── UUIDs khớp với firmware ESP32 ──────────────────────────────
const String _kServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const String _kRxUuid      = '0000ffe1-0000-1000-8000-00805f9b34fb'; // App → ESP32
const String _kTxUuid      = '0000ffe2-0000-1000-8000-00805f9b34fb'; // ESP32 → App

enum BleConnectionState { disconnected, scanning, connecting, connected }

/// Stub để home_screen.dart không bị lỗi
class BleDevice {
  final String platformName;
  const BleDevice({this.platformName = 'Eink Clock'});
}

/// BleService — BLE GATT client kết nối với ESP32.
/// Chạy song song với Bluetooth Classic A2DP (nghe nhạc).
class BleService extends ChangeNotifier {
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _btDevice;
  BleDevice? device; // Stub cho home_screen.dart
  BluetoothCharacteristic? _txChar; // Nhận notify từ ESP32
  BluetoothCharacteristic? _rxChar; // Gửi lệnh lên ESP32
  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connSubscription;

  // Stream cho data nhận từ ESP32
  final _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  bool get isScanning  => _state == BleConnectionState.scanning;

  void _setState(BleConnectionState s) {
    _state = s;
    notifyListeners();
  }

  // ─── Scan & Connect ──────────────────────────────────────────
  Future<void> startScan() async {
    if (_state != BleConnectionState.disconnected) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    _setState(BleConnectionState.scanning);

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(_kServiceUuid)],
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          if (name.contains('ESP32_Pomodoro') || name.contains('Eink')) {
            stopScan();
            _connect(r.device);
            break;
          }
        }
      });

      // Auto-stop sau 10s nếu không tìm thấy
      Future.delayed(const Duration(seconds: 11), () {
        if (_state == BleConnectionState.scanning) {
          stopScan();
          _setState(BleConnectionState.disconnected);
        }
      });
    } catch (e) {
      debugPrint('[BLE] Lỗi scan: $e');
      _setState(BleConnectionState.disconnected);
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> _connect(BluetoothDevice dev) async {
    _setState(BleConnectionState.connecting);
    try {
      await dev.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      _btDevice = dev;
      device = BleDevice(platformName: dev.platformName);

      _connSubscription = dev.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _cleanup();
          _setState(BleConnectionState.disconnected);
          // Tự động quảng bá lại (ESP32 đã xử lý phía firmware)
        }
      });

      await _discoverServices(dev);
      _setState(BleConnectionState.connected);
    } catch (e) {
      debugPrint('[BLE] Lỗi kết nối: $e');
      _cleanup();
      _setState(BleConnectionState.disconnected);
    }
  }

  Future<void> _discoverServices(BluetoothDevice dev) async {
    final services = await dev.discoverServices();
    for (final svc in services) {
      if (svc.uuid.toString().toLowerCase().contains('ffe0')) {
        for (final c in svc.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains('ffe1')) _rxChar = c; // Gửi lệnh đi
          if (uuid.contains('ffe2')) {             // Nhận notify
            _txChar = c;
            await c.setNotifyValue(true);
            _notifySubscription = c.lastValueStream.listen((bytes) {
              if (bytes.isEmpty) return;
              try {
                final str = utf8.decode(bytes, allowMalformed: true);
                debugPrint('[BLE RX] $str');
                _dataController.add(str);
              } catch (e) {
                debugPrint('[BLE RX] decode error: $e');
              }
            });
          }
        }
        break;
      }
    }
  }

  // ─── Gửi lệnh JSON lên ESP32 ─────────────────────────────────
  Future<bool> sendJson(Map<String, dynamic> payload) async {
    if (_rxChar == null || !isConnected) return false;
    try {
      final bytes = utf8.encode(jsonEncode(payload));
      await _rxChar!.write(bytes, withoutResponse: true);
      return true;
    } catch (e) {
      debugPrint('[BLE TX] Lỗi gửi: $e');
      return false;
    }
  }

  Future<bool> sendData(List<int> data) async {
    if (_rxChar == null || !isConnected) return false;
    try {
      await _rxChar!.write(data, withoutResponse: true);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> syncTime() async {
    final now = DateTime.now();
    return sendJson({
      'cmd': 'SET_TIME',
      'params': {
        'year': now.year, 'month': now.month, 'day': now.day,
        'hour': now.hour, 'minute': now.minute, 'second': now.second,
      }
    });
  }

  // ─── Disconnect ───────────────────────────────────────────────
  Future<void> disconnect() async {
    stopScan();
    await _btDevice?.disconnect();
    _cleanup();
    _setState(BleConnectionState.disconnected);
  }

  void _cleanup() {
    _notifySubscription?.cancel();
    _connSubscription?.cancel();
    _notifySubscription = null;
    _connSubscription = null;
    _rxChar = null;
    _txChar = null;
    _btDevice = null;
    device = null;
  }

  @override
  void dispose() {
    stopScan();
    _cleanup();
    _dataController.close();
    super.dispose();
  }
}
