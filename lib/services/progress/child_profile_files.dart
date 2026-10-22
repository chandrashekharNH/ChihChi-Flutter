import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where each child's own files live (name recording, character, Turbo Race and AR Explorer
/// progress). The first child keeps the base folder; every child added later gets their own.
class ChildProfileFiles {
  static const _activeKey = 'activeChildProfileID';
  static String _activeID = '';
  static Directory? _base;

  /// Called once at start-up.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeID = prefs.getString(_activeKey) ?? '';
    final support = await getApplicationSupportDirectory();
    _base = Directory('${support.path}/ChihChi');
    await _base!.create(recursive: true);
  }

  /// The child who is playing. Empty is the first child, from before profiles existed.
  static String get activeID => _activeID;

  static Future<void> setActiveID(String id) async {
    _activeID = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  static Directory get baseDirectory => _base ?? Directory.systemTemp;

  static Directory directory(String id) =>
      id.isEmpty ? baseDirectory : Directory('${baseDirectory.path}/Profiles/$id');

  /// The folder of the child who is playing now.
  static Directory get activeDirectory => directory(_activeID);

  /// Erases one child's files. For the first child that is everything in the base folder except
  /// the other children's folders.
  static Future<void> deleteFiles(String id) async {
    try {
      if (id.isNotEmpty) {
        await directory(id).delete(recursive: true);
        return;
      }
      for (final item in baseDirectory.listSync()) {
        final name = item.path.split('/').last;
        if (name != 'Profiles' && name != 'profiles.json') await item.delete(recursive: true);
      }
    } catch (_) {}
  }
}
