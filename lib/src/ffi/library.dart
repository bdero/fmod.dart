import 'dart:ffi';
import 'dart:io';

/// Locates and opens the FMOD Engine dynamic libraries.
///
/// FMOD's license does not permit redistributing the SDK, so this
/// package never ships or downloads binaries. The libraries are found,
/// in order, from
///
/// 1. `FMOD_LIBRARY_PATH`, a directory containing the core and studio
///    libraries.
/// 2. `FMOD_SDK_PATH`, the root of an extracted FMOD Engine SDK (the
///    directory containing `api/`), using the SDK's per-platform
///    layout.
/// 3. The platform loader's default search path (libraries already
///    bundled with or linked into the app).
// TODO(audio): wire the build hook's bundled code assets to these
// lookups once verified against a real SDK per platform, so release
// builds need no environment variables.
class FmodLibrary {
  FmodLibrary._(this.core, this.studio);

  final DynamicLibrary core;
  final DynamicLibrary studio;

  static const _libraryPathEnv = 'FMOD_LIBRARY_PATH';
  static const _sdkPathEnv = 'FMOD_SDK_PATH';

  static (String, String) get _names {
    if (Platform.isMacOS || Platform.isIOS) {
      return ('libfmod.dylib', 'libfmodstudio.dylib');
    }
    if (Platform.isWindows) return ('fmod.dll', 'fmodstudio.dll');
    return ('libfmod.so', 'libfmodstudio.so');
  }

  // The SDK's lib directory for the host, relative to the SDK root.
  static List<String> get _sdkLibDirs {
    if (Platform.isMacOS) {
      return ['api/core/lib', 'api/studio/lib'];
    }
    if (Platform.isWindows) {
      return ['api/core/lib/x64', 'api/studio/lib/x64'];
    }
    final arch = Abi.current() == Abi.linuxArm64 ? 'arm64' : 'x86_64';
    return ['api/core/lib/$arch', 'api/studio/lib/$arch'];
  }

  static FmodLibrary open() {
    final (coreName, studioName) = _names;

    final libraryDir = Platform.environment[_libraryPathEnv];
    if (libraryDir != null) {
      return FmodLibrary._(
        _openConfigured('$libraryDir/$coreName', _libraryPathEnv),
        _openConfigured('$libraryDir/$studioName', _libraryPathEnv),
      );
    }

    final sdkRoot = Platform.environment[_sdkPathEnv];
    if (sdkRoot != null) {
      final [coreDir, studioDir] = _sdkLibDirs;
      return FmodLibrary._(
        _openConfigured('$sdkRoot/$coreDir/$coreName', _sdkPathEnv),
        _openConfigured('$sdkRoot/$studioDir/$studioName', _sdkPathEnv),
      );
    }

    try {
      return FmodLibrary._(
        DynamicLibrary.open(coreName),
        DynamicLibrary.open(studioName),
      );
    } on ArgumentError {
      // Fall through to the process image (static or preloaded links).
    }
    final process = DynamicLibrary.process();
    if (process.providesSymbol('FMOD_Studio_System_Create')) {
      return FmodLibrary._(process, process);
    }
    throw StateError(
      'FMOD Engine libraries not found. Download the FMOD Engine SDK for '
      'this platform from fmod.com (registration required), then set '
      '$_sdkPathEnv to the extracted SDK root or $_libraryPathEnv to a '
      'directory containing $coreName and $studioName.',
    );
  }

  // Opens a library at a path configured through [envVar], turning the
  // loader's raw failure into actionable guidance (the common causes
  // are a wrong path, a mismatched architecture, and macOS refusing
  // still-quarantined downloads).
  static DynamicLibrary _openConfigured(String path, String envVar) {
    try {
      return DynamicLibrary.open(path);
    } on ArgumentError catch (error) {
      final quarantineHint = Platform.isMacOS && File(path).existsSync()
          ? ' The file exists, so if the underlying error says "library '
                'load disallowed by system policy", clear the download '
                'quarantine from the extracted SDK with: xattr -dr '
                'com.apple.quarantine "<sdk root>".'
          : ' Check that $envVar points at the right place and that the '
                'SDK matches this platform and architecture.';
      throw StateError(
        'Failed to load the FMOD library at $path (from \$$envVar).'
        '$quarantineHint\nUnderlying error: ${error.message}',
      );
    }
  }
}
