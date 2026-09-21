import 'package:flutter/material.dart';

import '../editor/editor_seite.dart';
import '../foto.dart';
import '../server/immich.dart';

// ponytail: nur die neuesten 200 Server-Fotos; Blättern und lokale Fotos in M2.
class GalerieSeite extends StatefulWidget {
  const GalerieSeite({
    super.key,
    required this.immich,
    required this.onAbmelden,
  });

  final Immich immich;
  final VoidCallback onAbmelden;

  @override
  State<GalerieSeite> createState() => _GalerieSeiteState();
}

class _GalerieSeiteState extends State<GalerieSeite> {
  late Future<List<Foto>> _fotos = widget.immich.fotos();

  Future<void> _oeffnen(Foto foto) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorSeite(immich: widget.immich, foto: foto),
      ),
    );
    setState(() => _fotos = widget.immich.fotos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor for Immich'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: widget.onAbmelden,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _fotos,
        builder: (context, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          final fotos = s.data;
          if (fotos == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: fotos.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _oeffnen(fotos[i]),
              child: Image.network(
                widget.immich.miniatur(fotos[i].id).toString(),
                headers: widget.immich.kopf,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}
