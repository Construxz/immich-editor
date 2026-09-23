import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../foto.dart';
import '../server/immich.dart';
import 'abgleich.dart';
import 'betrachter.dart';
import 'geraet.dart';
import 'kacheln.dart';

/// Der Reiter „Bibliothek" wie in der Immich-App: „Auf diesem Gerät" mit allen Ordnern — auch
/// denen, die die Immich-App nicht sichert (D-36).
class Bibliothek extends StatefulWidget {
  const Bibliothek({super.key, required this.immich, required this.stand});

  final Immich immich;
  final Abgleich stand;

  @override
  State<Bibliothek> createState() => _BibliothekState();
}

class _BibliothekState extends State<Bibliothek> {
  late Future<List<AssetPathEntity>> _ordner = geraetOrdner();

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(() {
        _ordner = geraetOrdner();
      });
      await _ordner;
    },
    child: FutureBuilder(
      future: _ordner,
      builder: (context, s) {
        final ordner = s.data;
        if (ordner == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Auf diesem Gerät',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final o in ordner)
              _OrdnerZeile(
                key: ValueKey(o.id),
                ordner: o,
                immich: widget.immich,
                stand: widget.stand,
              ),
          ],
        );
      },
    ),
  );
}

/// Ein Ordner: erstes Foto, Name, Anzahl und wie viel davon gesichert ist.
class _OrdnerZeile extends StatefulWidget {
  const _OrdnerZeile({
    super.key,
    required this.ordner,
    required this.immich,
    required this.stand,
  });

  final AssetPathEntity ordner;
  final Immich immich;
  final Abgleich stand;

  @override
  State<_OrdnerZeile> createState() => _OrdnerZeileState();
}

class _OrdnerZeileState extends State<_OrdnerZeile> {
  late final Future<List<AssetEntity>> _fotos = widget.ordner.assetCountAsync
      .then(
        (n) => n == 0 ? [] : widget.ordner.getAssetListRange(start: 0, end: n),
      );
  late final Future<Uint8List?> _vorn = _fotos.then(
    (f) => f.isEmpty
        ? null
        : f.first.thumbnailDataWithSize(const ThumbnailSize.square(160)),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _fotos,
    builder: (context, s) {
      final fotos = s.data ?? const [];
      final gesichert = fotos
          .where((a) => widget.stand.geraetGesichert.contains(a.id))
          .length;
      return ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 56,
            child: FutureBuilder(
              future: _vorn,
              builder: (context, b) => b.data == null
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    )
                  : Image.memory(b.data!, fit: BoxFit.cover),
            ),
          ),
        ),
        title: Text(widget.ordner.name),
        subtitle: s.data == null
            ? null
            : Text(
                gesichert == 0
                    ? '${fotos.length} Fotos · nicht in Immich'
                    : gesichert == fotos.length
                    ? '${fotos.length} Fotos · gesichert'
                    : '${fotos.length} Fotos · $gesichert gesichert',
              ),
        trailing: Icon(
          gesichert == 0 ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
          size: 20,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrdnerSeite(
              ordner: widget.ordner,
              immich: widget.immich,
              stand: widget.stand,
            ),
          ),
        ),
      );
    },
  );
}

/// Die Fotos eines Geräteordners; antippen öffnet den Betrachter.
class OrdnerSeite extends StatefulWidget {
  const OrdnerSeite({
    super.key,
    required this.ordner,
    required this.immich,
    required this.stand,
  });

  final AssetPathEntity ordner;
  final Immich immich;
  final Abgleich stand;

  @override
  State<OrdnerSeite> createState() => _OrdnerSeiteState();
}

class _OrdnerSeiteState extends State<OrdnerSeite> {
  late Future<List<AssetEntity>> _fotos = _laden();

  Future<List<AssetEntity>> _laden() async {
    final n = await widget.ordner.fetchPathProperties().then(
      (p) => (p ?? widget.ordner).assetCountAsync,
    );
    return n == 0 ? [] : widget.ordner.getAssetListRange(start: 0, end: n);
  }

  Future<void> _oeffnen(List<AssetEntity> fotos, int i) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BetrachterSeite(
          immich: widget.immich,
          anzahl: fotos.length,
          eintragBei: (j) async => (id: fotos[j].id, geraet: true),
          start: i,
        ),
      ),
    );
    // Es kann eine Kopie dazugekommen sein.
    if (mounted) {
      setState(() {
        _fotos = _laden();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(centerTitle: false, title: Text(widget.ordner.name)),
    body: FutureBuilder(
      future: _fotos,
      builder: (context, s) {
        final fotos = s.data;
        if (fotos == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return GridView.builder(
          gridDelegate: kachelRaster,
          itemCount: fotos.length,
          itemBuilder: (context, i) => FotoKachel(
            key: ValueKey(fotos[i].id),
            bild: GeraetMiniatur(fotos[i]),
            stapel: 1,
            ablage: widget.stand.geraetGesichert.contains(fotos[i].id)
                ? Ablage.beide
                : Ablage.geraet,
            gewaehlt: false,
            waehlt: false,
            onTap: () => _oeffnen(fotos, i),
            onLongPress: () {},
          ),
        );
      },
    ),
  );
}
