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
dart run melos version --no-git-tag-version --no-git-commit-version   # preview-style run
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

Until the launch milestone (M3), every package has `publish_to: none`, so
`publish --dry-run` reports "no unpublished packages". Removing it from all four
packages in one change is part of #51.

## Prereleases

A published version can never be reused or deleted (a version can be retracted
for 7 days, but its number stays taken). So ship prereleases before a stable
release and test each one:

| Step | Version | Purpose |
|---|---|---|
| 1 | `0.1.0-dev.1`, `-dev.2`, ... | Check that publishing and installing work end to end. |
| 2 | `0.1.0-rc.1`, ... | Release candidate: feature complete, being tried by the first users. |
| 3 | `0.1.0` | The stable release. |

```sh
dart run melos version --prerelease      # 0.1.0-dev.1 (then dev.2 on the next run)
dart run melos run generate              # regenerate version.g.dart and commit it
dart run melos publish --dry-run
dart run melos publish
```

Graduate to the stable version with:

```sh
dart run melos version --graduate        # 0.1.0-rc.N -> 0.1.0
```

To move from `dev` to `rc`, use `--preid rc` on the `--prerelease` run.

How pub treats prereleases:

- `dart pub global activate dartlane` installs the latest **stable** version.
  While only prereleases exist, ask for one explicitly:
  `dart pub global activate dartlane 0.1.0-dev.1`. Do not put that in the quick
  start for ordinary users; share it with testers directly.
- pub.dev lists prereleases on a separate line and does not make them the
  package's main version.
- The generated `dartlane/pubspec.yaml` uses `^<dartlane version>`, so a
  prerelease CLI writes a prerelease constraint such as `^0.1.0-dev.1`, which
  resolves against that prerelease and later ones.
- The update notice parses versions with `pub_semver`, so it works for
  prereleases: someone on `0.1.0-dev.1` is told about `0.1.0-dev.2` or `0.1.0`.
  pub.dev's `latest` is the newest stable version, or the newest prerelease
  while no stable exists.

## Checklist for each published version

1. All four packages: `publish_to: none` removed, versions bumped together.
2. `dart run melos run check` passes.
3. `dart run melos publish --dry-run` is clean.
4. Publish, in dependency order (Melos does this).
5. On a clean machine or container, without the repo checked out:

   ```sh
   dart pub global activate dartlane <version>
   dartlane --version
   cd some_flutter_app && dartlane init && dartlane doctor && dartlane run flutter_build_apk --dry-run
   ```

6. If it is broken, publish the next prerelease. Retract only a version that
   would hurt users who install it.
