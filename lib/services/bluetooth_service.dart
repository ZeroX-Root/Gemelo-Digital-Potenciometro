import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothService._internal();

  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() => _instance;

  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;

  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();

  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<int> get statusStream => _statusController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;

  // Estados compatibles con el código existente
  static const int connected = 1;
  static const int disconnected = 0;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      _isConnected = true;

      if (!_statusController.isClosed) {
        _statusController.add(connected);
      }

      // Escuchar datos entrantes
      _connection!.input!
          .listen((Uint8List data) {
            if (!_dataController.isClosed) {
              _dataController.add(data);
            }
          })
          .onDone(() {
            // Conexión cerrada por el otro lado
            _isConnected = false;
            _connectedDevice = null;
            if (!_statusController.isClosed) {
              _statusController.add(disconnected);
            }
          });
    } catch (e) {
      _isConnected = false;
      _connectedDevice = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _isConnected = false;
    _connectedDevice = null;
  }

  Future<void> sendMessage(String message) async {
    if (!_isConnected || _connection == null) return;
    _connection!.output.add(
      Uint8List.fromList("${message.trim()}\n".codeUnits),
    );
    await _connection!.output.allSent;
  }

  Future<void> dispose() async {
    await _connection?.close();
    await _dataController.close();
    await _statusController.close();
    _isConnected = false;
    _connectedDevice = null;
  }
}
