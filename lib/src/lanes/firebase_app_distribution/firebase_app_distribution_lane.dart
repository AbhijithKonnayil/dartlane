import 'dart:io';

import 'package:dartlane/src/core/datatype_utils.dart';
import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/exception.dart';
import 'package:dartlane/src/core/utils.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/constants.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/firebase_app_distribution_helper.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/firebase_dist_api.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:googleapis/firebaseappdistribution/v1.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class FirebaseAppDistributionLane extends Lane {
  final DLogger _logger = DLogger();
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
      final platform = appDistHelper.platformFromAppId(appId);
      final timeout = params.getValue(
        Keys.UPLOAD_TIMEOUT,
        defaultVale: DEFAULT_UPLOAD_TIMEOUT_SECONDS.toString(),
      );
      final binaryPath = getBinaryPath(platform, params);
      final serviceAccountFilePath = getServiceAccountFilePath(params);
      final response = await upload(
        appName: appName,
        binaryPath: binaryPath,
        serviceCredentialsFilePath: serviceAccountFilePath,
      );
    } catch (e) {
      _logger.err(e.toString());
    }
  }

  @override
  String get name => 'firebaseAppDistribution';

  Future<auth.AutoRefreshingAuthClient> getAuthenticatedClient(
    String serviceCredentialsFilePath,
  ) async {
    final serviceAccount = File(serviceCredentialsFilePath).readAsStringSync();
    final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccount);

    final scopes = [FirebaseAppDistributionApi.cloudPlatformScope];

    final client = await auth.clientViaServiceAccount(credentials, scopes);
    return client;
  }

  Future<GoogleLongrunningOperation> upload({
    required String appName,
    required String binaryPath,
    required String serviceCredentialsFilePath,
  }) async {
    try {
      final binaryFile = File(binaryPath);
      final binaryFileLength = binaryFile.lengthSync();
      _logger.info('Using Service Account at file $serviceCredentialsFilePath');
      // Obtain authenticated HTTP client
      final client = await getAuthenticatedClient(serviceCredentialsFilePath);
      _logger.info(
          'Uploading binary at path `$binaryPath` to Firebase App Distribution');
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

  String getBinaryPath(
    FlutterPlatform platform,
    Map<String, String> params,
  ) {
    try {
      if (platform == FlutterPlatform.ios) {
        return params[Keys.APK_PATH] ??
            Directory('.')
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('.ipa'))
                .last
                .path;
      } else if (platform == FlutterPlatform.android) {
        if (params[Keys.APK_PATH] != null ||
            params[Keys.ANDROID_ARTIFACT_PATH] != null) {
          return (params[Keys.APK_PATH] ?? params[Keys.ANDROID_ARTIFACT_PATH])!;
        } else if (params[Keys.ANDROID_ARTIFACT_TYPE] == 'AAB') {
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
      throw DException('Unknown Platform');
    } catch (e) {
      rethrow;
    }
  }

  String getServiceAccountFilePath(Map<String, String> params) {
    try {
      final serviceAccountFilePath = params.getValue(
        Keys.SERVICE_ACCOUNT_FILE_PATH,
        defaultVale: Utils.getEnvironmentVariable(
          Keys.GOOGLE_APPLICATION_CREDENTIALS,
        ),
      );
      return serviceAccountFilePath;
    } catch (e) {
      throw DException(
        Messages.SERVICE_ACCOUNT_NOT_FOUND_MESSAGE,
        title: Messages.SERVICE_ACCOUNT_NOT_FOUND_TITLE,
      );
    }
  }
}
