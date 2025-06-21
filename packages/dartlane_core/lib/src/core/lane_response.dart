import 'package:dartlane_core/dartlane_core.dart';

class LaneResponse {
  final dynamic response;
  late final Status status;

  LaneResponse({required this.response, required this.status});

  LaneResponse.success({this.response}) {
    status = Status.completed;
  }
  LaneResponse.error({this.response}) {
    status = Status.error;
  }
}
