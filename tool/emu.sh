# Drive the app in the emulator via adb, for testing by agents (Git Bash).
#   . tool/emu.sh            then e.g.:  tap Anpassen; shot before; open_photo testfoto-a-hdr4
# Default is the emulator; the owner's phone only after asking (S=-s <serial>).
# Taps only go through while the app is in front — otherwise input lands in other apps.
export MSYS_NO_PATHCONV=1
A="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
S="${S:--s emulator-5554}"
D="${D:-${TEMP:-/tmp}/immich-editor-emu}"; mkdir -p "$D"

in_front() { "$A" $S shell dumpsys window | grep -q "mCurrentFocus.*io.github.construxz.photoeditor"; }
dump() { "$A" $S shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; "$A" $S shell cat /sdcard/ui.xml > "$D/ui.xml"; }

# center "text" [n]: center of the n-th element whose text/content-desc/hint contains the text
center() { python - "$1" "${2:-0}" "$D/ui.xml" <<'PY'
import re,sys
t,n,f=sys.argv[1],int(sys.argv[2]),sys.argv[3]
h=[m.group(0) for m in re.finditer(r'<node [^>]*>',open(f,encoding='utf-8').read()) if re.search(r'(text|content-desc|hint)="[^"]*'+re.escape(t),m.group(0))]
b=[int(x) for x in re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',h[n]).groups()]
print((b[0]+b[2])//2,(b[1]+b[3])//2)
PY
}
tap() { in_front || { echo "app not in front — no tap"; return 1; }; dump; "$A" $S shell input tap $(center "$@"); }

# text "…": type into the focused field. If nothing arrives, Gboard is often stuck:
#   "$A" $S shell ime reset
text() { local q; q=$(python -c "import sys; s=sys.argv[1].replace(' ','%s'); print(\"'\"+s.replace(\"'\",\"'\\''\")+\"'\")" "$1"); "$A" $S shell "input text $q"; }
shot() { "$A" $S exec-out screencap -p > "$D/$1.png"; echo "$D/$1.png"; }

# open_photo "filename": tap gallery tiles until the editor carries this name
# (a copy opens the original — the editor then shows its name)
open_photo() {
  for i in $(seq 1 20); do dump; grep -q 'content-desc="Foto' "$D/ui.xml" && break; sleep 1; done
  local k
  for k in $(python -c "
import re
for m in re.finditer(r'content-desc=\"Foto[^\"]*\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', open(r'$D/ui.xml',encoding='utf-8').read()):
    a=[int(x) for x in m.groups()]; print(f'{(a[0]+a[2])//2},{(a[1]+a[3])//2}')"); do
    in_front || return 1; "$A" $S shell input tap ${k/,/ }
    for i in $(seq 1 15); do sleep 1; dump; grep -q 'Speichern' "$D/ui.xml" && break; done
    grep -q "$1" "$D/ui.xml" && { echo "open: $1"; return 0; }
    "$A" $S shell input keyevent KEYCODE_BACK; sleep 2
  done; echo "not found: $1"; return 1
}
