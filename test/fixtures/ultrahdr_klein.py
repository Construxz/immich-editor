"""Erzeugt ultrahdr_klein.jpg: ein winziges Ultra-HDR-JPEG im Aufbau, den Androids
Bitmap.compress mit Gain-Map schreibt (JFIF, eigenes EXIF, XMP mit Gain-Map-Verzeichnis,
MPF hinter den Tabellen, Gain-Map-JPEG angehängt). Nur Pillow + Standardbibliothek."""
import io, struct
from PIL import Image

def jpeg(farbe, groesse):
    b = io.BytesIO(); Image.new('RGB', groesse, farbe).save(b, 'JPEG', quality=90); return b.getvalue()

def segment(marker, daten):
    return b'\xff' + bytes([marker]) + struct.pack('>H', len(daten) + 2) + daten

def kopf_und_rest(j):  # Segmente vor SOS (ohne SOI) und Rest ab SOS
    i = 2
    while j[i + 1] != 0xDA:
        i += 2 + struct.unpack('>H', j[i + 2:i + 4])[0]
    return j[2:i], j[i:]

gainmap = jpeg((128, 128, 128), (4, 2))
exif = Image.Exif(); exif[0x0128] = 2
xmp = ('<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
       '<rdf:Description xmlns:Container="http://ns.google.com/photos/1.0/container/" '
       'xmlns:Item="http://ns.google.com/photos/1.0/container/item/" '
       'xmlns:hdrgm="http://ns.adobe.com/hdr-gain-map/1.0/" hdrgm:Version="1.0"><Container:Directory><rdf:Seq>'
       '<rdf:li rdf:parseType="Resource"><Container:Item Item:Semantic="Primary" Item:Mime="image/jpeg"/></rdf:li>'
       f'<rdf:li rdf:parseType="Resource"><Container:Item Item:Semantic="GainMap" Item:Mime="image/jpeg" Item:Length="{len(gainmap)}"/></rdf:li>'
       '</rdf:Seq></Container:Directory></rdf:Description></rdf:RDF></x:xmpmeta>')
kopf, rest = kopf_und_rest(jpeg((200, 30, 30), (8, 4)))
app0 = kopf[:18]  # JFIF
vor_mpf = (app0 + segment(0xE1, exif.tobytes()) + segment(0xE1, b'http://ns.adobe.com/xap/1.0/\0' + xmp.encode())
           + kopf[18:])

def mpf(primaer, gm_offset):  # MM-TIFF mit drei Tags, MP-Entry dahinter
    tiff = b'MM\0*' + struct.pack('>I', 8) + struct.pack('>H', 3)
    tiff += struct.pack('>HHI4s', 0xB000, 7, 4, b'0100')
    tiff += struct.pack('>HHII', 0xB001, 4, 1, 2)
    tiff += struct.pack('>HHII', 0xB002, 7, 32, 50) + struct.pack('>I', 0)
    tiff += struct.pack('>IIIHH', 0x030000, primaer, 0, 0, 0) + struct.pack('>IIIHH', 0, len(gainmap), gm_offset, 0, 0)
    return segment(0xE2, b'MPF\0' + tiff)

laenge_mpf = len(mpf(0, 0))
primaer = 2 + len(vor_mpf) + laenge_mpf + len(rest)
mpf_tiff = 2 + len(vor_mpf) + 4 + 4  # Marker, Länge, "MPF\0"
datei = b'\xff\xd8' + vor_mpf + mpf(primaer, primaer - mpf_tiff) + rest + gainmap
open('test/fixtures/ultrahdr_klein.jpg', 'wb').write(datei)
print(len(datei), 'Bytes, Gain-Map ab', primaer)
