# Dartlane: Product Requirements Document

| | |
|---|---|
| **Status** | Draft v0.1 |
| **Owner** | Abhijith Konnayil |
| **Last updated** | 2026-10-06 |
| **Repo** | https://github.com/AbhijithKonnayil/dartlane |

> Items marked **(decided)** were chosen by the maintainer. Items marked **(proposed)** are recommendations that are still open for confirmation.

## 1. Summary

Dartlane is an open-source release-automation tool for Flutter and Dart. You write your release workflows ("lanes") in typed Dart, run them with one command on a laptop or in any CI, and never touch Ruby. It is a Dart-native alternative to fastlane.

**Ambition (decided):** become the default release and CI/CD automation choice for the Flutter and Dart ecosystem.

## 2. Problem

Flutter teams that automate releases today usually reach for fastlane, or for shell scripts and GitHub Actions marketplace steps. The pain points the maintainer wants to fix (all decided):

1. **Ruby toolchain.** Ruby, Bundler and gem version conflicts, especially on fresh machines and CI.
2. **Lanes written in Ruby.** Flutter developers write Dart, not Ruby.
3. **Flutter feels bolted on.** Fastlane is centred on native iOS and Android, so Flutter versioning, flavors and build commands need glue.
4. **Setup and config ceremony.** Too much configuration before a first successful upload.

## 3. Goals and non-goals

### Goals
- A working lane in under 2 minutes from `dartlane init` **(decided)**.
- No Ruby dependency; runs the same locally and in CI ("zero-install on CI") **(decided)**.
- Lanes defined in Dart code **(decided)**: typed, testable, refactorable.
- A 0.1.0 preview on pub.dev within about 2 weeks of this document **(decided)**, covering the Android and Firebase App Distribution story.

### Non-goals (for now)
- Not a hosted CI/CD platform (no runners, dashboards or pipelines of our own) **(proposed)**.
- No iOS code signing or App Store Connect support in 0.1.0 **(decided: Android/Firebase first)**.
- No YAML or other declarative lane format; Dart only **(decided)**.
- No plugin registry or marketplace in 0.1.0 **(proposed)**.
- Not a replacement for fastlane's full iOS tooling in the near term.

## 4. Target users

- **Primary:** Flutter developers (solo, indie, or small teams) who ship to Firebase App Distribution and later to the stores, and who want one command that works on a laptop and on CI.
- **Secondary:** Dart-only authors (CLIs, servers, packages) who want typed task automation. Flutter is the wedge; pure Dart should not be blocked by the design.

## 5. Positioning and competition

Dartlane is a **release-automation layer** that runs inside any CI and locally **(proposed)**, not a CI platform.

| Alternative | Relation to Dartlane |
|---|---|
| fastlane | Incumbent. Mature iOS tooling and large action library, but Ruby-based and Flutter is an afterthought. |
| GitHub Actions marketplace steps / shell scripts | The real baseline. Dartlane's first five minutes must clearly beat a ten-line YAML file. |
| Flutter-focused CI vendors (e.g. Codemagic) | Potential partners or sponsors more than competitors, since Dartlane runs inside their CI. |
| General Dart task runners (e.g. grinder, derry, melos scripts) | Not verified in detail; check their current state before launch. Dartlane's difference should be release-domain actions with typed results, `doctor`, dry-run and CI integration. |

**Differentiators:** zero Ruby; lanes in typed Dart; typed results flowing between steps; dry-run/explain mode; unit-testable lanes; Flutter-aware defaults.

## 6. Design principles

1. **Library-first.** Dartlane is a library of typed actions plus a small runtime; the CLI is a launcher.
2. **Typed everywhere.** Typed params in, typed results out; no `Map<String, String>` between steps.
3. **One choke point.** Every step runs through `ctx.run(action)`, giving uniform logging, timing, dry-run, error handling and exit codes.
4. **Fail loudly.** Any failure returns a non-zero exit code. CI must never report success on a failed step.
5. **Testable by construction.** Process, HTTP and secrets sit behind interfaces with fakes provided.
6. **Small core, plugins as packages.** Extending Dartlane means publishing a normal pub.dev package.
7. **Explicit over magic.** Configuration is Dart code; no hidden global state.

## 7. Product scope

### 7.1 Concepts
- **Action:** one reusable, typed step (for example `FlutterBuild`, `FirebaseDistribute`). Takes typed parameters as plain constructor fields (`LaneAction<R>`, no separate params object), returns a typed result, can describe itself for dry-run.
- **Lane:** a workflow defined by the user as a Dart function that calls actions in order and passes results between them.

Example (proposed API, names may change):

```dart
void main(List<String> args) => dartlane(args, lanes: {
  'beta': Lane('Build and ship to QA', (ctx) async {
    await ctx.run(FlutterAnalyze());
    final build = await ctx.run(FlutterBuild(target: BuildTarget.apk, flavor: 'prod'));
    await ctx.run(FirebaseDistribute(build.path, app: Config.firebaseAppId, groups: ['qa']));
  }),
});
```

### 7.2 Release scope

**0.1.0 preview (target: ~2 weeks)**
- CLI: `init`, `run`, `list`, `doctor` (basic), `update`.
- Actions: `FlutterBuild` (apk, appbundle; modes; flavor; dart-define; build name/number), `FlutterPubGet`, `FlutterAnalyze`, `FlutterTest`, pubspec version read/bump, `FirebaseDistribute` (APK upload, release notes, testers, groups).
- Typed `BuildResult` from the build; its `path` is passed to Firebase (`dartlane_firebase` does not depend on `dartlane_flutter`, so it takes a path); optional explicit path override.
- Service-account-file authentication for Firebase **(decided)**, with Application Default Credentials as a fallback **(proposed, low cost)**.
- `--dry-run` that prints the planned steps.
- Correct non-zero exit codes on failure.
- Docs: quick start, writing a lane, writing an action; example app and an example GitHub Actions workflow.

**0.2**
- Git tag and changelog / release-notes generation.
- Slack/Discord notify action.
- Compile cache for faster repeat runs; `dartlane create action` scaffolder.
- Lane hooks (`onError`, `onSuccess`).

**Later**
- Google Play lane, then iOS via the App Store Connect API in pure Dart.
- Secret provider adapters, fastlane-to-Dartlane migration helper, possible paid team features.

## 8. Functional requirements

### 8.1 CLI
| ID | Requirement |
|---|---|
| CLI-1 | `dartlane init` creates a nested `dartlane/` package (own `pubspec.yaml`, `lanes.dart`, `config.dart`) without modifying the app's `pubspec.yaml`. |
| CLI-2 | `dartlane run <lane> [--key=value ...]` runs the lane and exits with the lane's exit code. |
| CLI-3 | `dartlane list` shows lanes with their descriptions. |
| CLI-4 | `dartlane doctor` checks the environment (Flutter and Dart SDKs, credentials present, flavors detected) and reports clear fixes. |
| CLI-5 | `--dry-run` prints each planned step without executing side effects. `--verbose` shows executed commands. |
| CLI-6 | `dartlane update` and an update notice via pub.dev. |

### 8.2 Runtime and API
| ID | Requirement |
|---|---|
| RT-1 | Lanes are plain Dart functions; registration requires only a name and description. |
| RT-2 | Actions are typed classes with a `run(LaneContext)` method, a `describe()` for dry-run, and a typed result. |
| RT-3 | `ctx.run(action)` provides timing, logging, error mapping and dry-run uniformly. |
| RT-4 | Shell access goes through `LaneShell` and HTTP through a `package:http` `Client` (`ctx.shell`, `ctx.sh`, `ctx.http`); `dartlane_core/testing.dart` provides fakes. |
| RT-5 | Secrets are read through `ctx.secrets` and masked in logs. |
| RT-6 | Errors form a small hierarchy (user error with a hint, action failed) mapped to exit codes. |
| RT-7 | Arguments accept `--key=value` (and the legacy `key:value` form if cheap to keep). |

### 8.3 Built-in actions
| ID | Requirement |
|---|---|
| ACT-1 | `FlutterBuild`: one action with typed params (`target`, `mode`, `flavor`, `dartDefines` as a list/map, `buildName`, `buildNumber`, `obfuscate` with `splitDebugInfo`), returns `BuildResult(path, version, mode, flavor)`. Convenience aliases (e.g. `flutterBuildApk`) keep existing lane names working. |
| ACT-2 | `FlutterAnalyze`, `FlutterTest`, `FlutterPubGet` as gate steps. |
| ACT-3 | Version action reads and bumps `version:` and build number in `pubspec.yaml`. (The separate `fastlane-plugin-flutter_versioner` project stays independent **(decided)**.) |
| ACT-4 | `FirebaseDistribute`: uploads an APK, polls the operation, sets release notes, and distributes to testers and groups; supports notes and testers from a file. |
| ACT-5 | `FirebaseDistribute` fails the lane on any error, and treats "no testers or groups" as a clearly reported outcome that does not contradict its own message. |
| ACT-6 | Binary location comes from `BuildResult.path`, which is read from Flutter's own `Built <path>` output line, or from an explicit override. It is never guessed from the `build/` folder layout. |

### 8.4 Extensibility
- A custom lane is a function in the user's `lanes.dart`.
- A custom action is a class in the user's `dartlane/` package, or a pub.dev package depending only on `dartlane_core` (convention: `dartlane_<name>`).
- No registry or manifest in 0.1.0.
- First-party action packages export ready-made lanes (for example a Firebase distribute lane) built from arguments. `dartlane init` registers them in `lanes.dart`, so common steps run with no custom lane. `dartlane_core` never pre-registers them, to keep it independent of the action packages.

## 9. Architecture summary (proposed)

Repo is a pub workspace (Dart 3.10+), fully split into four packages **(decided)**:

```text
packages/
  dartlane_core/       # LaneAction, LaneContext, runner, Shell/HTTP/secrets interfaces, errors, testing fakes
  dartlane_flutter/    # build, pub get, analyze, test, version actions
  dartlane_firebase/   # FirebaseDistribute, upload/polling, auth, client
  dartlane/            # CLI: init, run, list, doctor, update, launcher
examples/flutter_app/
docs/
tool/                  # publish-in-dependency-order script, check script
```

Dependency direction: the CLI and both action packages depend on `dartlane_core`; actions do not depend on each other, and the CLI does not depend on the action packages. This removes the current package cycle.

Client project layout: the app stays clean; Dartlane lives in a nested `dartlane/` package (own pubspec, `lanes.dart`, `config.dart`, optional tests). A `.dartlane/` cache folder and `.env` are gitignored.

## 10. Non-functional requirements

- **Reliability:** every failure path ends in a non-zero exit code; no swallowed exceptions.
- **Performance:** repeat `dartlane run` startup should be fast (compile cache is a 0.2 goal); first-run cost documented honestly. A cold-start comparison against fastlane is a launch-post candidate.
- **Security:** secrets never logged when read through `ctx.secrets`; service-account keys are documented as secrets, never committed. Masking is best-effort, not a security boundary.
- **Compatibility:** macOS, Linux and common CI runners; Windows best-effort.
- **Quality:** unit tests for core and each action using fakes; CI runs analyze and tests; lints via the shared analysis options.
- **Maintainability:** one command bumps and publishes all packages in dependency order.

## 11. Success metrics

Proposed; confirm targets before launch.

- Time from `dartlane init` to first successful lane run: under 2 minutes **(decided goal)**.
- 0.1.0 published on pub.dev with all four packages.
- Adoption signals tracked monthly: pub.dev downloads, GitHub stars, number of external issues and PRs, and number of public repos using Dartlane in CI.
- At least three outside users try 0.1.0 and report feedback.
- A defined stop/continue review at a set date (for example 3 months after launch), decided by the maintainer.

## 12. Go-to-market

- First 100 users via Flutter community channels (r/FlutterDev, Flutter Discord, X, newsletters) **(decided)**.
- Launch assets: 2-minute demo, "Ship your Flutter app to Firebase in one command" post, example GitHub Actions workflow, honest README stating Android/Firebase scope and the roadmap.
- Sustainability paths all stay open **(decided)**: GitHub Sponsors, possible open-core features, portfolio value, and possible acquisition or foundation home. The CLI and core stay MIT licensed.

## 13. Milestones

Capacity: serious part-time, about 15 hrs/week **(decided)**.

| When | Milestone |
|---|---|
| Spike (first 1 to 2 days) | Vertical slice: core interfaces, `FlutterBuild`, `FirebaseDistribute`, `beta` lane via plain `dart run`. Validates the workspace setup, the `ctx.run` ergonomics and an end-to-end Firebase upload. |
| Week 1 | Remove `publish_to: none`, fix package structure, `init` on the nested package, `doctor`, `--dry-run`, correct exit codes, docs matching reality. |
| Week 2 | GitHub Actions example, demo recording, launch post, publish 0.1.0, post to community channels. |
| After launch | 0.2 scope (git tag/changelog, notify, compile cache, scaffolder), then Google Play and iOS. |

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Nobody adopts it (fastlane inertia; "good enough" scripts) | Win one narrow flow end to end; make the first five minutes clearly better than a YAML file; measure adoption early. |
| Store API and iOS signing depth | Defer iOS; ship Android/Firebase first; plan Google Play before iOS. |
| Competition from Google/Flutter or CI vendors | Run inside any CI; stay pluggable so vendors can embed Dartlane. |
| Time and burnout (solo maintainer, four packages) | Thin vertical slice first; workspace plus publish script; defer nice-to-haves; seek co-maintainers after launch. |
| `LaneContext` grows into a god object | Keep it small or split into narrow interfaces. |
| `ctx.run` can be bypassed | Document the convention; lint first-party actions. |
| Dry-run drifts from real behaviour | Treat it as best-effort and say so. |
| Compile cache bugs | Start with plain `dart run`; add the cache only after it is proven. |
| Unverified assumptions (workspace behaviour with global activation; nested package resolution on CI) | Test both in the spike before committing. |
| Over-engineering before proving the product | Respect the 0.1.0 scope above; everything else waits. |

## 15. Open questions

1. Compiled binary or pub.dev package first for the install story?
2. Which three people or teams will try 0.1.0 and report what breaks?
3. What would make the maintainer stop (adoption threshold after N months, or an official Flutter tool)?
4. Is `describe()` required or optional for custom actions?
5. Ship a `dartlane create action` scaffolder before 0.1.0 or after?
6. Final confirmation of release-automation-layer positioning, plugin-as-package, and env-vars-plus-`.env` for secrets.
7. How exactly does the legacy `key:value` argument format migrate, if at all? (Existing lane names migrate as ready-made lanes exported by the action packages and registered by `init`; see 8.4.)

## 16. Known issues in the current code (input to the refactor)

Observed on branch `old-tuf` of the local checkout:

- Arguments are dropped between `run` and the lane (`Lanes.runLane` calls `execute({})`).
- Package cycle: lanes in `dartlane_core` import `package:dartlane/...`, and `dartlane_core`'s pubspec lacks the dependencies those lanes need.
- Flutter build and Firebase lanes catch and log errors instead of failing, so failures can exit with code 0.
- `init` hardcodes `--path=../` dev paths and edits the app's pubspec.
- Static lane registry; unused isolate code in `Lane`; empty `executeT` stubs.
- `exeType` is used for both the target type and the build mode argument.
- Firebase lane finds the binary with an unordered directory listing; AAB branch is unreachable; upload timeout is unused; the whole file is read into memory.
- Package `publish_to: none`; README promises `dart pub global activate dartlane`; CLI description still says "A Very Good Project created by Very Good CLI".
