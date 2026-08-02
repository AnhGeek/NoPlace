import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the map is showing.
///
/// `city` frames the whole city; `nearby` zooms to walking distance. It is the
/// only piece of map state worth lifting out of the widget — the camera itself
/// belongs to `flutter_map`.
enum MapScope { city, nearby }

class MapScopeController extends Notifier<MapScope> {
  @override
  MapScope build() => MapScope.city;

  // ignore: use_setters_to_change_properties
  void select(MapScope scope) => state = scope;
}

final mapScopeProvider = NotifierProvider<MapScopeController, MapScope>(
  MapScopeController.new,
);

/// Zoom level per scope. Tuned for a dense Asian city centre: 16 shows a
/// handful of blocks, 17.5 shows the street you are standing on.
extension MapScopeCamera on MapScope {
  double get zoom => switch (this) {
    MapScope.city => 15.5,
    MapScope.nearby => 17.2,
  };
}
