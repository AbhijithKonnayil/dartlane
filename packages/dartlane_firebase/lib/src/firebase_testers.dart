import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_firebase/src/firebase_api.dart';
import 'package:dartlane_firebase/src/firebase_credentials.dart';
import 'package:dartlane_firebase/src/firebase_inputs.dart';
import 'package:http/http.dart' as http;

/// The most emails the API accepts in one `batchAdd` or `batchRemove` call.
const _batchSize = 1000;

/// Adds testers to a Firebase project, so they can be given releases.
///
/// ```dart
/// await ctx.run(
///   FirebaseAddTesters(project: '1234567890', emails: ['a@b.c']),
/// );
/// ```
///
/// Testers are per project, not per app. [project] is the project number: the
/// second part of the app ID, `1:1234567890:android:abc`. Returns the emails
/// Firebase added. An email that is already a tester is not an error.
///
/// Every email is checked before signing in, so a bad address fails the lane
/// before anything is sent. Giving no email at all is a [UserError]. A refused
/// request is an `ActionFailed`.
class FirebaseAddTesters extends LaneAction<List<String>> {
  /// Creates the action.
  const FirebaseAddTesters({
    required this.project,
    this.emails = const [],
    this.emailsFile,
    this.serviceAccountFile,
    this.client,
  });

  /// The Firebase project number, such as `1234567890`.
  final String project;

  /// Email addresses of the testers to add.
  final List<String> emails;

  /// A file of tester emails, added to [emails].
  ///
  /// One per line or separated by commas. Blank lines and lines starting with
  /// `#` are ignored.
  final String? emailsFile;

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
  String describe() =>
      'Add ${_count(emails.length, emailsFile)} to Firebase '
      'project $project';

  /// In a dry run: the emails that would be added. Nothing is sent.
  ///
  /// The project number and the emails are still checked, and the file is read
  /// if it exists, so a dry run catches a bad address.
  @override
  List<String> dryRunResult(LaneContext ctx) {
    firebaseProjectName(project);
    return _emails(readFileIfPresent: true);
  }

  @override
  Future<List<String>> run(LaneContext ctx) async {
    final name = firebaseProjectName(project);
    final all = _emails();
    return _withClient(ctx, client, serviceAccountFile, (web) async {
      final added = <String>[];
      for (final batch in _batches(all)) {
        final body = await sendFirebaseJson(
          web,
          'POST',
          '$firebaseHost/v1/$name/testers:batchAdd',
          {'emails': batch},
          'add the testers',
        );
        final testers = body['testers'];
        added.addAll(
          testers is List
              ? [
                  for (final t in testers)
                    if (t is Map<String, dynamic> && t['name'] is String)
                      (t['name'] as String).split('/').last,
                ]
              : batch,
        );
      }
      ctx.logger.info('  added ${added.length} tester(s)');
      return added;
    });
  }

  List<String> _emails({bool readFileIfPresent = false}) =>
      _collectEmails(emails, emailsFile, readFileIfPresent: readFileIfPresent);
}

/// Removes testers from a Firebase project.
///
/// ```dart
/// await ctx.run(
///   FirebaseRemoveTesters(project: '1234567890', emails: ['a@b.c']),
/// );
/// ```
///
/// Testers are per project, not per app. [project] is the project number: the
/// second part of the app ID, `1:1234567890:android:abc`. Returns the emails
/// Firebase removed.
///
/// Every email is checked before signing in, so a bad address fails the lane
/// before anything is sent. Giving no email at all is a [UserError]. A refused
/// request is an `ActionFailed`.
class FirebaseRemoveTesters extends LaneAction<List<String>> {
  /// Creates the action.
  const FirebaseRemoveTesters({
    required this.project,
    this.emails = const [],
    this.emailsFile,
    this.serviceAccountFile,
    this.client,
  });

  /// The Firebase project number, such as `1234567890`.
  final String project;

  /// Email addresses of the testers to remove.
  final List<String> emails;

  /// A file of tester emails, added to [emails]. Same format as
  /// [FirebaseAddTesters.emailsFile].
  final String? emailsFile;

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
  String describe() =>
      'Remove ${_count(emails.length, emailsFile)} from Firebase '
      'project $project';

  /// In a dry run: the emails that would be removed. Nothing is sent.
  ///
  /// The project number and the emails are still checked, and the file is read
  /// if it exists, so a dry run catches a bad address.
  @override
  List<String> dryRunResult(LaneContext ctx) {
    firebaseProjectName(project);
    return _emails(readFileIfPresent: true);
  }

  @override
  Future<List<String>> run(LaneContext ctx) async {
    final name = firebaseProjectName(project);
    final all = _emails();
    return _withClient(ctx, client, serviceAccountFile, (web) async {
      final removed = <String>[];
      for (final batch in _batches(all)) {
        final body = await sendFirebaseJson(
          web,
          'POST',
          '$firebaseHost/v1/$name/testers:batchRemove',
          {'emails': batch},
          'remove the testers',
        );
        final gone = body['emails'];
        removed.addAll(
          gone is List ? [for (final e in gone) e.toString()] : batch,
        );
      }
      ctx.logger.info('  removed ${removed.length} tester(s)');
      return removed;
    });
  }

  List<String> _emails({bool readFileIfPresent = false}) =>
      _collectEmails(emails, emailsFile, readFileIfPresent: readFileIfPresent);
}

String _count(int inline, String? file) {
  if (file == null) return '$inline tester(s)';
  return inline == 0 ? 'testers from $file' : '$inline tester(s) and $file';
}

/// The inline emails and the file's, trimmed, without duplicates, checked.
List<String> _collectEmails(
  List<String> inline,
  String? file, {
  required bool readFileIfPresent,
}) {
  final fromInline = [
    for (final e in inline)
      if (e.trim().isNotEmpty) e.trim(),
  ];
  requireEmails(fromInline, 'The tester list');
  var fromFile = const <String>[];
  // In a dry run an earlier step may not have written the file yet.
  final pending = readFileIfPresent && file != null && !File(file).existsSync();
  if (file != null && !pending) {
    fromFile = readInputList(file, 'testers');
    requireEmails(fromFile, file);
  }
  final all = {...fromInline, ...fromFile}.toList();
  if (all.isEmpty && !pending) {
    throw const UserError(
      'No tester emails were given.',
      hint: 'Pass emails, or a file with one email per line.',
    );
  }
  return all;
}

Iterable<List<String>> _batches(List<String> emails) sync* {
  for (var i = 0; i < emails.length; i += _batchSize) {
    final end = i + _batchSize;
    yield emails.sublist(i, end > emails.length ? emails.length : end);
  }
}

Future<T> _withClient<T>(
  LaneContext ctx,
  http.Client? client,
  String? serviceAccountFile,
  Future<T> Function(http.Client web) body,
) async {
  final owned = client == null;
  final web =
      client ??
      await connectToFirebase(ctx, serviceAccountFile: serviceAccountFile);
  try {
    return await body(web);
  } finally {
    if (owned) web.close();
  }
}
