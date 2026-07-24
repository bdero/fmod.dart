import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:fmod/src/common.dart';
import 'package:fmod/src/core.dart';
import 'package:fmod/src/ffi/bindings.dart';
import 'package:fmod/src/ffi/library.dart';
import 'package:fmod/src/system_resources.dart';
import 'package:vector_math/vector_math.dart';

/// An FMOD Studio system, the top-level object of these bindings.
///
/// Create one with [FmodStudioSystem.create], call [update] once per
/// frame, and load banks exported from FMOD Studio to fire their
/// events. The Core API is reachable through [core] for raw sound and
/// channel playback. Drive a system from a single isolate.
class FmodStudioSystem {
  FmodStudioSystem._(this.bindings, this._system) {
    _resources = SystemResources(bindings);
    bindings.check(
      bindings.Studio_System_GetCoreSystem(_system, _resources.pointerOut),
      'Studio_System_GetCoreSystem',
    );
    core = FmodCoreSystem.internal(
      bindings,
      _resources.pointerOut.value,
      _resources,
    );
  }

  /// Loads the FMOD libraries and creates and initializes a Studio
  /// system.
  ///
  /// [headerVersion] is the FMOD header handshake, defaulting to the
  /// 2.03 series these bindings target; pass the matching value when
  /// using another SDK series. [liveUpdate] enables mixing and
  /// profiling from the FMOD Studio tool over the network (development
  /// builds only).
  factory FmodStudioSystem.create({
    int maxChannels = 256,
    bool liveUpdate = false,
    int headerVersion = kFmodDefaultHeaderVersion,
    FmodLibrary? library,
  }) {
    final bindings = FmodBindings(library ?? FmodLibrary.open());
    final out = calloc<Pointer<Void>>();
    try {
      bindings.check(
        bindings.Studio_System_Create(out, headerVersion),
        'Studio_System_Create',
      );
      final system = out.value;
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
      return FmodStudioSystem._(bindings, system);
    } finally {
      calloc.free(out);
    }
  }

  final FmodBindings bindings;
  final Pointer<Void> _system;
  late final SystemResources _resources;

  /// The Core API system underneath this Studio system.
  late final FmodCoreSystem core;

  bool _released = false;

  /// Processes queued commands and updates the 3D engine. Call once per
  /// frame.
  void update() {
    bindings.check(
      bindings.Studio_System_Update(_system),
      'Studio_System_Update',
    );
  }

  /// Loads a bank from a file path.
  FmodBank loadBankFile(String path) {
    final pathUtf8 = path.toNativeUtf8();
    try {
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.Studio_System_LoadBankFile(
          _system,
          pathUtf8,
          fmodStudioLoadBankNormal,
          _resources.pointerOut,
        ),
        'Studio_System_LoadBankFile',
      );
      return FmodBank._(this, _resources.pointerOut.value);
    } finally {
      calloc.free(pathUtf8);
    }
  }

  /// Loads a bank from in-memory bank bytes.
  FmodBank loadBankMemory(Uint8List bytes) {
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.Studio_System_LoadBankMemory(
          _system,
          buffer,
          bytes.length,
          fmodStudioLoadMemory,
          fmodStudioLoadBankNormal,
          _resources.pointerOut,
        ),
        'Studio_System_LoadBankMemory',
      );
      return FmodBank._(this, _resources.pointerOut.value);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Resolves an authored event by its `event:/` path. Its bank (and
  /// the strings bank) must be loaded. Throws [FmodException] with
  /// FMOD_ERR_EVENT_NOTFOUND when the path is unknown.
  FmodEventDescription getEvent(String path) {
    final pathUtf8 = path.toNativeUtf8();
    try {
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.Studio_System_GetEvent(
          _system,
          pathUtf8,
          _resources.pointerOut,
        ),
        'Studio_System_GetEvent',
      );
      return FmodEventDescription._(this, _resources.pointerOut.value);
    } finally {
      calloc.free(pathUtf8);
    }
  }

  /// Resolves a mixer bus by its `bus:/` path (`'bus:/'` is the master
  /// bus).
  FmodStudioBus getBus(String path) {
    final pathUtf8 = path.toNativeUtf8();
    try {
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.Studio_System_GetBus(_system, pathUtf8, _resources.pointerOut),
        'Studio_System_GetBus',
      );
      return FmodStudioBus._(this, _resources.pointerOut.value);
    } finally {
      calloc.free(pathUtf8);
    }
  }

  /// Sets the 3D listener pose. FMOD's coordinate system is left-handed
  /// by default; [forward] and [up] must be normalized and orthogonal.
  void setListenerAttributes({
    int index = 0,
    required Vector3 position,
    required Vector3 velocity,
    required Vector3 forward,
    required Vector3 up,
  }) {
    _resources.writeAttributes(
      position: position,
      velocity: velocity,
      forward: forward,
      up: up,
    );
    bindings.check(
      bindings.Studio_System_SetListenerAttributes(
        _system,
        index,
        _resources.attributes,
        nullptr,
      ),
      'Studio_System_SetListenerAttributes',
    );
  }

  /// Shuts down the system and frees its native resources. The system
  /// and every object created from it are unusable afterwards.
  void release() {
    if (_released) return;
    _released = true;
    bindings.check(
      bindings.Studio_System_Release(_system),
      'Studio_System_Release',
    );
    _resources.release();
  }
}

/// A loaded Studio bank.
class FmodBank {
  FmodBank._(this._owner, this._bank);

  final FmodStudioSystem _owner;
  final Pointer<Void> _bank;
  bool _unloaded = false;

  /// Unloads the bank, stopping its events.
  void unload() {
    if (_unloaded) return;
    _unloaded = true;
    _owner.bindings.check(
      _owner.bindings.Studio_Bank_Unload(_bank),
      'Studio_Bank_Unload',
    );
  }
}

/// A mixer bus authored in FMOD Studio.
class FmodStudioBus {
  FmodStudioBus._(this._owner, this._bus);

  final FmodStudioSystem _owner;
  final Pointer<Void> _bus;

  double _volume = 1.0;

  /// Gain applied to everything routed through the bus. `1.0` is unity.
  double get volume => _volume;

  set volume(double value) {
    _volume = value;
    _owner.bindings.check(
      _owner.bindings.Studio_Bus_SetVolume(_bus, value),
      'Studio_Bus_SetVolume',
    );
  }
}

/// An authored event resolved from a bank; a factory for instances.
class FmodEventDescription {
  FmodEventDescription._(this._owner, this._description);

  final FmodStudioSystem _owner;
  final Pointer<Void> _description;

  /// Creates a playable instance of this event.
  FmodEventInstance createInstance() {
    final out = _owner._resources.pointerOut..value = nullptr;
    _owner.bindings.check(
      _owner.bindings.Studio_EventDescription_CreateInstance(_description, out),
      'Studio_EventDescription_CreateInstance',
    );
    return FmodEventInstance._(_owner, out.value);
  }
}

/// One playable instance of an authored event.
class FmodEventInstance {
  FmodEventInstance._(this._owner, this._instance);

  final FmodStudioSystem _owner;
  final Pointer<Void> _instance;

  FmodBindings get _bindings => _owner.bindings;

  /// Starts (or restarts) the event.
  void start() {
    _bindings.check(
      _bindings.Studio_EventInstance_Start(_instance),
      'Studio_EventInstance_Start',
    );
  }

  /// Stops the event.
  void stop({FmodStopMode mode = FmodStopMode.allowFadeout}) {
    _bindings.check(
      _bindings.Studio_EventInstance_Stop(_instance, mode.index),
      'Studio_EventInstance_Stop',
    );
  }

  /// Releases the instance; it is destroyed once it stops.
  void release() {
    _bindings.check(
      _bindings.Studio_EventInstance_Release(_instance),
      'Studio_EventInstance_Release',
    );
  }

  set paused(bool value) {
    _bindings.check(
      _bindings.Studio_EventInstance_SetPaused(_instance, value ? 1 : 0),
      'Studio_EventInstance_SetPaused',
    );
  }

  set volume(double value) {
    _bindings.check(
      _bindings.Studio_EventInstance_SetVolume(_instance, value),
      'Studio_EventInstance_SetVolume',
    );
  }

  set pitch(double value) {
    _bindings.check(
      _bindings.Studio_EventInstance_SetPitch(_instance, value),
      'Studio_EventInstance_SetPitch',
    );
  }

  /// Sets an event parameter by name. Throws [FmodException] with
  /// FMOD_ERR_EVENT_NOTFOUND for names the event does not declare.
  void setParameter(String name, double value, {bool ignoreSeekSpeed = false}) {
    final nameUtf8 = name.toNativeUtf8();
    try {
      _bindings.check(
        _bindings.Studio_EventInstance_SetParameterByName(
          _instance,
          nameUtf8,
          value,
          ignoreSeekSpeed ? 1 : 0,
        ),
        'Studio_EventInstance_SetParameterByName',
      );
    } finally {
      calloc.free(nameUtf8);
    }
  }

  FmodPlaybackState get playbackState {
    _bindings.check(
      _bindings.Studio_EventInstance_GetPlaybackState(
        _instance,
        _owner._resources.intOut,
      ),
      'Studio_EventInstance_GetPlaybackState',
    );
    return FmodPlaybackState.fromNative(_owner._resources.intOut.value);
  }

  /// Pushes the instance's 3D pose. [forward] and [up] must be
  /// normalized and orthogonal.
  void set3dAttributes({
    required Vector3 position,
    required Vector3 velocity,
    required Vector3 forward,
    required Vector3 up,
  }) {
    _owner._resources.writeAttributes(
      position: position,
      velocity: velocity,
      forward: forward,
      up: up,
    );
    _bindings.check(
      _bindings.Studio_EventInstance_Set3DAttributes(
        _instance,
        _owner._resources.attributes,
      ),
      'Studio_EventInstance_Set3DAttributes',
    );
  }

  /// Overrides the authored minimum attenuation distance.
  set minimumDistance(double value) {
    _bindings.check(
      _bindings.Studio_EventInstance_SetProperty(
        _instance,
        fmodStudioEventPropertyMinDistance,
        value,
      ),
      'Studio_EventInstance_SetProperty',
    );
  }

  /// Overrides the authored maximum attenuation distance.
  set maximumDistance(double value) {
    _bindings.check(
      _bindings.Studio_EventInstance_SetProperty(
        _instance,
        fmodStudioEventPropertyMaxDistance,
        value,
      ),
      'Studio_EventInstance_SetProperty',
    );
  }
}
