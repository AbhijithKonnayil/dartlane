import 'package:http/http.dart';

/// A dry run cannot go any further.
///
/// A dry run describes the steps of a lane without running them. It stops, with
/// this, when it reaches something it cannot describe safely: an action whose
/// result it cannot make up (see `LaneAction.dryRunResult`), or a request that
/// would change something on the web. The runner prints [message], the steps
/// described so far, and exits with 0: a dry run is a best-effort preview, not
/// a check that the lane works.
class DryRunStopped implements Exception {
  /// Creates the exception with a [message] for the user.
  const DryRunStopped(this.message);

  /// Why the dry run cannot continue.
  final String message;

  @override
  String toString() => message;
}

/// The HTTP client a lane gets during a dry run.
///
/// Requests that only read (`GET` and `HEAD`) go through. Anything else would
/// change something on the web, so it stops the dry run with a
/// [DryRunStopped] before it is sent.
class DryRunClient extends BaseClient {
  /// Wraps the `inner` client.
  DryRunClient(this._inner);

  final Client _inner;

  static const _readOnly = {'GET', 'HEAD'};

  /// Throws a [DryRunStopped] unless [request] only reads.
  static void ensureReadOnly(BaseRequest request) {
    if (!_readOnly.contains(request.method)) {
      throw DryRunStopped(
        'a dry run does not send ${request.method} ${request.url}.',
      );
    }
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    ensureReadOnly(request);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
