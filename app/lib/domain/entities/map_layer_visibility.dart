import 'package:equatable/equatable.dart';

import 'map_point.dart';

/// Which kinds of point the map is currently drawing.
///
/// A player who has dropped two hundred pins wants to be able to see the city
/// again; a player hunting for somewhere new wants the suggestions and nothing
/// else. Each kind is therefore silenced independently, and the choice is
/// remembered.
class MapLayerVisibility extends Equatable {
  const MapLayerVisibility({
    this.showSuggested = true,
    this.showUser = true,
    this.showPictures = true,
    this.showFog = true,
  });

  /// Points from the places data.
  final bool showSuggested;

  /// Points the player dropped themselves.
  final bool showUser;

  /// Points created from a photo.
  final bool showPictures;

  /// The fog itself.
  ///
  /// Off is a *look*, not a cheat: the trail underneath is untouched, the walk
  /// keeps recording, and turning it back on shows exactly the ground the player
  /// had earned before. It exists because the fog is also what stops you finding
  /// the street you are looking for — and an explorer who cannot orient
  /// themselves stops walking, which costs more than the peek does.
  final bool showFog;

  bool isVisible(MapPointKind kind) => switch (kind) {
    MapPointKind.suggested => showSuggested,
    MapPointKind.user => showUser,
    MapPointKind.picture => showPictures,
  };

  MapLayerVisibility withKind(MapPointKind kind, {required bool visible}) =>
      switch (kind) {
        MapPointKind.suggested => MapLayerVisibility(
          showSuggested: visible,
          showUser: showUser,
          showPictures: showPictures,
          showFog: showFog,
        ),
        MapPointKind.user => MapLayerVisibility(
          showSuggested: showSuggested,
          showUser: visible,
          showPictures: showPictures,
          showFog: showFog,
        ),
        MapPointKind.picture => MapLayerVisibility(
          showSuggested: showSuggested,
          showUser: showUser,
          showPictures: visible,
          showFog: showFog,
        ),
      };

  MapLayerVisibility withFog({required bool visible}) => MapLayerVisibility(
    showSuggested: showSuggested,
    showUser: showUser,
    showPictures: showPictures,
    showFog: visible,
  );

  @override
  List<Object?> get props => [showSuggested, showUser, showPictures, showFog];
}
