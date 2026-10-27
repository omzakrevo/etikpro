import 'bt_api.dart';

/// Web : pas d'accès Bluetooth direct, on imprime via le navigateur.
bool get btSupported => false;

enum BtPermission { granted, denied, permanentlyDenied }

class BtPermissionException implements Exception {
  final bool permanent;
  BtPermissionException(this.permanent);
}

Future<BtPermission> btRequestPermission({bool forBleScan = false}) async => BtPermission.denied;
Future<void> btOpenAppPermissions() async {}
Future<List<BtDevice>> btPaired() async => [];
Stream<List<BtDevice>> btScanBle({Duration duration = const Duration(seconds: 8)}) => const Stream.empty();
Future<void> btStopScan() async {}
Future<String?> btConnect(String address, {bool ble = false}) async =>
    'Bluetooth indisponible sur cette plateforme';
Future<bool> btIsConnected() async => false;
Future<void> btDisconnect() async {}
Future<void> btOpenSystemSettings() async {}
Future<bool?> btEnabled() async => false;
Future<String?> btSend(String address, List<int> bytes, {bool ble = false}) async =>
    'Bluetooth indisponible sur cette plateforme';
