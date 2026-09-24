import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show storage;

/// HDR on or off — one state for gallery, viewer and editor (D-58).
final hdrOn = ValueNotifier(true);

/// Whether the HDR button shows in gallery, viewer and editor; off: only in the settings (D-58).
// ponytail: one switch for one button; a list of buttons once there are more to customise.
final hdrButton = ValueNotifier(true);

const _hdrKey = 'hdr'; // persisted: do not rename ('an' / 'aus')
const _buttonKey = 'hdrButton'; // persisted: do not rename

Future<void> readHdr() async {
  hdrOn.value = await storage.read(key: _hdrKey) != 'aus';
  hdrButton.value = await storage.read(key: _buttonKey) != 'aus';
}

Future<void> setHdr(bool on) async {
  hdrOn.value = on;
  await storage.write(key: _hdrKey, value: on ? 'an' : 'aus');
}

Future<void> setHdrButton(bool on) async {
  hdrButton.value = on;
  await storage.write(key: _buttonKey, value: on ? 'an' : 'aus');
}

/// The HDR button of gallery, viewer and editor; nothing if hidden in the settings.
class HdrButton extends StatelessWidget {
  const HdrButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hdrOn, hdrButton]),
    builder: (context, _) {
      if (!hdrButton.value) return const SizedBox.shrink();
      final l = AppLocalizations.of(context);
      final on = hdrOn.value;
      return IconButton(
        icon: Icon(on ? Icons.hdr_on : Icons.hdr_off),
        tooltip: on ? l.editorHdrOn : l.editorHdrOff,
        onPressed: enabled ? () => setHdr(!on) : null,
      );
    },
  );
}
