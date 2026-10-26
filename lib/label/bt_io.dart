import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'bt_api.dart';

bool get btSupported => Platform.isAndroid || Platform.isWindows;

Future<List<BtDevice>> btPaired() async {
  if (!btSupported) return [];
  if (Platform.isAndroid) {
    // Android 12+ : demander l'autorisation « Appareils à proximité ».
    await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!granted) {
      throw Exception('Autorisez « Appareils à proximité » pour ETIKPRO dans les paramètres.');
    }
  }
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return list.map((e) => BtDevice(e.name, e.macAdress)).toList();
}

/// Envoie les octets à l'imprimante. Renvoie null si OK, sinon le message d'erreur.
Future<String?> btSend(String address, List<int> bytes) async {
  if (!btSupported) return 'Bluetooth indisponible sur cette plateforme';
  if (Platform.isAndroid && !await PrintBluetoothThermal.bluetoothEnabled) {
    return 'Activez le Bluetooth du téléphone.';
  }
  var connected = await PrintBluetoothThermal.connectionStatus;
  if (!connected) {
    connected = await PrintBluetoothThermal.connect(macPrinterAddress: address);
  }
  if (!connected) return "Connexion à l'imprimante impossible. Est-elle allumée ?";
  // Envoi par paquets pour ne pas saturer le tampon de l'imprimante.
  const chunk = 4096;
  for (var i = 0; i < bytes.length; i += chunk) {
    final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
    final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
    if (!ok) return "Échec d'envoi à l'imprimante.";
  }
  return null;
}
