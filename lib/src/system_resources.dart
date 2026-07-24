import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:fmod/src/ffi/bindings.dart';
import 'package:vector_math/vector_math.dart';

/// Native scratch buffers shared by a system's wrapper objects, so the
/// per-frame calls (3D attributes, playback state polls) allocate
/// nothing. FMOD systems are expected to be driven from one isolate.
class SystemResources {
  SystemResources(this.bindings)
    : attributes = calloc<Fmod3dAttributes>(),
      vectorA = calloc<FmodVector>(),
      vectorB = calloc<FmodVector>(),
      intOut = calloc<Int32>(),
      uintOut = calloc<Uint32>(),
      pointerOut = calloc<Pointer<Void>>();

  final FmodBindings bindings;
  final Pointer<Fmod3dAttributes> attributes;
  final Pointer<FmodVector> vectorA;
  final Pointer<FmodVector> vectorB;
  final Pointer<Int32> intOut;
  final Pointer<Uint32> uintOut;
  final Pointer<Pointer<Void>> pointerOut;

  bool _released = false;

  void writeAttributes({
    required Vector3 position,
    required Vector3 velocity,
    required Vector3 forward,
    required Vector3 up,
  }) {
    final target = attributes.ref;
    writeVector(target.position, position);
    writeVector(target.velocity, velocity);
    writeVector(target.forward, forward);
    writeVector(target.up, up);
  }

  static void writeVector(FmodVector target, Vector3 source) {
    target.x = source.x;
    target.y = source.y;
    target.z = source.z;
  }

  void release() {
    if (_released) return;
    _released = true;
    calloc.free(attributes);
    calloc.free(vectorA);
    calloc.free(vectorB);
    calloc.free(intOut);
    calloc.free(uintOut);
    calloc.free(pointerOut);
  }
}
