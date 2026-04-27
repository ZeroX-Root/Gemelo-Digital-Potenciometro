import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:app_parcial/services/bluetooth_service.dart';
import 'package:app_parcial/widget/conexion_bluetooth.dart';

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

  // ── Logs ──────────────────────────────────────────
  final List<String> _logs = [];
  final ScrollController _logScroll = ScrollController();
  bool _showLogs = false;

  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _bluetoothTimer;

  BluetoothDevice? get device => bluetoothService.connectedDevice;

  void _log(String msg) {
    final time = DateTime.now();
    final label =
        "[${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}]";
    final line = "$label $msg";
    if (!mounted) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > 100) _logs.removeAt(0); // máximo 100 líneas
    });
    // Auto-scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() {
    isConnected = bluetoothService.isConnected;
    _log(
      isConnected
          ? "✅ BT conectado al iniciar"
          : "❌ BT no conectado al iniciar",
    );

    _dataSubscription = bluetoothService.dataStream.listen(_onDataReceived);
    _statusSubscription = bluetoothService.statusStream.listen((status) {
      if (!mounted) return;
      final connected = status == BluetoothService.connected;
      _log(connected ? "✅ Estado: conectado" : "❌ Estado: desconectado");
      setState(() => isConnected = connected);
      if (status == BluetoothService.disconnected && !_isNavigating) {
        _isNavigating = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConexionBluetooth()),
        );
      }
    });

    if (isConnected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _log("📤 Enviando: M1");
        _sendMessage("M1");
      });
    }
  }

  void _onDataReceived(Uint8List data) {
    _buffer += ascii.decode(data, allowInvalid: true);

    while (_buffer.contains('\n')) {
      final idx = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);

      if (line.isEmpty) continue;

      _log("📥 Recibido: '$line'");

      if (line.startsWith('P') && _currentMode == 0) {
        final val = int.tryParse(line.substring(1));
        if (val != null) {
          _log("🎛️ Potenciómetro: $val");
          if (mounted) setState(() => _potentiometerValue = val.clamp(0, 255));
        } else {
          _log("⚠️ No se pudo parsear valor P: '${line.substring(1)}'");
        }
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (!isConnected) {
      _log("⚠️ Intento de envío sin conexión: $text");
      return;
    }
    _log("📤 Enviando: $text");
    await bluetoothService.sendMessage(text);
  }

  void _changeMode(int index) {
    if (!isConnected) return;
    setState(() {
      _currentMode = index;
      _buffer = "";
    });
    _log("🔄 Modo cambiado a: ${index == 0 ? 'FÍSICO' : 'APP'}");
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
    _logScroll.dispose();
    super.dispose();
  }

  // ── Panel de logs ──────────────────────────────────
  Widget _buildLogPanel() {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: _accent, size: 14),
                const SizedBox(width: 8),
                const Text(
                  "LOGS EN TIEMPO REAL",
                  style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                // Botón limpiar
                GestureDetector(
                  onTap: () => setState(() => _logs.clear()),
                  child: const Text(
                    "LIMPIAR",
                    style: TextStyle(color: _textDim, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          // Lista de logs
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      "Sin logs aún...",
                      style: TextStyle(color: _textDim, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _logScroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      Color color = _textDim;
                      if (log.contains('✅')) color = Colors.green;
                      if (log.contains('❌')) color = Colors.redAccent;
                      if (log.contains('⚠️')) color = Colors.amber;
                      if (log.contains('📥')) color = const Color(0xFF00E5FF);
                      if (log.contains('📤')) color = Colors.purpleAccent;
                      if (log.contains('🎛️')) color = Colors.greenAccent;
                      return Text(
                        log,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Gauge ──────────────────────────────────────────
  Widget _buildGauge(double value, Color color) {
    const double maxRealValue = 255.0; // ✅ corregido
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

  // ── Modos ──────────────────────────────────────────
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
        if (_showLogs) _buildLogPanel(),
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
                    _bluetoothTimer?.cancel();
                    _bluetoothTimer = Timer(
                      const Duration(milliseconds: 150),
                      () => _sendMessage("V${v.toInt()}"),
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
        if (_showLogs) _buildLogPanel(),
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
          // ── Botón toggle logs ──
          IconButton(
            icon: Icon(Icons.terminal, color: _showLogs ? _accent : _textDim),
            tooltip: "Ver logs",
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),
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
