import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopCoordinate {
  final double latitude;
  final double longitude;
  const ShopCoordinate(this.latitude, this.longitude);
}

class ShopDistance {
  final double meters;
  final Position position;
  const ShopDistance(this.meters, this.position);
  String get label => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '${meters.round()} m';
}

class ForegroundLocationService {
  StreamSubscription<Position>? _subscription;
  final _updates = StreamController<ShopDistance>.broadcast();
  Stream<ShopDistance> get updates => _updates.stream;

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  Future<void> saveShopLocation(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('shop_latitude', position.latitude);
    await prefs.setDouble('shop_longitude', position.longitude);
  }

  Future<ShopCoordinate?> shopLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('shop_latitude');
    final lng = prefs.getDouble('shop_longitude');
    if (lat == null || lng == null) return null;
    return ShopCoordinate(lat, lng);
  }

  Future<Position?> currentPosition() async {
    if (!await ensurePermission()) return null;
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20));
  }

  Future<bool> start() async {
    if (!await ensurePermission()) return false;
    final shop = await shopLocation();
    if (shop == null) return false;
    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20)).listen((position) {
      final meters = Geolocator.distanceBetween(shop.latitude, shop.longitude, position.latitude, position.longitude);
      _updates.add(ShopDistance(meters, position));
    });
    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _subscription?.cancel();
    _updates.close();
  }
}
