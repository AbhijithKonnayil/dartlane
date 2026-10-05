import 'dart:convert';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:googleapis/firebaseappdistribution/v1.dart';

final requestHeaders = {
  'user-agent': 'google-api-dart-client/14.0.0',
  'x-goog-api-client': 'gl-dart/${commons.dartVersion} gdcl/14.0.0',
};

class FirebaseDistApi extends FirebaseAppDistributionApi {
  FirebaseDistApi(
    super.client, {
    String rootUrl = 'https://firebaseappdistribution.googleapis.com/',
    String servicePath = '',
  }) : _requester = _FirebaseAppDistApiRequester(
          client,
          rootUrl,
          servicePath,
          requestHeaders,
        );

  final commons.ApiRequester _requester;

  @override
  MediaResource get media => MediaResource(_requester);
}

class _FirebaseAppDistApiRequester extends commons.ApiRequester {
  _FirebaseAppDistApiRequester(
    super.httpClient,
    super.rootUrl,
    super.basePath,
    super.requestHeaders,
  );

  @override
  // ignore: strict_raw_type
  Future request(
    String requestUrl,
    String method, {
    String? body,
    Map<String, List<String>>? queryParams,
    commons.Media? uploadMedia,
    commons.UploadOptions? uploadOptions,
    commons.DownloadOptions? downloadOptions = DownloadOptions.metadata,
  }) {
    return super.request(
      requestUrl,
      method,
      body: parseAndCheckEmpty(body),
      queryParams: queryParams,
      uploadMedia: uploadMedia,
      uploadOptions: uploadOptions,
      downloadOptions: downloadOptions,
    );
  }
}

String? parseAndCheckEmpty(String? jsonString) {
  try {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    final decoded = json.decode(jsonString);

    if (decoded is Map) {
      return decoded.isNotEmpty ? jsonString : null;
    } else if (decoded is List) {
      return decoded.isNotEmpty ? jsonString : null;
    }
    return jsonString;
  } catch (e) {
    return null;
  }
}
