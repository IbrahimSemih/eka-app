import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Basit Google Maps Test Ekranı
class SimpleGoogleMapsScreen extends StatefulWidget {
  const SimpleGoogleMapsScreen({super.key});

  @override
  State<SimpleGoogleMapsScreen> createState() => _SimpleGoogleMapsScreenState();
}

class _SimpleGoogleMapsScreenState extends State<SimpleGoogleMapsScreen> {
  GoogleMapController? _mapController;
  static const LatLng _istanbul = LatLng(41.0082, 28.9784);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Test'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Test bilgileri
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  'Google Maps Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Konum: İstanbul (${_istanbul.latitude}, ${_istanbul.longitude})',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ],
            ),
          ),

          // Harita
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _istanbul,
                    zoom: 12,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    print('✅ Basit Google Maps başlatıldı');
                  },
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: false,
                  markers: {
                    const Marker(
                      markerId: MarkerId('istanbul'),
                      position: _istanbul,
                      infoWindow: InfoWindow(
                        title: 'İstanbul',
                        snippet: 'Test konumu',
                      ),
                    ),
                  },
                ),
              ),
            ),
          ),

          // Test butonları
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_istanbul, 15),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('İstanbul'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        const LatLng(41.0055, 28.9769), // Sultanahmet
                        16,
                      ),
                    );
                  },
                  icon: const Icon(Icons.place),
                  label: const Text('Sultanahmet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
