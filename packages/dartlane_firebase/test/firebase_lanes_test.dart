import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_firebase/dartlane_firebase.dart';
import 'package:test/test.dart';

void main() {
  final lane = firebaseLanes()['firebase_distribute']!;

  test('needs --app and --file', () {
    expect(
      lane.run(FakeLaneContext(args: ['--file=app.apk'])),
      throwsA(isA<UserError>()),
    );
    expect(
      lane.run(FakeLaneContext(args: ['--app=1:123:android:abc'])),
      throwsA(isA<UserError>()),
    );
  });

  test('rejects a misspelled option', () {
    final ctx = FakeLaneContext(
      args: ['--app=1:123:android:abc', '--file=a.apk', '--group=qa'],
    );
    expect(lane.run(ctx), throwsA(isA<UserError>()));
  });

  test('describes the distribution in a dry run', () async {
    final ctx = FakeLaneContext(
      dryRun: true,
      args: [
        '--app=1:123:android:abc',
        '--file=app.apk',
        '--groups=qa,beta',
        '--testers=a@x.com',
      ],
    );

    await lane.run(ctx);

    expect(
      ctx.dryRunSteps.single,
      'Distribute app.apk to Firebase app 1:123:android:abc '
      '(qa, beta, a@x.com)',
    );
  });

  test('checks the app id', () {
    final ctx = FakeLaneContext(
      dryRun: true,
      args: ['--app=nope', '--file=app.apk'],
    );
    expect(lane.run(ctx), throwsA(isA<UserError>()));
  });
}
