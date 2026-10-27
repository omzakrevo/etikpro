import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'bt_api.dart';

/// Bluetooth des imprimantes :
/// - Android, Bluetooth classique : code natif ETIKPRO (MainActivity.kt), connexion avec
///   plusieurs méthodes de repli et envoi sans aucun octet parasite ;
/// - Android, Bluetooth Low Energy (BLE) : flutter_blue_plus ;
/// - Windows : module print_bluetooth_thermal.
bool get btSupported => Platform.isAndroid || Platform.isWindows;

const _classic = MethodChannel('etikpro/bt_classic');

enum BtPermission { granted, denied, permanentlyDenied }

class BtPermissionException implements Exception {
  final bool permanent;
  BtPermissionException(this.permanent);
  @override
  String toString() => permanent
      ? 'L’autorisation « Appareils à proximité » est bloquée. Ouvrez les autorisations d’ETIKPRO et activez-la.'
      : 'Autorisez « Appareils à proximité » pour qu’ETIKPRO trouve l’imprimante.';
}

int? _sdk;
Future<int> _androidSdk() async {
  if (_sdk != null) return _sdk!;
  try {
    _sdk = await _classic.invokeMethod<int>('sdk');
  } catch (_) {}
  return _sdk ?? 31;
}

/// Android 12+ : « Appareils à proximité » (BLUETOOTH_CONNECT + BLUETOOTH_SCAN).
/// Android 11 et moins : la localisation est nécessaire pour rechercher en BLE.
Future<BtPermission> btRequestPermission({bool forBleScan = false}) async {
  if (!Platform.isAndroid) return BtPermission.granted;
  final perms = [Permission.bluetoothConnect, Permission.bluetoothScan];
  final res = await perms.request();
  var ok = res.values.every((s) => s.isGranted || s.isLimited);
  if (forBleScan && await _androidSdk() < 31) {
    // Android 11 et moins : la recherche BLE exige la localisation.
    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) ok = false;
  }
  if (ok) return BtPermission.granted;
  if (res.values.any((s) => s.isPermanentlyDenied)) return BtPermission.permanentlyDenied;
  return BtPermission.denied;
}

Future<void> btOpenAppPermissions() => openAppSettings();

/// Le Bluetooth est-il allumé ? (null = inconnu)
Future<bool?> btEnabled() async {
  if (!btSupported) return false;
  if (Platform.isWindows) return true;
  try {
    return await _classic.invokeMethod<bool>('enabled');
  } catch (_) {
    return null;
  }
}

/// Appareils appairés (Bluetooth classique et BLE déjà associés).
Future<List<BtDevice>> btPaired() async {
  if (!btSupported) return [];
  if (Platform.isWindows) {
    final l = await PrintBluetoothThermal.pairedBluetooths;
    return l.map((e) => BtDevice(e.name, e.macAdress, ble: true, type: 'ble')).toList();
  }
  final perm = await btRequestPermission();
  if (perm != BtPermission.granted) throw BtPermissionException(perm == BtPermission.permanentlyDenied);
  final raw = await _classic.invokeListMethod<Map>('paired') ?? [];
  return raw.map((m) {
    final type = '${m['type']}';
    return BtDevice('${m['name']}', '${m['address']}', ble: type == 'le', type: type);
  }).toList();
}

/// Recherche des imprimantes Bluetooth Low Energy à proximité (Android).
Stream<List<BtDevice>> btScanBle({Duration duration = const Duration(seconds: 8)}) async* {
  if (!Platform.isAndroid) return;
  final perm = await btRequestPermission(forBleScan: true);
  if (perm != BtPermission.granted) throw BtPermissionException(perm == BtPermission.permanentlyDenied);
  if (!await fbp.FlutterBluePlus.isSupported) return;
  final found = <String, BtDevice>{};
  final ctrl = StreamController<List<BtDevice>>();
  final sub = fbp.FlutterBluePlus.onScanResults.listen((results) {
    for (final r in results) {
      final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
      if (name.isEmpty) continue; // ignore les appareils sans nom (balises, montres…)
      found[r.device.remoteId.str] = BtDevice(
        name,
        r.device.remoteId.str,
        ble: true,
        type: 'ble',
        rssi: r.rssi,
      );
    }
    final list = found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (!ctrl.isClosed) ctrl.add(list);
  });
  try {
    await fbp.FlutterBluePlus.startScan(timeout: duration);
  } catch (e) {
    await sub.cancel();
    throw Exception('Recherche BLE impossible : $e');
  }
  Timer(duration + const Duration(milliseconds: 300), () async {
    await sub.cancel();
    await ctrl.close();
  });
  yield* ctrl.stream;
}

Future<void> btStopScan() async {
  if (Platform.isAndroid) {
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// BLE : connexion et caractéristique d'écriture
// ---------------------------------------------------------------------------

fbp.BluetoothDevice? _bleDevice;
fbp.BluetoothCharacteristic? _bleChar;
String? _bleAddress;

/// Services / caractéristiques d'impression connus (imprimantes chinoises courantes).
const _knownChars = [
  '00002af1-0000-1000-8000-00805f9b34fb', // service 18F0 (ESC/POS BLE)
  '49535343-8841-43f4-a8d4-ecbe34729bb3', // ISSC / Microchip transparent UART
  'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f', // service E7810A71
  '0000ff02-0000-1000-8000-00805f9b34fb', // service FF00
  '0000ffe1-0000-1000-8000-00805f9b34fb', // service FFE0
  '0000fff2-0000-1000-8000-00805f9b34fb', // service FFF0
  '0000ae01-0000-1000-8000-00805f9b34fb', // service AE30 (mini imprimantes)
];
const _ignoredServices = ['1800', '1801', '180a', '180f', '1805'];

fbp.BluetoothCharacteristic? _pickWritable(List<fbp.BluetoothService> services) {
  final all = <fbp.BluetoothCharacteristic>[];
  for (final s in services) {
    final su = s.uuid.str128.toLowerCase();
    if (_ignoredServices.any((x) => su.startsWith('0000$x'))) continue;
    for (final c in s.characteristics) {
      if (c.properties.write || c.properties.writeWithoutResponse) all.add(c);
    }
  }
  for (final k in _knownChars) {
    for (final c in all) {
      if (c.uuid.str128.toLowerCase() == k) return c;
    }
  }
  // sinon : la 1re caractéristique « écriture sans réponse », puis « écriture »
  for (final c in all) {
    if (c.properties.writeWithoutResponse) return c;
  }
  return all.isEmpty ? null : all.first;
}

Future<String?> _bleConnect(String address) async {
  if (_bleAddress == address && _bleDevice != null && _bleChar != null && _bleDevice!.isConnected) {
    return null;
  }
  await _bleDisconnect();
  final dev = fbp.BluetoothDevice.fromId(address);
  try {
    await btStopScan();
    await dev.connect(timeout: const Duration(seconds: 15), mtu: 512);
  } catch (e) {
    return 'Connexion BLE impossible. Allumez l’imprimante, rapprochez-la et réessayez.';
  }
  try {
    final services = await dev.discoverServices();
    final c = _pickWritable(services);
    if (c == null) {
      await dev.disconnect();
      return 'Cette imprimante BLE n’expose pas de canal d’impression reconnu.';
    }
    _bleDevice = dev;
    _bleChar = c;
    _bleAddress = address;
    return null;
  } catch (e) {
    try {
      await dev.disconnect();
    } catch (_) {}
    return 'Connexion BLE interrompue ($e).';
  }
}

Future<void> _bleDisconnect() async {
  try {
    await _bleDevice?.disconnect();
  } catch (_) {}
  _bleDevice = null;
  _bleChar = null;
  _bleAddress = null;
}

Future<String?> _bleWrite(List<int> bytes) async {
  final c = _bleChar, d = _bleDevice;
  if (c == null || d == null) return 'Imprimante BLE non connectée.';
  final noResp = c.properties.writeWithoutResponse;
  // taille de paquet : MTU - 3, plafonnée pour les petites imprimantes
  final mtu = d.mtuNow;
  final size = (mtu - 3).clamp(20, noResp ? 180 : 500);
  try {
    for (var i = 0; i < bytes.length; i += size) {
      final end = i + size < bytes.length ? i + size : bytes.length;
      await c.write(bytes.sublist(i, end), withoutResponse: noResp, allowLongWrite: false);
      if (noResp) await Future.delayed(const Duration(milliseconds: 12));
    }
    return null;
  } catch (e) {
    await _bleDisconnect();
    return 'Envoi BLE interrompu. Réessayez.';
  }
}

// ---------------------------------------------------------------------------
// API commune
// ---------------------------------------------------------------------------

Future<bool> btIsConnected() async {
  if (!btSupported) return false;
  if (Platform.isWindows) return PrintBluetoothThermal.connectionStatus;
  if (_bleDevice != null && _bleDevice!.isConnected) return true;
  try {
    return await _classic.invokeMethod<bool>('isConnected') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> btDisconnect() async {
  if (!btSupported) return;
  if (Platform.isWindows) {
    await PrintBluetoothThermal.disconnect;
    return;
  }
  await _bleDisconnect();
  try {
    await _classic.invokeMethod('disconnect');
  } catch (_) {}
}

/// Connecte l'imprimante. Renvoie null si OK, sinon un message clair.
Future<String?> btConnect(String address, {bool ble = false}) async {
  if (!btSupported) return 'Bluetooth indisponible sur cette plateforme';
  if (Platform.isWindows) {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address);
    return ok ? null : "Connexion impossible. Vérifiez que l'imprimante est allumée.";
  }
  final perm = await btRequestPermission();
  if (perm != BtPermission.granted) {
    return BtPermissionException(perm == BtPermission.permanentlyDenied).toString();
  }
  if (await btEnabled() == false) return 'Le Bluetooth est éteint. Allumez-le puis réessayez.';
  if (ble) {
    try {
      await _classic.invokeMethod('disconnect');
    } catch (_) {}
    return _bleConnect(address);
  }
  await _bleDisconnect();
  try {
    return await _classic.invokeMethod<String>('connect', {'address': address});
  } on PlatformException catch (e) {
    return 'Connexion impossible (${e.message}).';
  }
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
Future<String?> btSend(String address, List<int> bytes, {bool ble = false}) async {
  final err = await btConnect(address, ble: ble);
  if (err != null) return err;
  if (Platform.isWindows) {
    // Windows passe par BLE : petits paquets
    for (var i = 0; i < bytes.length; i += 180) {
      final end = i + 180 < bytes.length ? i + 180 : bytes.length;
      if (!await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end))) {
        return "Échec d'envoi à l'imprimante.";
      }
    }
    return null;
  }
  if (ble) return _bleWrite(bytes);
  try {
    final r = await _classic.invokeMethod<String>('write', {
      'data': Uint8List.fromList(bytes),
      'chunk': 1024,
      'delayMs': 6,
    });
    if (r == null) return null;
    // 1 nouvelle tentative après reconnexion (imprimante mise en veille entre deux impressions)
    final again = await btConnect(address);
    if (again != null) return again;
    return await _classic.invokeMethod<String>('write', {
      'data': Uint8List.fromList(bytes),
      'chunk': 512,
      'delayMs': 10,
    });
  } on PlatformException catch (e) {
    return "Échec d'envoi (${e.message}).";
  }
}
