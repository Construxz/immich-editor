"""Generates ultrahdr_small.jpg: a tiny Ultra HDR JPEG with the layout Android's
Bitmap.compress writes with a gain map (JFIF, own EXIF, XMP with gain map directory,
MPF after the tables, gain map JPEG appended). Pillow + standard library only."""
import io, struct
from PIL import Image

def jpeg(color, size):
    b = io.BytesIO(); Image.new('RGB', size, color).save(b, 'JPEG', quality=90); return b.getvalue()

def segment(marker, data):
    return b'\xff' + bytes([marker]) + struct.pack('>H', len(data) + 2) + data

def head_and_rest(j):  # segments before SOS (without SOI) and rest from SOS on
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
head, rest = head_and_rest(jpeg((200, 30, 30), (8, 4)))
app0 = head[:18]  # JFIF
before_mpf = (app0 + segment(0xE1, exif.tobytes()) + segment(0xE1, b'http://ns.adobe.com/xap/1.0/\0' + xmp.encode())
              + head[18:])

def mpf(primary, gm_offset):  # MM-TIFF with three tags, MP entry after them
    tiff = b'MM\0*' + struct.pack('>I', 8) + struct.pack('>H', 3)
    tiff += struct.pack('>HHI4s', 0xB000, 7, 4, b'0100')
    tiff += struct.pack('>HHII', 0xB001, 4, 1, 2)
    tiff += struct.pack('>HHII', 0xB002, 7, 32, 50) + struct.pack('>I', 0)
    tiff += struct.pack('>IIIHH', 0x030000, primary, 0, 0, 0) + struct.pack('>IIIHH', 0, len(gainmap), gm_offset, 0, 0)
    return segment(0xE2, b'MPF\0' + tiff)

mpf_length = len(mpf(0, 0))
primary = 2 + len(before_mpf) + mpf_length + len(rest)
mpf_tiff = 2 + len(before_mpf) + 4 + 4  # marker, length, "MPF\0"
data = b'\xff\xd8' + before_mpf + mpf(primary, primary - mpf_tiff) + rest + gainmap
open('test/fixtures/ultrahdr_small.jpg', 'wb').write(data)
print(len(data), 'bytes, gain map at', primary)
