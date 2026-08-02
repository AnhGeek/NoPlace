import 'dart:async';

/// A broadcast stream that hands every new listener the current value first.
///
/// Without the replay, a screen opened after a value was emitted would sit in
/// its loading state forever. `rxdart` has `BehaviorSubject` for this; we need
/// exactly this much of it, so we keep the dependency out.
class ReplaySubject<T> {
  ReplaySubject(this._value);

  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    _value = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Emits the current value, then every subsequent change.
  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }

  Future<void> close() => _controller.close();
}
