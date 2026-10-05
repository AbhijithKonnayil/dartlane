// ignore_for_file: avoid_print

import 'package:dartlane_core/dartlane_core.dart';

Future<void> main(List<String> args) async {
  await DartlaneRunner.run(
    args,
    setup: () {
      Lanes.register('custom', CustomLane());
    },
  );
}

class CustomLane extends Lane {
  @override
  Future<void> execute(Map<String, String> laneArgs) async {
    print('Custom lane executed with args : $laneArgs');
  }

  @override
  String get description => 'Custom lane description';

  @override
  String get name => 'custom';
}
