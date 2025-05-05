// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars

class Keys {
  static const String GOOGLE_APPLICATION_CREDENTIALS =
      'GOOGLE_APPLICATION_CREDENTIALS';
  static const String SERVICE_ACCOUNT_FILE_PATH = 'serviceCredentialsFilePath';
  static const String UPLOAD_TIMEOUT = 'uploadTimeout';
  static const String IPA_PATH = 'ipa_path';
  static const String APK_PATH = 'apk_path';
  static const String ANDROID_ARTIFACT_PATH = 'android_artifact_path';
  static const String ANDROID_ARTIFACT_TYPE = 'android_artifact_type';
  static const String RELEASE_NOTES = 'release_notes';
  static const String RELEASE_NOTES_FILE_PATH = 'release_notes_file_path';
}

class Messages {
  static const String SERVICE_ACCOUNT_NOT_FOUND_TITLE =
      'Service account file path not found';
  static const String SERVICE_ACCOUNT_NOT_FOUND_MESSAGE =
      'Provide a valid file path in the `serviceCredentialsFilePath` lane argument or set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to the service account key file.';
  static const String APP_ID_NOT_FOUND =
      'Missing app id. Please check that the app parameter is set and try again.';
  static const String UNSUPPORTED_FILE_FORMAT =
      'Unsupported distribution file format, should be .ipa, .apk, or .aab';

  static const String BINARY_PATH_NOT_FOUND_TITLE = 'Binary path not found';
  static const String ONLY_APK_SUPPORTED_FOR_NOW =
      'At present,only APK files are supported for upload to Firebase App Distribution.';
  static const String NO_RELEASE_NOTES_MESSAGE =
      '⏩ No release notes passed in. Skipping this step.';
}
