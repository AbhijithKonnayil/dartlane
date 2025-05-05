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
  static const UPLOAD_POLLING_INTERVAL_SECONDS = 5;
  static const UPLOAD_MAX_POLLING_RETRIES = 60;

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
      final binaryType = appDistHelper.binaryTypeFromPath(binaryPath);
      if (binaryType != ExecutableType.apk) {
        throw DException(
          Messages.ONLY_APK_SUPPORTED_FOR_NOW,
          title: 'Unsupported File Type',
        );
      }
      if (binaryType == ExecutableType.appbundle) {
        validateAabSetup();
        getAabInfo();
      }
      final serviceCredentialsFilePath = getServiceAccountFilePath(params);
      _logger.info('Using Service Account at file $serviceCredentialsFilePath');
      // Obtain authenticated HTTP client
      final client = await getAuthenticatedClient(serviceCredentialsFilePath);
      final operation = await upload(
        appName: appName,
        binaryPath: binaryPath,
        client: client,
      );
      var release = await pollUploadReleaseOperation(
        operation: operation,
        client: client,
        binaryType: binaryType,
      );
      final releaseNotes = getReleaseNotes(params);
      release = await updateReleaseNotes(
        client: client,
        release: release,
        releaseNotes: releaseNotes,
      );
      await distributeRelease(
        client: client,
        params: params,
        release: release,
      );
      _logger.success(
        '🎉 App Distribution upload finished successfully.',
      );
      if (release.firebaseConsoleUri != null) {
        _logger.info(
          '${Messages.VIEW_RELEASE_IN_CONSOLE}: ${release.firebaseConsoleUri}',
        );
      }
      if (release.testingUri != null) {
        _logger.info(
          '${Messages.SHARE_RELEASE_WITH_TESTERS}: ${release.testingUri}',
        );
      }
      if (release.binaryDownloadUri != null) {
        _logger.info(
          '${Messages.DOWNLOAD_BINARY_LINK}: ${release.binaryDownloadUri}',
        );
      }
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
    required auth.AutoRefreshingAuthClient client,
  }) async {
    try {
      final binaryFile = File(binaryPath);
      final binaryFileLength = binaryFile.lengthSync();
      _logger.info(
        'Uploading binary at path `$binaryPath` to Firebase App Distribution',
      );
      final operation = await FirebaseDistApi(client).media.upload(
            GoogleFirebaseAppdistroV1UploadReleaseRequest(),
            appName,
            uploadMedia: Media(
              http.ByteStream.fromBytes(binaryFile.readAsBytesSync()),
              binaryFileLength,
              //contentType: 'application/vnd.android.package-archive'
            ),
          );
      return operation;
    } catch (e) {
      rethrow;
    }
  }

  Future<GoogleFirebaseAppdistroV1Release> pollUploadReleaseOperation({
    required auth.AutoRefreshingAuthClient client,
    required GoogleLongrunningOperation operation,
    required ExecutableType binaryType,
  }) async {
    _logger.info('Validating upload...');
    for (var i = 0; i < UPLOAD_MAX_POLLING_RETRIES; i++) {
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(
        const Duration(seconds: UPLOAD_POLLING_INTERVAL_SECONDS),
      );
      operation = await FirebaseDistApi(client)
          .projects
          .apps
          .releases
          .operations
          .get(operation.name!);

      if ((operation.done ?? false) &&
          operation.response != null &&
          operation.response?['release'] != null) {
        final release = extractRelease(operation);

        switch (operation.response!['result']) {
          case 'RELEASE_UPDATED':
            _logger.success(
              // ignore: lines_longer_than_80_chars
              '✅ Uploaded ${binaryType.name} successfully; updated provisioning profile of existing release ${releaseVersion(release)}.',
            );
          case 'RELEASE_UNMODIFIED':
            _logger.success(
              // ignore: lines_longer_than_80_chars
              '✅ The same ${binaryType.name} was found in release ${releaseVersion(release)} with no changes, skipping.',
            );
          case 'RELEASE_CREATED':
            _logger.success(
              // ignore: lines_longer_than_80_chars
              '✅ Uploaded ${binaryType.name} successfully and created release ${releaseVersion(release)}.',
            );
          default:
            _logger.err(
              // ignore: lines_longer_than_80_chars
              '❌ Failed to upload ${binaryType.name}, please try again.',
            );
        }

        return release;
      } else if (operation.done != true) {
        continue;
      } else {
        if (operation.error != null && operation.error!.message != null) {
          throw DException(
            operation.error!.message!,
            title:
                // ignore: lines_longer_than_80_chars
                'App Distribution halted because it had a problem uploading the ${binaryType.name}."',
          );
        } else {
          throw DException(
            // ignore: lines_longer_than_80_chars
            'App Distribution halted because it had a problem uploading the ${binaryType.name}."',
          );
        }
      }
    }

    if (operation.done != true ||
        operation.response == null ||
        operation.response!['release'] == null) {
      throw Exception(
        // ignore: lines_longer_than_80_chars
        'It took longer than expected to process your ${binaryType.name}, please try again.',
      );
    }

    return extractRelease(operation);
  }

  GoogleFirebaseAppdistroV1Release extractRelease(
    GoogleLongrunningOperation operation,
  ) {
    if (operation.response == null) {
      throw DException('No response found in operation');
    }
    if (operation.response!['release'] == null) {
      throw DException('No release found in operation response');
    }
    if (operation.response!['release'] is! Map<String, dynamic>) {
      throw DException('Release is not a map');
    }
    return GoogleFirebaseAppdistroV1Release.fromJson(
      operation.response!['release']! as Map<String, dynamic>,
    );
  }

  String releaseVersion(GoogleFirebaseAppdistroV1Release release) {
    if (release.displayVersion != null && release.buildVersion != null) {
      return '${release.displayVersion} (${release.buildVersion})';
    } else if (release.displayVersion != null) {
      return release.displayVersion!;
    } else {
      return release.buildVersion!;
    }
  }

  String getBinaryPath(
    FlutterPlatform platform,
    Map<String, String> params,
  ) {
    try {
      late String binaryPath;
      if (platform == FlutterPlatform.ios) {
        binaryPath = params[Keys.APK_PATH] ??
            Directory('.')
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('.ipa'))
                .last
                .path;
      } else if (platform == FlutterPlatform.android) {
        if (params[Keys.APK_PATH] != null ||
            params[Keys.ANDROID_ARTIFACT_PATH] != null) {
          binaryPath =
              (params[Keys.APK_PATH] ?? params[Keys.ANDROID_ARTIFACT_PATH])!;
        } else if (params[Keys.ANDROID_ARTIFACT_TYPE] == 'AAB') {
          binaryPath = Directory(
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
          binaryPath = Directory(
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
      if (binaryPath.isEmpty || !File(binaryPath).existsSync()) {
        throw PathNotFoundException(
          binaryPath,
          const OSError(),
        );
      }
      return binaryPath;
    } on PathNotFoundException catch (e) {
      throw DException(
        'Binary not found at path: ${e.path}',
        title: Messages.BINARY_PATH_NOT_FOUND_TITLE,
      );
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

  void validateAabSetup() {
    // TODO(abhijithkonnayil): Implement AAB setup validation
  }
  void getAabInfo() {
    // TODO(abhijithkonnayil): Implement AAB info retrieval
  }

  String? getReleaseNotes(Map<String, String> params) {
    final (releaseNotes, isFromFile) = appDistHelper.getValueFromValueOrFile(
      filePath: params[Keys.RELEASE_NOTES_FILE_PATH],
      value: params[Keys.RELEASE_NOTES],
    );
    return releaseNotes;
  }

  Future<GoogleFirebaseAppdistroV1Release> updateReleaseNotes({
    required String? releaseNotes,
    required GoogleFirebaseAppdistroV1Release release,
    required auth.AutoRefreshingAuthClient client,
  }) async {
    if (releaseNotes.hasValue()) {
      _logger.info('📜 Setting release notes.');
      release.releaseNotes = GoogleFirebaseAppdistroV1ReleaseNotes(
        text: releaseNotes,
      );
      return updateRelease(
        client,
        release,
      );
    } else {
      _logger.info(Messages.NO_RELEASE_NOTES_MESSAGE);
    }
    return release;
  }

  Future<GoogleFirebaseAppdistroV1Release> updateRelease(
    auth.AutoRefreshingAuthClient client,
    GoogleFirebaseAppdistroV1Release release,
  ) async {
    try {
      return await FirebaseDistApi(client).projects.apps.releases.patch(
            release,
            release.name!,
            //updateMask: 'releaseNotes.text',
          );
    } catch (e) {
      rethrow;
    }
  }

  Future<GoogleFirebaseAppdistroV1DistributeReleaseResponse> distributeRelease({
    required auth.AutoRefreshingAuthClient client,
    required Map<String, String> params,
    required GoogleFirebaseAppdistroV1Release release,
  }) async {
    try {
      final (testers, isTestersFromFile) =
          appDistHelper.getValueFromValueOrFile(
        value: params[Keys.TESTERS],
        filePath: params[Keys.TESTERS_FILE_PATH],
      );
      final (groups, isGroupsFromFile) = appDistHelper.getValueFromValueOrFile(
        value: params[Keys.GROUPS],
        filePath: params[Keys.GROUPS_FILE_PATH],
      );
      final emails = testers.stringToArray(
        delimiter: isTestersFromFile ? '\n' : ',',
      );
      final groupAliases = groups.stringToArray(
        delimiter: isGroupsFromFile ? '\n' : ',',
      );
      if (emails.isNotEmpty || groupAliases.isNotEmpty) {
        _logger.info(Messages.DISTRIBUTING_RELEASE);
        return await FirebaseDistApi(client).projects.apps.releases.distribute(
              GoogleFirebaseAppdistroV1DistributeReleaseRequest(
                testerEmails: emails,
                groupAliases: groupAliases,
              ),
              release.name!,
            );
      } else {
        throw DException(
          Messages.NO_TESTERS_OR_GROUPS,
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
