import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';

import 'config.dart';

/// List the lanes, run one, preview one, and check your setup, from the project
/// root:
///
///     dartlane list
///     dartlane run build
///     dartlane run build --dry-run
///     dartlane doctor
///
/// or without the dartlane command:
///
///     dart run dartlane/lanes.dart build
Future<void> main(List<String> args) => dartlane(
  args,
  lanes: {
    'build': Lane('Build a release APK', (ctx) async {
      final build = await ctx.run(
        FlutterBuild.apk(
          flavor: Config.flavor,
          dartDefines: Config.dartDefines,
        ),
      );

      // In a dry run (`dartlane run build --dry-run`) nothing was built.
      ctx.logger.success(
        '${ctx.dryRun ? 'Would build' : 'Built'} ${build.path}',
      );
    }),
    // Add your own lanes here.
  },
  // What `dartlane doctor` checks. Packages contribute their own checks.
  checks: flutterChecks(),
);
