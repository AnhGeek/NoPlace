import '../../domain/entities/geo_point.dart';
import 'region_pack_store.dart';

/// Which cities NoPlace has a map for, and where those maps come from.
///
/// Hard-coded for the beta. It becomes a document fetched from our API — the
/// shape below is deliberately the shape of that response, so the swap is a new
/// implementation of the lookup and nothing else.
abstract final class RegionCatalogue {
  /// The base the remote packs sit under.
  ///
  /// A pack is a static file, so this can point at Cloudflare R2, S3, a CDN or
  /// a plain web server without any other change. Keep it a bare HTTPS prefix:
  /// the moment this needs a vendor SDK to read, the portability is gone.
  static const String remoteBase = 'https://maps.lya3hc.site/packs';

  /// Ships in the app so the map works on first launch, on a plane, and in the
  /// dead zones the product is explicitly meant to survive.
  ///
  /// The claim stops at 106.80°E, well short of the 107.03 the pack is cooked
  /// to. The two rectangles genuinely overlap on the ground — Ho Chi Minh City
  /// and Đồng Nai are not rectangles, and a box drawn around either one swallows
  /// a slice of the other — so somebody in Biên Hòa is inside both. The river is
  /// the honest divide, and it is roughly this meridian. Nothing breaks if a
  /// street on the wrong side of it resolves to its neighbour: both packs hold
  /// tiles for the overlap, so the map draws either way.
  static const RegionPackSource hcmc = RegionPackSource(
    regionId: 'vn-hcmc',
    bounds: RegionBounds(
      minLongitude: 106.36,
      minLatitude: 10.34,
      maxLongitude: 106.80,
      maxLatitude: 11.16,
    ),
    bundledAsset: 'assets/maps/vn-hcmc.mbtiles',
    remoteUrl: '$remoteBase/vn-hcmc.mbtiles',
  );

  /// Bundled too: the province next door is where this app is actually walked,
  /// and the whole point of an offline map is that it is there before the phone
  /// has a signal to fetch it with.
  static const RegionPackSource dongNai = RegionPackSource(
    regionId: 'vn-dongnai',
    bounds: RegionBounds(
      minLongitude: 106.80,
      minLatitude: 10.50,
      maxLongitude: 107.65,
      maxLatitude: 11.58,
    ),
    bundledAsset: 'assets/maps/vn-dongnai.mbtiles',
    remoteUrl: '$remoteBase/vn-dongnai.mbtiles',
  );

  /// Download-only: 700 km away, and bundling it would be weight in the APK of
  /// every player who never leaves the south.
  static const RegionPackSource hanoi = RegionPackSource(
    regionId: 'vn-hanoi',
    bounds: RegionBounds(
      minLongitude: 105.29,
      minLatitude: 20.56,
      maxLongitude: 106.02,
      maxLatitude: 21.39,
    ),
    remoteUrl: '$remoteBase/vn-hanoi.mbtiles',
  );

  static const List<RegionPackSource> all = [hcmc, dongNai, hanoi];

  /// The region the app opens with, before the GPS has said anything.
  ///
  /// Also where a trail written before the schema was region-scoped lives.
  static const RegionPackSource fallback = hcmc;

  /// The region whose ground [position] is standing on, or null when we have no
  /// map for it.
  ///
  /// Point-in-rectangle, with the nearest claim centre breaking a tie. The
  /// claims are trimmed not to overlap, so the tie-break is insurance for the
  /// next city added rather than something today's three regions exercise.
  static RegionPackSource? forPosition(GeoPoint position) {
    RegionPackSource? best;
    var bestDistance = double.infinity;

    for (final region in all) {
      final bounds = region.bounds;
      if (bounds == null || !bounds.contains(position)) continue;

      final distance = position.distanceTo(bounds.centre);
      if (distance < bestDistance) {
        best = region;
        bestDistance = distance;
      }
    }

    return best;
  }
}
