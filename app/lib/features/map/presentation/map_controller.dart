import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which half of the home screen the player is looking at.
///
/// `city` is the map; `nearby` is the list of what is within walking distance.
/// They are two answers to two questions — "where am I" and "what is around
/// me" — and the second one was never a camera position: a map zoomed to one
/// street shows fewer places than a list of the same places, not more.
///
/// It is the only piece of map state worth lifting out of the widget — the
/// camera itself belongs to `flutter_map`.
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

/// The zoom the map opens at, and the one [MapScope.nearby] hands back to when
/// the player returns to the map.
///
/// Tuned for a dense Asian city centre: 15.5 shows a handful of blocks around
/// the player, which is the scale at which the fog reads as progress.
const double mapDefaultZoom = 15.5;
