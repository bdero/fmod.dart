/// A failed FMOD call.
class FmodException implements Exception {
  FmodException(this.operation, this.result);

  final String operation;

  /// The FMOD_RESULT error code; see fmod_common.h for meanings.
  final int result;

  @override
  String toString() => 'FmodException($operation failed, FMOD_RESULT $result)';
}
