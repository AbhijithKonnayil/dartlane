import 'dart:io';

import 'package:dartlane/src/version.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// Checks that the Dart SDK running Dartlane is new enough.
class DartSdkCheck extends DoctorCheck {
  /// Creates the check.
  ///
  /// [version] is the text of the Dart version, as in `Platform.version`. It
  /// defaults to the running SDK and can be set in tests.
  DartSdkCheck({String? version}) : _version = version ?? Platform.version;

  final String _version;

  @override
  String get name => 'Dart SDK';

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final found = _parse(_version);
    if (found == null) {
      return DoctorResult.fail(
        'Could not read the Dart version from "$_version".',
        fix: 'Reinstall Dart or Flutter: https://dart.dev/get-dart',
      );
    }

    final shown = found.join('.');
    if (_isOlder(found, _parse(minimumDartVersion)!)) {
      return DoctorResult.fail(
        '$shown is older than the $minimumDartVersion that Dartlane needs.',
        fix:
            'Update Dart ($minimumDartVersion or newer) or run `flutter '
            'upgrade`.',
      );
    }
    return DoctorResult.pass(shown);
  }

  /// `3.12.2 (stable) ...` gives `[3, 12, 2]`.
  List<int>? _parse(String text) {
    final match = RegExp(r'^\s*(\d+)\.(\d+)\.(\d+)').firstMatch(text);
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  bool _isOlder(List<int> version, List<int> minimum) {
    for (var i = 0; i < 3; i++) {
      if (version[i] != minimum[i]) return version[i] < minimum[i];
    }
    return false;
  }
}
