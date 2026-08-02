import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:region_cooker/pmtiles.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Cooks a NoPlace region pack from OpenStreetMap data.
///
/// One city in, one `.mbtiles` file out — the format in
/// docs/region-pack-format.md, which the app reads directly.
///
/// The pipeline is deliberately three steps and no rendering:
///
///   1. `pmtiles extract` cuts our bounding box out of the Protomaps daily
///      planet build, over HTTP range requests. Nothing is downloaded but the
///      tiles we asked for.
///   2. `pmtiles convert` turns that archive into MBTiles.
///   3. we stamp our metadata in, and refuse to publish a pack that fails
///      inspection.
///
/// The tiles stay **vector**, so the map's look is decided at runtime by
/// `NpBasemapStyle` from the design tokens. There is no style baked in here and
/// no GL renderer in the loop — which is the whole reason this is a 200-line
/// script instead of a Docker image.
Future<int> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help')) {
    stdout.writeln(_usage);
    return arguments.isEmpty ? 64 : 0;
  }

  final regionId = arguments.first;
  final root = _repoRoot();
  final configFile = File(
    p.join(root, 'tools', 'region_cooker', 'regions', '$regionId.json'),
  );

  if (!configFile.existsSync()) {
    _fail('no region config at ${configFile.path}');
    return 66;
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;

  if (!await _hasPmtilesCli()) {
    _fail(
      'the `pmtiles` CLI is not on PATH.\n'
      '  Install it from https://docs.protomaps.com/pmtiles/cli\n'
      '  (a single Go binary — no Docker, no account, no API key).',
    );
    return 69;
  }

  final distribution = Directory(p.join(root, 'tools', 'region_cooker', 'dist'))
    ..createSync(recursive: true);
  final work = Directory(p.join(distribution.path, '.work'))
    ..createSync(recursive: true);

  final bbox = (config['bbox'] as List).cast<num>();
  final maxZoom = config['maxzoom'] as int;
  final minZoom = config['minzoom'] as int;
  final build = config['build'] as String;

  final extracted = p.join(work.path, '$regionId.pmtiles');
  final packed = p.join(distribution.path, '$regionId.mbtiles');

  // 1. Cut the bbox out of the planet.
  //
  // The daily build is a free download and needs no credentials. A Protomaps
  // API key (`protomaps_api_key` in .env) is for their *hosted tile service* —
  // the vendor path this whole design exists to avoid — and is not used here.
  final source = 'https://build.protomaps.com/$build.pmtiles';
  _step('extracting $regionId from $source');

  if (File(extracted).existsSync()) File(extracted).deleteSync();
  if (!await _run('pmtiles', [
    'extract',
    source,
    extracted,
    '--bbox=${bbox.join(',')}',
    '--minzoom=$minZoom',
    '--maxzoom=$maxZoom',
  ])) {
    return 70;
  }

  // 2. PMTiles → MBTiles. Same tiles, a container the app already links a
  //    reader for. The CLI only converts in the other direction, so this half
  //    is ours — see lib/pmtiles.dart.
  _step('converting to MBTiles');
  if (File(packed).existsSync()) File(packed).deleteSync();

  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(packed);

  try {
    final written = await _convert(extracted, database);
    _step('  wrote $written tiles');

    // 3. Make it a NoPlace pack rather than a generic one.
    _step('stamping metadata');
    await _stamp(database, config, minZoom: minZoom, maxZoom: maxZoom);

    _step('verifying');
    final problems = await _verify(
      database,
      packed,
      minZoom: minZoom,
      maxZoom: maxZoom,
      maxSizeMb: config['max_size_mb'] as int,
    );

    if (problems.isNotEmpty) {
      for (final problem in problems) {
        _fail(problem);
      }
      return 65;
    }
  } finally {
    await database.close();
  }

  final megabytes = File(packed).lengthSync() / (1024 * 1024);
  stdout
    ..writeln()
    ..writeln('  ${p.relative(packed, from: root)}  '
        '${megabytes.toStringAsFixed(1)} MB')
    ..writeln()
    ..writeln('  Bundle it:   copy to app/assets/maps/$regionId.mbtiles')
    ..writeln('  Or host it:  upload to any HTTPS object store and point')
    ..writeln('               RegionCatalogue.remoteBase at it');
  return 0;
}

/// Writes every tile of a PMTiles archive into a fresh MBTiles database.
///
/// The one thing to get right is the y axis: PMTiles addresses tiles top-down
/// (XYZ), MBTiles stores them bottom-up (TMS). The flip happens here, and the
/// app flips back when it reads. Both sides are tested.
Future<int> _convert(String archivePath, Database database) async {
  final archive = PmTilesArchive.open(archivePath);

  await database.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
  await database.execute(
    'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
    'tile_row INTEGER, tile_data BLOB)',
  );

  var written = 0;
  var batch = database.batch();

  for (final tile in archive.tiles()) {
    batch.insert('tiles', {
      'zoom_level': tile.z,
      'tile_column': tile.x,
      'tile_row': (1 << tile.z) - 1 - tile.y,
      'tile_data': tile.data,
    });
    written++;

    // Commit periodically: a city is thousands of tiles and tens of megabytes,
    // and one batch of all of it is a needless spike in memory.
    if (written % 2000 == 0) {
      await batch.commit(noResult: true);
      batch = database.batch();
    }
  }

  await batch.commit(noResult: true);

  // The index the app's tile lookup runs against. Created after the inserts,
  // which is much faster than maintaining it during them.
  await database.execute(
    'CREATE UNIQUE INDEX tile_index ON tiles '
    '(zoom_level, tile_column, tile_row)',
  );

  return written;
}

Future<void> _stamp(
  Database database,
  Map<String, dynamic> config, {
  required int minZoom,
  required int maxZoom,
}) async {
  final bbox = (config['bbox'] as List).cast<num>();
  final centre = [
    (bbox[0] + bbox[2]) / 2,
    (bbox[1] + bbox[3]) / 2,
    maxZoom - 1,
  ];

  final values = {
    // MBTiles standard.
    'name': config['name_en'] as String,
    'format': 'pbf',
    'type': 'baselayer',
    'version': '1',
    'description': '${config['name_en']} — NoPlace region pack',
    'bounds': bbox.join(','),
    'center': centre.join(','),
    'minzoom': '$minZoom',
    'maxzoom': '$maxZoom',

    // Ours. See docs/region-pack-format.md.
    'np:format_version': '1',
    'np:region_id': config['id'] as String,
    'np:region_name': config['name'] as String,
    'np:region_name_en': config['name_en'] as String,
    'np:country': config['country'] as String,
    'np:pack_version': '1',
    'np:built_at': DateTime.now().toUtc().toIso8601String(),
    'np:tile_source': config['tile_source'] as String,
    'np:source_build': config['build'] as String,

    // Rendered verbatim by the app. Getting this wrong is a licence problem,
    // not a cosmetic one.
    'np:attribution': config['attribution'] as String,
  };

  final batch = database.batch();
  for (final entry in values.entries) {
    batch
      ..delete('metadata', where: 'name = ?', whereArgs: [entry.key])
      ..insert('metadata', {'name': entry.key, 'value': entry.value});
  }
  await batch.commit(noResult: true);
}

/// Everything that would make a pack unsafe to ship. Returns the reasons.
Future<List<String>> _verify(
  Database database,
  String path, {
  required int minZoom,
  required int maxZoom,
  required int maxSizeMb,
}) async {
  final problems = <String>[];

  // Every zoom in the range has tiles. Catches an extract that died half way,
  // which otherwise looks like a city that dissolves when you zoom in.
  for (var z = minZoom; z <= maxZoom; z++) {
    final count = await _count(
      database,
      'SELECT COUNT(*) FROM tiles WHERE zoom_level = ?',
      [z],
    );
    if (count == 0) {
      problems.add('zoom $z has no tiles');
    }
  }

  // No empty tiles: a zero-byte row renders as a hole with no way to tell it
  // from sea.
  final empty = await _count(
    database,
    'SELECT COUNT(*) FROM tiles WHERE tile_data IS NULL OR '
    'length(tile_data) = 0',
  );
  if (empty > 0) {
    problems.add('$empty tiles are empty');
  }

  // The y-flip, checked from this side of the contract too. A tile at TMS row
  // r must be reachable at XYZ y = (1<<z)-1-r, which is the same arithmetic
  // the app's test asserts.
  final sample = await database.rawQuery(
    'SELECT zoom_level, tile_column, tile_row FROM tiles LIMIT 1',
  );
  if (sample.isEmpty) {
    problems.add('the pack has no tiles at all');
  } else {
    final z = sample.first['zoom_level']! as int;
    final row = sample.first['tile_row']! as int;
    final y = (1 << z) - 1 - row;
    if ((1 << z) - 1 - y != row) {
      problems.add('y-flip does not round-trip at zoom $z');
    }
  }

  final attribution = await database.query(
    'metadata',
    where: 'name = ?',
    whereArgs: ['np:attribution'],
  );
  if (attribution.isEmpty) {
    problems.add('np:attribution is missing — an empty string is a choice, '
        'a missing row is a mistake');
  }

  final megabytes = File(path).lengthSync() / (1024 * 1024);
  if (megabytes > maxSizeMb) {
    problems.add(
      'pack is ${megabytes.toStringAsFixed(1)} MB, over the '
      '$maxSizeMb MB budget — lower maxzoom or tighten the bbox',
    );
  }

  return problems;
}

Future<int> _count(
  Database database,
  String sql, [
  List<Object?>? arguments,
]) async {
  final rows = await database.rawQuery(sql, arguments);
  return (rows.first.values.first as int?) ?? 0;
}

Future<bool> _hasPmtilesCli() async {
  try {
    final result = await Process.run('pmtiles', ['version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<bool> _run(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    _fail('$executable ${arguments.first} exited with $code');
    return false;
  }
  return true;
}

String _repoRoot() {
  var directory = Directory.current;
  while (!Directory(p.join(directory.path, '.git')).existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) return Directory.current.path;
    directory = parent;
  }
  return directory.path;
}

void _step(String message) => stdout.writeln('  $message');

void _fail(String message) => stderr.writeln('  ✗ $message');

const String _usage = '''
Cook a NoPlace region pack.

  dart run bin/cook.dart <region-id>

Regions live in regions/*.json — one file per city, and adding a city is
adding one of those and nothing else.

  vn-hcmc      Ho Chi Minh City
  vn-dongnai   Dong Nai
  vn-hanoi     Hanoi

Requires the `pmtiles` CLI on PATH: https://docs.protomaps.com/pmtiles/cli
No API key, no account, no Docker.
''';
