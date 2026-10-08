import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

const _docs =
    'https://cloud.google.com/docs/authentication/provide-credentials-adc';

/// The service account file to sign in with, or null to use Application
/// Default Credentials.
///
/// [explicit] wins; otherwise the `GOOGLE_APPLICATION_CREDENTIALS` environment
/// variable is used. The path is not checked here.
String? serviceAccountFileFor(LaneContext ctx, {String? explicit}) {
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final fromEnv = ctx.env['GOOGLE_APPLICATION_CREDENTIALS'];
  return fromEnv == null || fromEnv.isEmpty ? null : fromEnv;
}

/// Where `gcloud auth application-default login` stores its credentials.
String? wellKnownCredentialsFile(Map<String, String> env) {
  if (Platform.isWindows) {
    final appData = env['APPDATA'];
    return appData == null
        ? null
        : p.join(appData, 'gcloud', 'application_default_credentials.json');
  }
  final home = env['HOME'];
  return home == null
      ? null
      : p.join(
          home,
          '.config',
          'gcloud',
          'application_default_credentials.json',
        );
}

/// Signs in to Google and returns an HTTP client that sends the access token.
///
/// With a service account file ([serviceAccountFile], or
/// `GOOGLE_APPLICATION_CREDENTIALS`) it signs in as that account. Without one
/// it falls back to Application Default Credentials: `gcloud auth
/// application-default login` on a laptop, or the attached service account on
/// Google Cloud.
///
/// The private key is masked in the log. Throws a [UserError], with a pointer
/// to the docs, if no credentials can be found or the file cannot be used. The
/// caller closes the returned client.
Future<http.Client> connectToFirebase(
  LaneContext ctx, {
  String? serviceAccountFile,
}) async {
  final path = serviceAccountFileFor(ctx, explicit: serviceAccountFile);
  if (path != null) return _viaServiceAccount(ctx, path);

  try {
    return await clientViaApplicationDefaultCredentials(scopes: _scopes);
  } on Object catch (error) {
    ctx.logger.detail('Application Default Credentials failed: $error');
    throw const UserError(
      'No Google credentials found.',
      hint:
          'Point GOOGLE_APPLICATION_CREDENTIALS at a service account JSON '
          'file, or run `gcloud auth application-default login`. See '
          '$_docs',
    );
  }
}

Future<http.Client> _viaServiceAccount(LaneContext ctx, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw UserError(
      'Service account file not found: $path',
      hint:
          'Check the path. Create a key under Google Cloud > IAM > Service '
          'Accounts > Keys. See $_docs',
    );
  }
  final json = file.readAsStringSync();
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    throw UserError(
      '$path is not valid JSON: ${error.message}',
      hint: 'Download a new JSON key for the service account.',
    );
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['private_key'] is! String ||
      decoded['client_email'] is! String ||
      decoded['client_id'] is! String) {
    throw UserError(
      '$path is not a service account key file.',
      hint:
          'It needs client_email, client_id and private_key. Download a '
          'new JSON key for the service account.',
    );
  }
  ctx.logger.mask(decoded['private_key'] as String);
  return clientViaServiceAccount(
    ServiceAccountCredentials.fromJson(decoded),
    _scopes,
  );
}

/// Reports whether Google credentials can be found, for `dartlane doctor`.
///
/// It only looks for a credentials file and never signs in. On Google Cloud
/// the credentials come from the machine and need no file, so a failure is a
/// warning, not an error.
class FirebaseCredentialsCheck extends DoctorCheck {
  /// Creates the check. [serviceAccountFile] is the path the lane passes to
  /// `FirebaseDistribute`, if it passes one.
  const FirebaseCredentialsCheck({this.serviceAccountFile});

  /// The service account file the lane uses, if set explicitly.
  final String? serviceAccountFile;

  @override
  String get name => 'Firebase credentials';

  @override
  bool get isRequired => false;

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final path = serviceAccountFileFor(ctx, explicit: serviceAccountFile);
    if (path != null) {
      return File(path).existsSync()
          ? DoctorResult.pass('service account file $path')
          : DoctorResult.fail(
              'Service account file not found: $path',
              fix: 'Check the path, or download a new JSON key.',
            );
    }
    final adc = wellKnownCredentialsFile(ctx.env);
    if (adc != null && File(adc).existsSync()) {
      return DoctorResult.pass('Application Default Credentials ($adc)');
    }
    return const DoctorResult.fail(
      'No Google credentials found.',
      fix:
          'Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file, '
          'or run `gcloud auth application-default login`. Ignore this on '
          'Google Cloud, where the machine provides credentials. See $_docs',
    );
  }
}

/// The checks `dartlane doctor` runs for Firebase.
///
/// ```dart
/// dartlane(args, lanes: {...}, checks: [
///   ...flutterChecks(),
///   ...firebaseChecks(),
/// ]);
/// ```
List<DoctorCheck> firebaseChecks({String? serviceAccountFile}) => [
  FirebaseCredentialsCheck(serviceAccountFile: serviceAccountFile),
];
