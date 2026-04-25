import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:app_parcial/services/bluetooth_service.dart';
import 'package:app_parcial/widget/conexion_bluetooth.dart';

// Paleta de colores consistente
const _bgDark = Color(0xFF0D1117);
const _bgCard = Color(0xFF161B22);
const _accent = Color(0xFF00E5FF);
const _textMain = Color(0xFFE6EDF3);
const _textDim = Color(0xFF8B949E);

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

  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _bluetoothTimer; // Timer para el Debounce del Slider

  BluetoothDevice? get device => bluetoothService.connectedDevice;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() {
    isConnected = bluetoothService.isConnected;
    _dataSubscription = bluetoothService.dataStream.listen(_onDataReceived);
    _statusSubscription = bluetoothService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => isConnected = status == BluetoothService.connected);
      if (status == BluetoothService.disconnected && !_isNavigating) {
        _isNavigating = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConexionBluetooth()),
        );
      }
    });

    if (isConnected) {
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _sendMessage("M1"),
      );
    }
  }

  void _onDataReceived(Uint8List data) {
    final dataString = ascii.decode(data, allowInvalid: true);
    _buffer += dataString;
    while (_buffer.contains('\n')) {
      final parts = _buffer.split('\n');
      final cmd = parts.first.trim();
      _buffer = parts.sublist(1).join('\n');
      if (cmd.startsWith("P") && _currentMode == 0) {
        try {
          final val = int.parse(cmd.substring(1));
          if (mounted) setState(() => _potentiometerValue = val.clamp(0, 255));
        } catch (_) {}
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (!isConnected) return;
    await bluetoothService.sendMessage(text);
  }

  void _changeMode(int index) {
    if (!isConnected) return;
    setState(() => _currentMode = index);
    if (index == 0) {
      _sendMessage("M1");
    } else {
      _sendMessage("M2");
      _sendMessage("V${_appSliderValue.toInt()}");
    }
  }

  Color _getIntensityColor(int value) {
    if (value < 60) return const Color(0xFF00E676);
    if (value < 140) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }

  Future<void> _disconnectAndReturn() async {
    if (_isNavigating) return;
    _isNavigating = true;
    _bluetoothTimer?.cancel();
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
    _bluetoothTimer?.cancel();
    _dataSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  // --- COMPONENTES ---

  Widget _buildGauge(double value, Color color) {
    // AJUSTE DE ESCALA: Cambia 180 por el valor máximo real de tu sensor para llegar al 100%
    const double maxRealValue = 180.0;
    double displayValue = (value / maxRealValue).clamp(0.0, 1.0);
    double percentage = displayValue * 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 210,
          height: 210,
          child: CircularProgressIndicator(
            value: displayValue,
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            backgroundColor: _bgCard,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${percentage.toStringAsFixed(1)}%",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: _textMain,
                letterSpacing: -2,
              ),
            ),
            Text(
              "POTENCIA",
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _textDim, fontSize: 13),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- VISTAS ---

  Widget _buildPhysicalMode() {
    final intensityColor = _getIntensityColor(_potentiometerValue);
    final voltaje = _potentiometerValue * (5.0 / 255.0);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 40),
        _buildGauge(_potentiometerValue.toDouble(), intensityColor),
        const SizedBox(height: 40),
        _buildDataCard(
          label: "VALOR PWM (RAW)",
          value: "$_potentiometerValue",
          icon: Icons.memory,
          color: _accent,
        ),
        _buildDataCard(
          label: "VOLTAJE",
          value: "${voltaje.toStringAsFixed(2)} V",
          icon: Icons.bolt,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildAppMode() {
    final intensityColor = _getIntensityColor(_appSliderValue.toInt());
    final voltaje = _appSliderValue * (5.0 / 255.0);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 40),
        _buildGauge(_appSliderValue, intensityColor),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _accent.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const Text(
                "CONTROL DESLIZANTE",
                style: TextStyle(
                  color: _textDim,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _accent,
                  inactiveTrackColor: _bgDark,
                  thumbColor: Colors.white,
                  trackHeight: 8,
                ),
                child: Slider(
                  value: _appSliderValue,
                  min: 0,
                  max: 255,
                  onChanged: (v) {
                    setState(() => _appSliderValue = v);
                    // TIMER (Debounce) para evitar saturación y lag
                    if (_bluetoothTimer?.isActive ?? false)
                      _bluetoothTimer!.cancel();
                    _bluetoothTimer = Timer(
                      const Duration(milliseconds: 80),
                      () {
                        _sendMessage("V${v.toInt()}");
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDataCard(
          label: "SALIDA CALCULADA",
          value: "${voltaje.toStringAsFixed(2)} V",
          icon: Icons.bolt,
          color: Colors.amber,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device?.name ?? "HC-05",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textMain,
              ),
            ),
            Text(
              isConnected ? "SISTEMA EN LÍNEA" : "RECONECTANDO...",
              style: TextStyle(
                fontSize: 10,
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: _disconnectAndReturn,
          ),
        ],
      ),
      body: !isConnected
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : (_currentMode == 0 ? _buildPhysicalMode() : _buildAppMode()),
      bottomNavigationBar: Container(
        height: 85,
        decoration: const BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _currentMode,
            onTap: _changeMode,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: _accent,
            unselectedItemColor: _textDim.withOpacity(0.5),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                label: 'MONITOR',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_remote),
                label: 'CONTROL',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
