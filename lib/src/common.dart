import 'package:fmod/src/constants.dart';

/// Playback state of an event instance or channel. Values mirror
/// FMOD_STUDIO_PLAYBACK_STATE.
enum FmodPlaybackState {
  playing,
  sustaining,
  stopped,
  starting,
  stopping;

  static FmodPlaybackState fromNative(int value) => values[value];
}

/// How playback ends when stopped. Values mirror FMOD_STUDIO_STOP_MODE.
enum FmodStopMode {
  /// Let AHDSR modulators and fades run before ending.
  allowFadeout,

  /// End immediately.
  immediate,
}

/// Common FMOD_MODE flag combinations for sounds and channels. The raw
/// flags from `bindings.dart` (`fmod3d`, `fmodLoopNormal`, ...) can be
/// OR'd freely; these cover the frequent cases.
abstract final class FmodMode {
  /// A fully decoded 3D sample, the default for
  /// `FmodCoreSystem.createSound` loads.
  static const int sample3d = fmod3d | fmodCreateSample;

  /// A fully decoded 2D sample.
  static const int sample2d = fmod2d | fmodCreateSample;
}

/// Output driver selection for system creation. Values mirror the head
/// of FMOD_OUTPUTTYPE.
enum FmodOutputType {
  /// Pick the platform's default audio output.
  autodetect,

  /// Placeholder for a plugin-provided output.
  unknown,

  /// Mix without an audio device (headless runs, tests, CI).
  nosound,

  /// Write the mix to fmodoutput.wav in the working directory.
  wavWriter,
}
