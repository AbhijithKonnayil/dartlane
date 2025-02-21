import 'dart:io';

import 'package:dartlane/src/command_runner.dart';

Future<void> main(List<String> args) async {
  //ReceivePort receivePort = ReceivePort();
  //Isolate.spawn(isoMain, null);
  await DartlaneCommandRunner().run(args);
  //await _flushThenExit(await DartlaneCommandRunner().run(args));
}

/// Flushes the stdout and stderr streams, then exits the program with the given
/// status code.
///
/// This returns a Future that will never complete, since the program will have
/// exited already. This is useful to prevent Future chains from proceeding
/// after you've decided to exit.
// TODO(abhijith): check this functionality.
// ignore: unused_element
Future<void> _flushThenExit(int status) {
  return Future.wait<void>([stdout.close(), stderr.close()])
      .then<void>((_) => exit(status));
}
