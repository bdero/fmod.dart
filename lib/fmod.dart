/// Unofficial Dart FFI bindings for the FMOD Engine audio middleware.
///
/// Create an [FmodStudioSystem], load banks exported from FMOD Studio,
/// and fire events; the Core API is reachable through
/// [FmodStudioSystem.core] for raw sound playback. Requires a
/// user-supplied FMOD Engine SDK; see the README for setup. The raw C
/// entry points are available through [FmodBindings] for calls the
/// wrapper does not cover.
library;

export 'src/common.dart';
export 'src/core.dart';
export 'src/ffi/bindings.dart';
export 'src/ffi/library.dart';
export 'src/studio.dart';
