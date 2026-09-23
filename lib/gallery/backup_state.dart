import 'package:photo_manager/photo_manager.dart';

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
  final count = await deviceCount();
  final all = count == 0 ? <AssetEntity>[] : await devicePhotos(0, count);
  return (
    deviceOnly: [
      for (final a in all)
        if (!found.containsKey(a.id)) a,
    ],
    deviceBackedUp: found.keys.toSet(),
    serverOnDevice: found.values.toSet(),
  );
}
