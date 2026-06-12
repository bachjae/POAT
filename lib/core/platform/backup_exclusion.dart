/// iOS iCloud backup exclusion for large on-device files.
///
/// Calls `NSURLIsExcludedFromBackupKey` via a MethodChannel so the bundled
/// model file (~2.6 GB) is never uploaded to iCloud. The Android side is a
/// no-op. The call is fire-and-forget: failures are swallowed because a
/// missing iOS backup attribute is not a user-visible error.
library;

import 'dart:io';

import 'package:flutter/services.dart';

class BackupExclusion {
  static const _channel = MethodChannel('rallycoach/backup');

  /// Excludes [filePath] from iCloud backup on iOS. No-op on other platforms.
  static Future<void> excludeFromBackup(String filePath) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('excludeFromBackup', {'path': filePath});
  }
}
