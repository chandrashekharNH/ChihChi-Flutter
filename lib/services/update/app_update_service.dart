import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AvailableUpdate {
  const AvailableUpdate(this.version, this.storeURL);
  final String version;
  final Uri storeURL;

  @override
  bool operator ==(Object other) => other is AvailableUpdate && other.version == version && other.storeURL == storeURL;
  @override
  int get hashCode => Object.hash(version, storeURL);
}

typedef UpdateFetch = Future<String> Function(Uri url);

/// Asks the store whether a newer ChihChi is available. This is the app's only network use: it
/// sends just the app id to Apple's public lookup, and when there is no connection it fails
/// quietly so the games keep working fully offline. Google Play has no public lookup, so on
/// Android the Play Store's own update prompts are relied on instead.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({UpdateFetch? fetch}) : _fetch = fetch ?? _fetchFromAppStore;

  /// Don't ask the store more often than this (e.g. every time the app is reopened).
  static const minimumCheckInterval = Duration(hours: 6);

  final UpdateFetch _fetch;
  AvailableUpdate? availableUpdate;
  bool _isChecking = false;
  DateTime? _lastCheck;

  Future<void> checkForUpdate([DateTime? now]) async {
    if (kIsWeb || !Platform.isIOS) return;
    final time = now ?? DateTime.now();
    if (_isChecking) return;
    if (_lastCheck != null && time.difference(_lastCheck!) < minimumCheckInterval) return;
    _isChecking = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final region = ui.PlatformDispatcher.instance.locale.countryCode;
      final url = lookupURL(info.packageName, region);
      final body = await _fetch(url);
      _lastCheck = time;
      final systemVersion = RegExp(r'\d+(\.\d+)*').firstMatch(Platform.operatingSystemVersion)?.group(0) ?? '0';
      availableUpdate = update(body, info.version, systemVersion);
      notifyListeners();
    } catch (_) {
      // Offline or the store is unreachable: nothing to show, try again next time.
    } finally {
      _isChecking = false;
    }
  }

  static Uri lookupURL(String bundleID, String? region) => Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': bundleID,
        if (region != null && region.isNotEmpty) 'country': region.toLowerCase(),
      });

  /// The store's version when it is newer than ours and supports this device's system version.
  static AvailableUpdate? update(String body, String currentVersion, String systemVersion) {
    try {
      final results = (jsonDecode(body) as Map<String, dynamic>)['results'] as List;
      if (results.isEmpty) return null;
      final app = results.first as Map<String, dynamic>;
      final version = app['version'] as String;
      if (!isVersionNewer(version, currentVersion)) return null;
      final minimumOS = app['minimumOsVersion'] as String?;
      if (minimumOS != null && isVersionNewer(minimumOS, systemVersion)) return null;
      return AvailableUpdate(version, Uri.parse('itms-apps://itunes.apple.com/app/id${app['trackId']}'));
    } catch (_) {
      return null;
    }
  }

  /// Compares dotted versions numerically, so "1.10" is newer than "1.9".
  static bool isVersionNewer(String candidate, String current) {
    List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<String> _fetchFromAppStore(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('store lookup ${response.statusCode}');
    return response.body;
  }
}
