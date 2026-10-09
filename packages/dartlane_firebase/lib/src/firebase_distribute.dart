import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_firebase/src/firebase_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const _host = 'https://firebaseappdistribution.googleapis.com';

/// What Firebase did with an upload.
enum ReleaseOutcome {
  /// A new release was created.
  created,

  /// An existing release was updated.
  updated,

  /// The same binary was already uploaded, so nothing changed.
  unmodified,
}

/// What [FirebaseDistribute] produced.
class DistributionResult {
  /// Creates a result.
  const DistributionResult({
    required this.releaseName,
    required this.outcome,
    required this.distributed,
    this.displayVersion,
    this.buildVersion,
    this.consoleUri,
    this.testingUri,
  });

  /// The full release name, `projects/<n>/apps/<id>/releases/<id>`.
  final String releaseName;

  /// Whether the release was created, updated or already there.
  final ReleaseOutcome outcome;

  /// Whether testers or groups were notified.
  ///
  /// False when none were given. That is not an error: the binary is uploaded.
  final bool distributed;

  /// The version name, such as `1.2.3`.
  final String? displayVersion;

  /// The build number, such as `45`.
  final String? buildVersion;

  /// The release page in the Firebase console.
  final String? consoleUri;

  /// The link testers use to install the release.
  final String? testingUri;
}

/// Uploads an APK, app bundle or IPA to Firebase App Distribution, sets the
/// release notes and notifies testers and groups.
///
/// ```dart
/// final release = await ctx.run(
///   FirebaseDistribute(build.path, app: Config.firebaseAppId, groups: ['qa']),
/// );
/// ```
///
/// The file is always the one you pass, normally `BuildResult.path`; it is
/// never searched for. Before uploading it signs in with a service account
/// file or Application Default Credentials (see [connectToFirebase]), so
/// missing credentials fail the lane before anything is sent.
///
/// Every failure throws: a missing file, a rejected upload or an operation that
/// ends in an error is an `ActionFailed`, so the lane fails. Giving no testers
/// and no groups is not a failure; the binary is uploaded, a warning says
/// nobody was notified and [DistributionResult.distributed] is false.
class FirebaseDistribute extends LaneAction<DistributionResult> {
  /// Creates the action.
  const FirebaseDistribute(
    this.binary, {
    required this.app,
    this.groups = const [],
    this.testers = const [],
    this.releaseNotes,
    this.releaseNotesFile,
    this.testersFile,
    this.groupsFile,
    this.uploadTimeout = const Duration(minutes: 5),
    this.pollInterval = const Duration(seconds: 2),
    this.serviceAccountFile,
    this.client,
  });

  /// The file to upload: `.apk`, `.aab` or `.ipa`.
  final String binary;

  /// The Firebase app ID, such as `1:1234567890:android:abc123`.
  final String app;

  /// Aliases of the tester groups to notify.
  final List<String> groups;

  /// Email addresses of testers to notify.
  final List<String> testers;

  /// Text shown to testers with the release.
  ///
  /// Give this or [releaseNotesFile], not both.
  final String? releaseNotes;

  /// A text file whose contents are the release notes, for example a changelog
  /// written by an earlier step.
  final String? releaseNotesFile;

  /// A file of tester emails, added to [testers].
  ///
  /// One per line or separated by commas. Blank lines and lines starting with
  /// `#` are ignored.
  final String? testersFile;

  /// A file of group aliases, added to [groups]. Same format as [testersFile].
  final String? groupsFile;

  /// How long the upload, and then the wait for Firebase to process it, may
  /// each take before the action fails.
  final Duration uploadTimeout;

  /// How long to wait between checks of the processing status.
  final Duration pollInterval;

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
  String describe() {
    final to = [...groups, ...testers];
    return 'Distribute $binary to Firebase app $app'
        '${to.isEmpty ? '' : ' (${to.join(', ')})'}';
  }

  /// In a dry run: a placeholder release. Nothing is uploaded.
  ///
  /// The app ID is still checked. The file is not: in a dry run the build that
  /// makes it did not run.
  @override
  DistributionResult dryRunResult(LaneContext ctx) {
    _appName();
    return DistributionResult(
      releaseName: '${_appName()}/releases/dry-run',
      outcome: ReleaseOutcome.created,
      distributed:
          groups.isNotEmpty ||
          testers.isNotEmpty ||
          groupsFile != null ||
          testersFile != null,
    );
  }

  @override
  Future<DistributionResult> run(LaneContext ctx) async {
    final appName = _appName();
    final file = _checkFile();
    final inputs = _readInputs();
    final owned = client == null;
    final web =
        client ??
        await connectToFirebase(ctx, serviceAccountFile: serviceAccountFile);
    try {
      return await _distribute(ctx, web, appName, file, inputs);
    } finally {
      if (owned) web.close();
    }
  }

  Future<DistributionResult> _distribute(
    LaneContext ctx,
    http.Client web,
    String appName,
    File file,
    _Inputs inputs,
  ) async {
    ctx.logger.info('  uploading ${p.basename(binary)}');
    final operation = await _upload(web, appName, file);
    final done = await _waitFor(web, operation);

    final response = done['response'] as Map<String, dynamic>? ?? const {};
    final release = response['release'] as Map<String, dynamic>? ?? const {};
    final name = release['name'] as String?;
    if (name == null) {
      throw const ActionFailed(
        'Firebase finished processing the upload but did not return a '
        'release.',
      );
    }

    final notes = inputs.notes;
    if (notes != null && notes.isNotEmpty) {
      await _json(
        web,
        'PATCH',
        '$_host/v1/$name?updateMask=release_notes.text',
        {
          'releaseNotes': {'text': notes},
        },
        'set the release notes',
      );
    }

    final distribute = inputs.testers.isNotEmpty || inputs.groups.isNotEmpty;
    if (distribute) {
      await _json(web, 'POST', '$_host/v1/$name:distribute', {
        if (inputs.testers.isNotEmpty) 'testerEmails': inputs.testers,
        if (inputs.groups.isNotEmpty) 'groupAliases': inputs.groups,
      }, 'distribute the release');
    } else {
      ctx.logger.warn(
        'Uploaded, but no testers or groups were given, so nobody was '
        'notified.',
      );
    }

    return DistributionResult(
      releaseName: name,
      outcome: switch (response['result']) {
        'RELEASE_UPDATED' => ReleaseOutcome.updated,
        'RELEASE_UNMODIFIED' => ReleaseOutcome.unmodified,
        _ => ReleaseOutcome.created,
      },
      distributed: distribute,
      displayVersion: release['displayVersion'] as String?,
      buildVersion: release['buildVersion'] as String?,
      consoleUri: release['firebaseConsoleUri'] as String?,
      testingUri: release['testingUri'] as String?,
    );
  }

  /// `projects/<project number>/apps/<app id>`, from the app ID, which holds
  /// the project number as its second part.
  String _appName() {
    final parts = app.split(':');
    if (parts.length != 4 || int.tryParse(parts[1]) == null) {
      throw UserError(
        'Invalid Firebase app ID "$app".',
        hint:
            'It looks like 1:1234567890:android:abc123 and is in the '
            'Firebase console under Project settings.',
      );
    }
    return 'projects/${parts[1]}/apps/$app';
  }

  /// The notes, testers and groups, with the files read and merged in.
  ///
  /// Read before signing in or uploading, so a bad file fails the lane early.
  _Inputs _readInputs() {
    if (releaseNotes != null && releaseNotesFile != null) {
      throw const UserError(
        'Both releaseNotes and releaseNotesFile were given.',
        hint: 'Use one of them.',
      );
    }
    final notesFile = releaseNotesFile;
    final notes = notesFile == null
        ? releaseNotes
        : _readFile(notesFile, 'release notes').trim();

    final testerFile = testersFile;
    final fileTesters = testerFile == null
        ? const <String>[]
        : _readList(testerFile, 'testers');
    for (final email in fileTesters) {
      if (!email.contains('@')) {
        throw UserError(
          '$testerFile has "$email", which is not an email address.',
          hint: 'List one tester email per line.',
        );
      }
    }
    final groupFile = groupsFile;
    return _Inputs(
      notes: notes,
      testers: {...testers, ...fileTesters}.toList(),
      groups: {
        ...groups,
        if (groupFile != null) ..._readList(groupFile, 'groups'),
      }.toList(),
    );
  }

  String _readFile(String path, String what) {
    final file = File(path);
    if (!file.existsSync()) {
      throw UserError(
        'The $what file $path does not exist.',
        hint: 'Check the path, or write the file in an earlier step.',
      );
    }
    return file.readAsStringSync();
  }

  List<String> _readList(String path, String what) => [
    for (final line in _readFile(path, what).split(RegExp(r'\r?\n')))
      if (!line.trim().startsWith('#'))
        for (final item in line.split(','))
          if (item.trim().isNotEmpty) item.trim(),
  ];

  File _checkFile() {
    final file = File(binary);
    if (!file.existsSync()) {
      throw UserError(
        'Cannot upload $binary: the file does not exist.',
        hint: 'Pass the path of a built .apk, .aab or .ipa.',
      );
    }
    return file;
  }

  Future<String> _upload(http.Client web, String appName, File file) async {
    final request =
        http.StreamedRequest(
            'POST',
            Uri.parse('$_host/upload/v1/$appName/releases:upload'),
          )
          ..headers.addAll({
            'X-Goog-Upload-Protocol': 'raw',
            'X-Goog-Upload-File-Name': Uri.encodeComponent(p.basename(binary)),
            'Content-Type': _contentType,
          })
          ..contentLength = file.lengthSync();
    // Stream from disk so a large binary is never held in memory.
    unawaited(file.openRead().pipe(request.sink).catchError((Object _) {}));

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await web.send(request).timeout(uploadTimeout),
      ).timeout(uploadTimeout);
    } on TimeoutException {
      throw ActionFailed(
        'Uploading $binary took longer than ${uploadTimeout.inSeconds}s.',
      );
    }
    final body = _decode(response, 'upload $binary');
    final name = body['name'] as String?;
    if (name == null) {
      throw const ActionFailed(
        'Firebase accepted the upload but did not '
        'return an operation to follow.',
      );
    }
    return name;
  }

  Future<Map<String, dynamic>> _waitFor(
    http.Client web,
    String operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      final response = await web.get(Uri.parse('$_host/v1/$operation'));
      final body = _decode(response, 'check the upload status');
      if (body['done'] == true) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          throw ActionFailed(
            'Firebase could not process the upload: '
            '${error['message'] ?? error}',
          );
        }
        return body;
      }
      if (stopwatch.elapsed > uploadTimeout) {
        throw ActionFailed(
          'Firebase was still processing the upload after '
          '${uploadTimeout.inSeconds}s.',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _json(
    http.Client web,
    String method,
    String url,
    Map<String, Object?> payload,
    String what,
  ) async {
    final request = http.Request(method, Uri.parse(url))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);
    final response = await http.Response.fromStream(await web.send(request));
    _decode(response, what);
  }

  Map<String, dynamic> _decode(http.Response response, String what) {
    var body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Not JSON; the status code below still decides.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      throw ActionFailed(
        'Firebase refused to $what (HTTP ${response.statusCode})'
        '${message == null ? '' : ': $message'}.',
      );
    }
    return body;
  }

  String get _contentType => switch (p.extension(binary).toLowerCase()) {
    '.apk' => 'application/vnd.android.package-archive',
    '.aab' => 'application/octet-stream',
    '.ipa' => 'application/octet-stream',
    _ => 'application/octet-stream',
  };
}

class _Inputs {
  const _Inputs({
    required this.notes,
    required this.testers,
    required this.groups,
  });

  final String? notes;
  final List<String> testers;
  final List<String> groups;
}
