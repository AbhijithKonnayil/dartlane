// A lane tested end to end with fakes only: no process is started and no
// network request is made. This is the pattern lane authors are meant to use.
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

/// Builds an APK, then uploads it.
final buildAndUpload = Lane('Build and upload', (ctx) async {
  await ctx.sh('flutter', ['build', 'apk']);
  final response = await ctx.http.post(
    Uri.parse('https://example.com/upload'),
    body: 'apk-bytes',
  );
  if (response.statusCode != 200) {
    throw StateError('upload failed with ${response.statusCode}');
  }
});

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  test('builds, then uploads', () async {
    ctx.http.stub('POST https://example.com/upload');

    await buildAndUpload.run(ctx);

    expect(ctx.shell.commands, ['flutter build apk']);
    expect(ctx.http.requests.single.body, 'apk-bytes');
  });

  test('fails when the upload is rejected', () async {
    ctx.http.stub('POST https://example.com/upload', status: 500);

    await expectLater(buildAndUpload.run(ctx), throwsStateError);
  });

  test('does not upload when the build fails', () async {
    ctx.shell.stub('flutter build apk', exitCode: 1);

    await expectLater(buildAndUpload.run(ctx), throwsA(isA<ShellException>()));
    expect(ctx.http.requests, isEmpty);
  });
}
