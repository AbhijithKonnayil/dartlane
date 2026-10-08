import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';

/// Checks that the `flutter` command is installed and working.
///
/// It runs `flutter --version` and reports the first line, for example
/// `Flutter 3.44.8 • channel stable`.
class FlutterSdkCheck extends DoctorCheck {
  /// Creates the check.
  const FlutterSdkCheck();

  @override
  String get name => 'Flutter SDK';

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final ShellResult result;
    try {
      result = await ctx.shell.run('flutter', ['--version']);
    } on ProcessException {
      return const DoctorResult.fail(
        'The flutter command was not found.',
        fix:
            'Install Flutter (https://docs.flutter.dev/get-started/install) '
            'and make sure `flutter --version` works in this terminal.',
      );
    }

    if (!result.ok) {
      final reason = result.stderr.trim().split('\n').first;
      return DoctorResult.fail(
        '`flutter --version` exited with code ${result.exitCode}.'
        '${reason.isEmpty ? '' : ' $reason'}',
        fix: 'Run `flutter doctor` to see what is wrong with the installation.',
      );
    }

    return DoctorResult.pass(_summary(result.stdout));
  }

  /// `Flutter 3.44.8 • channel stable • https://...` becomes
  /// `Flutter 3.44.8 • channel stable`.
  String _summary(String output) {
    final first = output.trim().split('\n').first;
    return first.split(' • ').take(2).join(' • ');
  }
}
