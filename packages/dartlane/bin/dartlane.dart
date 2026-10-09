import 'dart:io';

import 'package:dartlane/dartlane.dart';

Future<void> main(List<String> args) async {
  exitCode = await DartlaneCommandRunner().run(args);
}
