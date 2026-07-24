/// Unofficial Dart bindings for the FMOD Engine audio middleware.
///
/// Create an [FmodStudioSystem], load banks exported from FMOD Studio,
/// and fire events; the Core API is reachable through
/// [FmodStudioSystem.core] for raw sound playback. Requires a
/// user-supplied FMOD Engine SDK; see the README for setup.
///
/// This entry point is platform-neutral. The raw native layer (C entry
/// points, structs, the library loader) lives in `package:fmod/ffi.dart`.
library;

export 'src/common.dart';
export 'src/constants.dart';
export 'src/exceptions.dart';
export 'src/fmod_base.dart'
    show
        FmodBank,
        FmodChannel,
        FmodChannelGroup,
        FmodCoreSystem,
        FmodEventDescription,
        FmodEventInstance,
        FmodSound,
        FmodStudioBus,
        FmodStudioSystem;
