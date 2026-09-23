import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../editor/preview.dart' show rendererChannel;
import 'device.dart';

/// Checksums (SHA-1, Base64) of all device photos, as Immich keeps them as `checksum` — this is
/// how the gallery recognizes what is already backed up (D-36). Computed once, then from the
/// cache; only new or changed photos are computed again.

/// Which stored checksums are still valid and which photos need computing. [photos]: ID →
/// time of last modification; [stored]: ID → (modification when computed, checksum).
({Map<String, String> valid, List<String> pending}) reconcile(
  Map<String, int> photos,
  Map<String, (int, String)> stored,
) {
  final valid = <String, String>{};
  final pending = <String>[];
  photos.forEach((id, modified) {
    final s = stored[id];
    if (s != null && s.$1 == modified) {
      valid[id] = s.$2;
    } else {
      pending.add(id);
    }
  });
  return (valid: valid, pending: pending);
}

Future<File> _file() async {
  final dir = await rendererChannel.invokeMethod<String>('filesDir');
  final file = File('$dir/checksums.json');
  // Before the translation the file was called pruefsummen.json; take it over once.
  final old = File('$dir/pruefsummen.json');
  if (await old.exists() && !await file.exists()) await old.rename(file.path);
  return file;
}

Future<Map<String, (int, String)>> _read() async {
  try {
    final j = jsonDecode(await (await _file()).readAsString()) as Map;
    return {
      for (final e in j.entries)
        e.key as String: ((e.value as List)[0] as int, e.value[1] as String),
    };
  } catch (_) {
    return {}; // never computed or broken: compute anew
  }
}

Future<void> _write(Map<String, int> photos, Map<String, String> sums) async =>
    (await _file()).writeAsString(
      jsonEncode({
        for (final e in sums.entries) e.key: [photos[e.key], e.value],
      }),
    );

/// Progress of the checksum pass while checksums are being computed, otherwise null — for the
/// dialog, avatar and account dialog at once.
typedef ChecksumProgress = ({int done, int total, DateTime start});

final checksumProgress = ValueNotifier<ChecksumProgress?>(null);

Future<Map<String, String>>? _running;

/// ID → checksum of all photos on the device; progress is shown by [checksumProgress]. Runs
/// at most once at a time.
Future<Map<String, String>> deviceChecksums() =>
    _running ??= _compute().whenComplete(() {
      _running = null;
      checksumProgress.value = null;
    });

Future<Map<String, String>> _compute() async {
  final count = await deviceCount();
  final photos = {
    for (final a in count == 0 ? const [] : await devicePhotos(0, count))
      a.id as String: a.modifiedDateSecond as int? ?? 0,
  };
  final (:valid, :pending) = reconcile(photos, await _read());
  const batch = 40;
  final start = DateTime.now();
  if (pending.isNotEmpty) {
    checksumProgress.value = (done: 0, total: pending.length, start: start);
  }
  for (var i = 0; i < pending.length; i += batch) {
    final ids = pending.sublist(i, (i + batch).clamp(0, pending.length));
    final sums = await rendererChannel.invokeMapMethod<String, String>(
      'checksums',
      {'ids': ids},
    );
    valid.addAll(sums!);
    checksumProgress.value = (
      done: i + ids.length,
      total: pending.length,
      start: start,
    );
    // Save along the way: if the app is killed, it does not start over.
    if ((i ~/ batch) % 25 == 24) await _write(photos, valid);
  }
  if (pending.isNotEmpty || valid.length != photos.length) {
    await _write(photos, valid);
  }
  return valid;
}
