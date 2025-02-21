// ignore_for_file: avoid_print

import 'dart:isolate';

import 'package:dartlane/dartlane.dart';

Future<void> main(
  List<String> args,
  SendPort sendPort,
) async {
  Lane.register('custom', CustomLane());
}

class CustomLane extends Lane {
  @override
  Future<void> execute(Map<String, String> laneArgs) async {
    print('Custom lane executed with args : $laneArgs');
  }

  @override
  String get description => 'Custom lane description';
}
