import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/env.dart';

/// Mapbox streets-v12 raster tile URL (never OSM).
String mapboxStreetsTileUrl(String accessToken) {
  return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/'
      '{z}/{x}/{y}?access_token=$accessToken';
}

/// Thin basemap + pin for place picker / new-story shell (iOS + web via flutter_map).
///
/// Parent owns failure UX when token missing or tiles fail — do not fake pins.
class PlaceMap extends StatelessWidget {
  const PlaceMap({
    super.key,
    this.lat,
    this.lng,
    this.accessToken,
    this.height = 180,
    this.onTileError,
  });

  final double? lat;
  final double? lng;

  /// Defaults to [Env.mapboxAccessToken].
  final String? accessToken;

  final double height;

  /// Invoked when a Mapbox tile request fails (parent shows locked copy).
  final void Function(Object error, StackTrace? stackTrace)? onTileError;

  @override
  Widget build(BuildContext context) {
    final token = accessToken ?? Env.mapboxAccessToken;
    final hasPin = lat != null && lng != null;
    final center = hasPin ? LatLng(lat!, lng!) : const LatLng(20, 0);
    final zoom = hasPin ? 14.0 : 1.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: mapboxStreetsTileUrl(token),
            userAgentPackageName: 'tell_me_a_story',
            errorTileCallback: (tile, error, stackTrace) {
              onTileError?.call(error, stackTrace);
            },
          ),
          if (hasPin)
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
