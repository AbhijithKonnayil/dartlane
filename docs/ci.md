# Running lanes on CI

Lanes run the same way on a laptop and on CI. The runner only changes two
things when it detects a CI environment.

## What changes on CI

| Behavior | When | Effect |
|---|---|---|
| No prompts | `CI=true` or `GITHUB_ACTIONS=true`, or no terminal attached | `confirm` never asks. It returns its default value, so a lane never hangs waiting for input. |
| Annotations | `GITHUB_ACTIONS=true` | `error` and `warn` messages print as `::error::message` and `::warning::message`, which GitHub shows in the run summary. |

Everything else is the same everywhere: log levels, `--verbose`, error messages
and exit codes.

## Verbose output

`--verbose` shows detail output such as the commands that are run. It works
anywhere in the arguments and is not passed on to the lane:

```sh
dart run dartlane/lanes.dart beta --verbose
```

## Supported platforms

| Platform | No prompts | Annotations |
|---|---|---|
| GitHub Actions | Yes | Yes |
| Other platforms that set `CI=true` (for example GitLab CI, CircleCI, Travis CI, Buildkite) | Yes | No, plain output |
| Platforms that do not set `CI` (for example Azure Pipelines sets `TF_BUILD`) | Only if no terminal is attached, which is usual on CI | No, plain output |

Annotations are GitHub-specific because each platform uses its own format:

| Platform | Format |
|---|---|
| GitHub Actions | `::error::message` |
| Azure Pipelines | `##vso[task.logissue type=error]message` |
| TeamCity | `##teamcity[message text='...' status='ERROR']` |

Other platforms either have no equivalent for errors or only offer collapsible
log sections.

## Adding another platform

Not built yet, because only GitHub Actions is in scope for 0.1.0. When a second
platform is needed:

1. Replace the `githubActions` flag on `LaneLogger` with a small formatter that
   turns an error or a warning into that platform's line.
2. Choose the formatter in `LaneLogger.fromEnvironment` from the platform's
   environment variable.
3. Add the platform to the tables above and test the formatter like the
   GitHub one in `packages/dartlane_core/test/lane_logger_test.dart`.

Only `LaneLogger` and `fromEnvironment` know about the flag, so the change stays
inside them.
