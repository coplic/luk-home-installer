#!/system/bin/sh
# Runs ON THE TV, started by install.sh / install.ps1 with:
#   adb shell sh /data/local/tmp/lukhome/tv-apply.sh
# Copies the files staged in /data/local/tmp/lukhome/ into Luk Home's private folder with run-as (debug build).
# Writes only inside com.ivantrj.glasslauncher; never touches other apps or settings.
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
fi
echo "THEMES $n"

k=0
for f in "$D"/tiles/*; do
  [ -f "$f" ] || continue
  put "$f" "tiles/${f##*/}"
  k=$((k + 1))
done
echo "TILEFILES $k"

for x in rotate.txt dock.txt theme.txt logo.png; do
  if [ -f "$D/$x" ]; then put "$D/$x" "$x"; echo "WROTE $x"; fi
done
if [ -f "$D/pin.txt" ]; then
  put "$D/pin.txt" pin.txt
  run-as $P chmod 600 files/pin.txt
  echo "WROTE pin.txt"
fi

done_
echo "LUK_APPLY_OK"
