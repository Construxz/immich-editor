# Renders the test chart in the emulator through the app's renderer (D-73), one recipe per run —
# many in one run brought the emulator down; now and then a render comes back empty (transparent),
# then it is repeated. Needs the app and its test APK installed:
#   (cd android && ./gradlew installDebug installDebugAndroidTest)   with ANDROID_SERIAL=emulator-5554
#   bash tool/chartdump.sh OUTDIR shadows-1 '{"shadows":-1}' shadows1 '{"shadows":1}' ...
# Then: python tool/readchart.py --distance OUTDIR/shadows-1.png google-copy.jpg
export MSYS_NO_PATHCONV=1
A="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
OUT="$1"; shift; mkdir -p "$OUT"
while [ $# -gt 0 ]; do
  n="$1"; j="$2"; shift 2
  for t in 1 2 3; do
    "$A" -s emulator-5554 shell am instrument -w -e class io.github.construxz.photoeditor.ChartDump \
      -e recipes "'{\"$n\":$j}'" io.github.construxz.photoeditor.test/androidx.test.runner.AndroidJUnitRunner \
      </dev/null | grep -q "^OK" || { echo "failed: $n"; continue; }
    "$A" -s emulator-5554 pull "/sdcard/Android/data/io.github.construxz.photoeditor/files/chart/$n.png" "$OUT/" </dev/null >/dev/null
    python -c "import sys, numpy; from PIL import Image; sys.exit(int(numpy.asarray(Image.open(sys.argv[1]).convert('RGBA'))[..., 3].min() < 255))" "$OUT/$n.png" && break
    echo "empty: $n, again"
  done
done
