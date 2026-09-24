import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show storage;
import 'device.dart';

/// Which device folders show under "Fotos" — by default the camera, like Google Photos — and
/// which ones the library hides (D-48). Folders are their relative path, e.g. "DCIM/Camera/".
const _photosKey = 'photoFolders'; // persisted: do not rename
const _hiddenKey = 'hiddenFolders'; // persisted: do not rename
const defaultPhotoFolders = {'DCIM/Camera/'};

Future<Set<String>> _read(String key, Set<String> fallback) async {
  final v = await storage.read(key: key);
  return v == null
      ? {...fallback}
      : {for (final f in jsonDecode(v)) f as String};
}

Future<void> _write(String key, Set<String> folders) =>
    storage.write(key: key, value: jsonEncode([...folders]));

Future<Set<String>> photoFolders() => _read(_photosKey, defaultPhotoFolders);
Future<Set<String>> hiddenFolders() => _read(_hiddenKey, const {});

/// A folder's relative path, from its newest photo (photo_manager doesn't give it for the folder).
Future<String?> folderPath(AssetPathEntity folder) async =>
    (await folder.getAssetListRange(
      start: 0,
      end: 1,
    )).firstOrNull?.relativePath;

/// The device folders with their paths, newest first.
Future<List<(AssetPathEntity, String)>> foldersWithPaths() async => [
  for (final f in await deviceFolders())
    ?switch (await folderPath(f)) {
      final p? => (f, p),
      null => null,
    },
];

/// Settings → device folders: which ones show under "Fotos", which ones the library hides.
class FolderSettings extends StatefulWidget {
  const FolderSettings({super.key});

  @override
  State<FolderSettings> createState() => _FolderSettingsState();
}

class _FolderSettingsState extends State<FolderSettings> {
  late final _loaded = _load();

  Future<(List<(AssetPathEntity, String)>, Set<String>, Set<String>)>
  _load() async =>
      (await foldersWithPaths(), await photoFolders(), await hiddenFolders());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return FutureBuilder(
      future: _loaded,
      builder: (context, s) {
        final data = s.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (folders, inPhotos, hidden) = data;
        Widget header(String title, String hint) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(title, style: text.titleSmall),
              Text(hint, style: text.bodyMedium),
            ],
          ),
        );
        Widget check(
          String key,
          Set<String> set,
          AssetPathEntity f,
          String p,
        ) => CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(f.name),
          subtitle: Text(p),
          value: set.contains(p),
          onChanged: (on) {
            setState(() {
              on == true ? set.add(p) : set.remove(p);
            });
            _write(key, set);
          },
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(l.foldersInPhotos, l.foldersInPhotosHint),
            for (final (f, p) in folders) check(_photosKey, inPhotos, f, p),
            header(l.foldersHidden, l.foldersHiddenHint),
            for (final (f, p) in folders) check(_hiddenKey, hidden, f, p),
          ],
        );
      },
    );
  }
}
