import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'gallery/gallery_page.dart';
import 'l10n/app_localizations.dart';
import 'language.dart';
import 'stacking/background.dart';
import 'server/immich.dart';
import 'theme.dart';

const storage = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await readLanguage();
  await initBackground();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        title: 'Editor for Immich',
        theme: lightTheme,
        darkTheme: darkTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: (device, _) => resolveLocale(device),
        home: const Start(),
      ),
    );
  }
}

/// Shows the login or, with a stored session, the gallery.
class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  Immich? _immich;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    () async {
      // persisted: do not rename
      final server = await storage.read(key: 'server');
      final token = await storage.read(key: 'token');
      setState(() {
        if (server != null && token != null) _immich = Immich(server, token);
        _loaded = true;
      });
    }();
  }

  Future<void> _logout() async {
    await storage.deleteAll();
    await setLanguage(appLocale.value); // the language outlives the session
    setState(() => _immich = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold();
    final immich = _immich;
    if (immich == null) {
      return LoginPage(onLoggedIn: (i) => setState(() => _immich = i));
    }
    return GalleryPage(immich: immich, onLogout: _logout);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});

  final ValueChanged<Immich> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final immich = await Immich.login(
        _server.text.trim(),
        _email.text.trim(),
        _password.text,
      );
      final version = await immich.majorVersion();
      if (!await immich.isKnownServer()) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.loginUntestedVersion(version))),
        );
      }
      await storage.write(key: 'server', value: immich.baseUrl);
      await storage.write(key: 'token', value: immich.token);
      widget.onLoggedIn(immich);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.loginFailed('$e'))));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            decoration: InputDecoration(labelText: l.loginEmail),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          TextField(
            controller: _password,
            decoration: InputDecoration(labelText: l.loginPassword),
            obscureText: true,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _login,
            child: Text(l.loginButton),
          ),
        ],
      ),
    );
  }
}
