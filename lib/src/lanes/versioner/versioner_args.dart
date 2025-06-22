import 'package:dartlane/dartlane.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:json_annotation/json_annotation.dart';

part 'versioner_args.g.dart';

@JsonSerializable()
class VersionerArgs extends LaneArgs {
  VersionerArgs({
    required this.versionComponent,
    this.pubspecFile,
    this.value,
  });

  final String? pubspecFile;
  final VersionComponent versionComponent;
  final String? value;

  factory VersionerArgs.fromJson(Map<String, dynamic> json) =>
      _$VersionerArgsFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$VersionerArgsToJson(this);
}
