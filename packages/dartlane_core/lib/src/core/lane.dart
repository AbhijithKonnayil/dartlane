import 'dart:isolate';

import 'package:dartlane_core/src/core/lane_args.dart';
import 'package:dartlane_core/src/core/lane_response.dart';
import 'package:dartlane_core/src/core/logger.dart';

import 'enums.dart';

abstract class Lane {
  static final DLogger _logger = DLogger();

  String get description;
  String get name;

  /// Executes the lane logic with the given arguments.
  ///
  /// This method is the main entry point for running lane logic. It internally
  /// calls [executeLogic] and handles the result through [_handleResponse].
  /// Any errors during execution are caught and logged.
  Future<void> execute(Map<String, String> laneArgs) async {
    try {
      final response = await executeLogic(laneArgs);
      _handleResponse(response);
    } catch (e) {
      _logger.err('Error executing $name Lane: $e');
    }
  }

  void _handleResponse(LaneResponse response) {
    switch (response.status) {
      case Status.completed:
        _logger.success('$name Lane completed successfully.');
      case Status.error:
        _logger.err('$name Lane failed with exit code $response.');
    }
  }

  /// Defines the custom logic to be executed for this lane.
  ///
  /// This method should be overridden in custom lane implementations to provide
  /// the specific logic that needs to run when the lane is executed.
  ///
  /// The [laneArgs] map contains key-value pairs passed to the lane at runtime.
  /// Use these to modify or configure the behavior of the lane execution.
  ///
  /// This method is invoked internally by the [execute] method and should
  /// return a [LaneResponse] indicating the result of the operation.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<LaneResponse<void>> executeLogic(Map<String, String> laneArgs) async {
  ///   Custom logic here
  ///   return LaneResponse.success(exitCode: 0);
  /// }
  /// ```
  ///
  /// - [laneArgs]: Runtime arguments passed to the lane.
  /// - Returns: A [LaneResponse] containing the result of the execution.
  Future<LaneResponse> executeLogic(Map<String, String> laneArgs);

  Future<LaneResponse> executeLogicT(LaneArgs args) {
    return executeLogic(args.toStringJson());
  }

  Future<void> executeAndSendStatus(SendPort mainSendPort) async {
    _logger.info('Executing $name Lane\n');
    final isolateReceivePort =
        ReceivePort()..listen((data) async {
          if (data is Map<String, Map<String, String>>) {
            if (data.containsKey('execute')) {
              final args = data['execute']!;
              try {
                final response = await executeLogic(args);
                _handleResponse(response);
              } catch (e, stackTrace) {
                _logger.err(e.toString());
                _logger.err(stackTrace.toString());
              } finally {
                mainSendPort.send(Status.completed.name);
              }
            } else {
              mainSendPort.send(Status.completed.name);
            }
          }
        });
    mainSendPort.send(isolateReceivePort.sendPort);
  }
}
