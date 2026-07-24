import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:fmod/src/common.dart';
import 'package:fmod/src/ffi/bindings.dart';
import 'package:fmod/src/system_resources.dart';
import 'package:vector_math/vector_math.dart';

/// The FMOD Core API system underneath a Studio system, for raw sound
/// and channel playback. Obtained from `FmodStudioSystem.core`.
class FmodCoreSystem {
  /// Wraps a native core system. Internal; reach a core system through
  /// its studio system.
  FmodCoreSystem.internal(this.bindings, this._system, this._resources);

  final FmodBindings bindings;
  final Pointer<Void> _system;
  final SystemResources _resources;

  FmodChannelGroup? _master;

  /// The master channel group every channel ultimately routes through.
  FmodChannelGroup get masterChannelGroup {
    final cached = _master;
    if (cached != null) return cached;
    _resources.pointerOut.value = nullptr;
    bindings.check(
      bindings.System_GetMasterChannelGroup(_system, _resources.pointerOut),
      'System_GetMasterChannelGroup',
    );
    return _master = FmodChannelGroup._(this, _resources.pointerOut.value);
  }

  /// Loads and decodes a sound from a file path.
  FmodSound createSound(String path, {int mode = FmodMode.sample3d}) {
    final pathUtf8 = path.toNativeUtf8();
    try {
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.System_CreateSound(
          _system,
          pathUtf8,
          mode,
          nullptr,
          _resources.pointerOut,
        ),
        'System_CreateSound',
      );
      return FmodSound._(this, _resources.pointerOut.value);
    } finally {
      calloc.free(pathUtf8);
    }
  }

  /// Loads and decodes a sound from in-memory encoded bytes (any
  /// container FMOD decodes, typically wav/ogg/mp3).
  ///
  /// The bytes currently round-trip through a temporary file, since
  /// FMOD's open-from-memory path needs the version-sensitive
  /// FMOD_CREATESOUNDEXINFO struct.
  // TODO(fmod): bind FMOD_CREATESOUNDEXINFO and load from memory
  // directly.
  Future<FmodSound> createSoundFromBytes(
    Uint8List bytes, {
    int mode = FmodMode.sample3d,
  }) async {
    final directory = await Directory.systemTemp.createTemp('fmod_dart');
    final file = File('${directory.path}/sound');
    await file.writeAsBytes(bytes, flush: true);
    try {
      return createSound(file.path, mode: mode);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  /// Creates a named channel group routed into [parent] (the master
  /// group when null).
  FmodChannelGroup createChannelGroup(String name, {FmodChannelGroup? parent}) {
    final nameUtf8 = name.toNativeUtf8();
    try {
      _resources.pointerOut.value = nullptr;
      bindings.check(
        bindings.System_CreateChannelGroup(
          _system,
          nameUtf8,
          _resources.pointerOut,
        ),
        'System_CreateChannelGroup',
      );
      final group = FmodChannelGroup._(this, _resources.pointerOut.value);
      bindings.check(
        bindings.ChannelGroup_AddGroup(
          (parent ?? masterChannelGroup)._group,
          group._group,
          1,
          nullptr,
        ),
        'ChannelGroup_AddGroup',
      );
      return group;
    } finally {
      calloc.free(nameUtf8);
    }
  }

  /// Starts [sound] on a channel routed through [group] (the master
  /// group when null). The channel starts paused by default so it can
  /// be configured without an audible pop; unpause with
  /// `channel.paused = false`.
  FmodChannel playSound(
    FmodSound sound, {
    FmodChannelGroup? group,
    bool paused = true,
  }) {
    _resources.pointerOut.value = nullptr;
    bindings.check(
      bindings.System_PlaySound(
        _system,
        sound._sound,
        (group ?? masterChannelGroup)._group,
        paused ? 1 : 0,
        _resources.pointerOut,
      ),
      'System_PlaySound',
    );
    return FmodChannel._(this, _resources.pointerOut.value);
  }
}

/// A loaded, decoded sound.
class FmodSound {
  FmodSound._(this._owner, this._sound);

  final FmodCoreSystem _owner;
  final Pointer<Void> _sound;
  bool _released = false;

  /// Whether [release] has been called.
  bool get isReleased => _released;

  /// The decoded length.
  Duration get duration {
    _owner.bindings.check(
      _owner.bindings.Sound_GetLength(
        _sound,
        _owner._resources.uintOut,
        fmodTimeUnitMs,
      ),
      'Sound_GetLength',
    );
    return Duration(milliseconds: _owner._resources.uintOut.value);
  }

  /// Frees the sound, stopping channels playing it.
  void release() {
    if (_released) return;
    _released = true;
    _owner.bindings.check(
      _owner.bindings.Sound_Release(_sound),
      'Sound_Release',
    );
  }
}

/// A named mix group of channels.
class FmodChannelGroup {
  FmodChannelGroup._(this._owner, this._group);

  final FmodCoreSystem _owner;
  final Pointer<Void> _group;

  double _volume = 1.0;

  /// Gain applied to every channel in the group. `1.0` is unity.
  double get volume => _volume;

  set volume(double value) {
    _volume = value;
    _owner.bindings.check(
      _owner.bindings.ChannelGroup_SetVolume(_group, value),
      'ChannelGroup_SetVolume',
    );
  }

  set paused(bool value) {
    _owner.bindings.check(
      _owner.bindings.ChannelGroup_SetPaused(_group, value ? 1 : 0),
      'ChannelGroup_SetPaused',
    );
  }
}

/// One playback of a sound.
///
/// FMOD reuses channels: a finished or stolen channel's handle becomes
/// invalid, and every member here treats that as a clean end of
/// playback ([isPlaying] reports false, mutations are no-ops) rather
/// than an error.
class FmodChannel {
  FmodChannel._(this._owner, this._channel);

  final FmodCoreSystem _owner;
  final Pointer<Void> _channel;

  FmodBindings get _bindings => _owner.bindings;

  /// Whether the channel is still live (audible or paused).
  bool get isPlaying {
    final alive = _bindings.checkChannel(
      _bindings.Channel_IsPlaying(_channel, _owner._resources.intOut),
      'Channel_IsPlaying',
    );
    return alive && _owner._resources.intOut.value != 0;
  }

  set paused(bool value) {
    _bindings.checkChannel(
      _bindings.Channel_SetPaused(_channel, value ? 1 : 0),
      'Channel_SetPaused',
    );
  }

  /// Ends the playback.
  void stop() {
    _bindings.checkChannel(_bindings.Channel_Stop(_channel), 'Channel_Stop');
  }

  set volume(double value) {
    _bindings.checkChannel(
      _bindings.Channel_SetVolume(_channel, value),
      'Channel_SetVolume',
    );
  }

  set pitch(double value) {
    _bindings.checkChannel(
      _bindings.Channel_SetPitch(_channel, value),
      'Channel_SetPitch',
    );
  }

  /// Replaces the channel's FMOD_MODE flags (2D/3D, looping, rolloff).
  void setMode(int mode) {
    _bindings.checkChannel(
      _bindings.Channel_SetMode(_channel, mode),
      'Channel_SetMode',
    );
  }

  /// Pushes the channel's 3D position and velocity.
  void set3dAttributes(Vector3 position, Vector3 velocity) {
    SystemResources.writeVector(_owner._resources.vectorA.ref, position);
    SystemResources.writeVector(_owner._resources.vectorB.ref, velocity);
    _bindings.checkChannel(
      _bindings.Channel_Set3DAttributes(
        _channel,
        _owner._resources.vectorA,
        _owner._resources.vectorB,
      ),
      'Channel_Set3DAttributes',
    );
  }

  void set3dMinMaxDistance(double min, double max) {
    _bindings.checkChannel(
      _bindings.Channel_Set3DMinMaxDistance(_channel, min, max),
      'Channel_Set3DMinMaxDistance',
    );
  }

  /// Doppler strength. `0` disables, `1.0` is physical.
  set dopplerLevel(double value) {
    _bindings.checkChannel(
      _bindings.Channel_Set3DDopplerLevel(_channel, value),
      'Channel_Set3DDopplerLevel',
    );
  }

  /// Reroutes the channel through [group].
  set channelGroup(FmodChannelGroup group) {
    _bindings.checkChannel(
      _bindings.Channel_SetChannelGroup(_channel, group._group),
      'Channel_SetChannelGroup',
    );
  }
}
