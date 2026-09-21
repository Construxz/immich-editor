# Steuerung der App im Emulator per adb, für Tests durch Agenten (Git Bash).
#   . tool/emu.sh            dann z. B.:  tippe Anpassen; bild vorher; oeffne testfoto-a-hdr4
# Standard ist der Emulator; das Telefon des Besitzers nur nach Rückfrage (S=-s <serial>).
# Getippt wird nur, wenn die App vorn ist — sonst landen Eingaben in anderen Apps.
export MSYS_NO_PATHCONV=1
A="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
S="${S:--s emulator-5554}"
D="${D:-${TEMP:-/tmp}/immich-editor-emu}"; mkdir -p "$D"

vorn() { "$A" $S shell dumpsys window | grep -q "mCurrentFocus.*io.github.construxz.photoeditor"; }
dump() { "$A" $S shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; "$A" $S shell cat /sdcard/ui.xml > "$D/ui.xml"; }

# mitte "Text" [n]: Mittelpunkt des n-ten Elements, dessen text/content-desc/hint den Text enthält
mitte() { python - "$1" "${2:-0}" "$D/ui.xml" <<'PY'
import re,sys
t,n,f=sys.argv[1],int(sys.argv[2]),sys.argv[3]
h=[m.group(0) for m in re.finditer(r'<node [^>]*>',open(f,encoding='utf-8').read()) if re.search(r'(text|content-desc|hint)="[^"]*'+re.escape(t),m.group(0))]
b=[int(x) for x in re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',h[n]).groups()]
print((b[0]+b[2])//2,(b[1]+b[3])//2)
PY
}
tippe() { vorn || { echo "App nicht vorn — kein Tipp"; return 1; }; dump; "$A" $S shell input tap $(mitte "$@"); }

# text "…": in das fokussierte Feld schreiben. Kommt nichts an, hängt oft Gboard:
#   "$A" $S shell ime reset
text() { local q; q=$(python -c "import sys; s=sys.argv[1].replace(' ','%s'); print(\"'\"+s.replace(\"'\",\"'\\''\")+\"'\")" "$1"); "$A" $S shell "input text $q"; }
bild() { "$A" $S exec-out screencap -p > "$D/$1.png"; echo "$D/$1.png"; }

# oeffne "dateiname": Galerie-Kacheln antippen, bis der Editor diesen Namen trägt
# (eine Kopie öffnet das Original — der Editor zeigt dann dessen Namen)
oeffne() {
  for i in $(seq 1 20); do dump; grep -q 'content-desc="Foto' "$D/ui.xml" && break; sleep 1; done
  local k
  for k in $(python -c "
import re
for m in re.finditer(r'content-desc=\"Foto[^\"]*\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', open(r'$D/ui.xml',encoding='utf-8').read()):
    a=[int(x) for x in m.groups()]; print(f'{(a[0]+a[2])//2},{(a[1]+a[3])//2}')"); do
    vorn || return 1; "$A" $S shell input tap ${k/,/ }
    for i in $(seq 1 15); do sleep 1; dump; grep -q 'Speichern' "$D/ui.xml" && break; done
    grep -q "$1" "$D/ui.xml" && { echo "offen: $1"; return 0; }
    "$A" $S shell input keyevent KEYCODE_BACK; sleep 2
  done; echo "nicht gefunden: $1"; return 1
}
