import 'bt_api.dart';

/// Web : pas d'accès Bluetooth direct, on imprime via le navigateur.
bool get btSupported => false;
Future<List<BtDevice>> btPaired() async => [];
Future<String?> btSend(String address, List<int> bytes) async =>
    'Bluetooth indisponible sur cette plateforme';
