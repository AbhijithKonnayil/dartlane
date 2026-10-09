import 'dart:async';
import 'dart:convert';

import 'package:dartlane_core/testing.dart';
import 'package:http/http.dart';

/// The address the update check asks.
const dartlaneUrl = 'https://pub.dev/api/packages/dartlane';

/// Makes [http] answer the way pub.dev does when [version] is the newest.
void stubLatest(FakeHttp http, String version) => http.stub(
  'GET $dartlaneUrl',
  body: jsonEncode({
    'name': 'dartlane',
    'latest': {'version': version},
  }),
);

/// A client whose requests never finish, to test timeouts.
class HangingClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) =>
      Completer<StreamedResponse>().future;
}
