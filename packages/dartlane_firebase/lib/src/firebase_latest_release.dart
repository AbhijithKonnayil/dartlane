import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_firebase/src/firebase_api.dart';
import 'package:dartlane_firebase/src/firebase_credentials.dart';
import 'package:http/http.dart' as http;

/// A release in Firebase App Distribution.
class FirebaseRelease {
  /// Creates a release.
  const FirebaseRelease({
    required this.name,
    this.displayVersion,
    this.buildVersion,
    this.createTime,
    this.consoleUri,
    this.testingUri,
    this.releaseNotes,
  });

  /// Reads a release from the API's JSON.
  ///
  /// Throws an `ActionFailed` if it has no name.
  factory FirebaseRelease.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    if (name == null) {
      throw const ActionFailed('Firebase returned a release without a name.');
    }
    final notes = json['releaseNotes'];
    return FirebaseRelease(
      name: name,
      displayVersion: json['displayVersion'] as String?,
      buildVersion: json['buildVersion'] as String?,
      createTime: DateTime.tryParse(json['createTime'] as String? ?? ''),
      consoleUri: json['firebaseConsoleUri'] as String?,
      testingUri: json['testingUri'] as String?,
      releaseNotes: notes is Map<String, dynamic>
          ? notes['text'] as String?
          : null,
    );
  }

  /// The full release name, `projects/<n>/apps/<id>/releases/<id>`.
  final String name;

  /// The version name, such as `1.2.3`.
  final String? displayVersion;

  /// The build number, such as `45`.
  final String? buildVersion;

  /// When Firebase created the release.
  final DateTime? createTime;

  /// The release page in the Firebase console.
  final String? consoleUri;

  /// The link testers use to install the release.
  final String? testingUri;

  /// The release notes shown to testers.
  final String? releaseNotes;
}

/// Finds the newest release of a Firebase app.
///
/// ```dart
/// final latest = await ctx.run(FirebaseGetLatestRelease(app: appId));
/// final next = (int.tryParse(latest?.buildVersion ?? '') ?? 0) + 1;
/// ```
///
/// The result is null when the app has no releases yet. That is a normal
/// outcome, not an error, so a first upload can start from build 1. Every other
/// failure throws: bad credentials or a refused request is an `ActionFailed`.
///
/// Signs in the same way as `FirebaseDistribute` (see [connectToFirebase]).
class FirebaseGetLatestRelease extends LaneAction<FirebaseRelease?> {
  /// Creates the action.
  const FirebaseGetLatestRelease({
    required this.app,
    this.serviceAccountFile,
    this.client,
  });

  /// The Firebase app ID, such as `1:1234567890:android:abc123`.
  final String app;

  /// The service account JSON file to sign in with.
  ///
  /// Defaults to the `GOOGLE_APPLICATION_CREDENTIALS` environment variable, and
  /// then to Application Default Credentials. See [connectToFirebase].
  final String? serviceAccountFile;

  /// An already authorized HTTP client to use instead of signing in.
  ///
  /// Mostly for tests. It is not closed by the action.
  final http.Client? client;

  @override
  String describe() => 'Get the latest Firebase release of $app';

  /// In a dry run: a placeholder release. Nothing is requested.
  ///
  /// It is never null, so a lane that reads the build number keeps working.
  /// The app ID is still checked.
  @override
  FirebaseRelease? dryRunResult(LaneContext ctx) => FirebaseRelease(
    name: '${firebaseAppName(app)}/releases/dry-run',
    displayVersion: '0.0.0',
    buildVersion: '0',
  );

  @override
  Future<FirebaseRelease?> run(LaneContext ctx) async {
    final appName = firebaseAppName(app);
    final owned = client == null;
    final web =
        client ??
        await connectToFirebase(ctx, serviceAccountFile: serviceAccountFile);
    try {
      final response = await web.get(
        Uri.parse('$firebaseHost/v1/$appName/releases?pageSize=1'),
      );
      final body = decodeFirebaseResponse(
        response,
        'list the releases of $app',
      );
      final releases = body['releases'];
      if (releases is! List || releases.isEmpty) {
        ctx.logger.info('  $app has no releases yet');
        return null;
      }
      final found = FirebaseRelease.fromJson(
        releases.first as Map<String, dynamic>,
      );
      ctx.logger.info(
        '  latest release: ${found.displayVersion ?? '?'} '
        '(${found.buildVersion ?? '?'})',
      );
      return found;
    } finally {
      if (owned) web.close();
    }
  }
}
