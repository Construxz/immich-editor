import 'package:flutter/material.dart';

import 'foto.dart';
import 'main.dart' show speicher;
import 'server/immich.dart';
import 'stapeln/stapeln.dart';

/// Immichs Avatarfarben (`avatarColor`), wie die Immich-App sie zeigt.
const _farben = {
  'primary': Color(0xFF4250AF),
  'pink': Color(0xFFDE7FB3),
  'red': Color(0xFFE64132),
  'yellow': Color(0xFFD3BA2E),
  'blue': Color(0xFF3B82F6),
  'green': Color(0xFF22C55E),
  'purple': Color(0xFFA855F7),
  'orange': Color(0xFFF97316),
  'gray': Color(0xFF6B7280),
  'amber': Color(0xFFF59E0B),
};

/// Profilbild des angemeldeten Nutzers, sonst seine Initiale auf seiner Farbe — wie bei Immich.
class Profilbild extends StatelessWidget {
  const Profilbild({
    super.key,
    required this.immich,
    required this.konto,
    this.radius = 16,
  });

  final Immich immich;
  final Konto konto;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: _farben[konto.farbe] ?? _farben['primary'],
    foregroundColor: Colors.white,
    foregroundImage: konto.hatBild
        ? NetworkImage(
            immich.profilbild(konto.id).toString(),
            headers: immich.kopf,
          )
        : null,
    child: Text(
      konto.name.isEmpty ? '?' : konto.name.characters.first.toUpperCase(),
    ),
  );
}

/// Oben rechts in der Galerie: Profilbild; antippen zeigt Konto, Wartendes und Einstellungen.
class KontoKnopf extends StatefulWidget {
  const KontoKnopf({super.key, required this.immich, required this.onAbmelden});

  final Immich immich;
  final VoidCallback onAbmelden;

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
        icon: konto == null
            ? const Icon(Icons.account_circle)
            : Profilbild(immich: widget.immich, konto: konto),
        onPressed: konto == null ? null : () => _zeigen(konto),
      );
    },
  );

  Future<void> _zeigen(Konto konto) async {
    final wartend = await wartendeStapel();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final wahl = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Profilbild(immich: widget.immich, konto: konto, radius: 32),
            const SizedBox(height: 12),
            Text(konto.name, style: Theme.of(c).textTheme.titleMedium),
            Text(konto.email),
            const SizedBox(height: 4),
            Text(widget.immich.basis, style: Theme.of(c).textTheme.bodySmall),
            if (wartend > 0) ...[
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.hourglass_top),
                title: Text(
                  wartend == 1
                      ? '1 Bearbeitung wartet auf das Backup'
                      : '$wartend Bearbeitungen warten auf das Backup',
                ),
                subtitle: Text(
                  'Die Immich-App muss mit ${konto.email} sichern.',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'abmelden'),
            child: const Text('Abmelden'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(c, 'einstellungen'),
            child: const Text('Einstellungen'),
          ),
        ],
      ),
    );
    if (wahl == 'abmelden') widget.onAbmelden();
    if (wahl == 'einstellungen') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              EinstellungenSeite(immich: widget.immich, konto: konto),
        ),
      );
    }
  }
}

/// Alle Einstellungen, nach Themen geordnet. Jede steht in [speicher]; der Editor liest sie dort.
class EinstellungenSeite extends StatefulWidget {
  const EinstellungenSeite({
    super.key,
    required this.immich,
    required this.konto,
  });

  final Immich immich;
  final Konto konto;

  @override
  State<EinstellungenSeite> createState() => _EinstellungenSeiteState();
}

class _EinstellungenSeiteState extends State<EinstellungenSeite> {
  // Schlüssel → Wert, der „aus" bedeutet; alles andere (auch nichts) heißt „an".
  static const _aus = {'hdr': 'aus', 'online': 'server', 'mobil': 'aus'};
  static const _an = {'hdr': 'an', 'online': 'geraet', 'mobil': 'an'};
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

  void _setzen(String k, bool an) {
    setState(() => _werte[k] = an);
    speicher.write(key: k, value: an ? _an[k]! : _aus[k]!);
  }

  Widget _schalter(String k, String titel, String text) => SwitchListTile(
    title: Text(titel),
    subtitle: Text(text),
    value: _werte[k] ?? true,
    onChanged: (an) => _setzen(k, an),
  );

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
    Widget kopf(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          kopf('Bearbeiten'),
          _schalter(
            'hdr',
            'HDR',
            'Ultra-HDR-Fotos in HDR zeigen und als Ultra HDR speichern',
          ),
          kopf('Speichern'),
          _schalter(
            'online',
            'Online-Fotos übers Gerät sichern',
            'Die Kopie eines Fotos, das nur auf dem Server liegt, kommt ins '
                'Kamera-Album; die Immich-App sichert sie, danach verlässt sie das '
                'Gerät. Aus: direkt auf den Server.',
          ),
          _schalter(
            'mobil',
            'Mobile Daten',
            'Originale laden und Kopien hochladen auch ohne WLAN. Aus: nur nach '
                'Rückfrage.',
          ),
          kopf('Stapeln'),
          ListTile(
            leading: const Icon(Icons.hourglass_top),
            title: Text(
              _wartend == 0
                  ? 'Nichts wartet auf das Backup'
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _stapelt ? null : _jetztStapeln,
                  child: const Text('Jetzt stapeln'),
                ),
              ),
            ),
          kopf('Konto'),
          ListTile(
            leading: Profilbild(immich: widget.immich, konto: widget.konto),
            title: Text(widget.konto.name),
            subtitle: Text('${widget.konto.email}\n${widget.immich.basis}'),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}
