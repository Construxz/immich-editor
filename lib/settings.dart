import 'package:flutter/material.dart';

import 'editor/preview.dart' show appVersion;
import 'photo.dart';
import 'gallery/checksums.dart' show checksumProgress;
import 'main.dart' show storage;
import 'server/immich.dart';
import 'stacking/stacking.dart';
import 'theme.dart';

// Account dialog and settings laid out like the Immich app (`widgets/common/app_bar_dialog/`,
// `pages/common/settings.page.dart`, `widgets/settings/`, tag v3.2.2, AGPL-3.0) — D-35.

/// Immich's avatar colors (`AvatarColor.toColor`).
Color _color(String name, bool dark) => switch (name) {
  'pink' => const Color.fromARGB(255, 244, 114, 182),
  'red' => const Color.fromARGB(255, 239, 68, 68),
  'yellow' => const Color.fromARGB(255, 234, 179, 8),
  'blue' => const Color.fromARGB(255, 59, 130, 246),
  'green' => const Color.fromARGB(255, 22, 163, 74),
  'purple' => const Color.fromARGB(255, 147, 51, 234),
  'orange' => const Color.fromARGB(255, 234, 88, 12),
  'gray' => const Color.fromARGB(255, 75, 85, 99),
  'amber' => const Color.fromARGB(255, 217, 119, 6),
  _ => dark ? const Color(0xFFABCBFA) : const Color(0xFF4250AF),
};

/// The user's avatar, else their initial on their color (`UserCircleAvatar`).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.immich,
    required this.account,
    this.size = 44,
    this.border = false,
  });

  final Immich immich;
  final Account account;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final color = _color(
      account.color,
      Theme.of(context).brightness == Brightness.dark,
    );
    final initial = Center(
      child: Text(
        account.name.isEmpty
            ? '?'
            : account.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        ),
      ),
    );
    return Tooltip(
      message: account.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border ? Border.all(color: color, width: 1.5) : null,
        ),
        child: account.hasImage
            ? ClipOval(
                child: Image.network(
                  immich.avatarUri(account.id).toString(),
                  headers: immich.headers,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initial,
                ),
              )
            : initial,
      ),
    );
  }
}

/// "17.400" instead of "17400".
String _number(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

String _duration(Duration d) => d.inMinutes < 1
    ? 'einer Minute'
    : d.inMinutes < 60
    ? '${d.inMinutes + 1} Minuten'
    : '${d.inHours} Std. ${d.inMinutes % 60} Min.';

/// Bar and progress of the checksum run; nothing when none is running.
class ChecksumProgressView extends StatelessWidget {
  const ChecksumProgressView({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: checksumProgress,
    builder: (context, s, _) {
      if (s == null) return const SizedBox();
      final elapsed = DateTime.now().difference(s.start);
      // Remaining time at the pace so far; only once there is one.
      final remaining = s.done == 0 || elapsed.inSeconds < 3
          ? null
          : elapsed * ((s.total - s.done) / s.done);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          LinearProgressIndicator(
            minHeight: 10,
            value: s.total == 0 ? null : s.done / s.total,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          Text(
            '${_number(s.done)} von ${_number(s.total)} Fotos'
            '${remaining == null ? '' : ' · fertig in etwa ${_duration(remaining)}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}

/// Explains the first checksum run (once per install); closing the dialog lets it continue,
/// shown on the avatar and in the account dialog. Closes itself when done.
Future<void> explainChecksums(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => ValueListenableBuilder(
    valueListenable: checksumProgress,
    builder: (c, s, _) {
      if (s == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (c.mounted) Navigator.of(c).maybePop();
        });
      }
      return AlertDialog(
        title: const Text('Bildabgleich'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              'Die App rechnet einmal für jedes Foto auf diesem Gerät eine '
              'Prüfsumme. Daran erkennt sie, welche Fotos schon in Immich liegen '
              '— das zeigen die Wolken in der Zeitleiste.\n\n'
              'Das passiert nur beim ersten Mal, danach nur für neue Fotos. '
              'Hochgeladen wird dabei nichts; an den Server gehen nur die '
              'Prüfsummen.',
            ),
            ChecksumProgressView(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Im Hintergrund'),
          ),
        ],
      );
    },
  ),
);

/// Top right in the gallery: the avatar; tapping opens the account dialog.
class AccountButton extends StatefulWidget {
  const AccountButton({
    super.key,
    required this.immich,
    required this.onLogout,
    required this.onSettings,
  });

  final Immich immich;
  final VoidCallback onLogout;

  /// After leaving the settings — the gallery rereads them.
  final VoidCallback onSettings;

  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  late final Future<Account> _account = widget.immich.me();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _account,
    builder: (context, s) {
      final account = s.data;
      return IconButton(
        tooltip: 'Konto und Einstellungen',
        // While checksums run, a ring around the avatar like Immich's backup indicator.
        icon: ValueListenableBuilder(
          valueListenable: checksumProgress,
          builder: (context, progress, avatar) => progress == null
              ? avatar!
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: progress.total == 0
                            ? null
                            : progress.done / progress.total,
                      ),
                    ),
                    avatar!,
                  ],
                ),
          child: account == null
              ? const Icon(Icons.account_circle)
              : Avatar(immich: widget.immich, account: account, size: 32),
        ),
        onPressed: account == null
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => _AccountDialog(
                  immich: widget.immich,
                  account: account,
                  onLogout: widget.onLogout,
                  onSettings: widget.onSettings,
                ),
              ),
      );
    },
  );
}

String _bytes(int b) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var x = b.toDouble();
  var i = 0;
  while (x >= 1024 && i < units.length - 1) {
    x /= 1024;
    i++;
  }
  return '${x.toStringAsFixed(i == 0 ? 0 : 1).replaceAll('.', ',')} ${units[i]}';
}

/// The Immich app's account dialog: close and name on top, profile, storage and server in the
/// card; below it pending edits, settings, logout; licenses at the bottom.
class _AccountDialog extends StatefulWidget {
  const _AccountDialog({
    required this.immich,
    required this.account,
    required this.onLogout,
    required this.onSettings,
  });

  final Immich immich;
  final Account account;
  final VoidCallback onLogout, onSettings;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _storage = widget.immich.storageUsage(widget.account);
  late final _server = widget.immich.version();
  final _app = appVersion();
  final _pending = pendingCount();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    ListTile button(IconData icon, String title, VoidCallback onTap) =>
        ListTile(
          dense: true,
          visualDensity: VisualDensity.standard,
          contentPadding: const EdgeInsets.only(left: 30, right: 30),
          minLeadingWidth: 40,
          leading: Icon(icon, size: 20, color: text.labelLarge?.color),
          title: Text(title, style: text.labelLarge),
          onTap: onTap,
        );

    Widget row(String name, Future<String> value) => Row(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: text.labelSmall?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FutureBuilder(
            future: value,
            builder: (context, s) => Text(
              s.data ?? '--',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );

    return Dismissible(
      key: const Key('konto'),
      direction: DismissDirection.down,
      onDismissed: (_) => Navigator.pop(context),
      child: Dialog(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(
          top: 40,
          left: 20,
          right: 20,
          bottom: 100,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      IconButton(
                        tooltip: 'Schließen',
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Align(
                        child: Text(
                          'Editor for Immich',
                          style: text.titleSmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      minLeadingWidth: 50,
                      leading: Avatar(
                        immich: widget.immich,
                        account: widget.account,
                        border: true,
                      ),
                      title: Text(
                        widget.account.name,
                        style: text.titleMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        widget.account.email,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceSecondary,
                        ),
                      ),
                    ),
                    Divider(thickness: 4, color: colors.surfaceContainer),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: FutureBuilder(
                        future: _storage,
                        builder: (context, s) {
                          final p = s.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: [
                              Text(
                                'Speicherplatz auf dem Server',
                                style: text.labelLarge,
                              ),
                              LinearProgressIndicator(
                                minHeight: 10,
                                value: p == null || p.total == 0
                                    ? 0
                                    : p.used / p.total,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              Text(
                                p == null
                                    ? '--'
                                    : '${_bytes(p.used)} von ${_bytes(p.total)} belegt',
                                style: text.bodySmall,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: checksumProgress,
                      builder: (context, progress, _) => progress == null
                          ? const SizedBox()
                          : Column(
                              children: [
                                Divider(
                                  thickness: 4,
                                  color: colors.surfaceContainer,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 12,
                                    children: [
                                      Text(
                                        'Bildabgleich',
                                        style: text.labelLarge,
                                      ),
                                      const ChecksumProgressView(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Divider(thickness: 4, color: colors.surfaceContainer),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          row('App-Version', _app),
                          const Divider(thickness: 1),
                          row(
                            'Server-Version',
                            _server.then(
                              (v) => '${v.major}.${v.minor}.${v.patch}',
                            ),
                          ),
                          const Divider(thickness: 1),
                          row(
                            'Server-Adresse',
                            Future.value(widget.immich.baseUrl),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder(
                future: _pending,
                builder: (context, s) => (s.data ?? 0) == 0
                    ? const SizedBox()
                    : button(
                        Icons.hourglass_top,
                        s.data == 1
                            ? '1 Bearbeitung wartet auf das Backup'
                            : '${s.data} Bearbeitungen warten auf das Backup',
                        () => _openSettings(context, _Section.stacking),
                      ),
              ),
              button(
                Icons.settings_outlined,
                'Einstellungen',
                () => _openSettings(context, null),
              ),
              button(Icons.logout_rounded, 'Abmelden', _logout),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: InkWell(
                  onTap: () async {
                    final version = await _app;
                    if (!context.mounted) return;
                    showLicensePage(
                      context: context,
                      applicationName: 'Editor for Immich',
                      applicationVersion: version,
                    );
                  },
                  child: Text('Lizenzen', style: text.bodySmall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, _Section? section) async {
    final navigator = Navigator.of(context)..pop();
    final onBack = widget.onSettings;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => section == null
            ? SettingsPage(immich: widget.immich, account: widget.account)
            : _SectionPage(
                section: section,
                immich: widget.immich,
                account: widget.account,
              ),
      ),
    );
    onBack();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(context);
    widget.onLogout();
  }
}

/// The settings sections, like Immich's `SettingSection`.
enum _Section {
  view(
    Icons.auto_awesome_mosaic_outlined,
    'Ansicht',
    'Eine Zeitleiste über Gerät und Server',
  ),
  edit(Icons.tune, 'Bearbeiten', 'HDR in Vorschau und Kopie'),
  save(
    Icons.cloud_upload_outlined,
    'Speichern',
    'Wohin Bearbeitungen von Online-Fotos gehen',
  ),
  network(Icons.wifi, 'Netzwerk', 'Mobile Daten für Originale und Uploads'),
  stacking(
    Icons.filter_none,
    'Stapeln',
    'Bearbeitungen, die auf das Backup warten',
  );

  const _Section(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

/// The settings page: one card per section (`SettingsCard`).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.immich, required this.account});

  final Immich immich;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 60),
        children: [
          for (final b in _Section.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                color: colors.surfaceContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      color: colors.brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.white.withAlpha(100),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(b.icon, color: colors.primary),
                  ),
                  title: Text(
                    b.title,
                    style: text.titleMedium!.copyWith(color: colors.primary),
                  ),
                  subtitle: Text(b.text, style: text.bodyMedium),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _SectionPage(
                        section: b,
                        immich: immich,
                        account: account,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One settings section; every setting lives in [storage], the editor reads it there.
class _SectionPage extends StatefulWidget {
  const _SectionPage({
    required this.section,
    required this.immich,
    required this.account,
  });

  final _Section section;
  final Immich immich;
  final Account account;

  @override
  State<_SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<_SectionPage> {
  // Key → value meaning "off"; anything else (including none) means "on". persisted: do not rename
  static const _off = {
    'hdr': 'aus',
    'online': 'server',
    'mobil': 'aus',
    'zusammen': 'getrennt',
  };
  static const _on = {
    'hdr': 'an',
    'online': 'geraet',
    'mobil': 'an',
    'zusammen': 'zusammen',
  };
  final _values = <String, bool>{};
  var _pending = 0;
  var _stacking = false;

  @override
  void initState() {
    super.initState();
    () async {
      for (final k in _off.keys) {
        _values[k] = await storage.read(key: k) != _off[k];
      }
      _pending = await pendingCount();
      if (mounted) setState(() {});
    }();
  }

  /// Like Immich's `SettingsSwitchListTile`.
  Widget _toggle(String k, IconData icon, String title, String text) {
    final colors = Theme.of(context).colorScheme;
    final isOn = _values[k] ?? true;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
      value: isOn,
      activeThumbColor: colors.primary,
      secondary: Icon(icon, color: isOn ? colors.primary : null),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500, height: 1.5),
      ),
      subtitle: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colors.onSurfaceSecondary),
      ),
      onChanged: (v) {
        setState(() => _values[k] = v);
        storage.write(key: k, value: v ? _on[k]! : _off[k]!);
      },
    );
  }

  Future<void> _stackNow() async {
    setState(() => _stacking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await stackPending(widget.immich);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    final pending = await pendingCount();
    if (mounted) {
      setState(() {
        _pending = pending;
        _stacking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = switch (widget.section) {
      _Section.view => [
        _toggle(
          'zusammen',
          Icons.auto_awesome_mosaic_outlined,
          'Gerät und Server zusammen',
          'Eine Zeitleiste wie in der Immich-App; die Wolke unten rechts zeigt, '
              'ob ein Foto nur auf dem Gerät, nur auf dem Server oder auf beiden '
              'liegt. Aus: zwei Reiter „Gerät" und „Immich".',
        ),
      ],
      _Section.edit => [
        _toggle(
          'hdr',
          Icons.hdr_on,
          'HDR',
          'Ultra-HDR-Fotos in HDR zeigen und als Ultra HDR speichern',
        ),
      ],
      _Section.save => [
        _toggle(
          'online',
          Icons.phone_android,
          'Online-Fotos übers Gerät sichern',
          'Die Kopie eines Fotos, das nur auf dem Server liegt, kommt ins '
              'Kamera-Album; die Immich-App sichert sie, danach verlässt sie '
              'das Gerät. Aus: direkt auf den Server.',
        ),
      ],
      _Section.network => [
        _toggle(
          'mobil',
          Icons.signal_cellular_alt,
          'Mobile Daten',
          'Originale laden und Kopien hochladen auch ohne WLAN. Aus: nur '
              'nach Rückfrage.',
        ),
      ],
      _Section.stacking => [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.hourglass_top),
          title: Text(
            _pending == 0
                ? 'Nichts wartet auf das Backup'
                : _pending == 1
                ? '1 Bearbeitung wartet auf das Backup'
                : '$_pending Bearbeitungen warten auf das Backup',
          ),
          subtitle: Text(
            'Auf dem Gerät gespeicherte Kopien stapelt die App, sobald die '
            'Immich-App Original und Kopie gesichert hat — dafür muss sie mit '
            '${widget.account.email} angemeldet sein.',
          ),
        ),
        if (_pending > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _stacking ? null : _stackNow,
                child: const Text('Jetzt stapeln'),
              ),
            ),
          ),
      ],
    };
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(widget.section.title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      ),
    );
  }
}
