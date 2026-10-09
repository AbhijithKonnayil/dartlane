import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:test/test.dart';

const _apkOutput = 'Built build/app/outputs/flutter-apk/app-prod-profile.apk';

void main() {
  final lanes = flutterLanes();

  test('registers the lanes', () {
    expect(
      lanes.keys,
      containsAll([
        'flutter_build_apk',
        'flutter_build_appbundle',
        'flutter_pub_get',
        'flutter_analyze',
        'flutter_test',
      ]),
    );
  });

  test('flutter_build_apk passes its options to the build', () async {
    final ctx = FakeLaneContext(
      args: [
        '--mode=profile',
        '--flavor=prod',
        '--dart-define=A=1,2',
        '--dart-define=B=x',
        '--build-name=1.2.3',
        '--build-number=4',
      ],
    );
    ctx.shell.stub(
      'flutter build apk --profile --flavor=prod --dart-define=A=1,2 '
      '--dart-define=B=x --build-name=1.2.3 --build-number=4',
      stdout: _apkOutput,
    );

    await lanes['flutter_build_apk']!.run(ctx);

    expect(ctx.shell.commands, hasLength(1));
  });

  test('flutter_build_appbundle defaults to a release bundle', () async {
    final ctx = FakeLaneContext();
    ctx.shell.stub(
      'flutter build appbundle --release',
      stdout: 'Built build/app/outputs/bundle/release/app-release.aab',
    );

    await lanes['flutter_build_appbundle']!.run(ctx);

    expect(ctx.shell.commands, ['flutter build appbundle --release']);
  });

  test('rejects a bad mode', () {
    final ctx = FakeLaneContext(args: ['--mode=fast']);
    expect(lanes['flutter_build_apk']!.run(ctx), throwsA(isA<UserError>()));
  });

  test('rejects a misspelled option', () {
    final ctx = FakeLaneContext(args: ['--flavour=prod']);
    expect(lanes['flutter_build_apk']!.run(ctx), throwsA(isA<UserError>()));
  });

  test('flutter_analyze can relax the gates', () async {
    final ctx = FakeLaneContext(args: ['--no-fatal-infos']);
    await lanes['flutter_analyze']!.run(ctx);
    expect(ctx.shell.commands, ['flutter analyze --no-fatal-infos']);
  });

  test('flutter_test takes paths and coverage', () async {
    final ctx = FakeLaneContext(args: ['--coverage', 'test/a_test.dart']);
    await lanes['flutter_test']!.run(ctx);
    expect(ctx.shell.commands, ['flutter test --coverage test/a_test.dart']);
  });

  test('flutter_pub_get runs offline on request', () async {
    final ctx = FakeLaneContext(args: ['--offline']);
    await lanes['flutter_pub_get']!.run(ctx);
    expect(ctx.shell.commands, ['flutter pub get --offline']);
  });
}
