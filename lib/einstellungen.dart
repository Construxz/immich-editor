import 'package:flutter/material.dart';

import 'editor/vorschau.dart' show appVersion;
import 'foto.dart';
import 'gallery/pruefsummen.dart' show abgleichStand;
import 'main.dart' show speicher;
import 'server/immich.dart';
import 'stapeln/stapeln.dart';
import 'thema.dart';

// Konto-Fenster und Einstellungen im Aufbau der Immich-App (`widgets/common/app_bar_dialog/`,
// `pages/common/settings.page.dart`, `widgets/settings/`, Tag v3.2.2, AGPL-3.0) — D-35.

/// Immichs Avatarfarben (`AvatarColor.toColor`).
Color _farbe(String name, bool dunkel) => switch (name) {
  'pink' => const Color.fromARGB(255, 244, 114, 182),
  'red' => const Color.fromARGB(255, 239, 68, 68),
  'yellow' => const Color.fromARGB(255, 234, 179, 8),
  'blue' => const Color.fromARGB(255, 59, 130, 246),
  'green' => const Color.fromARGB(255, 22, 163, 74),
  'purple' => const Color.fromARGB(255, 147, 51, 234),
  'orange' => const Color.fromARGB(255, 234, 88, 12),
  'gray' => const Color.fromARGB(255, 75, 85, 99),
  'amber' => const Color.fromARGB(255, 217, 119, 6),
  _ => dunkel ? const Color(0xFFABCBFA) : const Color(0xFF4250AF),
};

/// Profilbild des Nutzers, sonst seine Initiale auf seiner Farbe (`UserCircleAvatar`).
class Profilbild extends StatelessWidget {
  const Profilbild({
    super.key,
    required this.immich,
    required this.konto,
    this.groesse = 44,
    this.rand = false,
  });

  final Immich immich;
  final Konto konto;
  final double groesse;
  final bool rand;

  @override
  Widget build(BuildContext context) {
    final farbe = _farbe(
      konto.farbe,
      Theme.of(context).brightness == Brightness.dark,
    );
    final initiale = Center(
      child: Text(
        konto.name.isEmpty ? '?' : konto.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: farbe.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        ),
      ),
    );
    return Tooltip(
      message: konto.name,
      child: Container(
        width: groesse,
        height: groesse,
        decoration: BoxDecoration(
          color: farbe,
          shape: BoxShape.circle,
          border: rand ? Border.all(color: farbe, width: 1.5) : null,
        ),
        child: konto.hatBild
            ? ClipOval(
                child: Image.network(
                  immich.profilbild(konto.id).toString(),
                  headers: immich.kopf,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initiale,
                ),
              )
            : initiale,
      ),
    );
  }
}

/// „17.400" statt „17400".
String _zahl(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

String _dauer(Duration d) => d.inMinutes < 1
    ? 'einer Minute'
    : d.inMinutes < 60
    ? '${d.inMinutes + 1} Minuten'
    : '${d.inHours} Std. ${d.inMinutes % 60} Min.';

/// Balken und Stand des Bildabgleichs; nichts, wenn keiner läuft.
class AbgleichAnzeige extends StatelessWidget {
  const AbgleichAnzeige({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: abgleichStand,
    builder: (context, s, _) {
      if (s == null) return const SizedBox();
      final vergangen = DateTime.now().difference(s.beginn);
      // Restzeit nach dem bisherigen Tempo; erst, wenn es eines gibt.
      final rest = s.fertig == 0 || vergangen.inSeconds < 3
          ? null
          : vergangen * ((s.gesamt - s.fertig) / s.fertig);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          LinearProgressIndicator(
            minHeight: 10,
            value: s.gesamt == 0 ? null : s.fertig / s.gesamt,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          Text(
            '${_zahl(s.fertig)} von ${_zahl(s.gesamt)} Fotos'
            '${rest == null ? '' : ' · fertig in etwa ${_dauer(rest)}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}

/// Erklärt den ersten Bildabgleich (einmal je Installation); schließt man das Fenster, läuft er
/// weiter und zeigt sich am Profilbild und im Konto-Fenster. Geht zu, sobald er fertig ist.
Future<void> abgleichErklaeren(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => ValueListenableBuilder(
    valueListenable: abgleichStand,
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
            AbgleichAnzeige(),
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

/// Oben rechts in der Galerie: das Profilbild; antippen öffnet das Konto-Fenster.
class KontoKnopf extends StatefulWidget {
  const KontoKnopf({
    super.key,
    required this.immich,
    required this.onAbmelden,
    required this.onEinstellungen,
  });

  final Immich immich;
  final VoidCallback onAbmelden;

  /// Nach dem Verlassen der Einstellungen — die Galerie liest sie neu.
  final VoidCallback onEinstellungen;

  @override
  State<KontoKnopf> createState() => _KontoKnopfState();
}

class _KontoKnopfState extends State<KontoKnopf> {
  late final Future<Konto> _konto = widget.immich.ich();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _konto,
    builder: (context, s) {
      final konto = s.data;
      return IconButton(
        tooltip: 'Konto und Einstellungen',
        // Läuft der Bildabgleich, ein Ring ums Profilbild wie Immichs Backup-Anzeige.
        icon: ValueListenableBuilder(
          valueListenable: abgleichStand,
          builder: (context, stand, bild) => stand == null
              ? bild!
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: stand.gesamt == 0
                            ? null
                            : stand.fertig / stand.gesamt,
                      ),
                    ),
                    bild!,
                  ],
                ),
          child: konto == null
              ? const Icon(Icons.account_circle)
              : Profilbild(immich: widget.immich, konto: konto, groesse: 32),
        ),
        onPressed: konto == null
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => _KontoFenster(
                  immich: widget.immich,
                  konto: konto,
                  onAbmelden: widget.onAbmelden,
                  onEinstellungen: widget.onEinstellungen,
                ),
              ),
      );
    },
  );
}

String _bytes(int b) {
  const einheiten = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var x = b.toDouble();
  var i = 0;
  while (x >= 1024 && i < einheiten.length - 1) {
    x /= 1024;
    i++;
  }
  return '${x.toStringAsFixed(i == 0 ? 0 : 1).replaceAll('.', ',')} ${einheiten[i]}';
}

/// Das Konto-Fenster der Immich-App: oben Schließen und Name, in der Karte Profil, Speicherplatz
/// und Server; darunter Wartendes, Einstellungen, Abmelden; unten Lizenzen.
class _KontoFenster extends StatefulWidget {
  const _KontoFenster({
    required this.immich,
    required this.konto,
    required this.onAbmelden,
    required this.onEinstellungen,
  });

  final Immich immich;
  final Konto konto;
  final VoidCallback onAbmelden, onEinstellungen;

  @override
  State<_KontoFenster> createState() => _KontoFensterState();
}

class _KontoFensterState extends State<_KontoFenster> {
  late final _platz = widget.immich.speicherplatz(widget.konto);
  late final _server = widget.immich.version();
  final _app = appVersion();
  final _wartend = wartendeStapel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final text = theme.textTheme;

    ListTile knopf(IconData icon, String titel, VoidCallback onTap) => ListTile(
      dense: true,
      visualDensity: VisualDensity.standard,
      contentPadding: const EdgeInsets.only(left: 30, right: 30),
      minLeadingWidth: 40,
      leading: Icon(icon, size: 20, color: text.labelLarge?.color),
      title: Text(titel, style: text.labelLarge),
      onTap: onTap,
    );

    Widget zeile(String name, Future<String> wert) => Row(
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
            future: wert,
            builder: (context, s) => Text(
              s.data ?? '--',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: farben.onSurfaceSecondary,
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
                          color: farben.onSurfaceVariant,
                        ),
                      ),
                      Align(
                        child: Text(
                          'Editor for Immich',
                          style: text.titleSmall?.copyWith(
                            color: farben.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: farben.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      minLeadingWidth: 50,
                      leading: Profilbild(
                        immich: widget.immich,
                        konto: widget.konto,
                        rand: true,
                      ),
                      title: Text(
                        widget.konto.name,
                        style: text.titleMedium?.copyWith(
                          color: farben.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        widget.konto.email,
                        style: text.bodySmall?.copyWith(
                          color: farben.onSurfaceSecondary,
                        ),
                      ),
                    ),
                    Divider(thickness: 4, color: farben.surfaceContainer),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: FutureBuilder(
                        future: _platz,
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
                                value: p == null || p.gesamt == 0
                                    ? 0
                                    : p.belegt / p.gesamt,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              Text(
                                p == null
                                    ? '--'
                                    : '${_bytes(p.belegt)} von ${_bytes(p.gesamt)} belegt',
                                style: text.bodySmall,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: abgleichStand,
                      builder: (context, stand, _) => stand == null
                          ? const SizedBox()
                          : Column(
                              children: [
                                Divider(
                                  thickness: 4,
                                  color: farben.surfaceContainer,
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
                                      const AbgleichAnzeige(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Divider(thickness: 4, color: farben.surfaceContainer),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          zeile('App-Version', _app),
                          const Divider(thickness: 1),
                          zeile(
                            'Server-Version',
                            _server.then(
                              (v) => '${v.major}.${v.minor}.${v.patch}',
                            ),
                          ),
                          const Divider(thickness: 1),
                          zeile(
                            'Server-Adresse',
                            Future.value(widget.immich.basis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder(
                future: _wartend,
                builder: (context, s) => (s.data ?? 0) == 0
                    ? const SizedBox()
                    : knopf(
                        Icons.hourglass_top,
                        s.data == 1
                            ? '1 Bearbeitung wartet auf das Backup'
                            : '${s.data} Bearbeitungen warten auf das Backup',
                        () => _einstellungen(context, _Bereich.stapeln),
                      ),
              ),
              knopf(
                Icons.settings_outlined,
                'Einstellungen',
                () => _einstellungen(context, null),
              ),
              knopf(Icons.logout_rounded, 'Abmelden', _abmelden),
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

  Future<void> _einstellungen(BuildContext context, _Bereich? bereich) async {
    final navigator = Navigator.of(context)..pop();
    final zurueck = widget.onEinstellungen;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => bereich == null
            ? EinstellungenSeite(immich: widget.immich, konto: widget.konto)
            : _BereichSeite(
                bereich: bereich,
                immich: widget.immich,
                konto: widget.konto,
              ),
      ),
    );
    zurueck();
  }

  Future<void> _abmelden() async {
    final ja = await showDialog<bool>(
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
    if (ja != true || !mounted) return;
    Navigator.pop(context);
    widget.onAbmelden();
  }
}

/// Die Bereiche der Einstellungen, wie Immichs `SettingSection`.
enum _Bereich {
  ansicht(
    Icons.auto_awesome_mosaic_outlined,
    'Ansicht',
    'Eine Zeitleiste über Gerät und Server',
  ),
  bearbeiten(Icons.tune, 'Bearbeiten', 'HDR in Vorschau und Kopie'),
  speichern(
    Icons.cloud_upload_outlined,
    'Speichern',
    'Wohin Bearbeitungen von Online-Fotos gehen',
  ),
  netzwerk(Icons.wifi, 'Netzwerk', 'Mobile Daten für Originale und Uploads'),
  stapeln(
    Icons.filter_none,
    'Stapeln',
    'Bearbeitungen, die auf das Backup warten',
  );

  const _Bereich(this.icon, this.titel, this.text);

  final IconData icon;
  final String titel;
  final String text;
}

/// Die Einstellungsseite: eine Karte je Bereich (`SettingsCard`).
class EinstellungenSeite extends StatelessWidget {
  const EinstellungenSeite({
    super.key,
    required this.immich,
    required this.konto,
  });

  final Immich immich;
  final Konto konto;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 60),
        children: [
          for (final b in _Bereich.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                color: farben.surfaceContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      color: farben.brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.white.withAlpha(100),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(b.icon, color: farben.primary),
                  ),
                  title: Text(
                    b.titel,
                    style: text.titleMedium!.copyWith(color: farben.primary),
                  ),
                  subtitle: Text(b.text, style: text.bodyMedium),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _BereichSeite(
                        bereich: b,
                        immich: immich,
                        konto: konto,
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

/// Ein Bereich der Einstellungen; jede Einstellung steht in [speicher], der Editor liest sie dort.
class _BereichSeite extends StatefulWidget {
  const _BereichSeite({
    required this.bereich,
    required this.immich,
    required this.konto,
  });

  final _Bereich bereich;
  final Immich immich;
  final Konto konto;

  @override
  State<_BereichSeite> createState() => _BereichSeiteState();
}

class _BereichSeiteState extends State<_BereichSeite> {
  // Schlüssel → Wert, der „aus" bedeutet; alles andere (auch nichts) heißt „an".
  static const _aus = {
    'hdr': 'aus',
    'online': 'server',
    'mobil': 'aus',
    'zusammen': 'getrennt',
  };
  static const _an = {
    'hdr': 'an',
    'online': 'geraet',
    'mobil': 'an',
    'zusammen': 'zusammen',
  };
  final _werte = <String, bool>{};
  var _wartend = 0;
  var _stapelt = false;

  @override
  void initState() {
    super.initState();
    () async {
      for (final k in _aus.keys) {
        _werte[k] = await speicher.read(key: k) != _aus[k];
      }
      _wartend = await wartendeStapel();
      if (mounted) setState(() {});
    }();
  }

  /// Wie Immichs `SettingsSwitchListTile`.
  Widget _schalter(String k, IconData icon, String titel, String text) {
    final farben = Theme.of(context).colorScheme;
    final an = _werte[k] ?? true;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
      value: an,
      activeThumbColor: farben.primary,
      secondary: Icon(icon, color: an ? farben.primary : null),
      title: Text(
        titel,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500, height: 1.5),
      ),
      subtitle: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: farben.onSurfaceSecondary),
      ),
      onChanged: (neu) {
        setState(() => _werte[k] = neu);
        speicher.write(key: k, value: neu ? _an[k]! : _aus[k]!);
      },
    );
  }

  Future<void> _jetztStapeln() async {
    setState(() => _stapelt = true);
    final meldung = ScaffoldMessenger.of(context);
    try {
      await ausstehendeStapeln(widget.immich);
    } catch (e) {
      meldung.showSnackBar(SnackBar(content: Text('$e')));
    }
    final wartend = await wartendeStapel();
    if (mounted) {
      setState(() {
        _wartend = wartend;
        _stapelt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final einstellungen = switch (widget.bereich) {
      _Bereich.ansicht => [
        _schalter(
          'zusammen',
          Icons.auto_awesome_mosaic_outlined,
          'Gerät und Server zusammen',
          'Eine Zeitleiste wie in der Immich-App; die Wolke unten rechts zeigt, '
              'ob ein Foto nur auf dem Gerät, nur auf dem Server oder auf beiden '
              'liegt. Aus: zwei Reiter „Gerät" und „Immich".',
        ),
      ],
      _Bereich.bearbeiten => [
        _schalter(
          'hdr',
          Icons.hdr_on,
          'HDR',
          'Ultra-HDR-Fotos in HDR zeigen und als Ultra HDR speichern',
        ),
      ],
      _Bereich.speichern => [
        _schalter(
          'online',
          Icons.phone_android,
          'Online-Fotos übers Gerät sichern',
          'Die Kopie eines Fotos, das nur auf dem Server liegt, kommt ins '
              'Kamera-Album; die Immich-App sichert sie, danach verlässt sie '
              'das Gerät. Aus: direkt auf den Server.',
        ),
      ],
      _Bereich.netzwerk => [
        _schalter(
          'mobil',
          Icons.signal_cellular_alt,
          'Mobile Daten',
          'Originale laden und Kopien hochladen auch ohne WLAN. Aus: nur '
              'nach Rückfrage.',
        ),
      ],
      _Bereich.stapeln => [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.hourglass_top),
          title: Text(
            _wartend == 0
                ? 'Nichts wartet auf das Backup'
                : _wartend == 1
                ? '1 Bearbeitung wartet auf das Backup'
                : '$_wartend Bearbeitungen warten auf das Backup',
          ),
          subtitle: Text(
            'Auf dem Gerät gespeicherte Kopien stapelt die App, sobald die '
            'Immich-App Original und Kopie gesichert hat — dafür muss sie mit '
            '${widget.konto.email} angemeldet sein.',
          ),
        ),
        if (_wartend > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _stapelt ? null : _jetztStapeln,
                child: const Text('Jetzt stapeln'),
              ),
            ),
          ),
      ],
    };
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(widget.bereich.titel)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: einstellungen.length,
        itemBuilder: (_, i) => einstellungen[i],
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      ),
    );
  }
}
