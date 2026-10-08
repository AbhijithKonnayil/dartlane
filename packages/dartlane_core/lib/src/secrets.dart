import 'dart:io';

import 'package:dartlane_core/src/lane_error.dart';
import 'package:dartlane_core/src/lane_logger.dart';

/// Where secret values come from.
///
/// Implement this to read secrets from somewhere else, such as a keychain or a
/// secret manager, and pass it to `LaneContext`. [EnvSecretsProvider] is the
/// default.
// ignore: one_member_abstracts
abstract interface class SecretsProvider {
  /// The value of the secret [name], or null if there is none.
  String? read(String name);
}

/// Reads secrets from environment variables, then from a `.env` file.
///
/// An environment variable wins over the same name in the file. The file is
/// optional and is read on first use. It holds `NAME=value` lines; blank lines
/// and lines starting with `#` are skipped, a leading `export ` is allowed, and
/// a value may be wrapped in single or double quotes. There is no variable
/// expansion.
class EnvSecretsProvider implements SecretsProvider {
  /// Creates a provider over [env] and the file at [dotEnvPath].
  ///
  /// The file path is relative to the working directory.
  EnvSecretsProvider(this.env, {this.dotEnvPath = '.env'});

  /// The environment variables, which take precedence.
  final Map<String, String> env;

  /// The `.env` file to read, or null to read none. A missing file is ignored.
  final String? dotEnvPath;

  Map<String, String>? _file;

  @override
  String? read(String name) => env[name] ?? (_file ??= _load())[name];

  Map<String, String> _load() {
    final path = dotEnvPath;
    if (path == null) return const {};
    final file = File(path);
    if (!file.existsSync()) return const {};
    return parseDotEnv(file.readAsStringSync());
  }
}

/// Parses the text of a `.env` file into a map. See [EnvSecretsProvider] for
/// the accepted syntax.
Map<String, String> parseDotEnv(String source) {
  final values = <String, String>{};
  for (var line in source.split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

/// Reads secrets for a lane and keeps them out of the log.
///
/// Every value returned by [read] or [require] is registered with the logger,
/// which replaces it with `***` in everything it prints from then on.
///
/// Masking only covers values read through this class. A secret taken from
/// the context's `env` directly, or one a command prints that was never read
/// here, is not masked. Masking also matches the exact text: a transformed
/// value, such as a base64 encoded one, is not recognised.
class LaneSecrets {
  /// Creates secrets backed by a provider that mask through a logger.
  LaneSecrets(this._provider, this._logger);

  final SecretsProvider _provider;
  final LaneLogger _logger;

  /// The secret [name], or null if it is not set or is empty.
  String? read(String name) {
    final value = _provider.read(name);
    if (value == null || value.isEmpty) return null;
    _logger.mask(value);
    return value;
  }

  /// The secret [name]. Throws a [UserError] if it is not set.
  String require(String name) =>
      read(name) ??
      (throw UserError(
        'Missing secret $name.',
        hint: 'Set the $name environment variable or add it to .env.',
      ));
}
