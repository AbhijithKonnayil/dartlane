import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/src/flutter_flavors_check.dart';
import 'package:dartlane_flutter/src/flutter_sdk_check.dart';

/// The checks `dartlane doctor` runs for a Flutter project.
///
/// Pass them to `dartlane()` in `lanes.dart`:
///
/// ```dart
/// dartlane(args, lanes: {...}, checks: flutterChecks());
/// ```
///
/// [projectDirectory] is the Flutter project, the current directory by default.
List<DoctorCheck> flutterChecks({String projectDirectory = '.'}) => [
  const FlutterSdkCheck(),
  FlutterFlavorsCheck(projectDirectory: projectDirectory),
];
