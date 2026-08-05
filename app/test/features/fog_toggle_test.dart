import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/map_layer_visibility.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:noplace/features/map/presentation/widgets/fog_toggle_button.dart';

import '../support/pump_app.dart';

void main() {
  group('FogToggleButton', () {
    testWidgets('offers to lift the fog while the fog is drawn', (
      tester,
    ) async {
      await tester.pumpApp(FogToggleButton(fogVisible: true, onPressed: () {}));

      expect(find.bySemanticsLabel('Hide the fog'), findsOneWidget);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.filter_drama);
    });

    testWidgets('offers to put it back while it is lifted', (tester) async {
      await tester.pumpApp(
        FogToggleButton(fogVisible: false, onPressed: () {}),
      );

      expect(find.bySemanticsLabel('Show the fog'), findsOneWidget);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.cloud_off);
    });

    testWidgets('a tap asks for the other state', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        FogToggleButton(fogVisible: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(FogToggleButton));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('map layer visibility', () {
    test('the fog is drawn until somebody says otherwise', () {
      expect(const MapLayerVisibility().showFog, isTrue);
    });

    // The fog and the points are independent choices; a player who hid their
    // two hundred pins has not asked to see the whole city.
    test('lifting the fog leaves the point layers alone', () {
      const hidden = MapLayerVisibility(showUser: false);
      final lifted = hidden.withFog(visible: false);

      expect(lifted.showFog, isFalse);
      expect(lifted.showUser, isFalse);
      expect(lifted.showSuggested, isTrue);
      expect(lifted.showPictures, isTrue);
    });

    test('hiding a point layer leaves the fog alone', () {
      const lifted = MapLayerVisibility(showFog: false);

      expect(
        lifted.withKind(MapPointKind.picture, visible: false).showFog,
        isFalse,
      );
    });
  });
}
