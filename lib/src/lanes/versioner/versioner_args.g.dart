// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'versioner_args.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VersionerArgs _$VersionerArgsFromJson(Map<String, dynamic> json) =>
    VersionerArgs(
      versionComponent:
          $enumDecode(_$VersionComponentEnumMap, json['versionComponent']),
      pubspecFile: json['pubspecFile'] as String?,
      value: json['value'] as String?,
    );

Map<String, dynamic> _$VersionerArgsToJson(VersionerArgs instance) =>
    <String, dynamic>{
      'pubspecFile': instance.pubspecFile,
      'versionComponent': _$VersionComponentEnumMap[instance.versionComponent]!,
      'value': instance.value,
    };

const _$VersionComponentEnumMap = {
  VersionComponent.versionName: 'versionName',
  VersionComponent.versionCode: 'versionCode',
  VersionComponent.patch: 'patch',
  VersionComponent.major: 'major',
  VersionComponent.minor: 'minor',
};
