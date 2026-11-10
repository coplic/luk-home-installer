#!/system/bin/sh
# Luk Home installer (--retroarch / $RETROARCH=1): deja RetroArch configurado como el TV del cuarto.
# Corre EN EL TV (adb shell sh /data/local/tmp/lukra/tv-retroarch.sh <paquete> <api> <abi>).
# El instalador ya copió aquí: ext/ (retroarch.cfg + autoconfig), ra/ (opciones de núcleos + hiscore.dat),
# cores/*.so (núcleos oficiales de buildbot.libretro.com) e info/*.info (fichas oficiales de núcleos).
# Nunca borra ni pisa ROMs, partidas (saves), estados (states) ni BIOS (system/): solo agrega.
P="$1"; SDK="${2:-30}"; CABI="${3:-armeabi-v7a}"
D=/data/local/tmp/lukra
SD=/storage/emulated/0
EXT=$SD/Android/data/$P/files
RA=$SD/RetroArch
ROMS=$SD/ROMs
TS=$(date +%Y%m%d-%H%M%S)
fail() { echo "RA_FAIL $*"; exit 1; }
[ -d "$D/ext" ] || fail "faltan los archivos en $D"
pm path "$P" 2>/dev/null | grep -q package: || fail "RetroArch ($P) no está instalado"

# Permisos de almacenamiento (solo RetroArch; targetSdk 28 = almacenamiento clásico)
pm grant "$P" android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1
pm grant "$P" android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1

# 1) Primera vez: RetroArch se abre una vez para crear sus carpetas, su retroarch.cfg y sacar sus recursos.
if [ ! -f "$EXT/retroarch.cfg" ]; then
  am start -n "$P/com.retroarch.browser.mainmenu.MainMenuActivity" >/dev/null 2>&1
  i=0; while [ $i -lt 60 ] && [ ! -f "$EXT/retroarch.cfg" ]; do sleep 2; i=$((i + 1)); done
  [ -f "$EXT/retroarch.cfg" ] || { am force-stop "$P"; fail "RetroArch no creó su configuración (¿hay un aviso en la pantalla del TV?)"; }
  # Espera a que termine de sacar sus recursos (menú, bases de datos): last_version = version_current
  i=0; while [ $i -lt 45 ]; do
    cur=$(grep '^bundle_assets_extract_version_current' "$EXT/retroarch.cfg" | cut -d'"' -f2)
    last=$(grep '^bundle_assets_extract_last_version' "$EXT/retroarch.cfg" | cut -d'"' -f2)
    [ -n "$cur" ] && [ "$cur" = "$last" ] && break
    sleep 2; i=$((i + 1))
  done
  sleep 3
  echo "RA_FIRSTRUN"
fi
am force-stop "$P"; sleep 1

# 2) Núcleos: el propio RetroArch los copia a su carpeta privada (CoreSideloadActivity oficial, exportada).
mkdir -p "$EXT/lukra-cores"
n=0; ok=0; okl=""; bad=""
for so in "$D"/cores/*.so; do
  [ -f "$so" ] || continue
  n=$((n + 1)); b=${so##*/}
  cp -f "$so" "$EXT/lukra-cores/$b" && chmod 666 "$EXT/lukra-cores/$b"
  t=$(date '+%m-%d %H:%M:%S.000')
  am start -n "$P/com.retroarch.browser.debug.CoreSideloadActivity" --es LIBRETRO "$EXT/lukra-cores/$b" >/dev/null 2>&1
  i=0; got=0
  while [ $i -lt 45 ]; do
    if logcat -d -v brief -T "$t" -s sideload 2>/dev/null | grep -q "Running RetroArch with core .*/$b"; then got=1; break; fi
    sleep 1; i=$((i + 1))
  done
  sleep 2; am force-stop "$P"; sleep 1
  if [ "$got" = 1 ]; then ok=$((ok + 1)); okl="$okl ${b%_libretro_android.so}"; else bad="$bad ${b%_libretro_android.so}"; fi
done
rm -rf "$EXT/lukra-cores"
echo "RA_CORES $ok/$n${okl:+ ok:$okl}${bad:+ FALLARON:$bad}"

# Copia que funciona aunque el archivo lo haya creado RetroArch (Android 11+): si no se puede escribir encima,
# el viejo se aparta con .lukold-<fecha> y se pone el nuevo.
put() {   # $1 origen  $2 destino
  if cat "$1" > "$2" 2>/dev/null; then :; else
    mv -f "$2" "$2.lukold-$TS" 2>/dev/null; cat "$1" > "$2" 2>/dev/null || return 1
  fi
  chmod 666 "$2" 2>/dev/null; return 0
}
mkd() { mkdir -p "$1" 2>/dev/null; touch "$1/.lukw" 2>/dev/null && { rm -f "$1/.lukw"; return 0; }
        mv "$1" "$1.lukold-$TS" 2>/dev/null; mkdir -p "$1" && chmod 777 "$1" 2>/dev/null; }

# 3) retroarch.cfg del cuarto. Se quedan los valores propios de este TV (ruta del APK, carpeta de núcleos,
#    versión de recursos, audio) y las fichas de núcleos van a $EXT/info.
CFG="$EXT/retroarch.cfg"; NEW="$D/retroarch.cfg.new"
KEEP="bundle_assets_src_path bundle_assets_dst_path bundle_assets_dst_path_subdir bundle_assets_extract_last_version bundle_assets_extract_version_current libretro_directory audio_out_rate"
pat="^(libretro_info_path"; for k in $KEEP; do pat="$pat|$k"; done; pat="$pat) = "
sed -e "s#com\.retroarch\.ra32#$P#g" -e "s#/nightly/android/latest/armeabi-v7a/#/nightly/android/latest/$CABI/#" "$D/ext/retroarch.cfg" \
  | grep -vE "$pat" > "$NEW"
for k in $KEEP; do grep -E "^$k = " "$CFG" 2>/dev/null | head -1 >> "$NEW"; done
echo "libretro_info_path = \"$EXT/info\"" >> "$NEW"
grep -q '^libretro_directory = ' "$NEW" || echo "libretro_directory = \"/data/user/0/$P/cores/\"" >> "$NEW"
put "$NEW" "$CFG" || fail "no se pudo escribir $CFG"

# 4) Mandos (autoconfig), fichas de núcleos, opciones de FCEUmm y MAME 2003-Plus, hiscore.dat
mkd "$EXT/autoconfig"; mkd "$EXT/autoconfig/android"; na=0
for f in "$D"/ext/autoconfig/*.cfg; do [ -f "$f" ] && put "$f" "$EXT/autoconfig/${f##*/}" && na=$((na + 1)); done
for f in "$D"/ext/autoconfig/android/*.cfg; do [ -f "$f" ] && put "$f" "$EXT/autoconfig/android/${f##*/}" && na=$((na + 1)); done
mkd "$EXT/info"; ni=0
for f in "$D"/info/*.info; do [ -f "$f" ] && put "$f" "$EXT/info/${f##*/}" && ni=$((ni + 1)); done
mkdir -p "$RA/config/FCEUmm" "$RA/config/MAME 2003-Plus" "$RA/system/mame2003-plus" \
  "$RA/saves" "$RA/states" "$RA/screenshots" "$RA/playlists" "$RA/cheats" "$RA/config/remaps" "$RA/downloads" "$RA/temp" "$RA/thumbnails" "$RA/logs"
no=0
put "$D/ra/config/FCEUmm/FCEUmm.opt" "$RA/config/FCEUmm/FCEUmm.opt" && no=$((no + 1))
put "$D/ra/config/MAME 2003-Plus/MAME 2003-Plus.opt" "$RA/config/MAME 2003-Plus/MAME 2003-Plus.opt" && no=$((no + 1))
hs=ya
[ -f "$RA/system/mame2003-plus/hiscore.dat" ] || { put "$D/ra/system/mame2003-plus/hiscore.dat" "$RA/system/mame2003-plus/hiscore.dat" && hs=nuevo; }

# 5) Carpetas de juegos (vacías; nunca se borra nada de lo que ya tengan)
for f in "Nintendo - NES" "Arcade - Mame 2003 Plus" "Nintendo - N64" "SNK - NEO GEO" "fbneo_1_0_0_3_best/games" "fbneo_1_0_0_3_best/samples"; do
  mkdir -p "$ROMS/$f"
done
[ "$SDK" -ge 30 ] && chmod -R a+rwX "$EXT/autoconfig" "$EXT/info" "$CFG" >/dev/null 2>&1
rm -rf "$D"
echo "RA_OK cores=$ok/$n autoconfig=$na info=$ni opt=$no hiscore=$hs roms=$ROMS"
