import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:app_parcial/screens/control_screen.dart';
import 'package:app_parcial/services/bluetooth_service.dart';

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

    setState(() {
      conectando = true;
    });

    try {
      final List<BluetoothDevice> devices = await _bluetoothService
          .getPairedDevices();

      final BluetoothDevice hc = devices.firstWhere(
        (d) => d.name != null && d.name!.toUpperCase().contains("HC"),
        orElse: () => throw Exception("HC-05 no encontrado"),
      );

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conexión Bluetooth"),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              conectado ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 100,
              color: conectado ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              conectando
                  ? "CONECTANDO..."
                  : conectado
                  ? "DISPOSITIVO CONECTADO"
                  : "DISPOSITIVO DESCONECTADO",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: conectando
                    ? Colors.orange
                    : conectado
                    ? Colors.green
                    : Colors.red,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: conectando || conectado ? null : conectar,
                icon: const Icon(Icons.bluetooth_audio),
                label: Text(
                  conectando
                      ? "CONECTANDO..."
                      : conectado
                      ? "VINCULADO"
                      : "CONECTAR HC-05",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
