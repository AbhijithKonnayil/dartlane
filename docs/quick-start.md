# Quick start

From install to a build on your testers' phones in about five minutes.

## What this covers

Dartlane is early. Today it:

- builds **Android** APKs and app bundles with `flutter build`;
- uploads them to **Firebase App Distribution**.

It does not build or distribute iOS, sign apps, or publish to the Play Store or
App Store. iOS files (`.ipa`) can be uploaded to Firebase if you build them
yourself, but Dartlane does not build them.

## Before you start

- Dart 3.10 or newer and Flutter on your `PATH`. `dartlane doctor` checks both.
- A Flutter app that builds with `flutter build apk`.
- A Firebase project with App Distribution turned on, your Android app
  registered in it, and a tester group (for example `qa`).

## 1. Install

The packages are not on pub.dev yet, so install from a checkout:

```sh
git clone https://github.com/AbhijithKonnayil/dartlane.git
dart pub global activate --source path dartlane/packages/dartlane
```

Check it works:

```sh
dartlane --version
```

## 2. Set up your app

From your Flutter app's root:

```sh
dartlane init --local-repo /path/to/the/dartlane/checkout
```

(`--local-repo` is only needed until the packages are published.)

This creates a `dartlane/` folder with `lanes.dart`, `config.dart` and its own
`pubspec.yaml`, runs `dart pub get`, and adds `.dartlane/` and `.env` to your
`.gitignore`. Your app's `pubspec.yaml` is not touched. Delete the folder to
remove Dartlane.

Then check your setup:

```sh
dartlane doctor
```

## 3. Build

`init` registers ready-made lanes. See them all with `dartlane list`.

```sh
dartlane run flutter_build_apk
dartlane run flutter_build_apk --flavor=prod --dart-define=ENV=prod
```

To see what a lane would do without doing it, add `--dry-run`.

## 4. Sign in to Firebase

Use either of these:

- **A service account** (best for CI). Create one in Google Cloud with the
  *Firebase App Distribution Admin* role, download its JSON key, and set
  `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` in your shell or in `.env`.
  Never commit the key.
- **Your own login**, on a laptop: `gcloud auth application-default login`.

## 5. Release

Find your Firebase app ID (like `1:1234567890:android:abc123`) under
*Project settings* in the Firebase console, then:

```sh
dartlane run firebase_distribute \
  --app=1:1234567890:android:abc123 \
  --file=build/app/outputs/flutter-apk/app-release.apk \
  --groups=qa \
  --release-notes="First Dartlane release"
```

Testers in the group get an email. Without `--groups` or `--testers` the file is
uploaded but nobody is notified, and Dartlane says so.

## 6. Put it in one lane

Typing both commands gets old. Add a lane to `dartlane/lanes.dart`:

```dart
'beta': Lane('Build and ship to QA', (ctx) async {
  await ctx.run(const FlutterAnalyze());
  final build = await ctx.run(FlutterBuild.apk(flavor: Config.flavor));
  await ctx.run(
    FirebaseDistribute(
      build.path,
      app: Config.firebaseAppId,
      groups: ['qa'],
    ),
  );
}),
```

Add `static const firebaseAppId = '1:1234567890:android:abc123';` to
`dartlane/config.dart`, then:

```sh
dartlane run beta --dry-run   # preview
dartlane run beta             # ship it
```

## Next

- [Running lanes on CI](ci.md)
- `dartlane run <lane> --verbose` shows the commands that are run.
