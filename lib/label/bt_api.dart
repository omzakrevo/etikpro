class BtDevice {
  final String name;
  final String address;

  /// true = Bluetooth Low Energy (BLE), false = Bluetooth classique (SPP).
  final bool ble;

  /// classic | le | dual | unknown (Android), ou 'ble' pour un appareil trouvé par recherche BLE.
  final String type;

  /// Puissance du signal (BLE uniquement), pour trier les appareils proches.
  final int rssi;

  const BtDevice(this.name, this.address, {this.ble = false, this.type = '', this.rssi = 0});
}
