import 'bootstrap.dart';

/// Default entry point.
///
/// Keep it this thin: anything that runs before the first frame belongs in
/// [bootstrap], where the flavour entry points can share it.
Future<void> main() => bootstrap();
