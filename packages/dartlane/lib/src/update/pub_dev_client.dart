import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:pub_semver/pub_semver.dart';

/// pub.dev could not be asked, or its answer could not be understood.
class UpdateCheckException implements Exception {
  /// Creates an exception with a [message] for the user.
  const UpdateCheckException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Asks pub.dev for the newest version of a package.
class PubDevClient {
  /// Creates a client that makes its requests with the HTTP `client`.
  ///
  /// A request that takes longer than [timeout] fails.
  PubDevClient(
    this._client, {
    this.timeout = const Duration(seconds: 3),
  });

  final Client _client;

  /// How long to wait for pub.dev.
  final Duration timeout;

  /// The newest published version of [package], or null if pub.dev does not
  /// know the package, for example because it has not been published yet.
  ///
  /// Throws an [UpdateCheckException] if pub.dev cannot be reached or answers
  /// something else.
  Future<Version?> latestVersion(String package) async {
    final Response response;
    try {
      response = await _client
          .get(Uri.https('pub.dev', '/api/packages/$package'))
          .timeout(timeout);
    } on Object catch (error) {
      throw UpdateCheckException(
        'Could not reach pub.dev'
        '${error is TimeoutException ? ' (it took too long)' : ''}.',
      );
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'pub.dev answered with status ${response.statusCode}.',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = json['latest'] as Map<String, dynamic>;
      return Version.parse(latest['version'] as String);
    } on Object {
      throw const UpdateCheckException(
        'pub.dev sent an answer that could not be read.',
      );
    }
  }
}
