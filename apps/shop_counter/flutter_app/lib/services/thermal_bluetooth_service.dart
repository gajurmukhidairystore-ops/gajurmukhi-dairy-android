import 'dart:typed_data';
import 'package:print_bluetooth_thermal_plus/print_bluetooth_thermal.dart';
class ThermalBluetoothService {
 Future<List<BluetoothInfo>> devices()=>PrintBluetoothThermal.pairedBluetooths;
 Future<bool> connect(String mac)=>PrintBluetoothThermal.connect(macPrinterAddress: mac);
 Future<bool> printBytes(Uint8List bytes)=>PrintBluetoothThermal.writeBytes(bytes);
 Future<bool> disconnect()=>PrintBluetoothThermal.disconnect;
}
