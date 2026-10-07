import 'dart:io';

import 'package:dartlane/src/update/update_cache.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('dartlane_cache_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('nothing is read before anything is written', () {
    expect(UpdateCache(dir).read(), isNull);
  });

  test('a record can be read back', () {
    final cache = UpdateCache(dir);
    final when = DateTime.utc(2026, 10, 7, 12);

    cache.write(UpdateCheckRecord(checkedAt: when, latest: Version(0, 2, 0)));
    final record = cache.read()!;

    expect(record.checkedAt, when);
    expect(record.latest, Version(0, 2, 0));
  });

  test('a record with no version can be read back', () {
    final cache = UpdateCache(dir)
      ..write(UpdateCheckRecord(checkedAt: DateTime.utc(2026)));

    expect(cache.read()!.latest, isNull);
  });

  test('a later record replaces the earlier one', () {
    final cache = UpdateCache(dir)
      ..write(
        UpdateCheckRecord(
          checkedAt: DateTime.utc(2026),
          latest: Version(1, 0, 0),
        ),
      )
      ..write(
        UpdateCheckRecord(
          checkedAt: DateTime.utc(2027),
          latest: Version(2, 0, 0),
        ),
      );

    expect(cache.read()!.latest, Version(2, 0, 0));
  });

  test('the folder is created when it does not exist', () {
    final inner = Directory(p.join(dir.path, 'a', 'b'));

    UpdateCache(inner).write(UpdateCheckRecord(checkedAt: DateTime.utc(2026)));

    expect(UpdateCache(inner).read(), isNotNull);
  });

  test('a damaged file reads as nothing instead of failing', () {
    File(p.join(dir.path, 'update_check.json')).writeAsStringSync('{ nope');

    expect(UpdateCache(dir).read(), isNull);
  });

  test('a file that cannot be written is ignored', () {
    // A file where the folder should be.
    final blocker = File(p.join(dir.path, 'blocked'))..writeAsStringSync('');

    expect(
      () => UpdateCache(
        Directory(blocker.path),
      ).write(UpdateCheckRecord(checkedAt: DateTime.utc(2026))),
      returnsNormally,
    );
  });
}
