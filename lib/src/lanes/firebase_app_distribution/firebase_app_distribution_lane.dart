import 'dart:io' hide HttpClient;
import 'dart:io';

import 'package:dartlane/src/core/datatype_utils.dart';
import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/exception.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/firebase_app_distribution_helper.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/firebase_dist_api.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:googleapis/firebaseappdistribution/v1.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class FirebaseAppDistributionLane extends Lane {
  final DLogger _logger = DLogger();
  final httpClient = HttpClient();
  final appDistHelper = FirebaseAppDistributionHelper();

  static const DEFAULT_UPLOAD_TIMEOUT_SECONDS = 300;

  String? xcodeArchivePath;
  String? lanePlatform;

  @override
  String get description => 'Distribute the apk to firebase';

  @override
  Future<void> execute(Map<String, String> params) async {
    try {
      print(params);
      final appId = appDistHelper.appIdFromParams(params);
      final appName = appDistHelper.appNameFromAppId(appId!);
      final platform = platformFromAppId(appId);
      final timeout = params.getValue(
        'upload_timeout',
        defaultVale: DEFAULT_UPLOAD_TIMEOUT_SECONDS.toString(),
      );
      final binaryPath = getBinaryPath(platform, params);
      await upload(
        appName: appName,
        binaryPath: binaryPath,
      );
    } catch (e) {
      _logger.err(e.toString());
    }
  }

  @override
  String get name => 'firebaseAppDistribution';

  Future<auth.AutoRefreshingAuthClient> getAuthenticatedClient() async {
    final serviceAccount = File('service_account.json').readAsStringSync();
    final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccount);

    final scopes = [FirebaseAppDistributionApi.cloudPlatformScope];

    final client = await auth.clientViaServiceAccount(credentials, scopes);
    return client;
  }

  Future<GoogleLongrunningOperation> upload({
    required String appName,
    required String binaryPath,
  }) async {
    try {
      final binaryFile = File(binaryPath);
      final binaryFileLength = binaryFile.lengthSync();
      final serviceAccount = File('service_account.json').readAsStringSync();
      final credentials =
          auth.ServiceAccountCredentials.fromJson(serviceAccount);
      // Obtain authenticated HTTP client

      final client = await auth.clientViaServiceAccount(
        credentials,
        [FirebaseAppDistributionApi.cloudPlatformScope], // Required scope
      );
      return await FirebaseDistApi(client).media.upload(
            GoogleFirebaseAppdistroV1UploadReleaseRequest(),
            appName,
            uploadMedia: Media(
              http.ByteStream.fromBytes(binaryFile.readAsBytesSync()),
              binaryFileLength,
              //contentType: 'application/vnd.android.package-archive'
            ),
          );
    } catch (e) {
      rethrow;
    }
  }

  static FlutterPlatform platformFromAppId(String appId) {
    try {
      if (appId.contains(':ios:')) {
        return FlutterPlatform.ios;
      } else if (appId.contains(':android:')) {
        return FlutterPlatform.android;
      } else {
        throw DtException('Unknown Platform');
      }
    } catch (e) {
      rethrow;
    }
  }

  String getBinaryPath(
    FlutterPlatform platform,
    Map<String, String> params,
  ) {
    try {
      if (platform == FlutterPlatform.ios) {
        return params['ipa_path'] ??
            Directory('.')
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('.ipa'))
                .last
                .path;
      } else if (platform == FlutterPlatform.android) {
        if (params['apk_path'] != null ||
            params['android_artifact_path'] != null) {
          return (params['apk_path'] ?? params['android_artifact_path'])!;
        } else if (params['android_artifact_type'] == 'AAB') {
          return Directory(
            path.join(
              'build',
              'app',
              'outputs',
              'bundle',
              'release',
            ),
          )
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.aab'))
              .last
              .path;
        } else {
          return Directory(
            path.join(
              'build',
              'app',
              'outputs',
              'apk',
              'release',
            ),
          )
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.apk'))
              .last
              .path;
        }
      }
      throw DtException('Unknown Platform');
    } catch (e) {
      rethrow;
    }
  }
}
