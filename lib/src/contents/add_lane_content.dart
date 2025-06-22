const LANE_CONTENT = """
import 'package:dartlane_core/dartlane_core.dart';

class {{LANE_CLASSNAME}} extends Lane {
  @override
  // TODO: implement description
  String get description => throw UnimplementedError();

  @override
  Future<LaneResponse> executeLogic(Map<String, String> laneArgs) async {
  // TODO: implement description

   return LaneResponse.success();
  }

  @override
  // TODO: implement name
  String get name => throw UnimplementedError();
}
""";
const LANE_ARGS_CONTENT = r"""
import 'package:dartlane_core/dartlane_core.dart';
import 'package:json_annotation/json_annotation.dart';
part '{{LANE_FILENAME}}_args.g.dart';

@JsonSerializable()
class {{LANE_ARGS_CLASSNAME}} extends LaneArgs {
  {{LANE_ARGS_CLASSNAME}}();

  factory {{LANE_ARGS_CLASSNAME}}.fromJson(Map<String, dynamic> json) =>
      _${{LANE_ARGS_CLASSNAME}}FromJson(json);

  @override
  Map<String, dynamic> toJson() => _${{LANE_ARGS_CLASSNAME}}ToJson(this);
}
""";
