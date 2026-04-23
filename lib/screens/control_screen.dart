import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:app_parcial/services/bluetooth_service.dart';
import 'package:app_parcial/widget/conexion_bluetooth.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({Key? key}) : super(key: key);

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final BluetoothService bluetoothService = BluetoothService();

  bool isConnected = false;
  bool _isNavigating = false;

  int _currentMode = 0;
  int _potentiometerValue = 0;
  double _appSliderValue = 0;
  String _buffer = "";

  // 🔍 Logs en pantalla
  List<String> _logs = [];

  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;

  BluetoothDevice? get device => bluetoothService.connectedDevice;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() {
    isConnected = bluetoothService.isConnected;
    _currentMode = 0;

    _dataSubscription = bluetoothService.dataStream.listen((data) {
      _onDataReceived(data);
    });

    _statusSubscription = bluetoothService.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        isConnected = status == BluetoothService.connected;
      });

      if (status == BluetoothService.disconnected && !_isNavigating) {
        _isNavigating = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dispositivo desconectado")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConexionBluetooth()),
        );
      }
    });

    if (isConnected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendMessage("M1");
      });
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(msg);
      if (_logs.length > 10) _logs.removeAt(0);
    });
  }

  void _onDataReceived(Uint8List data) {
    final dataString = ascii.decode(data, allowInvalid: true);
    _addLog("RAW: '$dataString'");

    _buffer += dataString;

    while (_buffer.contains('\n')) {
      final parts = _buffer.split('\n');
      final cmd = parts.first.trim();
      _buffer = parts.sublist(1).join('\n');

      _addLog("CMD: '$cmd' | modo: $_currentMode");

      if (cmd.startsWith("P") && _currentMode == 0) {
        try {
          final val = int.parse(cmd.substring(1));
          _addLog("POT: $val");
          if (mounted) {
            setState(() {
              _potentiometerValue = val.clamp(0, 255);
            });
          }
        } catch (e) {
          _addLog("ERROR: $e");
        }
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (!isConnected) return;
    _addLog("SEND: '$text'");
    await bluetoothService.sendMessage(text);
  }

  void _changeMode(int index) {
    if (!isConnected) return;

    setState(() {
      _currentMode = index;
    });

    if (index == 0) {
      _sendMessage("M1");
    } else {
      _sendMessage("M2");
      _sendMessage("V${_appSliderValue.toInt()}");
    }
  }

  Color _getIntensityColor(int value) {
    if (value < 85) return Colors.green;
    if (value < 170) return Colors.yellow;
    return Colors.red;
  }

  Future<void> _disconnectAndReturn() async {
    if (_isNavigating) return;
    _isNavigating = true;

    await _dataSubscription?.cancel();
    await _statusSubscription?.cancel();
    await bluetoothService.disconnect();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConexionBluetooth()),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Widget _buildLogPanel() {
    return Container(
      height: 150,
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "🔍 Logs BT",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _logs.clear()),
                child: const Text(
                  "limpiar",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: _logs
                  .map(
                    (l) => Text(
                      l,
                      style: TextStyle(
                        color: l.startsWith("ERROR")
                            ? Colors.red
                            : l.startsWith("SEND")
                            ? Colors.yellow
                            : Colors.green,
                        fontSize: 10,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalMode() {
    final percentage = (_potentiometerValue / 255) * 100;
    final intensityColor = _getIntensityColor(_potentiometerValue);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Modo Potenciómetro (Físico)",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          "El Arduino está leyendo el potenciómetro y controlando el motor.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
        const SizedBox(height: 40),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: _potentiometerValue / 255,
                strokeWidth: 20,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(intensityColor),
              ),
            ),
            Column(
              children: [
                Text(
                  "${percentage.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: intensityColor,
                  ),
                ),
                const Text("Intensidad"),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        Icon(Icons.speed, size: 80, color: intensityColor),
      ],
    );
  }

  Widget _buildAppMode() {
    final percentage = (_appSliderValue / 255) * 100;
    final intensityColor = _getIntensityColor(_appSliderValue.toInt());

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Modo Aplicación (Virtual)",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          "Controla la intensidad del motor desde aquí.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
        const SizedBox(height: 40),
        Text(
          "${percentage.toStringAsFixed(1)}%",
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: intensityColor,
          ),
        ),
        const SizedBox(height: 20),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: intensityColor,
            thumbColor: intensityColor,
            overlayColor: intensityColor.withAlpha(50),
          ),
          child: Slider(
            value: _appSliderValue,
            min: 0,
            max: 255,
            onChanged: (value) {
              setState(() {
                _appSliderValue = value;
              });
            },
            onChangeEnd: (value) {
              if (_currentMode == 1) {
                _sendMessage("V${value.toInt()}");
              }
            },
          ),
        ),
        const SizedBox(height: 40),
        Icon(Icons.touch_app, size: 80, color: intensityColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = device?.name ?? "Dispositivo";

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _disconnectAndReturn,
            icon: const Icon(Icons.logout),
            tooltip: "Desconectar",
          ),
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: !isConnected
          ? const Center(child: Text("Dispositivo desconectado"))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _currentMode == 0
                        ? _buildPhysicalMode()
                        : _buildAppMode(),
                  ),
                ),
                _buildLogPanel(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentMode,
        onTap: _changeMode,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: 'Potenciómetro (Físico)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smartphone),
            label: 'App (Virtual)',
          ),
        ],
      ),
    );
  }
}
