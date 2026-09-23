import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'gallery/galerie_seite.dart';
import 'server/immich.dart';
import 'thema.dart';

const speicher = FlutterSecureStorage();

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editor for Immich',
      theme: themaHell,
      darkTheme: themaDunkel,
      home: const Start(),
    );
  }
}

/// Zeigt die Anmeldung oder, mit gespeicherter Sitzung, die Galerie.
class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  Immich? _immich;
  var _geladen = false;

  @override
  void initState() {
    super.initState();
    () async {
      final server = await speicher.read(key: 'server');
      final token = await speicher.read(key: 'token');
      setState(() {
        if (server != null && token != null) _immich = Immich(server, token);
        _geladen = true;
      });
    }();
  }

  Future<void> _abmelden() async {
    await speicher.deleteAll();
    setState(() => _immich = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_geladen) return const Scaffold();
    final immich = _immich;
    if (immich == null) {
      return AnmeldeSeite(onAngemeldet: (i) => setState(() => _immich = i));
    }
    return GalerieSeite(immich: immich, onAbmelden: _abmelden);
  }
}

class AnmeldeSeite extends StatefulWidget {
  const AnmeldeSeite({super.key, required this.onAngemeldet});

  final ValueChanged<Immich> onAngemeldet;

  @override
  State<AnmeldeSeite> createState() => _AnmeldeSeiteState();
}

class _AnmeldeSeiteState extends State<AnmeldeSeite> {
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _passwort = TextEditingController();
  var _laeuft = false;

  Future<void> _anmelden() async {
    setState(() => _laeuft = true);
    final meldung = ScaffoldMessenger.of(context);
    try {
      final immich = await Immich.anmelden(
        _server.text.trim(),
        _email.text.trim(),
        _passwort.text,
      );
      final version = await immich.hauptversion();
      if (!Immich.bekannteHauptversionen.contains(version)) {
        meldung.showSnackBar(
          SnackBar(
            content: Text(
              'Immich $version.x ist nicht geprüft — '
              'die App kann sich unerwartet verhalten.',
            ),
          ),
        );
      }
      await speicher.write(key: 'server', value: immich.basis);
      await speicher.write(key: 'token', value: immich.token);
      widget.onAngemeldet(immich);
    } catch (e) {
      meldung.showSnackBar(
        SnackBar(content: Text('Anmeldung fehlgeschlagen: $e')),
      );
      setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor for Immich')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Server',
              hintText: 'https://immich.example.com',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-Mail'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          TextField(
            controller: _passwort,
            decoration: const InputDecoration(labelText: 'Passwort'),
            obscureText: true,
            onSubmitted: (_) => _anmelden(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _laeuft ? null : _anmelden,
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
  }
}
