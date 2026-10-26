import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'bt_api.dart';

bool get btSupported => Platform.isAndroid || Platform.isWindows;

String? _connectedTo;

Future<void> _ensurePermission() async {
  if (!Platform.isAndroid) return;
  // Android 12+ : autorisation « Appareils à proximité ».
  await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
  final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
  if (!granted) {
    throw Exception('Autorisez « Appareils à proximité » pour ETIKPRO dans les paramètres.');
  }
}

Future<bool> btEnabled() async {
  if (!btSupported) return false;
  if (Platform.isWindows) return true;
  return PrintBluetoothThermal.bluetoothEnabled;
}

/// Imprimantes déjà appairées avec le téléphone / PC.
Future<List<BtDevice>> btPaired() async {
  if (!btSupported) return [];
  await _ensurePermission();
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return list.map((e) => BtDevice(e.name, e.macAdress)).toList();
}

Future<bool> btIsConnected() async {
  if (!btSupported) return false;
  final ok = await PrintBluetoothThermal.connectionStatus;
  if (!ok) _connectedTo = null;
  return ok;
}

Future<void> btDisconnect() async {
  if (!btSupported) return;
  await PrintBluetoothThermal.disconnect;
  _connectedTo = null;
}

/// Connecte l'imprimante (change d'imprimante si besoin). Renvoie null si OK.
Future<String?> btConnect(String address) async {
  if (!btSupported) return 'Bluetooth indisponible sur cette plateforme';
  try {
    await _ensurePermission();
  } catch (e) {
    return '$e'.replaceFirst('Exception: ', '');
  }
  if (!await btEnabled()) return 'Activez le Bluetooth.';
  if (await btIsConnected()) {
    if (_connectedTo == address) return null;
    await btDisconnect();
  }
  final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address);
  if (!ok) return "Connexion impossible. Vérifiez que l'imprimante est allumée et à proximité.";
  _connectedTo = address;
  return null;
}

/// Ouvre les réglages Bluetooth du système (pour appairer une nouvelle imprimante).
Future<void> btOpenSystemSettings() async {
  if (Platform.isAndroid) {
    await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', 'ms-settings:bluetooth']);
  }
}

/// Envoie les octets à l'imprimante. Renvoie null si OK, sinon le message d'erreur.
Future<String?> btSend(String address, List<int> bytes) async {
  final err = await btConnect(address);
  if (err != null) return err;
  // Envoi par paquets pour ne pas saturer le tampon de l'imprimante.
  const chunk = 4096;
  for (var i = 0; i < bytes.length; i += chunk) {
    final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
    final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
    if (!ok) {
      _connectedTo = null;
      return "Échec d'envoi à l'imprimante (connexion perdue). Réessayez.";
    }
  }
  return null;
}
