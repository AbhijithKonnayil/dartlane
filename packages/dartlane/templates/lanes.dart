import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';

import 'config.dart';

/// List the lanes, and run one, from the project root:
///
///     dartlane list
///     dartlane run build
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

      ctx.logger.success('Built ${build.path}');
    }),
    // Add your own lanes here.
  },
);
