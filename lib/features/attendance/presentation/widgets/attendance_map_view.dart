import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_utils.dart';
import '../../data/models/attendance_models.dart';

class AttendanceMapView extends StatefulWidget {
  const AttendanceMapView({
    super.key,
    this.office,
    this.gpsFix,
    this.checkIn,
    this.checkOut,
    this.employeeMarkers = const [],
    this.height = 320,
    this.onEmployeeTap,
  });

  final OfficeLocation? office;
  final GpsFix? gpsFix;
  final AttendanceRecord? checkIn;
  final AttendanceRecord? checkOut;
  final List<EmployeeMapMarker> employeeMarkers;
  final double height;
  final ValueChanged<EmployeeMapMarker>? onEmployeeTap;

  @override
  State<AttendanceMapView> createState() => _AttendanceMapViewState();
}

class _AttendanceMapViewState extends State<AttendanceMapView> {
  final MapController _controller = MapController();

  LatLng get _center {
    final office = widget.office;
    if (office != null) return LatLng(office.latitude, office.longitude);
    final gps = widget.gpsFix;
    if (gps != null) return LatLng(gps.latitude, gps.longitude);
    final checkIn = widget.checkIn;
    if (checkIn?.checkInLatitude != null && checkIn?.checkInLongitude != null) {
      return LatLng(checkIn!.checkInLatitude!, checkIn.checkInLongitude!);
    }
    if (widget.employeeMarkers.isNotEmpty) {
      final marker = widget.employeeMarkers.first;
      return LatLng(marker.latitude, marker.longitude);
    }
    return const LatLng(20.5937, 78.9629);
  }

  double get _zoom {
    if (widget.office != null || widget.gpsFix != null || widget.checkIn != null) {
      return 16;
    }
    if (widget.employeeMarkers.isNotEmpty) return 12;
    return 4;
  }

  void _recenter() {
    _controller.move(_center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
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
                  circles: [
                    if (widget.office != null)
                      CircleMarker(
                        point: LatLng(widget.office!.latitude, widget.office!.longitude),
                        radius: widget.office!.radiusMeters,
                        useRadiusInMeter: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderColor: theme.colorScheme.primary.withValues(alpha: 0.65),
                        borderStrokeWidth: 2,
                      ),
                    if (widget.gpsFix != null)
                      CircleMarker(
                        point: LatLng(widget.gpsFix!.latitude, widget.gpsFix!.longitude),
                        radius: widget.gpsFix!.accuracyMeters,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.10),
                        borderColor: Colors.blue.withValues(alpha: 0.45),
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (widget.office != null)
                      _mapMarker(
                        point: LatLng(widget.office!.latitude, widget.office!.longitude),
                        color: theme.colorScheme.primary,
                        icon: Icons.business_rounded,
                        tooltip: widget.office!.name,
                      ),
                    if (widget.gpsFix != null)
                      _mapMarker(
                        point: LatLng(widget.gpsFix!.latitude, widget.gpsFix!.longitude),
                        color: Colors.blue,
                        icon: Icons.my_location_rounded,
                        tooltip: 'Current device location',
                      ),
                    if (widget.checkIn?.checkInLatitude != null &&
                        widget.checkIn?.checkInLongitude != null)
                      _mapMarker(
                        point: LatLng(
                          widget.checkIn!.checkInLatitude!,
                          widget.checkIn!.checkInLongitude!,
                        ),
                        color: Colors.green.shade700,
                        icon: Icons.login_rounded,
                        tooltip: 'Check-in',
                      ),
                    if (widget.checkOut?.checkOutLatitude != null &&
                        widget.checkOut?.checkOutLongitude != null)
                      _mapMarker(
                        point: LatLng(
                          widget.checkOut!.checkOutLatitude!,
                          widget.checkOut!.checkOutLongitude!,
                        ),
                        color: Colors.red.shade700,
                        icon: Icons.logout_rounded,
                        tooltip: 'Check-out',
                      ),
                    ...widget.employeeMarkers.where((marker) {
                      return marker.latitude.isFinite && marker.longitude.isFinite;
                    }).map((marker) {
                      final tone = toneFromStatus(marker.status);
                      return _mapMarker(
                        point: LatLng(marker.latitude, marker.longitude),
                        color: tone == 'danger'
                            ? Colors.red.shade700
                            : tone == 'warning'
                                ? Colors.orange.shade800
                                : theme.colorScheme.primary,
                        icon: Icons.person_pin_circle_rounded,
                        tooltip: marker.employeeName,
                        onTap: widget.onEmployeeTap == null
                            ? null
                            : () => widget.onEmployeeTap!(marker),
                      );
                    }),
                  ],
                ),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: MapAttribution(),
                ),
              ],
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha:0.9),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: 'Recenter map',
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  onPressed: _recenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _mapMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Compact OpenStreetMap attribution that ellipsizes on narrow maps instead
/// of overflowing (flutter_map's SimpleAttributionWidget uses a fixed Row).
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
      ),
    );
  }
}
