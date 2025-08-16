import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static Future<LatLng?> pickGymLocation(BuildContext context) async {
    LatLng? selected;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MapPickerScreen(onSelected: (latlng) => selected = latlng),
    ));
    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('gym_lat', selected!.latitude);
      await prefs.setDouble('gym_lng', selected!.longitude);
    }
    return selected;
  }

  static Future<LatLng?> getSavedGymLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('gym_lat');
    final lng = prefs.getDouble('gym_lng');
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }
}

class _MapPickerScreen extends StatefulWidget {
  final Function(LatLng) onSelected;
  const _MapPickerScreen({required this.onSelected});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  LatLng? picked;
  LatLng? _deviceLocation;
  bool _loading = true;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (kIsWeb) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _loading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _loading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _loading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _deviceLocation = LatLng(position.latitude, position.longitude);
      _loading = false;
    });
  }

  void _addMarkerFromTextFields() {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    if (latText.isNotEmpty && lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat != null && lng != null) {
        setState(() {
          picked = LatLng(lat, lng);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid latitude or longitude!'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select your gym location')),
        body: const Center(
          child: Text("Map not supported in web. Use the mobile app."),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_deviceLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select your gym location')),
        body: const Center(
          child: Text("Could not get device location."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select your gym location')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Latitude",
                      hintText: "Paste latitude",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Longitude",
                      hintText: "Paste longitude",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_location_alt, color: Colors.blue),
                  onPressed: _addMarkerFromTextFields,
                  tooltip: "Add marker",
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _deviceLocation!,
                initialZoom: 15,
                onTap: (tapPosition, latlng) {
                  setState(() => picked = latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mobile_app',
                ),
                // Current location marker (blue dot)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _deviceLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                if (picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: picked!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: picked != null
          ? FloatingActionButton.extended(
        label: const Text('Confirm'),
        icon: const Icon(Icons.check),
        onPressed: () {
          widget.onSelected(picked!);
          Navigator.of(context).pop();
        },
      )
          : null,
    );
  }
}