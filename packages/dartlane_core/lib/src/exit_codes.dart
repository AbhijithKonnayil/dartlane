/// Process exit codes used by the runner.
///
/// The values follow the BSD `sysexits.h` convention where one fits, so
/// callers and CI can tell a usage mistake from a failed lane.
abstract final class ExitCodes {
  /// The lane finished.
  static const success = 0;

  /// A step failed (`ActionFailed`) or the lane threw something unexpected.
  static const failure = 1;

  /// The person running the lane gave something wrong: the lane name was
  /// missing or unknown, or a `UserError` was thrown (`EX_USAGE`).
  static const usage = 64;
}
