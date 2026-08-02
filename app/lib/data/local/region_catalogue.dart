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
  static const RegionPackSource hcmc = RegionPackSource(
    regionId: 'vn-hcmc',
    bundledAsset: 'assets/maps/vn-hcmc.mbtiles',
    remoteUrl: '$remoteBase/vn-hcmc.mbtiles',
  );

  /// Download-only for now — bundling three cities is an APK-size decision
  /// nobody has taken yet (see docs/tickets/NP-1-region-packs-on-device.md).
  static const RegionPackSource dongNai = RegionPackSource(
    regionId: 'vn-dongnai',
    remoteUrl: '$remoteBase/vn-dongnai.mbtiles',
  );

  static const RegionPackSource hanoi = RegionPackSource(
    regionId: 'vn-hanoi',
    remoteUrl: '$remoteBase/vn-hanoi.mbtiles',
  );

  static const List<RegionPackSource> all = [hcmc, dongNai, hanoi];

  /// The region the app opens with.
  ///
  /// Resolving the region from the player's actual position is NP-1's job and
  /// needs the pack bounds of every region, which means the catalogue has to
  /// come from somewhere that knows them. Until then: the bundled city.
  static const RegionPackSource fallback = hcmc;
}
