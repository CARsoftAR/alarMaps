import re
import sys

def migrate_to_flutter_map(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Imports
    content = content.replace("import 'package:google_maps_flutter/google_maps_flutter.dart';", "import 'package:flutter_map/flutter_map.dart';")
    content = content.replace("import 'package:latlong2/latlong.dart' as ll2;", "import 'package:latlong2/latlong.dart';")
    
    # Simulation latlong fix
    content = content.replace("ll2.LatLng", "LatLng")

    # Controller definition
    content = content.replace("final Completer<GoogleMapController> _controller = Completer();", "final MapController _mapController = MapController();")
    
    # AutoPositionOnStart
    content = re.sub(
        r"final GoogleMapController controller = await _controller\.future;\s*controller\.animateCamera\(CameraUpdate\.newLatLngZoom\(latLng, 15\)\);",
        r"_mapController.move(latLng, 15);",
        content
    )
    
    # GetCurrentLocation
    content = re.sub(
        r"final GoogleMapController controller = await _controller\.future;\s*controller\.animateCamera\(CameraUpdate\.newLatLngZoom\(latLng, 15\)\);",
        r"_mapController.move(latLng, 15);",
        content
    )
    
    # SelectFavorite
    content = re.sub(
        r"_controller\.future\.then\(\(c\) => c\.animateCamera\(CameraUpdate\.newLatLngZoom\(dest, 15\)\)\);",
        r"_mapController.move(dest, 15);",
        content
    )
    
    # Search origin
    content = re.sub(
        r"final GoogleMapController controller = await _controller\.future;\s*controller\.animateCamera\(CameraUpdate\.newLatLngZoom\(gLocation, 15\)\);",
        r"_mapController.move(gLocation, 15);",
        content
    )

    # Simulation step
    content = re.sub(
        r"final GoogleMapController controller = await _controller\.future;\s*controller\.animateCamera\(CameraUpdate\.newLatLng\(gPoint\)\);",
        r"_mapController.move(gPoint, _mapController.camera.zoom);",
        content
    )
    
    # OnMapCreated definition
    content = re.sub(
        r"void _onMapCreated\(GoogleMapController controller\) \{.*?\n.*?\}",
        "",
        content,
        flags=re.DOTALL
    )
    
    # CheckMapStatus
    content = re.sub(
        r"void _checkMapStatus\(GoogleMapController controller\) async \{.*?\n.*?\}",
        "",
        content,
        flags=re.DOTALL
    )

    # The GoogleMap widget replacement
    google_map_pattern = r"GoogleMap\([\s\S]*?onTap: \(point\) \{[\s\S]*?\},[\s\S]*?\),"
    
    flutter_map_replacement = """FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.6037, -58.3816),
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                if (!isActive && !isSimulating) {
                  ref.read(selectedDestinationProvider.notifier).state = point;
                  _destinationController.clear();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.alarmap',
              ),
              if (destination != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: destination,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 2,
                    )
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (destination != null)
                    Marker(
                      point: destination,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  if (userPos != null || origin != null)
                    Marker(
                      point: userPos ?? origin!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.my_location,
                        color: (origin != null && origin != userPos) ? Colors.green : Colors.blue,
                        size: 40
                      ),
                    ),
                ],
              ),
            ],
          ),"""

    content = re.sub(google_map_pattern, flutter_map_replacement, content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    migrate_to_flutter_map(r'c:\Sistemas ABBAMAT\alarMap\lib\features\map\presentation\map_screen.dart')
