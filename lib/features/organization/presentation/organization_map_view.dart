import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../attendance/data/models/attendance_models.dart';

class OrganizationMapView extends StatelessWidget {
  const OrganizationMapView({
    super.key,
    required this.locations,
    this.height = 300,
  });

  final List<OfficeLocation> locations;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plottable = locations
        .where((office) => office.latitude.isFinite && office.longitude.isFinite)
        .toList();
    final center = plottable.isEmpty
        ? const LatLng(20.5937, 78.9629)
        : LatLng(plottable.first.latitude, plottable.first.longitude);
    final zoom = plottable.isEmpty ? 4.0 : 13.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  maxNativeZoom: 19,
                  userAgentPackageName: 'com.smartattenddd.app',
                ),
                CircleLayer(
                  circles: plottable.map((office) {
                    return CircleMarker(
                      point: LatLng(office.latitude, office.longitude),
                      radius: office.radiusMeters <= 0 ? 1 : office.radiusMeters,
                      useRadiusInMeter: true,
                      color: Colors.grey.withValues(alpha: 0.14),
                      borderColor: Colors.grey.shade700.withValues(alpha: 0.65),
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: plottable.map((office) {
                    return Marker(
                      point: LatLng(office.latitude, office.longitude),
                      width: 64,
                      height: 42,
                      child: Tooltip(
                        message: '${office.name}\n${office.address}',
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: const Text(
                            'OFFICE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            if (plottable.isEmpty)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No office locations configured.'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
