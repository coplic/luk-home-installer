#!/system/bin/sh
# Runs ON THE TV, started by install.sh / install.ps1 with:
#   adb shell sh /data/local/tmp/lukhome/tv-apply.sh
# Copies the files staged in /data/local/tmp/lukhome/ into Luk Home's private folder with run-as (debug build).
# Writes only inside com.ivantrj.glasslauncher; never touches other apps or settings.
# Theme folders listed in themes/remove.txt (old installer themes not in the client's list, and old names of
# renamed themes, e.g. halloween-terror -> terror since 2026-11-01c) are deleted.
# block-app-buttons.txt ("on"/"off", 2026-11-02): remote app-shortcut buttons blocked or normal.
# dock-style.txt ("oscuro"/"colores", 2026-11-02d): dock card style; absent = oscuro.
# Prints "LUK_APPLY_OK" on success, "LUK_APPLY_FAIL <what>" on failure, and always deletes the staging folder.
P=com.ivantrj.glasslauncher
D=${LUK_STAGE:-/data/local/tmp/lukhome}

done_() { rm -rf "$D"; }
fail() { echo "LUK_APPLY_FAIL $*"; done_; exit 1; }
# put <staged file> <path under files/>: the redirect is opened by the shell user, run-as only writes.
put() { run-as $P sh -c "cat > files/$2" < "$1" || fail "put $2"; }

[ -d "$D" ] || fail "no staging folder"
run-as $P mkdir -p files/themes files/tiles || fail "run-as (Luk Home not installed or not a debug build)"

n=0
if [ -f "$D/themes/order.txt" ]; then
  while read -r t; do
    [ -n "$t" ] || continue
    [ -d "$D/themes/$t" ] || continue
    run-as $P sh -c "mkdir -p files/themes/$t && rm -f files/themes/$t/*" </dev/null || fail "theme folder $t"
    for f in "$D/themes/$t"/*; do
      [ -f "$f" ] && put "$f" "themes/$t/${f##*/}"
    done
    n=$((n + 1))
  done < "$D/themes/order.txt"
  put "$D/themes/order.txt" themes/order.txt
  # list of the themes the installer has put on this TV (used on reruns to know what it may remove)
  [ -f "$D/themes/installed.txt" ] && put "$D/themes/installed.txt" themes/.instalador.txt
fi
echo "THEMES $n"

# remove.txt: theme folders the installer put here earlier and that are no longer in the client's list.
# Only plain theme slugs, never one that is in order.txt, never anything outside files/themes/.
r=0
if [ -f "$D/themes/remove.txt" ] && [ -f "$D/themes/order.txt" ]; then
  while read -r t; do
    case "$t" in ''|-*|*[!a-z0-9_-]*) continue ;; esac
    keep=0
    while read -r o; do [ "$o" = "$t" ] && keep=1; done < "$D/themes/order.txt"
    [ "$keep" = 1 ] && continue
    run-as $P rm -rf "files/themes/$t" </dev/null && r=$((r + 1))
  done < "$D/themes/remove.txt"
fi
echo "REMOVED $r"

k=0
for f in "$D"/tiles/*; do
  [ -f "$f" ] || continue
  put "$f" "tiles/${f##*/}"
  k=$((k + 1))
done
echo "TILEFILES $k"

# weather.txt (city of the weather pill): keep a unidad=/unit= line (°C/°F) the TV already had.
if [ -f "$D/weather.txt" ]; then
  run-as $P cat files/weather.txt </dev/null 2>/dev/null | while read -r l; do
    case "$l" in unidad=*|unit=*|UNIDAD=*|Unidad=*) printf '%s\n' "$l" ;; esac
  done > "$D/weather.keep" 2>/dev/null
  [ -s "$D/weather.keep" ] && cat "$D/weather.keep" >> "$D/weather.txt"
fi
for x in rotate.txt dock.txt theme.txt logo.png weather.txt block-app-buttons.txt dock-style.txt; do
  if [ -f "$D/$x" ]; then put "$D/$x" "$x"; echo "WROTE $x"; fi
done
if [ -f "$D/pin.txt" ]; then
  put "$D/pin.txt" pin.txt
  run-as $P chmod 600 files/pin.txt
  echo "WROTE pin.txt"
fi

done_
echo "LUK_APPLY_OK"
