import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_firebase/src/firebase_distribute.dart';

/// Ready-made lanes for Firebase App Distribution, to spread into the `lanes`
/// map.
///
/// ```dart
/// dartlane(args, lanes: {...firebaseLanes(), 'beta': Lane(...)});
/// ```
///
/// `firebase_distribute` runs [FirebaseDistribute]:
///
/// ```text
/// dartlane run firebase_distribute --app=1:123:android:abc --file=app.apk \
///   --groups=qa --release-notes="Fixes login"
/// ```
///
/// `--app` and `--file` are required. Optional: `--groups`, `--testers`
/// (comma separated or repeated), `--release-notes`, `--release-notes-file`,
/// `--testers-file`, `--groups-file` and `--service-account`.
Map<String, Lane> firebaseLanes() => {
  'firebase_distribute': Lane(
    'Upload to Firebase App Distribution (--app, --file, --groups, ...)',
    (ctx) async {
      final args = ctx.args..expectOnly(_distributeOptions);
      final release = await ctx.run(
        FirebaseDistribute(
          args.requireString('file'),
          app: args.requireString('app'),
          groups: args.list('groups'),
          testers: args.list('testers'),
          releaseNotes: args.string('release-notes'),
          releaseNotesFile: args.string('release-notes-file'),
          testersFile: args.string('testers-file'),
          groupsFile: args.string('groups-file'),
          serviceAccountFile: args.string('service-account'),
        ),
      );
      ctx.logger.success(
        '${ctx.dryRun ? 'Would distribute' : 'Distributed'} '
        '${release.releaseName}',
      );
    },
  ),
};

const _distributeOptions = [
  'app',
  'file',
  'groups',
  'testers',
  'release-notes',
  'release-notes-file',
  'testers-file',
  'groups-file',
  'service-account',
];
