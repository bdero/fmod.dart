// FMOD's numeric constants, shared by every backend (the values are
// part of the FMOD ABI and identical across platforms, including the
// HTML5 build).

/// The FMOD header version these bindings target (2.03.00). Passed to
/// system creation; FMOD fails with a header-mismatch error when the
/// user's SDK is incompatible, in which case create the system with
/// the matching version.
const int kFmodDefaultHeaderVersion = 0x00020300;

// FMOD_RESULT values this package special-cases.
const int fmodOk = 0;
const int fmodErrChannelStolen = 3;
const int fmodErrInvalidHandle = 30;
const int fmodErrEventNotFound = 74;

// FMOD_MODE flags (fmod_common.h).
const int fmodLoopOff = 0x00000001;
const int fmodLoopNormal = 0x00000002;
const int fmod2d = 0x00000008;
const int fmod3d = 0x00000010;
const int fmodCreateSample = 0x00000100;
const int fmod3dInverseRolloff = 0x00100000;
const int fmod3dLinearRolloff = 0x00200000;
const int fmod3dInverseTaperedRolloff = 0x00800000;

// FMOD_STUDIO_* constants (fmod_studio_common.h).
const int fmodStudioInitNormal = 0;
const int fmodStudioInitLiveUpdate = 1;
const int fmodInitNormal = 0;
const int fmodStudioLoadBankNormal = 0;
const int fmodStudioLoadMemory = 0;
const int fmodStudioStopAllowFadeout = 0;
const int fmodStudioStopImmediate = 1;
const int fmodTimeUnitMs = 0x1;

/// FMOD_STUDIO_PLAYBACK_STATE.
const int fmodStudioPlaybackPlaying = 0;
const int fmodStudioPlaybackSustaining = 1;
const int fmodStudioPlaybackStopped = 2;
const int fmodStudioPlaybackStarting = 3;
const int fmodStudioPlaybackStopping = 4;

/// FMOD_STUDIO_EVENT_PROPERTY indices for distance overrides.
const int fmodStudioEventPropertyMinDistance = 3;
const int fmodStudioEventPropertyMaxDistance = 4;
