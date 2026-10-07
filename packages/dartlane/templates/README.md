# Templates for `dartlane init`

The files in this folder are what `dartlane init` writes into a project. Edit
them here, as normal files.

| File | Written as | Placeholders |
|---|---|---|
| `pubspec.yaml.tmpl` | `dartlane/pubspec.yaml` | `{{package_name}}`, `{{app_name}}`, `{{version}}` |
| `lanes.dart` | `dartlane/lanes.dart` | none |
| `config.dart` | `dartlane/config.dart` | none |
| `pubspec_overrides.yaml.tmpl` | `dartlane/pubspec_overrides.yaml`, only with `--local-repo` | `{{repo}}` |

The CLI does not read this folder at runtime, because a compiled executable has
no access to package files. The files are embedded into
`lib/src/templates.g.dart` instead. After editing a template, run:

```sh
dart run melos run generate
```

Two tests keep this honest. `templates_test.dart` fails if the generated file is
out of date. `templates_valid_test.dart` renders the templates into a temporary
package, runs `dart pub get` and `dart analyze` on it, and fails on syntax or
type errors, for example after renaming something in `dartlane_flutter`.

`lanes.dart` and `config.dart` are analyzed and formatted like any other Dart
file, so an editor highlights, formats and reports errors in them. They import
packages the CLI does not depend on, so `analysis_options.yaml` in this folder
turns off a few style lints that do not apply to a copied example.
