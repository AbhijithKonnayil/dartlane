import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// What an earlier check found out.
class UpdateCheckRecord {
  /// Creates a record of a check made at [checkedAt].
  ///
  /// [latest] is null if the check found no version, for example because the
  /// package is not published or pub.dev could not be reached.
  const UpdateCheckRecord({required this.checkedAt, this.latest});

  /// When the check was made.
  final DateTime checkedAt;

  /// The newest version that check found, if any.
  final Version? latest;
}

/// Remembers the last update check in a small file, so the network is asked at
/// most once a day and not on every command.
class UpdateCache {
  /// Creates a cache that keeps its file in [directory].
  const UpdateCache(this.directory);

  /// The folder for the cache file, usually `~/.dartlane`.
  final Directory directory;

  File get _file => File(p.join(directory.path, 'update_check.json'));

  /// The last record, or null if there is none or it cannot be read.
  UpdateCheckRecord? read() {
    try {
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      final latest = json['latest'] as String?;
      return UpdateCheckRecord(
        checkedAt: DateTime.parse(json['checkedAt'] as String),
        latest: latest == null ? null : Version.parse(latest),
      );
    } on Object {
      return null;
    }
  }

  /// Saves [record]. Failing to write is ignored: the cache is only a speedup.
  void write(UpdateCheckRecord record) {
    try {
      directory.createSync(recursive: true);
      _file.writeAsStringSync(
        jsonEncode({
          'checkedAt': record.checkedAt.toUtc().toIso8601String(),
          'latest': record.latest?.toString(),
        }),
      );
    } on Object {
      // Nothing to do: the next command checks again.
    }
  }
}
