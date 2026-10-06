# Dartlane GitHub plan

Source of truth for the labels, milestones and issues created by
`tool/create_github_issues.sh`. Keep the structure below, since the script parses it:

- `## Labels` and `## Milestones`: bullets of `- a | b | c`
  (label: name, color, description; milestone: title, description).
- `## Issues`: `###` is a milestone title (must match one declared above),
  `####` is an issue title, the `Labels:` line is the comma-separated labels,
  and everything after it is the issue body.
- Issue bodies must not contain lines starting with `#`.

## Labels

- area:core | 1d76db | dartlane_core package
- area:cli | 0e8a16 | dartlane CLI package
- area:flutter | 5319e7 | dartlane_flutter package
- area:firebase | fbca04 | dartlane_firebase package
- area:ci | bfd4f2 | CI, tooling and repo setup
- area:docs | c5def5 | Documentation and launch material
- type:feature | a2eeef | New functionality
- type:bug | d73a4a | Something is broken
- type:chore | ededed | Maintenance and refactoring
- good first issue | 7057ff | Small, well-defined task for new contributors

## Milestones

- M0: Foundation | Workspace, tooling and CI safety net
- M1: Vertical slice | Prove the architecture end to end: build an APK and ship it to Firebase
- M2: 0.1.0 | Everything needed for the 0.1.0 preview
- M3: Launch | Publish 0.1.0 and announce it
- M4: 0.2 | Follow-up features after launch
- Later | Not scheduled yet: Google Play, iOS, and more

## Issues

### M0: Foundation

#### Convert repo to a pub workspace with four package skeletons

Labels: area:ci,type:chore

Create the workspace layout from the PRD: `packages/dartlane_core`, `packages/dartlane_flutter`, `packages/dartlane_firebase`, `packages/dartlane` (CLI). Root `pubspec.yaml` lists them under `workspace:` and each package sets `resolution: workspace`. Requires Dart SDK 3.6 or newer.

**Acceptance criteria**
- `dart pub get` at the root resolves all four packages with one lockfile.
- Each package has a minimal public library file and an empty passing test.
- No `path:` dependencies between packages.
- Dependency direction: CLI, flutter and firebase depend on core only.

#### Set up Melos for scripts, versioning and publishing

Labels: area:ci,type:chore

Configure Melos on top of the pub workspace. Start small: run analyze and tests across all packages, versioning and changelogs, and publish in dependency order.

**Acceptance criteria**
- `melos run analyze` and `melos run test` work across all packages.
- Documented process to version and publish packages (dry run is enough for now).
- Decide whether to use Conventional Commits and document the decision.

#### Adapt CI to analyze and test all workspace packages

Labels: area:ci,type:chore

Update the existing GitHub Actions workflow (and `pr_check.sh`) to run format check, analyze and tests across all packages on every pull request.

**Acceptance criteria**
- PRs run analyze and test for every package.
- CI is green on the empty skeletons.
- Failing analyze or tests blocks merging (branch protection noted in the issue).

#### Share lints and spell-check config across packages

Labels: area:ci,type:chore,good first issue

Move `analysis_options.yaml` and `cspell.json` so every package uses the same rules. Remove template leftovers (for example the "A Very Good Project created by Very Good CLI" description string).

**Acceptance criteria**
- One shared lint configuration used by all packages.
- Spell check runs in CI and passes.

#### Remove the package cycle and path dependencies

Labels: area:core,type:chore

Today the lanes in `dartlane_core` import `package:dartlane/...` while `dartlane` depends on `dartlane_core`, and `dartlane_core`'s pubspec lacks the dependencies those lanes need. Resolve by moving lane code into the new action packages and fixing dependencies.

**Acceptance criteria**
- No package imports a package that depends on it.
- Every package's pubspec lists all dependencies it imports.
- `dart analyze` is clean in each package.

### M1: Vertical slice

#### Core: Action, Context, lane() and the runner

Labels: area:core,type:feature

Implement the core API: `Action<P, R>` base class with `run(Context)` and `describe()`, `Context` (args, env, shell, http, logger, dryRun), `lane(description, fn)`, and `dartlane(args, lanes: {...})` entry point. `ctx.run(action)` is the single choke point for logging, timing and errors.

**Acceptance criteria**
- A lane written as a plain Dart function runs and can call actions.
- `ctx.run` logs each step with timing and propagates results.
- Unknown lane names print the available lanes and exit non-zero.
- Unit tested.

#### Core: Shell and HTTP interfaces with test fakes

Labels: area:core,type:feature

Define `Shell` and HTTP client interfaces with real implementations, and ship `FakeShell`, `FakeHttp` and `FakeContext` in `package:dartlane_core/testing.dart`.

**Acceptance criteria**
- Actions never call `Process` or `http` directly; they use `ctx.shell` / `ctx.http`.
- A sample lane is unit tested using only fakes.
- `ctx.sh(...)` throws on a non-zero exit code.

#### Core: error types and exit-code mapping

Labels: area:core,type:feature

Introduce a small error hierarchy (for example `UserError` with a hint, and `ActionFailed`) and map it to exit codes in the runner.

**Acceptance criteria**
- Any failing action makes the process exit non-zero.
- User errors show a clear message and hint without a stack trace unless `--verbose`.
- No `catch (e) { log }` that swallows failures.

#### Core: logger with levels and CI-friendly output

Labels: area:core,type:feature

Build on the existing logger: levels (info, detail, warn, error, success), `--verbose`, and a CI mode that emits GitHub Actions annotations (`::error::`) and avoids interactive prompts.

**Acceptance criteria**
- `--verbose` shows executed commands; default output stays quiet.
- When running on GitHub Actions, errors are annotated.

#### Flutter: FlutterBuild action and BuildResult

Labels: area:flutter,type:feature

One typed build action: `FlutterBuild(target: apk|appbundle, mode, flavor, dartDefines, buildName, buildNumber, obfuscate, splitDebugInfo)`. Returns `BuildResult(path, version, mode, flavor)`. Keep convenience aliases (`flutterBuildApk`, `flutterBuildAppBundle`).

**Acceptance criteria**
- A failed `flutter build` fails the lane (non-zero exit).
- `--dart-define` can be passed multiple times.
- `BuildResult.path` points to the real artifact, including flavored builds.
- Unit tested with `FakeShell`.
- Removes the `exeType` naming confusion (target vs mode).

#### Firebase: FirebaseDistribute action (migrate existing upload logic)

Labels: area:firebase,type:feature

Move the existing upload, polling, release notes and distribute logic into `dartlane_firebase` as `FirebaseDistribute(artifact, app, groups, testers, releaseNotes, ...)` and fix the known problems.

**Acceptance criteria**
- All failures propagate (no swallowed errors).
- Binary comes from `BuildResult` or an explicit override, never from guessing a directory.
- Upload timeout is honoured; the "no testers or groups" outcome is reported clearly after a successful upload.
- Unit tested with `FakeHttp`.

#### Example app runs a beta lane end to end

Labels: area:ci,type:feature

Add `examples/flutter_app` with a `dartlane/` package whose `beta` lane analyzes, builds an APK and distributes it to Firebase.

**Acceptance criteria**
- `dartlane run beta` produces a Firebase release from the example app.
- Document what was checked: pub workspace resolution locally and on a CI runner, and how `ctx.run` feels to write.

### M2: 0.1.0

#### CLI: init creates a nested dartlane/ package

Labels: area:cli,type:feature

`dartlane init` creates `dartlane/pubspec.yaml`, `lanes.dart` and `config.dart` in the client project without touching the app's `pubspec.yaml`. Templates live in Dart string constants.

**Acceptance criteria**
- Working lane in under 2 minutes from `init`.
- No hardcoded `--path=../`.
- Adds `.dartlane/` and `.env` to `.gitignore`.
- Asks before overwriting an existing `dartlane/` folder.

#### CLI: run forwards arguments and the exit code

Labels: area:cli,type:feature

Today `run` only passes the lane name and `Lanes.runLane` calls `execute({})`, so arguments are lost.

**Acceptance criteria**
- `dartlane run beta --flavor=prod` reaches the lane as typed args.
- The CLI exits with the lane's exit code.
- Missing `dartlane/` folder gives a clear error pointing to `dartlane init`.

#### Core: argument parsing (--key=value) with typed getters

Labels: area:core,type:feature

Parse `--key=value` into `ctx.args` with typed getters (`string`, `bool`, `int`, lists), required-value errors, and decide whether the legacy `key:value` format stays.

**Acceptance criteria**
- Values containing commas and colons (for example tester emails) parse correctly.
- Decision on the legacy format recorded in the issue.

#### CLI: list command

Labels: area:cli,type:feature

`dartlane list` prints available lanes with descriptions.

**Acceptance criteria**
- Shows lane names and descriptions from the user's `lanes.dart`.

#### CLI: doctor command

Labels: area:cli,type:feature

`dartlane doctor` checks the Dart/Flutter SDKs, credentials presence, detected flavors, and any checks contributed by actions.

**Acceptance criteria**
- Clear pass/fail output with a suggested fix for each failure.
- Non-zero exit code when a required check fails.

#### CLI: fix branding, description and update notice

Labels: area:cli,type:chore,good first issue

Replace the template description string, verify `dartlane update` and the pub.dev update notice, and make sure the version file is generated correctly.

**Acceptance criteria**
- `dartlane --help` and `dartlane --version` show correct text.

#### Core: --dry-run using Action.describe()

Labels: area:core,type:feature

With `--dry-run`, `ctx.run` prints each step's `describe()` and skips side effects.

**Acceptance criteria**
- Built-in actions implement `describe()`.
- Documented as best-effort.

#### Core: secrets provider and log masking

Labels: area:core,type:feature

`ctx.secrets` reads from environment variables and an optional `.env`, behind a small provider interface. Values read through it are masked in logs.

**Acceptance criteria**
- A secret value never appears in log output.
- Documented that masking only covers values read via `ctx.secrets`.

#### Flutter: pub get, analyze and test actions

Labels: area:flutter,type:feature

Add `FlutterPubGet`, `FlutterAnalyze` and `FlutterTest` as gate steps.

**Acceptance criteria**
- A failing analyze or test fails the lane.
- Unit tested with `FakeShell`.

#### Flutter: pubspec version read and bump action

Labels: area:flutter,type:feature

Read and bump `version:` and build number in `pubspec.yaml`, returning the new version for later steps (for example Firebase release notes).

**Acceptance criteria**
- Supports bumping major, minor, patch and build number.
- Preserves the rest of `pubspec.yaml` formatting and comments.

#### Firebase: authentication via service account file, with ADC fallback

Labels: area:firebase,type:feature

Support a service-account file path (and `GOOGLE_APPLICATION_CREDENTIALS`), and fall back to Application Default Credentials when none is given.

**Acceptance criteria**
- Clear error when no credentials can be found, with a pointer to the docs.
- `doctor` reports whether credentials are available.

#### Firebase: release notes and testers from files

Labels: area:firebase,type:feature

Support release notes, testers and groups as inline values or from files, as the current lane does.

**Acceptance criteria**
- Both inline and file inputs work and are tested.

#### Docs: quick start

Labels: area:docs,type:feature

A quick start that takes a Flutter developer from install to a Firebase release.

**Acceptance criteria**
- A new user can follow it in under 5 minutes.
- Honest about the Android and Firebase scope.

#### Docs: writing a lane and writing an action

Labels: area:docs,type:feature

Guides with code for custom lanes, one-off shell steps and custom actions (local and as a pub.dev package), plus how to test them with the fakes.

**Acceptance criteria**
- Includes the `dartlane_<name>` package naming convention.

#### Example GitHub Actions workflow for the beta lane

Labels: area:ci,area:docs,type:feature

Ship an example workflow that installs Flutter, runs `dartlane run beta`, and reads the Firebase key from a repository secret.

**Acceptance criteria**
- The workflow runs in the example app's repo and is linked from the docs.

### M3: Launch

#### Publish process: remove publish_to: none and release 0.1.0 of all packages

Labels: area:ci,type:chore

Use Melos to version and publish all four packages in dependency order.

**Acceptance criteria**
- All four packages are on pub.dev at 0.1.0.
- `dart pub global activate dartlane` works on a clean machine.
- Verify pub workspace behaviour with global activation before publishing.

#### README rewrite with honest scope and roadmap

Labels: area:docs,type:feature

Rewrite the README around the 2-minute path, state the Android/Firebase scope plainly, and link the roadmap (Google Play, then iOS).

**Acceptance criteria**
- README commands match what actually works.

#### Record a 2-minute demo

Labels: area:docs,type:feature

Screen recording from `dartlane init` to a Firebase release.

**Acceptance criteria**
- Embedded in the README.

#### Launch post and community announcement

Labels: area:docs,type:feature

Write "Ship your Flutter app to Firebase in one command" and announce it in Flutter community channels (r/FlutterDev, Flutter Discord, X, newsletters).

**Acceptance criteria**
- Post published and shared; include a cold-start comparison against fastlane if measured.

#### Find three people to try 0.1.0 and report feedback

Labels: area:docs,type:chore

Recruit three outside users or teams, give them the quick start, and record what broke.

**Acceptance criteria**
- Three written feedback notes turned into issues.

### M4: 0.2

#### Git tag and changelog / release notes action

Labels: area:flutter,type:feature

Tag a release and generate release notes from commits, usable as Firebase release notes.

#### Notify action for Slack and Discord

Labels: area:core,type:feature

Post the release link and version to a chat webhook after distribution.

#### Compile cache for faster repeat runs

Labels: area:cli,type:feature

Compile the user's lanes file and cache it in `.dartlane/`, keyed by a hash of the file and its pubspec. Keep `dart run` as the fallback.

**Acceptance criteria**
- Cache invalidates when lanes or dependencies change.
- Behaviour (working directory, relative paths) matches `dart run`.

#### dartlane create action scaffolder

Labels: area:cli,type:feature

Generate a plugin package skeleton (`dartlane_<name>`) with an action, tests and a README.

#### Lane hooks: onError and onSuccess

Labels: area:core,type:feature

Allow lanes to define hooks that run after a failure or success (for example to notify a team when a release fails).

### Later

#### Google Play lane (spike)

Labels: area:core,type:feature

Investigate uploading an AAB to the Play internal track via the Play Developer API in pure Dart. Output: a design note and an effort estimate.

#### iOS via App Store Connect API in pure Dart (spike)

Labels: area:core,type:feature

Investigate signing and uploading to TestFlight without Ruby. Output: a design note listing what must be built natively and what can shell out to Apple tools.

#### fastlane to Dartlane migration helper

Labels: area:cli,type:feature

Explore reading an existing Fastfile and generating an equivalent `lanes.dart`.
