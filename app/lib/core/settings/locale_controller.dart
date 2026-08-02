import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The language the user picked, or `null` to follow the device setting.
///
/// Kept in memory for now. When the persistence layer lands, this controller is
/// the only thing that changes: `build()` reads the stored value and [select]
/// writes it back. Nothing in the UI has to move.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// A named verb reads better than assigning to the controller's state.
  // ignore: use_setters_to_change_properties
  void select(Locale? locale) => state = locale;
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
