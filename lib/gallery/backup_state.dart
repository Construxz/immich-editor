import 'dart:convert';
import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../editor/preview.dart' show rendererChannel;
import '../server/immich.dart';
import 'checksums.dart';
import 'device.dart';

/// What on the device is already backed up (D-36): [deviceOnly] lives only here (newest first),
/// [deviceBackedUp] are device photos with a counterpart on the server, [serverOnDevice] the
/// server photos that also live here.
typedef BackupState = ({
  List<AssetEntity> deviceOnly,
  Set<String> deviceBackedUp,
  Set<String> serverOnDevice,
});

const BackupState emptyBackupState = (
  deviceOnly: [],
  deviceBackedUp: {},
  serverOnDevice: {},
);

/// Whether Immich backs up the device folder [folder] (`relative_path`, e.g. "DCIM/Camera/") — a
/// guess: yes, as soon as one of its photos is on the server (D-36).
Future<bool> folderBackedUp(Immich immich, String folder) async {
  final ids = await deviceIdsIn(folder);
  final sums = await deviceChecksums();
  final found = await immich.existing({
    for (final id in ids)
      if (sums[id] != null) id: sums[id]!,
  });
  return found.isNotEmpty;
}

/// Matches the device photos against the server by checksum; computing new checksums is shown
/// by [checksumProgress]. Without permission for device photos: empty.
Future<BackupState> checkBackup(Immich immich) async {
  if (!await devicePermitted()) return emptyBackupState;
  final sums = await deviceChecksums();
  final found = await immich.existing(sums); // device ID → server ID
  final all = lastListed; // listed by the checksum pass just now
  final state = (
    deviceOnly: [
      for (final a in all)
        if (!found.containsKey(a.id)) a,
    ],
    deviceBackedUp: found.keys.toSet(),
    serverOnDevice: found.values.toSet(),
  );
  _store(state).ignore();
  return state;
}

/// The last state, stored, so the gallery shows the device photos at once and checks in the
/// background — the check takes about 2 s with 17,500 photos (D-51).
Future<File> _file() async => File(
  '${await rendererChannel.invokeMethod<String>('filesDir')}/backup.json',
);

Future<void> _store(BackupState s) async => (await _file()).writeAsString(
  jsonEncode({
    'deviceOnly': [
      for (final a in s.deviceOnly)
        [
          a.id,
          a.createDateSecond,
          a.width,
          a.height,
          a.orientation,
          a.relativePath,
        ],
    ],
    'deviceBackedUp': [...s.deviceBackedUp],
    'serverOnDevice': [...s.serverOnDevice],
  }),
);

/// The state of the last check, or [emptyBackupState] if there is none.
Future<BackupState> storedBackup() async {
  try {
    final j = jsonDecode(await (await _file()).readAsString());
    return (
      deviceOnly: [
        for (final a in j['deviceOnly'] as List)
          AssetEntity(
            id: a[0],
            typeInt: AssetType.image.index,
            createDateSecond: a[1],
            width: a[2],
            height: a[3],
            orientation: a[4],
            relativePath: a[5],
          ),
      ],
      deviceBackedUp: {for (final id in j['deviceBackedUp']) id as String},
      serverOnDevice: {for (final id in j['serverOnDevice']) id as String},
    );
  } catch (_) {
    return emptyBackupState; // never checked, or broken
  }
}
