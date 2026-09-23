import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../main.dart' show storage;
import '../server/immich.dart';
import 'stacking.dart';

/// Stacking without opening the app: Android's WorkManager runs [stackPending] about every
/// 15 minutes while something is pending and a network is there (D-46).
const _task = 'stackPending';

/// Runs in a headless Flutter engine — without our activity, so without the renderer channel
/// and Android's delete dialog; see `background:` in [stackPending].
@pragma('vm:entry-point')
void backgroundMain() => Workmanager().executeTask((_, _) async {
  WidgetsFlutterBinding.ensureInitialized();
  // persisted: do not rename
  final server = await storage.read(key: 'server');
  final token = await storage.read(key: 'token');
  if (server != null && token != null) {
    await stackPending(Immich(server, token), background: true);
  }
  return true;
});

Future<void> initBackground() => Workmanager().initialize(backgroundMain);

Future<void> scheduleBackgroundStacking() => Workmanager().registerPeriodicTask(
  _task,
  _task,
  constraints: Constraints(networkType: NetworkType.connected),
  existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
);

Future<void> cancelBackgroundStacking() =>
    Workmanager().cancelByUniqueName(_task);
