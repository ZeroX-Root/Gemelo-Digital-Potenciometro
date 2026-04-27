import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_parcial/screens/control_screen.dart';
import 'package:app_parcial/services/bluetooth_service.dart';

const _bgDark = Color(0xFF0D1117);
const _bgCard = Color(0xFF161B22);
const _accent = Color(0xFF00E5FF);
const _textMain = Color(0xFFE6EDF3);
const _textDim = Color(0xFF8B949E);

class ConexionBluetooth extends StatefulWidget {
  const ConexionBluetooth({super.key});

  @override
  State<ConexionBluetooth> createState() => _ConexionBluetoothState();
}

class _ConexionBluetoothState extends State<ConexionBluetooth> {
  final BluetoothService _bluetoothService = BluetoothService();
  bool conectado = false;
  bool conectando = false;

  Future<void> conectar() async {
    if (conectando) return;
    setState(() => conectando = true);

    try {
      // 1. Pedir permisos uno por uno (Android 12+)
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      if (await Permission.location.isDenied) {
        await Permission.location.request();
      }

      // 2. Verificar que estén concedidos
      final btScan = await Permission.bluetoothScan.isGranted;
      final btConnect = await Permission.bluetoothConnect.isGranted;

      if (!btScan || !btConnect) {
        final anyPermanent =
            await Permission.bluetoothScan.isPermanentlyDenied ||
            await Permission.bluetoothConnect.isPermanentlyDenied;
        if (anyPermanent) await openAppSettings();
        throw Exception(
          "Activa 'Dispositivos Cercanos' en Ajustes → Apps → Permisos",
        );
      }

      // 3. Verificar Bluetooth encendido
      final btState = await FlutterBluetoothSerial.instance.state;
      if (btState != BluetoothState.STATE_ON) {
        await FlutterBluetoothSerial.instance.requestEnable();
        throw Exception("Activa el Bluetooth e intenta de nuevo");
      }

      // 4. Obtener dispositivos vinculados
      final List<BluetoothDevice> devices = await _bluetoothService
          .getPairedDevices();

      if (devices.isEmpty) {
        throw Exception(
          "No hay dispositivos vinculados. Vincula el HC-05 primero en Ajustes",
        );
      }

      // 5. Buscar HC-05
      final BluetoothDevice hc = devices.firstWhere(
        (d) => d.name != null && d.name!.toUpperCase().contains("HC"),
        orElse: () => throw Exception(
          "HC-05 no encontrado. Asegúrate de que esté vinculado",
        ),
      );

      // 6. Conectar
      await _bluetoothService.connect(hc);

      if (!mounted) return;
      setState(() {
        conectado = true;
        conectando = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        conectado = false;
        conectando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [_accent.withOpacity(0.1), _bgDark],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusIcon(),
            const SizedBox(height: 40),
            const Text(
              "SISTEMA DE CONTROL",
              style: TextStyle(
                color: _accent,
                letterSpacing: 4,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              conectando
                  ? "VINCULANDO HARDWARE..."
                  : (conectado ? "CONECTADO" : "DISPOSITIVO DESCONECTADO"),
              style: const TextStyle(
                color: _textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 80),
            _buildConnectButton(),
            const SizedBox(height: 20),
            const Text(
              "V 1.0.2 - Dev Logic Protocol",
              style: TextStyle(color: Color(0xFF30363D), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (conectando)
          const SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _bgCard,
            shape: BoxShape.circle,
            border: Border.all(
              color: conectando
                  ? _accent
                  : (conectado ? Colors.green : Colors.red.withOpacity(0.5)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (conectando
                            ? _accent
                            : (conectado ? Colors.green : Colors.red))
                        .withOpacity(0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Icon(
            conectado ? Icons.bluetooth_connected : Icons.bluetooth_audio,
            size: 80,
            color: conectado ? Colors.green : (conectando ? _accent : _textDim),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: conectando || conectado ? null : conectar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: _bgDark,
            disabledBackgroundColor: _bgCard,
            elevation: 8,
            shadowColor: _accent.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: conectando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _bgDark,
                    strokeWidth: 3,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, size: 18),
                    SizedBox(width: 10),
                    Text(
                      "CONECTAR HC-05",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
