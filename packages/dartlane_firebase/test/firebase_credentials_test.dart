import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_firebase/dartlane_firebase.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cred'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('serviceAccountFileFor', () {
    test('explicit wins over the environment', () {
      final ctx = FakeLaneContext(env: {'GOOGLE_APPLICATION_CREDENTIALS': 'e'});
      expect(serviceAccountFileFor(ctx, explicit: 'x.json'), 'x.json');
      expect(serviceAccountFileFor(ctx), 'e');
    });

    test('is null when nothing is set', () {
      expect(serviceAccountFileFor(FakeLaneContext()), isNull);
      expect(
        serviceAccountFileFor(
          FakeLaneContext(env: {'GOOGLE_APPLICATION_CREDENTIALS': ''}),
        ),
        isNull,
      );
    });
  });

  group('connectToFirebase errors', () {
    test('missing file is a UserError naming the path', () {
      expect(
        connectToFirebase(
          FakeLaneContext(),
          serviceAccountFile: '${dir.path}/none.json',
        ),
        throwsA(
          isA<UserError>().having(
            (e) => e.message,
            'message',
            contains('none.json'),
          ),
        ),
      );
    });

    test('invalid JSON and wrong shape are UserErrors', () async {
      final bad = File('${dir.path}/bad.json')..writeAsStringSync('{nope');
      final wrong = File('${dir.path}/wrong.json')
        ..writeAsStringSync(jsonEncode({'type': 'service_account'}));
      for (final file in [bad, wrong]) {
        await expectLater(
          connectToFirebase(FakeLaneContext(), serviceAccountFile: file.path),
          throwsA(isA<UserError>()),
        );
      }
    });

    test('the file from GOOGLE_APPLICATION_CREDENTIALS is used', () {
      final ctx = FakeLaneContext(
        env: {'GOOGLE_APPLICATION_CREDENTIALS': '${dir.path}/env.json'},
      );
      expect(
        connectToFirebase(ctx),
        throwsA(
          isA<UserError>().having(
            (e) => e.message,
            'message',
            contains('env.json'),
          ),
        ),
      );
    });
  });

  group('FirebaseCredentialsCheck', () {
    test('is an optional check', () {
      expect(const FirebaseCredentialsCheck().isRequired, isFalse);
      expect(firebaseChecks(), hasLength(1));
    });

    test('passes with an existing service account file', () async {
      final file = File('${dir.path}/k.json')..writeAsStringSync('{}');
      final result = await FirebaseCredentialsCheck(
        serviceAccountFile: file.path,
      ).run(FakeLaneContext());
      expect(result.ok, isTrue);
    });

    test('fails when the named file is missing', () async {
      final result = await const FirebaseCredentialsCheck(
        serviceAccountFile: '/nope/k.json',
      ).run(FakeLaneContext());
      expect(result.ok, isFalse);
      expect(result.message, contains('/nope/k.json'));
    });

    test('passes with the gcloud ADC file', () async {
      final adc = File(
        '${dir.path}/.config/gcloud/application_default_credentials.json',
      )..createSync(recursive: true);
      final ctx = FakeLaneContext(env: {'HOME': dir.path});
      final result = await const FirebaseCredentialsCheck().run(ctx);
      expect(adc.existsSync(), isTrue);
      expect(result.ok, Platform.isWindows ? isFalse : isTrue);
    });

    test('fails with a fix when nothing is found', () async {
      final result = await const FirebaseCredentialsCheck().run(
        FakeLaneContext(env: {'HOME': dir.path}),
      );
      expect(result.ok, isFalse);
      expect(result.fix, contains('GOOGLE_APPLICATION_CREDENTIALS'));
    });
  });
}
