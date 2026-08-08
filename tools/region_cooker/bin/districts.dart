import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

/// Cooks the district table of a region: one JSON file of administrative
/// boundaries, bundled with the app.
///
/// Progression is measured in districts, so the app has to know where they are.
/// The basemap pack cannot answer that — its `boundaries` layer is unnamed
/// lines and its `places` layer, for Ho Chi Minh City, holds three
/// district-scale names and several thousand `Khu phố 12`s. Names *and* shapes
/// come from the same place the basemap does, one level up: the OpenStreetMap
/// administrative relations, read through Overpass.
///
/// `admin_level = 6` is the smallest named unit Vietnam has. Since the 2025
/// reform that is the ward (phường) or commune (xã) — the districts (quận)
/// above them were abolished — so a "district" in NoPlace is whatever OSM calls
/// level 6 on the ground the player is standing on. That is the honest unit: it
/// is what a Vietnamese address names, and it is small enough that walking one
/// is an evening rather than a year.
///
/// What ships is deliberately not the raw boundary:
///
///  * **one ring per district**, the largest. A ward split by a river is drawn
///    by two polygons in OSM; the second is a sandbank nobody walks;
///  * **simplified to [_simplifyMeters]**, which takes Ho Chi Minh City from
///    twelve megabytes of node-by-node coastline to well under one. The app
///    uses these to answer "which ward is this metre in" and "how big is it" —
///    both survive an eighty-metre wobble in the border, and nothing is drawn
///    from them;
///  * **with the area precomputed**, because it is a property of the shape and
///    the phone should not be recomputing it on every profile open.
///
/// ```
/// dart run bin/districts.dart vn-hcmc
/// dart run bin/districts.dart --all
/// ```
Future<int> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help')) {
    stdout.writeln(_usage);
    return arguments.isEmpty ? 64 : 0;
  }

  final root = _repoRoot();
  final regionsDirectory = Directory(
    p.join(root, 'tools', 'region_cooker', 'regions'),
  );

  final regionIds = arguments.contains('--all')
      ? (regionsDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .map((file) => p.basenameWithoutExtension(file.path))
            .toList()
          ..sort())
      : arguments;

  for (final regionId in regionIds) {
    final configFile = File(p.join(regionsDirectory.path, '$regionId.json'));
    if (!configFile.existsSync()) {
      _fail('no region config at ${configFile.path}');
      return 66;
    }

    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final bbox = (config['bbox'] as List)
        .cast<num>()
        .map((value) => value.toDouble())
        .toList();

    _step('$regionId: asking Overpass for admin_level 6 inside the bbox');

    final Map<String, dynamic> response;
    try {
      response = await _overpass(bbox);
    } on Object catch (error) {
      _fail('$regionId: Overpass did not answer ($error)');
      return 69;
    }

    final elements = (response['elements'] as List).cast<Map<String, dynamic>>();
    _step('  ${elements.length} relations');

    final districts = <Map<String, Object?>>[];
    for (final element in elements) {
      final district = _districtOf(element);
      if (district != null) districts.add(district);
    }

    // Alphabetical by the name that will be on screen, so a diff of this file
    // between two cooks is readable — the app decides its own order.
    districts.sort(
      (a, b) => (a['name']! as String).compareTo(b['name']! as String),
    );

    final output = File(
      p.join(root, 'app', 'assets', 'districts', '$regionId.json'),
    )..parent.createSync(recursive: true);

    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'format_version': _formatVersion,
        'region_id': regionId,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'OpenStreetMap contributors, via the Overpass API',
        'admin_level': 6,
        'simplify_meters': _simplifyMeters,
        'districts': districts,
      }),
    );

    final kilobytes = output.lengthSync() / 1024;
    stdout.writeln(
      '  ${p.relative(output.path, from: root)}  '
      '${districts.length} districts, ${kilobytes.toStringAsFixed(0)} kB',
    );
  }

  return 0;
}

/// The version of the file this writes. The app refuses one it does not know.
const int _formatVersion = 1;

/// How far a simplified border may sit from the real one.
///
/// Eighty metres is about the width of the block either side of it, and both
/// questions the app asks of these shapes tolerate that: a walk misfiled at the
/// very edge of a ward lands in the ward next door, which is where the player
/// was standing anyway.
const double _simplifyMeters = 80;

/// Overpass is a public, rate-limited service. One request per region, and the
/// answer is committed to the repository — this is not run at build time and
/// never by the app.
Future<Map<String, dynamic>> _overpass(List<double> bbox) async {
  // Overpass takes bboxes as south,west,north,east — the opposite order to the
  // MBTiles convention the region configs are written in.
  final query =
      '[out:json][timeout:300];'
      'relation["boundary"="administrative"]["admin_level"="6"]'
      '(${bbox[1]},${bbox[0]},${bbox[3]},${bbox[2]});'
      'out geom;';

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.postUrl(
      Uri.parse('https://overpass-api.de/api/interpreter'),
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    // Overpass asks every client to say who it is, and a script that does not
    // is the first thing they block.
    request.headers.set(HttpHeaders.userAgentHeader, 'noplace-region-cooker/1');
    request.write('data=${Uri.encodeQueryComponent(query)}');

    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// One Overpass relation as a district row, or null when it is not usable.
Map<String, Object?>? _districtOf(Map<String, dynamic> element) {
  final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
  final name = tags['name'] as String?;
  if (name == null || name.isEmpty) return null;

  final members = (element['members'] as List?)?.cast<Map<String, dynamic>>();
  if (members == null) return null;

  final ways = <List<_Point>>[];
  for (final member in members) {
    if (member['type'] != 'way') continue;
    // An empty role is how a plain boundary way arrives; `inner` is a hole, and
    // a hole in a ward is somewhere the player can still walk, so it is dropped
    // rather than subtracted.
    final role = member['role'] as String? ?? '';
    if (role != 'outer' && role.isNotEmpty) continue;

    final geometry = (member['geometry'] as List?)?.cast<Map<String, dynamic>>();
    if (geometry == null || geometry.length < 2) continue;

    ways.add([
      for (final node in geometry)
        _Point(
          (node['lat'] as num).toDouble(),
          (node['lon'] as num).toDouble(),
        ),
    ]);
  }

  final ring = _largestRing(ways);
  if (ring == null) return null;

  final simplified = _simplify(ring, _simplifyMeters);
  if (simplified.length < 4) return null;

  final area = _areaSquareMeters(simplified);
  // A boundary that projects to nothing is a data error, not a district.
  if (area <= 0) return null;

  final centre = _centroid(simplified);

  var minLat = simplified.first.lat;
  var maxLat = simplified.first.lat;
  var minLng = simplified.first.lng;
  var maxLng = simplified.first.lng;
  for (final point in simplified) {
    minLat = math.min(minLat, point.lat);
    maxLat = math.max(maxLat, point.lat);
    minLng = math.min(minLng, point.lng);
    maxLng = math.max(maxLng, point.lng);
  }

  return {
    'id': 'osm-r${element['id']}',
    'name': name,
    if (tags['name:en'] != null) 'name_en': tags['name:en'],
    'center': [_round(centre.lat), _round(centre.lng)],
    'bbox': [_round(minLat), _round(minLng), _round(maxLat), _round(maxLng)],
    'area_m2': area.round(),
    // Flat `lat, lng, lat, lng…`. Half the punctuation of a list of pairs, and
    // the app reads it in one loop.
    'ring': [
      for (final point in simplified) ...[_round(point.lat), _round(point.lng)],
    ],
  };
}

/// Five decimal places is about a metre — finer than the simplification that
/// has already happened, and half the bytes of the raw doubles.
double _round(double value) => (value * 100000).roundToDouble() / 100000;

/// Stitches boundary ways into closed rings and returns the biggest.
///
/// OSM gives a boundary as unordered ways that share endpoints; a ward on a
/// river arrives as several rings, of which one is the ward and the rest are
/// sandbanks. Biggest wins.
List<_Point>? _largestRing(List<List<_Point>> ways) {
  final remaining = [...ways];
  List<_Point>? best;
  var bestArea = 0.0;

  while (remaining.isNotEmpty) {
    final ring = [...remaining.removeLast()];

    var joined = true;
    while (joined && !_isClosed(ring)) {
      joined = false;
      for (var index = 0; index < remaining.length; index++) {
        final candidate = remaining[index];
        if (_samePoint(candidate.first, ring.last)) {
          ring.addAll(candidate.skip(1));
        } else if (_samePoint(candidate.last, ring.last)) {
          ring.addAll(candidate.reversed.skip(1));
        } else {
          continue;
        }
        remaining.removeAt(index);
        joined = true;
        break;
      }
    }

    if (ring.length < 4) continue;
    final area = _areaSquareMeters(ring);
    if (area > bestArea) {
      bestArea = area;
      best = ring;
    }
  }

  return best;
}

bool _isClosed(List<_Point> ring) =>
    ring.length > 2 && _samePoint(ring.first, ring.last);

bool _samePoint(_Point a, _Point b) =>
    (a.lat - b.lat).abs() < 1e-9 && (a.lng - b.lng).abs() < 1e-9;

/// Ramer–Douglas–Peucker, with the tolerance in metres rather than degrees so
/// it means the same thing at every latitude.
List<_Point> _simplify(List<_Point> ring, double toleranceMeters) {
  if (ring.length < 3) return ring;

  final scale = _metresPerDegree(ring);
  final keep = List<bool>.filled(ring.length, false)
    ..first = true
    ..last = true;

  final stack = <(int, int)>[(0, ring.length - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    if (end <= start + 1) continue;

    var farthest = -1;
    var farthestDistance = toleranceMeters;
    for (var index = start + 1; index < end; index++) {
      final distance = _distanceToSegment(
        ring[index],
        ring[start],
        ring[end],
        scale,
      );
      if (distance > farthestDistance) {
        farthest = index;
        farthestDistance = distance;
      }
    }

    if (farthest < 0) continue;
    keep[farthest] = true;
    stack
      ..add((start, farthest))
      ..add((farthest, end));
  }

  final simplified = [
    for (var index = 0; index < ring.length; index++)
      if (keep[index]) ring[index],
  ];

  // Simplification can only remove points, so a ring that came in closed can
  // come out open at the seam. Close it again.
  if (!_isClosed(simplified)) simplified.add(simplified.first);
  return simplified;
}

/// Perpendicular distance from [point] to the segment [a]–[b], in metres.
double _distanceToSegment(_Point point, _Point a, _Point b, (double, double) scale) {
  final (latScale, lngScale) = scale;
  final px = point.lng * lngScale;
  final py = point.lat * latScale;
  final ax = a.lng * lngScale;
  final ay = a.lat * latScale;
  final bx = b.lng * lngScale;
  final by = b.lat * latScale;

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }

  var t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final nearestX = ax + t * dx;
  final nearestY = ay + t * dy;
  return math.sqrt(
    (px - nearestX) * (px - nearestX) + (py - nearestY) * (py - nearestY),
  );
}

/// Metres per degree of latitude and of longitude at this ring's latitude.
///
/// Equirectangular, which is exact enough for a shape a few kilometres across
/// and keeps every calculation below to plain arithmetic.
(double, double) _metresPerDegree(List<_Point> ring) {
  var sum = 0.0;
  for (final point in ring) {
    sum += point.lat;
  }
  final meanLatitude = sum / ring.length;
  return (110574, 111320 * math.cos(meanLatitude * math.pi / 180));
}

double _areaSquareMeters(List<_Point> ring) {
  final (latScale, lngScale) = _metresPerDegree(ring);
  var twiceArea = 0.0;
  for (var index = 0; index < ring.length - 1; index++) {
    final x1 = ring[index].lng * lngScale;
    final y1 = ring[index].lat * latScale;
    final x2 = ring[index + 1].lng * lngScale;
    final y2 = ring[index + 1].lat * latScale;
    twiceArea += x1 * y2 - x2 * y1;
  }
  return twiceArea.abs() / 2;
}

/// The polygon's own centre of area, not the middle of its bounding box: a
/// crescent-shaped ward along a river has a bbox centre in the water.
_Point _centroid(List<_Point> ring) {
  final (latScale, lngScale) = _metresPerDegree(ring);
  var twiceArea = 0.0;
  var x = 0.0;
  var y = 0.0;

  for (var index = 0; index < ring.length - 1; index++) {
    final x1 = ring[index].lng * lngScale;
    final y1 = ring[index].lat * latScale;
    final x2 = ring[index + 1].lng * lngScale;
    final y2 = ring[index + 1].lat * latScale;
    final cross = x1 * y2 - x2 * y1;
    twiceArea += cross;
    x += (x1 + x2) * cross;
    y += (y1 + y2) * cross;
  }

  if (twiceArea == 0) return ring.first;
  return _Point(y / (3 * twiceArea) / latScale, x / (3 * twiceArea) / lngScale);
}

class _Point {
  const _Point(this.lat, this.lng);

  final double lat;
  final double lng;
}

String _repoRoot() {
  var directory = Directory.current;
  while (!Directory(p.join(directory.path, '.git')).existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('run this from inside the repository');
    }
    directory = parent;
  }
  return directory.path;
}

void _step(String message) => stdout.writeln(message);

void _fail(String message) => stderr.writeln('✗ $message');

const String _usage = '''
Cooks the district table of a region into app/assets/districts/<region>.json.

  dart run bin/districts.dart <region-id>...
  dart run bin/districts.dart --all

Region ids are the file names in tools/region_cooker/regions/ — the bbox comes
from the same config the map pack is cut with, so the two always agree.
''';
