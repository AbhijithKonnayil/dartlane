/// Process exit codes used by the runner.
///
/// The values follow the BSD `sysexits.h` convention where one fits, so
/// callers and CI can tell a usage mistake from a failed lane.
abstract final class ExitCodes {
  /// The lane finished.
  static const success = 0;

  /// The lane threw.
  static const failure = 1;

  /// The lane name was missing or unknown (`EX_USAGE`).
  static const usage = 64;
}
