import 'package:dartlane_core/src/lane_context.dart';
import 'package:dartlane_core/src/secrets.dart';
import 'package:dartlane_core/src/testing/fake_http.dart';
import 'package:dartlane_core/src/testing/fake_lane_logger.dart';
import 'package:dartlane_core/src/testing/fake_lane_shell.dart';

/// A [LaneContext] wired to fakes, for testing lanes and actions.
///
/// Nothing runs, nothing touches the network and nothing is printed. Set up
/// answers on [shell] and [http], run the lane or action, then check what it
/// did through [shell], [http] and [logger].
class FakeLaneContext extends LaneContext {
  /// Creates a context with fresh fakes.
  ///
  /// [env] defaults to an empty environment rather than the real one, so tests
  /// do not depend on the machine they run on.
  FakeLaneContext({
    List<String> args = const [],
    Map<String, String> env = const {},
    bool dryRun = false,
    bool verbose = false,
  }) : this._(
         args: args,
         env: env,
         dryRun: dryRun,
         shell: FakeLaneShell(),
         http: FakeHttp(dryRun: dryRun),
         logger: FakeLaneLogger(verbose: verbose),
         secretsProvider: EnvSecretsProvider(env, dotEnvPath: null),
       );

  FakeLaneContext._({
    required List<String> args,
    required super.env,
    required super.dryRun,
    required FakeLaneShell shell,
    required FakeHttp http,
    required FakeLaneLogger logger,
    required SecretsProvider secretsProvider,
  }) : _shell = shell,
       _http = http,
       _logger = logger,
       super(
         args: args,
         shell: shell,
         http: http,
         logger: logger,
         secretsProvider: secretsProvider,
       );

  final FakeLaneShell _shell;
  final FakeHttp _http;
  final FakeLaneLogger _logger;

  @override
  FakeLaneShell get shell => _shell;

  @override
  FakeHttp get http => _http;

  @override
  FakeLaneLogger get logger => _logger;
}
