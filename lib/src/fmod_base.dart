/// The idiomatic wrapper over the native FFI layer. One library so the
/// wrapper types can share privates without exposing pointers or
/// bindings on their public surface (which must stay platform-neutral
/// for the future web backend).
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:fmod/src/common.dart';
import 'package:fmod/src/constants.dart';
import 'package:fmod/src/ffi/bindings.dart';
import 'package:fmod/src/ffi/library.dart';
import 'package:vector_math/vector_math.dart';

part 'core.dart';
part 'studio.dart';
part 'system_resources.dart';

FmodStudioSystem _createStudioSystem(
  FmodBindings bindings, {
  required int maxChannels,
  required bool liveUpdate,
  required int headerVersion,
  required FmodOutputType output,
}) {
  final out = calloc<Pointer<Void>>();
  try {
    bindings.check(
      bindings.Studio_System_Create(out, headerVersion),
      'Studio_System_Create',
    );
    final system = out.value;
    out.value = nullptr;
    // The core system is reachable before initialization, which is when
    // the output driver must be selected.
    bindings.check(
      bindings.Studio_System_GetCoreSystem(system, out),
      'Studio_System_GetCoreSystem',
    );
    final coreSystem = out.value;
    if (output != FmodOutputType.autodetect) {
      bindings.check(
        bindings.System_SetOutput(coreSystem, output.index),
        'System_SetOutput',
      );
    }
    bindings.check(
      bindings.Studio_System_Initialize(
        system,
        maxChannels,
        liveUpdate ? fmodStudioInitLiveUpdate : fmodStudioInitNormal,
        fmodInitNormal,
        nullptr,
      ),
      'Studio_System_Initialize',
    );
    return FmodStudioSystem._(bindings, system, coreSystem);
  } finally {
    calloc.free(out);
  }
}

/// Creates a Studio system over an explicitly opened [FmodLibrary]
/// instead of the environment-based lookup. Native-only; exported
/// through `package:fmod/ffi.dart`.
FmodStudioSystem createStudioSystemWithLibrary(
  FmodLibrary library, {
  int maxChannels = 256,
  bool liveUpdate = false,
  int headerVersion = kFmodDefaultHeaderVersion,
  FmodOutputType output = FmodOutputType.autodetect,
}) => _createStudioSystem(
  FmodBindings(library),
  maxChannels: maxChannels,
  liveUpdate: liveUpdate,
  headerVersion: headerVersion,
  output: output,
);

/// Raw access to a Studio system's native side, for FMOD calls the
/// wrapper does not cover. Native-only; exported through
/// `package:fmod/ffi.dart`.
extension FmodStudioSystemFfi on FmodStudioSystem {
  /// The looked-up C entry points.
  FmodBindings get ffiBindings => _bindings;

  /// The native FMOD_STUDIO_SYSTEM handle.
  Pointer<Void> get nativeSystem => _system;
}

/// Raw access to a Core system's native side. Native-only; exported
/// through `package:fmod/ffi.dart`.
extension FmodCoreSystemFfi on FmodCoreSystem {
  /// The native FMOD_SYSTEM handle.
  Pointer<Void> get nativeSystem => _system;
}
