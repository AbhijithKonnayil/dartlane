import 'dart:convert';

import 'package:http/http.dart';

/// A request that a [FakeHttp] received.
class RecordedRequest {
  /// Creates a record of a request.
  const RecordedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  /// The HTTP method, for example `POST`.
  final String method;

  /// The full URL.
  final Uri url;

  /// The request headers.
  final Map<String, String> headers;

  /// The request body decoded as UTF-8.
  final String body;

  /// The request as `METHOD url`, the form [FakeHttp.stub] matches on.
  String get summary => '$method $url';
}

class _Stub {
  const _Stub(this.status, this.body, this.headers);

  final int status;
  final String body;
  final Map<String, String> headers;
}

/// A `package:http` [Client] that makes no network calls. It records every
/// request and answers with responses you set up.
///
/// A request with no stub throws a [StateError], so a test fails loudly if a
/// lane calls a URL you did not expect.
class FakeHttp extends BaseClient {
  /// Creates a fake client.
  FakeHttp();

  final List<RecordedRequest> _requests = [];
  final Map<String, _Stub> _stubs = {};

  /// Every request received so far, in order.
  List<RecordedRequest> get requests => List.unmodifiable(_requests);

  /// Makes the request `METHOD url` (for example
  /// `POST https://example.com/upload`) answer with [status], [body] and
  /// [headers]. A later stub for the same request wins.
  void stub(
    String request, {
    int status = 200,
    String body = '',
    Map<String, String> headers = const {},
  }) {
    _stubs[request] = _Stub(status, body, headers);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final recorded = RecordedRequest(
      method: request.method,
      url: request.url,
      headers: Map.of(request.headers),
      body: utf8.decode(bytes, allowMalformed: true),
    );
    _requests.add(recorded);

    final stub = _stubs[recorded.summary];
    if (stub == null) {
      throw StateError('FakeHttp: no stub for ${recorded.summary}');
    }
    return StreamedResponse(
      Stream.value(utf8.encode(stub.body)),
      stub.status,
      headers: stub.headers,
      request: request,
    );
  }
}
