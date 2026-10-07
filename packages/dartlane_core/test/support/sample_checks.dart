// Small doctor checks used by the tests, one for each outcome.
import 'package:dartlane_core/dartlane_core.dart';

/// A required check that passes with a message.
class PassingCheck extends DoctorCheck {
  const PassingCheck({this.message = '3.12.2'});

  final String message;

  @override
  String get name => 'Dart SDK';

  @override
  Future<DoctorResult> run(LaneContext ctx) async => DoctorResult.pass(message);
}

/// A required check that fails with a fix.
class FailingCheck extends DoctorCheck {
  const FailingCheck();

  @override
  String get name => 'Flutter SDK';

  @override
  Future<DoctorResult> run(LaneContext ctx) async => const DoctorResult.fail(
    'flutter was not found',
    fix: 'Install Flutter and add it to your PATH.',
  );
}

/// An optional check that fails with a fix.
class OptionalFailingCheck extends DoctorCheck {
  const OptionalFailingCheck();

  @override
  String get name => 'Flavors';

  @override
  bool get isRequired => false;

  @override
  Future<DoctorResult> run(LaneContext ctx) async => const DoctorResult.fail(
    'none found',
    fix: 'Add productFlavors to android/app/build.gradle if you need them.',
  );
}

/// A check that throws instead of returning a result.
class ThrowingCheck extends DoctorCheck {
  const ThrowingCheck();

  @override
  String get name => 'Credentials';

  @override
  Future<DoctorResult> run(LaneContext ctx) async =>
      throw StateError('could not read the key file');
}
