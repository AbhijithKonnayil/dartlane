# Releasing

Dartlane is a pub workspace managed with [Melos](https://melos.invert.dev).
Melos configuration lives under `melos:` in the root `pubspec.yaml`.

## Setup

```sh
dart pub get
dart run melos bootstrap
```

Optionally `dart pub global activate melos` to call `melos` directly instead of
`dart run melos`.

## Scripts

| Command | What it does |
|---|---|
| `melos run analyze` | `dart analyze --fatal-infos` in every package |
| `melos run test` | `dart test` in every package that has a `test/` directory |
| `melos run format` | Formatting check in every package |
| `melos run fix` | `dart fix --apply` then `dart format` in every package. Modifies files, so run it locally before committing. It is not part of `check` or CI. |
| `melos run check` | Format, analyze and test in sequence |

## Commit convention

Decision: use [Conventional Commits](https://www.conventionalcommits.org)
(`feat:`, `fix:`, `chore:`, `feat!:` for breaking changes). Melos reads them to
choose the next version and generate each package's `CHANGELOG.md`.

Use the package name as scope when a change touches one package, for example
`feat(dartlane_core): add LaneContext`.

## Versioning

```sh
dart run melos version            # bump versions and changelogs from commits
dart run melos version --no-git-tag-version --no-git-commit   # preview-style run
```

Melos bumps only packages that changed, and bumps dependents so the versions stay
consistent.

The CLI reads its version from a generated file, `packages/dartlane/lib/src/version.g.dart`.
After `melos version`, regenerate it and commit it with the version bump:

```sh
dart run melos run generate
```

A test fails if the file does not match `pubspec.yaml`, so forgetting is caught.

## Publishing

```sh
dart run melos publish --dry-run   # what would be published
dart run melos publish             # publish in dependency order
```

Melos publishes `dartlane_core` before the packages that depend on it.

Until 0.1.0, every package has `publish_to: none`, so `publish --dry-run` reports
"no unpublished packages". Removing `publish_to: none` is part of the launch
milestone (M3).
