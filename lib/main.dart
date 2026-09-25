import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'gallery/gallery_page.dart';
import 'l10n/app_localizations.dart';
import 'hdr.dart';
import 'language.dart';
import 'stacking/background.dart';
import 'server/immich.dart';
import 'theme.dart';

const storage = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await readLanguage();
  await readHdr();
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

/// Shows the login or, with a stored session, the gallery — also without a server, when that
/// was chosen (D-79).
class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  Immich? _immich;
  var _withoutServer = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    () async {
      // persisted: do not rename
      final server = await storage.read(key: 'server');
      final token = await storage.read(key: 'token');
      final withoutServer = await storage.read(key: 'withoutServer') == 'yes';
      setState(() {
        if (server != null && token != null) _immich = Immich(server, token);
        _withoutServer = withoutServer;
        _loaded = true;
      });
    }();
  }

  Future<void> _logout() async {
    await _immich?.logout(); // the token stops working on the server too (D-78)
    await cancelBackgroundStacking();
    await storage.deleteAll();
    await setLanguage(appLocale.value); // the language outlives the session
    setState(() => _immich = null);
  }

  /// Without a server (D-79): the device's photos, nothing goes online; remembered.
  Future<void> _useWithoutServer(bool yes) async {
    if (yes) {
      await storage.write(key: 'withoutServer', value: 'yes');
    } else {
      await storage.delete(key: 'withoutServer');
    }
    setState(() => _withoutServer = yes);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold();
    final immich = _immich;
    if (immich == null && _withoutServer) {
      // "Connect to a server" in the account dialog leads to the login.
      return GalleryPage(
        immich: null,
        onLogout: () => _useWithoutServer(false),
      );
    }
    if (immich == null) {
      return LoginPage(
        onLoggedIn: (i) {
          storage.delete(key: 'withoutServer');
          setState(() => _immich = i);
        },
        onWithoutServer: () => _useWithoutServer(true),
      );
    }
    return GalleryPage(immich: immich, onLogout: _logout);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoggedIn,
    required this.onWithoutServer,
  });

  final ValueChanged<Immich> onLoggedIn;
  final VoidCallback onWithoutServer;

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
      final server = Immich.address(_server.text);
      final uri = Uri.parse(server);
      if (uri.scheme == 'http' &&
          !Immich.isPrivate(uri) &&
          !await _allowPlainHttp(l)) {
        setState(() => _busy = false);
        return;
      }
      final immich = await Immich.login(
        server,
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

  /// HTTP to an address on the internet: password and token would travel readable (D-78).
  Future<bool> _allowPlainHttp(AppLocalizations l) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.loginInsecureTitle),
          content: Text(l.loginInsecureText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.loginInsecureContinue),
            ),
          ],
        ),
      ) ==
      true;

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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : widget.onWithoutServer,
            child: Text(l.loginWithoutServer),
          ),
        ],
      ),
    );
  }
}
