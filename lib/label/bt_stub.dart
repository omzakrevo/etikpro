import 'bt_api.dart';

/// Web : pas d'accès Bluetooth direct, on imprime via le navigateur.
bool get btSupported => false;
Future<List<BtDevice>> btPaired() async => [];
Future<String?> btConnect(String address) async => 'Bluetooth indisponible sur cette plateforme';
Future<bool> btIsConnected() async => false;
Future<void> btDisconnect() async {}
Future<void> btOpenSystemSettings() async {}
Future<bool> btEnabled() async => false;
Future<String?> btSend(String address, List<int> bytes) async =>
    'Bluetooth indisponible sur cette plateforme';
