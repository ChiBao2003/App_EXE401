import 'dart:convert';

/// Accepts existing single-notification JSON and MTU-sized firmware fragments.
/// Header: 0x1e, transfer sequence, zero-based fragment index, fragment count.
class BleJsonAssembler {
  int? _sequence;
  int _count = 0;
  int _next = 0;
  final List<int> _bytes = [];

  void reset() {
    _sequence = null;
    _count = 0;
    _next = 0;
    _bytes.clear();
  }

  String? add(List<int> bytes) {
    if (bytes.isEmpty) return null;
    if (bytes.first != 0x1e) return utf8.decode(bytes);
    if (bytes.length < 5) {
      reset();
      return null;
    }
    final sequence = bytes[1], index = bytes[2], count = bytes[3];
    if (index == 0) {
      reset();
      _sequence = sequence;
      _count = count;
    }
    if (count == 0 ||
        sequence != _sequence ||
        count != _count ||
        index != _next) {
      reset();
      return null; // ESP32 retries the complete transfer when no ACK arrives.
    }
    _bytes.addAll(bytes.skip(4));
    if (_bytes.length > 2048) {
      reset();
      return null;
    }
    _next++;
    if (_next != _count) return null;
    try {
      return utf8.decode(_bytes);
    } finally {
      reset();
    }
  }
}
