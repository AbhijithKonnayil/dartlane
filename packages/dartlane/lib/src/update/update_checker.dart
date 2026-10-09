import 'package:dartlane/src/update/pub_dev_client.dart';
import 'package:dartlane/src/update/update_cache.dart';
import 'package:http/http.dart';
import 'package:pub_semver/pub_semver.dart';

/// The name of this package on pub.dev.
const dartlanePackageName = 'dartlane';

/// Finds out whether a newer Dartlane has been published, and tells the user.
class UpdateChecker {
  /// Creates a checker for the installed [currentVersion].
  ///
  /// [clientFactory] makes the HTTP client for one check, which is closed
  /// afterwards. [cache] remembers results for [cacheLifetime]. [now] can be
  /// set in tests.
  UpdateChecker({
    required this.currentVersion,
    required this.clientFactory,
    this.cache,
    this.cacheLifetime = const Duration(days: 1),
    this.timeout = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The version that is installed.
  final Version currentVersion;

  /// Makes the HTTP client for one check.
  final Client Function() clientFactory;

  /// Where the last result is kept. Without one, every check asks pub.dev.
  final UpdateCache? cache;

  /// How long a cached result is used before pub.dev is asked again.
  final Duration cacheLifetime;

  /// How long a check waits for pub.dev.
  final Duration timeout;

  final DateTime Function() _now;

  /// The newest published version, asking pub.dev now.
  ///
  /// Null if the package is not on pub.dev. Throws an [UpdateCheckException] if
  /// pub.dev cannot be asked.
  Future<Version?> latestVersion() async {
    final client = clientFactory();
    try {
      return await PubDevClient(client, timeout: timeout).latestVersion(
        dartlanePackageName,
      );
    } finally {
      client.close();
    }
  }

  /// The published version if it is newer than [currentVersion], otherwise
  /// null.
  ///
  /// Uses the cached result when it is recent, and records what it finds so
  /// the next check within [cacheLifetime] makes no request. It never throws:
  /// a check that cannot be made is just no news, and is remembered too, so a
  /// computer that is offline does not wait for a timeout on every command.
  Future<Version?> newerVersion() async {
    final cached = cache?.read();
    if (cached != null && _now().difference(cached.checkedAt) < cacheLifetime) {
      return _newerThanCurrent(cached.latest);
    }

    Version? latest;
    try {
      latest = await latestVersion();
    } on Object {
      latest = null;
    }
    cache?.write(UpdateCheckRecord(checkedAt: _now(), latest: latest));
    return _newerThanCurrent(latest);
  }

  /// The text to show when a newer version exists, otherwise null.
  Future<String?> notice() async {
    final newer = await newerVersion();
    if (newer == null) return null;
    return 'Update available! $currentVersion → $newer\n'
        'Run `dartlane update` to install it.';
  }

  Version? _newerThanCurrent(Version? latest) =>
      latest != null && latest > currentVersion ? latest : null;
}
