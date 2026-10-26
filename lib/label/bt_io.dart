import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'bt_api.dart';

bool get btSupported => Platform.isAndroid || Platform.isWindows;

String? _connectedTo;
const _channel = MethodChannel('groons.web.app/print');

/// Résultat de la vérification des autorisations Bluetooth.
enum BtPermission { granted, denied, permanentlyDenied }

/// Android 12+ : autorisation « Appareils à proximité » (BLUETOOTH_CONNECT + BLUETOOTH_SCAN).
/// Elle doit être accordée AVANT tout autre appel Bluetooth, sinon Android refuse de
/// répondre (et le Bluetooth paraît « désactivé » alors qu'il est allumé).
Future<BtPermission> btRequestPermission() async {
  if (!Platform.isAndroid) return BtPermission.granted;
  final res = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
  if (res.values.every((s) => s.isGranted || s.isLimited)) return BtPermission.granted;
  // Repli : demande via le plugin d'impression
  try {
    if (await PrintBluetoothThermal.isPermissionBluetoothGranted) return BtPermission.granted;
  } catch (_) {}
  if (res.values.any((s) => s.isPermanentlyDenied)) return BtPermission.permanentlyDenied;
  return BtPermission.denied;
}

Future<void> btOpenAppPermissions() => openAppSettings();

/// Le Bluetooth est-il allumé ? (null = impossible à savoir)
Future<bool?> btEnabled() async {
  if (!btSupported) return false;
  if (Platform.isWindows) return true;
  try {
    final r = await _channel.invokeMethod<bool>('bluetoothenabled');
    return r;
  } on PlatformException catch (e) {
    if (e.code == 'PERMISSION_DENIED') return null;
    return null;
  } catch (_) {
    return null;
  }
}

/// Imprimantes déjà appairées avec le téléphone / PC.
/// Lève une exception claire si l'autorisation est refusée.
Future<List<BtDevice>> btPaired() async {
  if (!btSupported) return [];
  final perm = await btRequestPermission();
  if (perm != BtPermission.granted) {
    throw BtPermissionException(perm == BtPermission.permanentlyDenied);
  }
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return list.map((e) => BtDevice(e.name, e.macAdress)).toList();
}

class BtPermissionException implements Exception {
  final bool permanent;
  BtPermissionException(this.permanent);
  @override
  String toString() => permanent
      ? 'L’autorisation « Appareils à proximité » est bloquée. Ouvrez les autorisations d’ETIKPRO et activez-la.'
      : 'Autorisez « Appareils à proximité » pour qu’ETIKPRO trouve l’imprimante.';
}

Future<bool> btIsConnected() async {
  if (!btSupported) return false;
  try {
    final ok = await PrintBluetoothThermal.connectionStatus;
    if (!ok) _connectedTo = null;
    return ok;
  } catch (_) {
    return false;
  }
}

Future<void> btDisconnect() async {
  if (!btSupported) return;
  try {
    await PrintBluetoothThermal.disconnect;
  } catch (_) {}
  _connectedTo = null;
}

/// Connecte l'imprimante (change d'imprimante si besoin). Renvoie null si OK.
Future<String?> btConnect(String address) async {
  if (!btSupported) return 'Bluetooth indisponible sur cette plateforme';
  final perm = await btRequestPermission();
  if (perm != BtPermission.granted) return BtPermissionException(perm == BtPermission.permanentlyDenied).toString();
  if (await btEnabled() == false) return 'Le Bluetooth est éteint. Allumez-le puis réessayez.';
  if (await btIsConnected()) {
    if (_connectedTo == address) return null;
    await btDisconnect();
  }
  bool ok = false;
  // 2 tentatives : certaines imprimantes refusent la 1re connexion juste après l'allumage
  for (var i = 0; i < 2 && !ok; i++) {
    try {
      ok = await PrintBluetoothThermal.connect(macPrinterAddress: address)
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
    } catch (_) {
      ok = false;
    }
    if (!ok && i == 0) await Future.delayed(const Duration(milliseconds: 800));
  }
  if (!ok) {
    return "Connexion impossible. Vérifiez que l'imprimante est allumée, à proximité, "
        "et qu'elle n'est pas déjà connectée à un autre téléphone.";
  }
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
  const chunk = 2048;
  for (var i = 0; i < bytes.length; i += chunk) {
    final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
    bool ok;
    try {
      ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      _connectedTo = null;
      return "Échec d'envoi à l'imprimante (connexion perdue). Réessayez.";
    }
  }
  return null;
}
