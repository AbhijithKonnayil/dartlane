import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/src/testing/fake_lane_context.dart';
import 'package:dartlane_core/src/testing/fake_lane_logger.dart';
import 'package:test/test.dart';

void main() {
  group('parseDotEnv', () {
    test('reads pairs, comments, export and quotes', () {
      expect(
        parseDotEnv('# c\n\nA=1\nexport B = "two words"\nC=\'x\'\nbad\n'),
        {'A': '1', 'B': 'two words', 'C': 'x'},
      );
    });
  });

  group('EnvSecretsProvider', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('secrets'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('env wins over the file; missing file is fine', () {
      final path = '${dir.path}/.env';
      File(path).writeAsStringSync('A=file\nB=file\n');
      final p = EnvSecretsProvider({'A': 'env'}, dotEnvPath: path);
      expect(p.read('A'), 'env');
      expect(p.read('B'), 'file');
      expect(p.read('C'), isNull);
      expect(
        EnvSecretsProvider({}, dotEnvPath: '${dir.path}/none').read('A'),
        isNull,
      );
    });
  });

  group('ctx.secrets', () {
    test('masks values read through it in every log level', () {
      final ctx = FakeLaneContext(env: {'TOKEN': 's3cret'}, verbose: true);
      expect(ctx.secrets.require('TOKEN'), 's3cret');
      ctx.logger
        ..info('a s3cret b')
        ..detail('s3cret')
        ..success('s3cret')
        ..warn('s3cret')
        ..error('s3cret');
      expect(ctx.logger.lines.join('\n'), isNot(contains('s3cret')));
      expect(ctx.logger.lines.first, 'a *** b');
    });

    test('masks in GitHub annotations', () {
      final logger = FakeLaneLogger(githubActions: true);
      final secrets = LaneSecrets(EnvSecretsProvider({'K': 'abc'}), logger)
        ..read('K');
      logger.error('bad abc');
      expect(logger.lines.single, '::error::bad ***');
      expect(secrets.read('NOPE'), isNull);
    });

    test('values not read through secrets are not masked', () {
      final ctx = FakeLaneContext(env: {'TOKEN': 's3cret'});
      ctx.logger.info('s3cret');
      expect(ctx.logger.lines.single, 's3cret');
    });

    test('require throws a UserError when missing', () {
      expect(
        () => FakeLaneContext().secrets.require('X'),
        throwsA(isA<UserError>()),
      );
    });
  });
}
