// Smoke tests against a real FMOD Engine SDK, driving the idiomatic
// wrapper (which exercises the raw bindings underneath). Skipped unless
// FMOD_SDK_PATH points at an extracted SDK (the directory containing
// api/), since the SDK cannot be redistributed or fetched in CI. Run
// locally with
//
//   FMOD_SDK_PATH="$HOME/projects/FMOD Programmers API" dart test

import 'dart:io';

import 'package:fmod/fmod.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

final String? sdkPath = Platform.environment['FMOD_SDK_PATH'];

String get _media => '$sdkPath/api/studio/examples/media';

Future<void> _pump(FmodStudioSystem system, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    system.update();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

void main() {
  final skip = sdkPath == null
      ? 'FMOD_SDK_PATH is not set; SDK smoke tests need a local FMOD SDK.'
      : null;

  late FmodStudioSystem system;

  setUp(() {
    system = FmodStudioSystem.create();
  });

  tearDown(() => system.release());

  test('banks load and an authored event reaches a playing state', () async {
    system.loadBankFile('$_media/Master.strings.bank');
    system.loadBankFile('$_media/Master.bank');
    system.loadBankFile('$_media/SFX.bank');

    system.setListenerAttributes(
      position: Vector3.zero(),
      velocity: Vector3.zero(),
      forward: Vector3(0, 0, 1),
      up: Vector3(0, 1, 0),
    );

    final event = system.getEvent('event:/Ambience/Country').createInstance();
    event.set3dAttributes(
      position: Vector3(0, 0, 4),
      velocity: Vector3.zero(),
      forward: Vector3(0, 0, 1),
      up: Vector3(0, 1, 0),
    );
    event.volume = 0.5;
    event.start();
    await _pump(system);
    expect(event.playbackState, isNot(FmodPlaybackState.stopped));

    event.stop(mode: FmodStopMode.immediate);
    event.release();
    system.update();
  }, skip: skip);

  test('event parameters apply, unknown names throw', () async {
    system.loadBankFile('$_media/Master.strings.bank');
    system.loadBankFile('$_media/Master.bank');
    system.loadBankFile('$_media/SFX.bank');

    final steps = system
        .getEvent('event:/Character/Player Footsteps')
        .createInstance();
    steps.setParameter('Surface', 2.0);
    steps.start();
    await _pump(system, frames: 5);
    expect(
      () => steps.setParameter('Bogus', 1.0),
      throwsA(isA<FmodException>().having((e) => e.result, 'result', 74)),
    );
    steps.stop(mode: FmodStopMode.immediate);
    steps.release();

    expect(() => system.getEvent('event:/Nope'), throwsA(isA<FmodException>()));
  }, skip: skip);

  test('bank loads from memory', () async {
    system.loadBankMemory(
      await File('$_media/Master.strings.bank').readAsBytes(),
    );
    system.loadBankMemory(await File('$_media/Master.bank').readAsBytes());
    expect(system.getBus('bus:/'), isNotNull);
  }, skip: skip);

  test('core sounds, channels, and channel groups', () async {
    final wav = '$sdkPath/api/core/examples/media/drumloop.wav';
    final sound = system.core.createSound(wav);
    expect(sound.duration.inMilliseconds, greaterThan(0));

    final group = system.core.createChannelGroup('sfx');
    group.volume = 0.7;

    final channel = system.core.playSound(sound, group: group)
      ..volume = 0.5
      ..pitch = 1.2
      ..setMode(FmodMode.sample3d | fmodLoopOff);
    channel.set3dAttributes(Vector3(1, 0, 3), Vector3.zero());
    channel.set3dMinMaxDistance(1, 100);
    channel.dopplerLevel = 0;
    channel.paused = false;
    await _pump(system, frames: 5);
    expect(channel.isPlaying, isTrue);
    channel.stop();
    await _pump(system, frames: 2);
    expect(channel.isPlaying, isFalse);
    // Operations on a dead channel are safe no-ops.
    channel.volume = 1.0;
    channel.stop();
    sound.release();
  }, skip: skip);

  test('sound loads from bytes', () async {
    final bytes = await File(
      '$sdkPath/api/core/examples/media/drumloop.wav',
    ).readAsBytes();
    final sound = await system.core.createSoundFromBytes(bytes);
    expect(sound.duration.inMilliseconds, greaterThan(0));
    sound.release();
  }, skip: skip);

  test('nosound output mixes headless', () async {
    final headless = FmodStudioSystem.create(output: FmodOutputType.nosound);
    try {
      headless.loadBankFile('$_media/Master.strings.bank');
      headless.loadBankFile('$_media/Master.bank');
      headless.loadBankFile('$_media/SFX.bank');
      final event = headless
          .getEvent('event:/Ambience/Country')
          .createInstance();
      event.start();
      await _pump(headless);
      expect(event.playbackState, isNot(FmodPlaybackState.stopped));
      event.stop(mode: FmodStopMode.immediate);
      event.release();
    } finally {
      headless.release();
    }
  }, skip: skip);

  test('studio bus volume applies', () async {
    system.loadBankFile('$_media/Master.strings.bank');
    system.loadBankFile('$_media/Master.bank');
    final bus = system.getBus('bus:/');
    bus.volume = 0.5;
    expect(bus.volume, 0.5);
  }, skip: skip);
}
