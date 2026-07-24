/// The raw native layer of the fmod package, the looked-up C entry
/// points, structs, the SDK-locating library loader, and escape hatches
/// from the idiomatic wrapper down to native handles.
///
/// Native platforms only; the platform-neutral surface is
/// `package:fmod/fmod.dart`.
library;

export 'src/ffi/bindings.dart';
export 'src/ffi/library.dart';
export 'src/fmod_base.dart'
    show FmodCoreSystemFfi, FmodStudioSystemFfi, createStudioSystemWithLibrary;
