# Writing a lane and writing an action

A **lane** is a Dart function that runs steps in order. An **action** is one
reusable, typed step. Start with a lane; pull a step out into an action when
you use it twice or want to test it alone.

Everything here uses `package:dartlane_core`. Tests use
`package:dartlane_core/testing.dart`.

## Writing a lane

Lanes live in `dartlane/lanes.dart`, in the `lanes` map:

```dart
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';

Future<void> main(List<String> args) => dartlane(
  args,
  lanes: {
    'check': Lane('Analyze and test', (ctx) async {
      await ctx.run(const FlutterAnalyze());
      await ctx.run(const FlutterTest());
    }),
  },
);
```

```sh
dartlane run check
dartlane list          # shows the description
```

A lane that throws fails with a non-zero exit code, so the first failing step
stops the lane.

### Passing results between steps

`ctx.run` returns the action's result:

```dart
final build = await ctx.run(FlutterBuild.apk(flavor: 'prod'));
await ctx.run(FirebaseDistribute(build.path, app: '1:123:android:abc'));
```

### Arguments

Words after the lane name arrive in `ctx.args`:

```sh
dartlane run beta --flavor=prod --groups=qa,beta --no-notify
```

```dart
ctx.args.expectOnly(['flavor', 'groups', 'notify']); // catches typos
final flavor = ctx.args.string('flavor');            // 'prod'
final groups = ctx.args.list('groups');              // ['qa', 'beta']
final notify = ctx.args.flag('notify', defaultValue: true);
final app = ctx.args.requireString('app');           // UserError if missing
```

A value is always written `--key=value`. `--flavor prod` is a flag plus a
positional argument.

### Secrets

```dart
final token = ctx.secrets.require('FIREBASE_TOKEN');
```

Secrets come from environment variables, then from `.env`, and are masked if
they show up in the log. Never put them in `lanes.dart`.

### One-off shell steps

For a command that does not deserve an action, use `ctx.sh`:

```dart
await ctx.sh('git', ['tag', 'v1.0.0']);

final sha = (await ctx.sh(
  'git', ['rev-parse', 'HEAD'],
  streamOutput: false,
)).stdout.trim();
```

It throws a `ShellException` when the command exits non-zero. Pass
`workingDirectory` or `environment` when needed.

### Logging and errors

```dart
ctx.logger.info('Building...');
ctx.logger.success('Done');
ctx.logger.warn('No testers given');

throw const UserError(
  'Missing flavor.',
  hint: 'Pass --flavor=prod.',        // printed without a stack trace
);
```

Throw `UserError` for something the user must fix and `ActionFailed` when a step
fails. Both print cleanly and set the exit code.

### Dry runs

`dartlane run beta --dry-run` describes each `ctx.run` and `ctx.sh` step
without running it. Code in a lane that has side effects some other way, such as
writing a file, still runs, so guard it:

```dart
if (!ctx.dryRun) File('notes.txt').writeAsStringSync(notes);
```

## Writing an action

Extend `LaneAction<R>`, keep the parameters as `final` fields, and implement
`run`:

```dart
import 'package:dartlane_core/dartlane_core.dart';

class GitTag extends LaneAction<String> {
  const GitTag(this.name, {this.push = false});

  final String name;
  final bool push;

  @override
  String describe() => 'Tag $name${push ? ' and push' : ''}';

  @override
  Future<String> run(LaneContext ctx) async {
    if (name.isEmpty) throw const UserError('Tag name is empty.');
    await ctx.sh('git', ['tag', name]);
    if (push) await ctx.sh('git', ['push', 'origin', name]);
    return name;
  }
}
```

Use it with `ctx.run(const GitTag('v1.0.0', push: true))`. Always go through
`ctx.run`, never call `run` directly: that is what logs, times and dry-runs the
step.

Rules of thumb:

- Take everything as constructor parameters. An action does not read
  `ctx.args`; the lane does and passes values in. (The ready-made lanes are the
  examples: see `flutterLanes()` and `firebaseLanes()`.)
- Use `ctx.sh`, `ctx.http`, `ctx.logger` and `ctx.secrets`, not `Process.run`
  or your own HTTP client, so the fakes work in tests and dry runs.
- Return a small result class instead of printing, so later steps can use it.
- Throw on failure. Never return a status code.

### Supporting dry runs

By default `describe()` is the class name, and a dry run of an action with a
non-void result stops there. Override both:

```dart
@override
String describe() => 'Tag $name';

@override
String dryRunResult(LaneContext ctx) => name; // no side effects; may validate
```

`ctx.sh` and write requests are already skipped in a dry run, so `run` is
usually safe, but `dryRunResult` is what the next step receives.

### Local or published

- **Local:** put the class in your `dartlane/` package, for example
  `dartlane/git_tag.dart`, and import it from `lanes.dart`. Nothing else is
  needed.
- **Shared:** publish a package named **`dartlane_<name>`**, for example
  `dartlane_slack` or `dartlane_sentry`. It depends only on `dartlane_core`
  (not on `dartlane_flutter` or the CLI) and exports its actions from
  `lib/dartlane_<name>.dart`:

  ```yaml
  name: dartlane_slack
  description: Slack actions for Dartlane.
  environment:
    sdk: ^3.10.0
  dependencies:
    dartlane_core: ^0.1.0
  dev_dependencies:
    test: ^1.25.0
  ```

  Users add it under `dependencies:` in `dartlane/pubspec.yaml`.

  If your package needs setup, give it `DoctorCheck`s and export a function
  such as `slackChecks()`, which users pass to `dartlane(checks: [...])`. A
  check only looks and reports; it must not change anything. Packages can also
  export ready-made lanes the way `flutterLanes()` does.

## Testing

`FakeLaneContext` runs lanes and actions with no process, no network and no
output. Stub what you need, run, then check what happened.

```dart
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test('tags and pushes', () async {
    final ctx = FakeLaneContext();

    final name = await ctx.run(const GitTag('v1.0.0', push: true));

    expect(name, 'v1.0.0');
    expect(ctx.shell.commands, [
      'git tag v1.0.0',
      'git push origin v1.0.0',
    ]);
  });

  test('a failing command fails the action', () {
    final ctx = FakeLaneContext()..shell.stub('git tag v1.0.0', exitCode: 1);

    expect(
      ctx.run(const GitTag('v1.0.0')),
      throwsA(isA<ShellException>()),
    );
  });

  test('a dry run runs nothing', () async {
    final ctx = FakeLaneContext(dryRun: true);

    await ctx.run(const GitTag('v1.0.0'));

    expect(ctx.shell.commands, isEmpty);
    expect(ctx.dryRunSteps, ['Tag v1.0.0']);
  });
}
```

What the fakes give you:

| Fake | Use |
| --- | --- |
| `ctx.shell` | `stub('git tag x', stdout: ..., exitCode: ...)`, `commands` lists what ran. A command with no stub succeeds with no output. |
| `ctx.http` | `stub('POST https://x.test/up', status: 200, body: ...)`, `requests` lists what was sent. A request with no stub fails the test. |
| `ctx.logger` | Records messages, so you can check a warning was shown. |
| `FakeLaneContext(args: [...], env: {...}, dryRun: true)` | Arguments, environment and dry-run mode. |

Test a lane by calling `lane.run(ctx)`:

```dart
final ctx = FakeLaneContext(args: ['--flavor=prod']);
await lanes['beta']!.run(ctx);
```

Export your lanes map from a file the test can import (for example
`final lanes = {...}` in `lanes.dart`'s sibling) so `main` stays a one-liner.

## See also

- [Quick start](quick-start.md)
- [Running lanes on CI](ci.md)
