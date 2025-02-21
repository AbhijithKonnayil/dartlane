// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/lane_args.dart';

class FlutterBuildLaneArgs implements LaneArgs {
  FlutterBuildLaneArgs({
    required this.target,
    required this.buildType,
    this.flavor,
    this.treeShakeIcons = true,
    this.pub = true,
    this.buildNumber,
    this.buildName,
    this.obfuscate = true,
    this.dartDefine = const {},
    this.dartDefineFromFile,
    this.splitPerAbi = true,
  });
  final bool treeShakeIcons;
  final String target;
  final String? flavor;
  final BuildType buildType;
  final bool pub;
  final int? buildNumber;
  final String? buildName;
  final bool obfuscate;
  final Map<String, String> dartDefine;
  final String? dartDefineFromFile;
  final bool splitPerAbi;
}
