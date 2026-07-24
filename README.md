# fmod

Unofficial Dart FFI bindings for the [FMOD Engine](https://www.fmod.com) audio middleware, covering the Studio API (banks, events, parameters, buses) and the Core API (sounds, channels, channel groups, 3D audio).

This is a pure Dart package (no Flutter dependency), usable from Flutter apps, `dart run` programs, and servers on desktop and mobile targets. FMOD is a trademark of Firelight Technologies Pty Ltd; this package is not affiliated with or endorsed by Firelight.

> **Status: experimental.** The wrapper covers the surface needed for game audio playback; the raw entry points are exposed through `FmodBindings` for anything not yet wrapped, and coverage grows as needed. Verified against FMOD Engine 2.03.14.

## FMOD SDK setup

FMOD is proprietary and its license does not permit redistributing the SDK, so this package ships no binaries. To use it

1. Register at [fmod.com](https://www.fmod.com) and download the FMOD Engine SDK for your target platforms (free license tiers are available; check the terms and the attribution requirement for your project).
2. Extract the SDK and set `FMOD_SDK_PATH` to the extracted root (the directory containing `api/`). Alternatively set `FMOD_LIBRARY_PATH` to any directory holding the core and studio dynamic libraries.
3. On macOS, clear the download quarantine from the extracted SDK or the system refuses to load the dylibs (`library load disallowed by system policy`): `xattr -dr com.apple.quarantine "<sdk root>"`.
4. Build and run with the variable set in the same shell, the runtime loads the libraries straight from the SDK during development.

Platform support: verified on macOS; the Windows and Linux SDK layouts are wired but not yet exercised; iOS and Android are not wired up yet. With `FMOD_SDK_PATH` set the build hook also bundles the SDK's dynamic libraries into the app as code assets, but the runtime does not consume the bundled copies yet, so a distributable build without the environment variables is not a supported flow yet.

Your app is responsible for FMOD's attribution requirement (the FMOD logo in your credits or splash).

## Usage

```dart
import 'package:fmod/fmod.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final system = FmodStudioSystem.create();

  system.loadBankFile('assets/banks/Master.strings.bank');
  system.loadBankFile('assets/banks/Master.bank');

  final event = system.getEvent('event:/Ambience/Country').createInstance();
  event.start();

  // Per frame: position the listener and pump the command queue.
  system.setListenerAttributes(
    position: Vector3.zero(),
    velocity: Vector3.zero(),
    forward: Vector3(0, 0, 1),
    up: Vector3(0, 1, 0),
  );
  system.update();

  // The Core API for raw sounds.
  final sound = system.core.createSound('assets/loop.ogg');
  final channel = system.core.playSound(sound)..volume = 0.8;
  channel.paused = false;
}
```

The SDK smoke tests run with `FMOD_SDK_PATH="<sdk root>" dart test` (they skip when the variable is unset, so CI needs no SDK).
