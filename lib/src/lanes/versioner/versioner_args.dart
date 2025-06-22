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

  factory VersionerArgs.fromJson(Map<String, dynamic> json) =>
      _$VersionerArgsFromJson(json);

  final String? pubspecFile;
  final VersionComponent versionComponent;
  final String? value;

  @override
  Map<String, dynamic> toJson() => _$VersionerArgsToJson(this);
}
