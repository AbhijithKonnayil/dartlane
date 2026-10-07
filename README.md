<p align="center">
  <img src="assets/dartlane.png" alt="Dartlane logo" width="160">
</p>

<h1 align="center">Dartlane</h1>

<p align="center">
  Release automation for Flutter and Dart, written in Dart.<br>
  A Dart-native alternative to fastlane: no Ruby, typed lanes, one command locally and on CI.
</p>

> **Status: planning / pre-alpha.** Nothing is published to pub.dev yet and the
> packages are not in this repo yet. This README describes where the project is
> heading. See the [PRD](docs/PRD.md) for the full plan.

## Why Dartlane

Flutter teams that automate releases usually reach for fastlane or a pile of shell
scripts. Dartlane aims to fix the pain points of that setup:

- **No Ruby toolchain.** No Ruby, Bundler or gem conflicts on fresh machines and CI.
- **Lanes in Dart.** Typed, testable and refactorable, in the language you already write.
- **Flutter-aware.** Versioning, flavors and build commands are first-class, not glue.
- **Fast to start.** The goal is a working lane in under 2 minutes from `dartlane init`.

## Concepts

- **Action:** one reusable, typed step (for example `FlutterBuild`, `FirebaseDistribute`).
  It takes typed params and returns a typed result.
- **Lane:** a workflow you write as a Dart function that calls actions in order and
  passes results between them.

## Planned usage

The API below is a proposal and names may change. `dartlane init`, `dartlane run` and `dartlane list` already work. Until the packages are published, `init` needs `--local-repo <path to this repo>`. `dartlane run <lane> [arguments]` starts `dartlane/lanes.dart`, passes the arguments through and exits with the lane's exit code; `dart run dartlane/lanes.dart <lane>` does the same without the CLI.

```dart
void main(List<String> args) => dartlane(args, lanes: {
  'beta': Lane('Build and ship to QA', (ctx) async {
    await ctx.run(FlutterAnalyze());
    final build = await ctx.run(FlutterBuild(target: BuildTarget.apk, flavor: 'prod'));
    await ctx.run(FirebaseDistribute(build.path, app: Config.firebaseAppId, groups: ['qa']));
  }),
});
```

```sh
dartlane init          # create a nested dartlane/ package in your app
dartlane list          # show available lanes
dartlane run beta      # run a lane
dartlane doctor        # check your environment
dartlane run beta --dry-run
```

## Roadmap

| Release | Scope |
|---|---|
| **0.1.0** (preview) | CLI (`init`, `run`, `list`, `doctor`, `update`), Flutter build/analyze/test/version actions, Firebase App Distribution, `--dry-run`, correct exit codes. Android and Firebase only. |
| **0.2** | Git tag and changelog, Slack/Discord notify, compile cache, action scaffolder, lane hooks. |
| **Later** | Google Play, then iOS via the App Store Connect API, fastlane migration helper. |

iOS signing and App Store Connect are not part of 0.1.0.

## Planned packages

The repo will be a pub workspace (Dart 3.10+) with four packages:

| Package | Purpose |
|---|---|
| `dartlane_core` | LaneAction, LaneContext, runner, Shell/HTTP/secrets interfaces, errors, test fakes |
| `dartlane_flutter` | Build, pub get, analyze, test and version actions |
| `dartlane_firebase` | `FirebaseDistribute`, upload, auth |
| `dartlane` | The CLI |

## Repository layout

```text
packages/  dartlane_core, dartlane_flutter, dartlane_firebase and the dartlane CLI
example/   a Flutter app used to try Dartlane end to end
assets/    logo and images
docs/      PRD and the GitHub issue plan
tool/      maintenance scripts
```

## Try it from source

The example app's `dartlane/` folder is generated and git-ignored. Recreate it
from the current code whenever the CLI or the templates change:

```sh
dart pub get                       # once, from the repo root
dart run melos run example:reset   # delete example/flutter_app/dartlane and run dartlane init again
cd example/flutter_app
dart run ../../packages/dartlane/bin/dartlane.dart run build
```

`example:reset` deletes everything in that folder, including files you added.

## Project planning

The roadmap is tracked as GitHub milestones and issues, generated from
[`docs/github-plan.md`](docs/github-plan.md) by a script. It needs the
[GitHub CLI](https://cli.github.com) and `gh auth login`.

```sh
DRY_RUN=1 ./tool/create_github_issues.sh   # preview
./tool/create_github_issues.sh             # create labels, milestones and issues
```

Re-running is safe: issues whose title already exists are skipped.

## Contributing

The project is at an early stage. Check the open issues, especially those labelled
`good first issue`, and open an issue before starting larger changes.

## License

The CLI and core are intended to be MIT licensed. A `LICENSE` file has not been added yet.
