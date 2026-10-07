import 'package:dartlane_core/src/lane_error.dart';

/// The arguments given to a lane, parsed from the command line.
///
/// Options are written `--key=value`, `--flag` or `--no-flag`:
///
/// ```text
/// dartlane run beta --flavor=prod --testers=a@x.com,b@y.com --no-notify
/// ```
///
/// ```dart
/// final flavor = ctx.args.string('flavor');           // 'prod'
/// final testers = ctx.args.list('testers');           // ['a@x.com', 'b@y.com']
/// final notify = ctx.args.flag('notify');             // false
/// final app = ctx.args.requireString('app');          // UserError if missing
/// ```
///
/// Rules:
///  * Only the first `=` splits, so a value can contain `=`, `:`, `,` and `@`,
///    for example `--url=https://x.test/a?b=c` or `--file=C:\app.apk`.
///  * A value is never taken from the next argument. `--flavor prod` is the
///    flag `--flavor` and the positional argument `prod`, which avoids guessing
///    whether `--flag value` is an option with a value or a flag followed by a
///    positional argument.
///  * Anything that does not start with `--` is positional, including `-x` and
///    the old `key:value` form. Everything after a bare `--` is positional.
///  * An option given more than once keeps every value; [string] returns the
///    last one and [list] returns them all.
///
/// Parsing never fails. Mistakes such as a missing required option or a value
/// that is not a number surface as a [UserError] when the value is read.
class LaneArgs {
  LaneArgs._(this.raw, this.positional, this._options);

  /// Parses [arguments], the words after the lane name.
  factory LaneArgs.parse(Iterable<String> arguments) {
    final raw = List<String>.unmodifiable(arguments);
    final positional = <String>[];
    final options = <String, List<String>>{};

    void add(String name, String value) => (options[name] ??= []).add(value);

    var onlyPositional = false;
    for (final argument in raw) {
      if (onlyPositional || !argument.startsWith('--')) {
        positional.add(argument);
      } else if (argument == '--') {
        onlyPositional = true;
      } else {
        final body = argument.substring(2);
        final equals = body.indexOf('=');
        if (equals == 0) {
          // `--=value` has no name.
          positional.add(argument);
        } else if (equals > 0) {
          add(body.substring(0, equals), body.substring(equals + 1));
        } else if (body.startsWith('no-') && body.length > 3) {
          add(body.substring(3), 'false');
        } else {
          add(body, 'true');
        }
      }
    }

    return LaneArgs._(
      raw,
      List<String>.unmodifiable(positional),
      options,
    );
  }

  /// No arguments.
  static final empty = LaneArgs.parse(const []);

  /// Every argument exactly as it was given, in order.
  final List<String> raw;

  /// The arguments that are not options, in order.
  final List<String> positional;

  final Map<String, List<String>> _options;

  /// The names of all options that were given, without the `--`.
  Iterable<String> get names => _options.keys;

  /// Whether the option [name] was given, with or without a value.
  bool has(String name) => _options.containsKey(name);

  /// The value of the option [name], or null if it was not given.
  ///
  /// If the option was given more than once, this is the last value. The value
  /// is returned as written, commas included. `--flag` reads as `'true'`.
  String? string(String name) => _options[name]?.last;

  /// Like [string], but throws a [UserError] if the option is missing or
  /// empty.
  String requireString(String name) {
    final value = string(name);
    if (value == null || value.isEmpty) throw _missing(name);
    return value;
  }

  /// The value of [name] as a whole number, or null if it was not given.
  ///
  /// Throws a [UserError] if it is not a whole number.
  int? integer(String name) {
    final value = string(name);
    if (value == null) return null;
    return int.tryParse(value) ??
        (throw UserError(
          '--$name must be a whole number, but got "$value".',
          hint: 'For example --$name=3.',
        ));
  }

  /// Like [integer], but throws a [UserError] if the option is missing.
  int requireInteger(String name) => integer(name) ?? (throw _missing(name));

  /// Whether the flag [name] is on.
  ///
  /// `--name` and `--name=true` are on, `--no-name` and `--name=false` are
  /// off. Returns [defaultValue] if the flag was not given. Throws a
  /// [UserError] for any other value.
  bool flag(String name, {bool defaultValue = false}) {
    final value = string(name);
    if (value == null) return defaultValue;
    return switch (value.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => throw UserError(
        '--$name must be true or false, but got "$value".',
        hint: 'Use --$name or --no-$name.',
      ),
    };
  }

  /// Every value given for the option [name], in order. Empty if it was not
  /// given.
  ///
  /// By default each value is also split at commas, so `--testers=a,b` and
  /// `--testers=a --testers=b` both give `['a', 'b']`. Items are trimmed and
  /// empty items dropped. Pass `commaSeparated: false` when the values may
  /// contain commas themselves, such as `--dart-define=URL=https://x?a=1,2`.
  List<String> list(String name, {bool commaSeparated = true}) {
    final values = _options[name] ?? const <String>[];
    if (!commaSeparated) return List.of(values);
    return [
      for (final value in values)
        for (final item in value.split(','))
          if (item.trim().isNotEmpty) item.trim(),
    ];
  }

  /// Throws a [UserError] if an option other than [known] was given.
  ///
  /// Call it at the start of a lane to catch typos such as `--flavour=prod`,
  /// which would otherwise be ignored without a word.
  void expectOnly(Iterable<String> known) {
    final allowed = known.toSet();
    final unknown = names.where((name) => !allowed.contains(name)).toList();
    if (unknown.isEmpty) return;

    final shown = unknown.map((name) => '--$name').join(', ');
    final options = allowed.toList()..sort();
    throw UserError(
      unknown.length == 1
          ? 'Unknown option $shown.'
          : 'Unknown options $shown.',
      hint: options.isEmpty
          ? 'This lane takes no options.'
          : 'Known options: ${options.map((name) => '--$name').join(', ')}.',
    );
  }

  UserError _missing(String name) => UserError(
    'Missing required option --$name.',
    hint: 'Pass --$name=<value>.',
  );

  @override
  String toString() => 'LaneArgs(${raw.join(' ')})';
}
