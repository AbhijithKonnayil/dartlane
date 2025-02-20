// ignore_for_file: avoid_print

import 'package:dartlane/dartlane.dart';

void main(
  List<String> args,
) {
  Lane.register('custom', CustomLane());
}

class CustomLane implements Lane {
  @override
  void description() {
    print('Custom lane description');
  }

  @override
  void execute() {
    print('Custom lane executed');
  }
}
