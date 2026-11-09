import 'dart:convert';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:http/http.dart' as http;

/// The App Distribution API host.
const String firebaseHost = 'https://firebaseappdistribution.googleapis.com';

/// `projects/<project number>/apps/<app id>`, from the app ID, which holds the
/// project number as its second part.
///
/// Throws a [UserError] if [app] is not a Firebase app ID.
String firebaseAppName(String app) {
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

/// The JSON body of [response], or an `ActionFailed` saying Firebase refused to
/// [what] when the status is not a success.
Map<String, dynamic> decodeFirebaseResponse(
  http.Response response,
  String what,
) {
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
