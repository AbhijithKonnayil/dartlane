import 'package:dartlane_core/dartlane_core.dart';
import 'package:test/test.dart';

/// Matches a [UserError] whose message contains [message].
Matcher userError(String message, {String? hint}) => isA<UserError>()
    .having((e) => e.message, 'message', contains(message))
    .having((e) => e.hint, 'hint', hint == null ? anything : contains(hint));

void main() {
  LaneArgs parse(List<String> arguments) => LaneArgs.parse(arguments);

  group('options', () {
    test('--key=value', () {
      final args = parse(['--flavor=prod']);

      expect(args.string('flavor'), 'prod');
      expect(args.has('flavor'), isTrue);
      expect(args.has('other'), isFalse);
      expect(args.string('other'), isNull);
    });

    test('values keep commas, colons, equals signs and at signs', () {
      final args = parse([
        '--testers=a@x.com,b@y.org',
        '--url=https://example.test:8080/a?b=c&d=e',
        r'--file=C:\builds\app.apk',
        '--define=KEY=a=b',
        '--notes=Fixes, improvements: faster',
      ]);

      expect(args.string('testers'), 'a@x.com,b@y.org');
      expect(args.string('url'), 'https://example.test:8080/a?b=c&d=e');
      expect(args.string('file'), r'C:\builds\app.apk');
      expect(args.string('define'), 'KEY=a=b');
      expect(args.string('notes'), 'Fixes, improvements: faster');
    });

    test('an empty value is kept', () {
      expect(parse(['--flavor=']).string('flavor'), '');
    });

    test('the last value wins when an option is repeated', () {
      expect(parse(['--a=1', '--a=2']).string('a'), '2');
    });

    test('names lists every option once', () {
      final args = parse(['--a=1', '--b', '--a=2', '--no-c', 'x']);

      expect(args.names, unorderedEquals(['a', 'b', 'c']));
    });

    test('raw keeps every argument as given', () {
      const arguments = ['--a=1', 'x', '--no-b', '--', '--c'];

      expect(parse(arguments).raw, arguments);
    });

    test('no arguments', () {
      expect(LaneArgs.empty.raw, isEmpty);
      expect(LaneArgs.empty.positional, isEmpty);
      expect(LaneArgs.empty.names, isEmpty);
    });
  });

  group('positional arguments', () {
    test('words that are not options', () {
      expect(parse(['one', '--a=1', 'two']).positional, ['one', 'two']);
    });

    test('a value is never taken from the next word', () {
      final args = parse(['--flavor', 'prod']);

      expect(args.string('flavor'), 'true');
      expect(args.positional, ['prod']);
    });

    test('single-dash words are positional', () {
      expect(parse(['-x', '-5']).positional, ['-x', '-5']);
    });

    test('the old key:value form is positional, not an error', () {
      final args = parse(['flavor:prod']);

      expect(args.positional, ['flavor:prod']);
      expect(args.has('flavor'), isFalse);
    });

    test('everything after -- is positional', () {
      final args = parse(['--a=1', '--', '--b=2', '--c']);

      expect(args.names, ['a']);
      expect(args.positional, ['--b=2', '--c']);
    });

    test('--=value has no name', () {
      final args = parse(['--=x']);

      expect(args.names, isEmpty);
      expect(args.positional, ['--=x']);
    });
  });

  group('flag', () {
    test('--name is on and --no-name is off', () {
      expect(parse(['--notify']).flag('notify'), isTrue);
      expect(
        parse(['--no-notify']).flag('notify', defaultValue: true),
        isFalse,
      );
    });

    test('--name=true and --name=false', () {
      expect(parse(['--notify=true']).flag('notify'), isTrue);
      expect(
        parse(['--notify=FALSE']).flag('notify', defaultValue: true),
        isFalse,
      );
    });

    test('uses the default when the flag was not given', () {
      expect(parse([]).flag('notify'), isFalse);
      expect(parse([]).flag('notify', defaultValue: true), isTrue);
    });

    test('the last one wins', () {
      expect(parse(['--notify', '--no-notify']).flag('notify'), isFalse);
    });

    test('another value is a user error', () {
      expect(
        () => parse(['--notify=maybe']).flag('notify'),
        throwsA(userError('--notify must be true or false, but got "maybe"')),
      );
    });
  });

  group('required values', () {
    test('requireString returns the value', () {
      expect(parse(['--app=1:23']).requireString('app'), '1:23');
    });

    test('requireString: missing', () {
      expect(
        () => parse([]).requireString('app'),
        throwsA(
          userError('Missing required option --app.', hint: '--app=<value>'),
        ),
      );
    });

    test('requireString: empty counts as missing', () {
      expect(
        () => parse(['--app=']).requireString('app'),
        throwsA(userError('Missing required option --app.')),
      );
    });

    test('requireInteger: missing', () {
      expect(
        () => parse([]).requireInteger('retries'),
        throwsA(userError('Missing required option --retries.')),
      );
    });

    test('a user error maps to the usage exit code', () {
      expect(
        () => parse([]).requireString('app'),
        throwsA(isA<UserError>().having((e) => e.exitCode, 'exitCode', 64)),
      );
    });
  });

  group('integer', () {
    test('parses whole numbers, including negative ones', () {
      expect(parse(['--n=3']).integer('n'), 3);
      expect(parse(['--n=-5']).integer('n'), -5);
      expect(parse(['--n=0']).requireInteger('n'), 0);
    });

    test('is null when not given', () {
      expect(parse([]).integer('n'), isNull);
    });

    test('anything else is a user error', () {
      for (final bad in ['abc', '1.5', '', '1,000']) {
        expect(
          () => parse(['--n=$bad']).integer('n'),
          throwsA(userError('--n must be a whole number, but got "$bad"')),
          reason: bad,
        );
      }
    });
  });

  group('list', () {
    test('splits one value at commas', () {
      expect(parse(['--testers=a@x.com,b@y.org']).list('testers'), [
        'a@x.com',
        'b@y.org',
      ]);
    });

    test('collects repeated options', () {
      expect(parse(['--t=a', '--t=b']).list('t'), ['a', 'b']);
    });

    test('combines repeated options and commas, in order', () {
      expect(parse(['--t=a,b', '--t=c']).list('t'), ['a', 'b', 'c']);
    });

    test('trims items and drops empty ones', () {
      expect(parse(['--t= a , ,b,']).list('t'), ['a', 'b']);
    });

    test('is empty when the option was not given', () {
      expect(parse([]).list('t'), isEmpty);
    });

    test('commaSeparated: false keeps commas inside each value', () {
      final args = parse([
        '--dart-define=URL=https://x?a=1,2',
        '--dart-define=B=2',
      ]);

      expect(args.list('dart-define', commaSeparated: false), [
        'URL=https://x?a=1,2',
        'B=2',
      ]);
    });
  });

  group('expectOnly', () {
    test('accepts known options', () {
      expect(
        () => parse([
          '--flavor=prod',
          '--no-notify',
        ]).expectOnly(['flavor', 'notify']),
        returnsNormally,
      );
    });

    test('accepts no options at all when none are given', () {
      expect(() => parse(['x']).expectOnly([]), returnsNormally);
    });

    test('rejects an unknown option and lists the known ones', () {
      expect(
        () => parse(['--flavour=prod']).expectOnly(['notify', 'flavor']),
        throwsA(
          userError(
            'Unknown option --flavour.',
            hint: 'Known options: --flavor, --notify.',
          ),
        ),
      );
    });

    test('names every unknown option', () {
      expect(
        () => parse(['--a', '--b', '--ok']).expectOnly(['ok']),
        throwsA(userError('Unknown options --a, --b.')),
      );
    });

    test('says so when the lane takes no options', () {
      expect(
        () => parse(['--a']).expectOnly([]),
        throwsA(userError('Unknown option --a.', hint: 'takes no options')),
      );
    });
  });

  test('toString shows the original arguments', () {
    expect('${parse(['--a=1', 'x'])}', 'LaneArgs(--a=1 x)');
  });
}
