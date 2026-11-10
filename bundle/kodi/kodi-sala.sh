#!/usr/bin/env bash
# Instalador del "Kodi de la sala" (Mac; también funciona en Linux).
#
# Lo llama el instalador de Luk Home con --kodi (Windows: $KODI=1):
#   curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- <IP> <PIN> ... --kodi
# También se puede correr solo:  bash bundle/kodi/kodi-sala.sh <IP> [--zip ARCHIVO] [--url URL] [--dry-run] [--reemplazar-kodi]
#
# Instala ÚNICA Y EXCLUSIVAMENTE Kodi con el build de la sala (todas las configuraciones, addons, repositorios,
# skin, menú, fondo, favoritos, fuentes, mandos y teclas). Sin credenciales: las cuentas (TorBox, etc.) hay que
# iniciarlas otra vez en Kodi. NO toca ninguna otra app, ni el launcher (Luk Home), ni el dock, ni ajustes del TV.
#
# Pasos: 1) adb  2) paquete  3) conexión  4) revisión del TV (ABI/API)  5) Kodi (instala si falta)
#        6) respaldo del Kodi que ya tenga el TV  7) copia del build  8) verificación
#
# Opciones:
#   --zip ARCHIVO      usa un kodi-sala.zip que ya está en la computadora (no descarga nada del repo)
#   --url URL          descarga el paquete desde otra URL
#   --dry-run          revisa todo y respalda, pero NO instala ni copia nada al TV
#   --reemplazar-kodi  si el TV tiene un Kodi incompatible (64 bits o versión vieja/nueva), lo desinstala
#                      (después del respaldo) y pone el Kodi 21.3 de 32 bits de la sala
#   --sin-respaldo     no respalda el Kodi que ya tenga el TV (por defecto SÍ se respalda)
# Repo privado: exporta GH_TOKEN (o GITHUB_TOKEN) con permiso de lectura, o ten "gh" con sesión iniciada.
# Variables: KODI_ADB (otro adb), KODI_SALA_DIR (carpeta de trabajo, por defecto ~/.kodi-sala).

set -u
main() {
  # ======== CONFIGURACIÓN DEL REPO (cambiar al publicar) ========
  local GITHUB_REPO="coplic/luk-home-installer"   # mismo repo del instalador de Luk Home
  local RELEASE_TAG="kodi-build-2026-11-09"        # Release con el paquete (más de 100 MB: no va en git)
  local ASSET="kodi-sala.zip"                  # nombre del archivo subido al Release
  local ZIP_SHA="9759a041fcd896e5304521fe7fb6555ace5225d3da1cb2618f47e8f6d9ca4187"   # sha256 de kodi-sala.zip (303.169.032 bytes)
  # ===============================================================
  local PKG_URL_DEFAULT="https://github.com/$GITHUB_REPO/releases/latest/download/$ASSET"
  [ "$RELEASE_TAG" = latest ] || PKG_URL_DEFAULT="https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/$ASSET"

  local KPKG=org.xbmc.kodi KVER=21.3 KVCODE=2103000
  local APK_V7_URL="https://mirrors.kodi.tv/releases/android/arm/kodi-21.3-Omega-armeabi-v7a.apk"
  local APK_V7_SHA="12d75e895649f68f217e42c2d881a94fd3177d7b9a7937825852aed545520cc8"

  local IP="" ZIP="" URL="" DRY=0 REPLACE=0 NOBACKUP=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --zip) ZIP="${2:-}"; shift ;;
      --zip=*) ZIP="${1#--zip=}" ;;
      --url) URL="${2:-}"; shift ;;
      --url=*) URL="${1#--url=}" ;;
      --dry-run|--simular) DRY=1 ;;
      --reemplazar-kodi) REPLACE=1 ;;
      --sin-respaldo) NOBACKUP=1 ;;
      -h|--help) sed -n '2,24p' "$0" 2>/dev/null; return 0 ;;
      -*) echo "Opción desconocida: $1"; return 2 ;;
      *) [ -z "$IP" ] && IP="$1" || { echo "Sobra el dato: $1"; return 2; } ;;
    esac; shift
  done
  [ -n "$IP" ] || { echo "Falta la IP del TV. Uso: ... | bash -s -- 192.168.0.x [--zip kodi-sala.zip]"; return 2; }
  local SERIAL="$IP"; case "$IP" in *:*) ;; *) SERIAL="$IP:5555" ;; esac

  local B="" G="" Y="" R="" C="" N=""
  if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'; fi
  local WORK="${KODI_SALA_DIR:-$HOME/.kodi-sala}" TS; TS=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$WORK/logs" "$WORK/apk" "$WORK/respaldos" || { echo "No pude crear $WORK"; return 1; }
  local LOG="$WORK/logs/instalacion-${IP%%:*}-$TS.log"; : > "$LOG"
  say()  { printf '%s\n' "$*"; printf '%s\n' "$*" | sed $'s/\033\\[[0-9;]*m//g' >> "$LOG"; }
  logq() { printf '%s\n' "$*" >> "$LOG"; }
  paso() { say ""; say "${B}${C}[${KODI_PASO_PREFIX:-}$1/8] $2${N}"; }
  bien() { say "   ${G}✔${N} $*"; }
  aviso(){ say "   ${Y}!${N} $*"; }
  sim()  { say "   ${Y}[simulación]${N} $*"; }
  local STAGE=""
  falla() {
    say ""; say "${R}${B}  ✘ NO SE PUDO TERMINAR${N}"; say "${R}  $1${N}"; [ $# -ge 2 ] && say "  $2"
    [ -n "$STAGE" ] && rm -rf "$STAGE"
    say ""; say "  Detalle técnico: $LOG"; say "  Se puede volver a correr la misma línea; es seguro repetirla."
    exit 1
  }
  trap 'falla "Se canceló (Ctrl+C)."' INT TERM
  sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
  unz() { if command -v unzip >/dev/null 2>&1; then unzip -qo "$1" -d "$2"; else python3 -m zipfile -e "$1" "$2"; fi; }
  dl()  { curl -fL --retry 3 --connect-timeout 20 -sS ${3:+-H "$3"} -o "$2" "$1" >>"$LOG" 2>&1; }
  local ADB=""
  A() { "$ADB" -s "$SERIAL" "$@" </dev/null; }
  S() { A shell "$@" 2>/dev/null | tr -d '\r'; }

  say "${B}Kodi de la sala — instalador${N}  (TV: $IP)"
  [ "$DRY" = 1 ] && say "${Y}Modo simulación: no se instala ni se copia nada al TV.${N}"

  # ---------- 1. adb ----------
  paso 1 "Preparando adb"
  if [ -n "${KODI_ADB:-}" ]; then ADB="$KODI_ADB"
  elif command -v adb >/dev/null 2>&1; then ADB=$(command -v adb)
  else
    local os; case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) falla "Sistema no soportado: $(uname -s)" ;; esac
    ADB="$WORK/platform-tools/adb"
    if ! "$ADB" version >/dev/null 2>&1; then
      say "   Descargando platform-tools de Google..."
      dl "https://dl.google.com/android/repository/platform-tools-latest-$os.zip" "$WORK/pt.zip" || falla "No se pudo descargar platform-tools."
      unz "$WORK/pt.zip" "$WORK" || falla "No se pudo descomprimir platform-tools."; rm -f "$WORK/pt.zip"; chmod +x "$ADB"
    fi
  fi
  "$ADB" version >/dev/null 2>&1 || falla "adb no funciona en esta computadora ($ADB)."
  bien "adb listo ($("$ADB" version | sed -n 's/^Version //p' | head -1))"

  # ---------- 2. paquete ----------
  paso 2 "Paquete del build de la sala"
  local PZ="$WORK/kodi-sala.zip"
  if [ -n "$ZIP" ]; then
    ZIP="${ZIP/#\~/$HOME}"; [ -f "$ZIP" ] || falla "No encuentro el paquete local: $ZIP"
    PZ="$ZIP"; bien "Paquete local: $ZIP"
  elif [ -z "$URL" ] && [ -f "$PZ" ] && [ "$(sha "$PZ")" = "$ZIP_SHA" ]; then
    bien "Paquete ya descargado antes (en $PZ, sha256 correcto)"
  else
    local TOK="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -z "$URL" ] && case "$GITHUB_REPO" in __*) true ;; *) false ;; esac; then
      falla "Este instalador todavía no tiene el repo configurado (__GITHUB_REPO__)." "Usa --zip con el paquete local, o --url."
    fi
    rm -f "$PZ"
    if [ -n "$URL" ]; then
      say "   Descargando $URL ..."; dl "$URL" "$PZ" ${TOK:+"Authorization: Bearer $TOK"} || falla "No se pudo descargar el paquete ($URL)."
    elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      say "   Descargando con gh ($GITHUB_REPO, $RELEASE_TAG)..."
      local tagarg=""; [ "$RELEASE_TAG" = latest ] || tagarg="$RELEASE_TAG"
      gh release download $tagarg -R "$GITHUB_REPO" -p "$ASSET" -O "$PZ" --clobber >>"$LOG" 2>&1 || falla "gh no pudo bajar $ASSET de $GITHUB_REPO."
    elif [ -n "$TOK" ]; then
      say "   Descargando del repo privado (token)..."
      local api="https://api.github.com/repos/$GITHUB_REPO/releases/latest" aid
      [ "$RELEASE_TAG" = latest ] || api="https://api.github.com/repos/$GITHUB_REPO/releases/tags/$RELEASE_TAG"
      aid=$(curl -fsSL -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github+json" "$api" 2>>"$LOG" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(a["id"] for a in d["assets"] if a["name"]==sys.argv[1]))' "$ASSET" 2>>"$LOG") \
        || falla "No encontré $ASSET en el Release de $GITHUB_REPO." "Revisa el token (permiso Contents: read) y que el Release tenga el archivo."
      curl -fL --retry 3 -sS -H "Authorization: Bearer $TOK" -H "Accept: application/octet-stream" -o "$PZ" \
        "https://api.github.com/repos/$GITHUB_REPO/releases/assets/$aid" >>"$LOG" 2>&1 || falla "No se pudo descargar $ASSET."
    else
      say "   Descargando $PKG_URL_DEFAULT ..."
      dl "$PKG_URL_DEFAULT" "$PZ" || falla "No se pudo descargar el paquete del Kodi de la sala." "Está en el Release $RELEASE_TAG de $GITHUB_REPO ($ASSET). Revisa el internet y repite; o usa --zip con el archivo."
    fi
    bien "Paquete descargado ($(( $(wc -c < "$PZ") / 1048576 )) MB)"
  fi
  if [ -z "$ZIP" ] || [ "${KODI_ZIP_CHECK:-1}" = 1 ]; then
    local zs; zs=$(sha "$PZ")
    if [ "$zs" = "$ZIP_SHA" ]; then bien "Paquete verificado (sha256 ${ZIP_SHA:0:12}…)"
    elif [ -n "$ZIP" ]; then aviso "El paquete local no es el publicado (sha256 ${zs:0:12}…); se usa igual porque lo elegiste con --zip"
    else rm -f "$PZ"; falla "El paquete descargado no coincide con el sha256 publicado." "Vuelve a correr la línea (se descarga de nuevo)."; fi
  fi
  STAGE=$(mktemp -d "$WORK/stage.XXXXXX")
  say "   Descomprimiendo..."
  unz "$PZ" "$STAGE" || falla "El paquete está dañado (no se pudo descomprimir)."
  local ROOT; ROOT=$(dirname "$(find "$STAGE" -maxdepth 3 -name MANIFEST.txt | head -1)")
  [ -d "$ROOT/.kodi/addons" ] && [ -d "$ROOT/.kodi/userdata" ] || falla "El paquete está incompleto (faltan .kodi/addons o .kodi/userdata)."
  if [ -f "$ROOT/SHA256SUMS" ]; then
    say "   Comprobando archivos (SHA256SUMS)..."
    ( cd "$ROOT" && if command -v shasum >/dev/null 2>&1; then shasum -a 256 -c -s SHA256SUMS; else sha256sum -c --quiet SHA256SUMS; fi ) >>"$LOG" 2>&1 \
      || falla "Algún archivo del paquete llegó dañado (SHA256SUMS no coincide)."
  fi
  local NADD; NADD=$(find "$ROOT/.kodi/addons" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  local KB; KB=$(du -sk "$ROOT/.kodi" | awk '{print $1}')
  bien "Build $(sed -n 's/^version=//p' "$ROOT/MANIFEST.txt"): $NADD addons, $((KB / 1024)) MB"

  # ---------- 3. conexión ----------
  paso 3 "Conectando con el TV $IP"
  "$ADB" start-server >/dev/null 2>&1
  local start now st out asked=0 fails=0; start=$(date +%s)
  while :; do
    out=$("$ADB" connect "$SERIAL" 2>&1 </dev/null | tr -d '\r'); logq "connect: $out"
    st=$("$ADB" -s "$SERIAL" get-state 2>&1 </dev/null | tr -d '\r'); now=$(date +%s)
    case "$st" in
      device) break ;;
      *unauthorized*) [ "$asked" = 1 ] || { say "   ${Y}${B}>>> MIRA EL TV: acepta \"¿Permitir depuración USB?\" (marca Permitir siempre) <<<${N}"; asked=1; }
        [ $((now - start)) -lt 120 ] || falla "No se aceptó el permiso de depuración en el TV."; sleep 3 ;;
      *) fails=$((fails + 1)); [ "$fails" -lt 5 ] || falla "No encuentro el TV en $IP." "TV prendido, misma red WiFi y Depuración ADB activada."; sleep 3 ;;
    esac
  done
  bien "Conectado"

  # ---------- 4. revisión ----------
  paso 4 "Revisando el TV (sin cambiar nada)"
  local SDK MODEL MAKER ABIS FREE
  SDK=$(S getprop ro.build.version.sdk); MODEL=$(S getprop ro.product.model); MAKER=$(S getprop ro.product.manufacturer)
  ABIS=$(S getprop ro.product.cpu.abilist); [ -n "$ABIS" ] || ABIS=$(S getprop ro.product.cpu.abi)
  [ -n "$SDK" ] || falla "El TV no responde a ADB."
  bien "$MAKER $MODEL — Android API $SDK — ABI: $ABIS"
  [ "$SDK" -ge 21 ] || falla "Android demasiado viejo (API $SDK). Kodi 21 necesita API 21+."
  case ",$ABIS," in *,armeabi-v7a,*) ;; *) falla "Este TV no acepta apps de 32 bits ARM (armeabi-v7a)." "El build de la sala trae emuladores y addons de 32 bits; no funcionaría completo aquí." ;; esac
  FREE=$(S df -k /sdcard | awk 'NR>1 {v=$4} END {print v+0}')
  logq "free_kb=$FREE need_kb=$KB"
  [ "${FREE:-0}" -eq 0 ] || [ "$FREE" -gt $((KB + 250000)) ] || falla "No hay espacio: libres $((FREE/1024)) MB, se necesitan ~$(((KB+250000)/1024)) MB."
  local FOCUS; FOCUS=$(S dumpsys window | grep -m1 mCurrentFocus)
  logq "focus: $FOCUS"
  case "$FOCUS" in *org.xbmc.kodi*) falla "Kodi está abierto en el TV ahora mismo." "Ciérralo (o espera a que terminen de ver) y repite la línea." ;; esac

  # ---------- 5. Kodi ----------
  paso 5 "Kodi $KVER (32 bits, oficial de kodi.tv)"
  local HAVE IVC IABI need_install=0 need_uninstall=0
  HAVE=$(S pm path $KPKG | grep -c package:)
  if [ "$HAVE" -gt 0 ]; then
    IVC=$(S dumpsys package $KPKG | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
    IABI=$(S dumpsys package $KPKG | sed -n 's/.*primaryCpuAbi=\([^ ]*\).*/\1/p' | head -1)
    say "   Kodi ya instalado: versionCode ${IVC:-?}, ABI ${IABI:-?}"
    if [ "$IABI" != armeabi-v7a ] || [ "${IVC:-0}" -lt 2100000 ] || [ "${IVC:-0}" -ge 2200000 ]; then
      [ "$REPLACE" = 1 ] || falla "El Kodi del TV no es compatible con el build (ABI $IABI, versión $IVC)." \
        "Repite con --reemplazar-kodi: se respalda, se desinstala ese Kodi y se pone el $KVER de 32 bits."
      need_uninstall=1; need_install=1
    elif [ "${IVC:-0}" -lt "$KVCODE" ]; then need_install=1; say "   Se actualiza a $KVER (conserva sus datos hasta el paso 7)."
    else bien "Kodi compatible; no se reinstala"; fi
  else need_install=1; say "   Kodi no está instalado: se instala."; fi
  local APK="$WORK/apk/kodi-21.3-Omega-armeabi-v7a.apk"
  if [ "$need_install" = 1 ]; then
    if [ ! -f "$APK" ] || [ "$(sha "$APK")" != "$APK_V7_SHA" ]; then
      say "   Descargando Kodi $KVER armeabi-v7a de mirrors.kodi.tv..."
      dl "$APK_V7_URL" "$APK.part" || falla "No se pudo descargar Kodi de mirrors.kodi.tv."
      mv "$APK.part" "$APK"
    fi
    [ "$(sha "$APK")" = "$APK_V7_SHA" ] || { rm -f "$APK"; falla "El APK de Kodi descargado no coincide con el SHA256 oficial."; }
    bien "APK verificado (sha256 ${APK_V7_SHA:0:12}…)"
  fi

  # ---------- 6. respaldo ----------
  paso 6 "Respaldo del Kodi que ya tiene el TV"
  local KD=/sdcard/Android/data/$KPKG/files BK=""
  if [ "$HAVE" -gt 0 ] && [ "$(S "[ -d $KD/.kodi ] && echo y")" = y ]; then
    if [ "$NOBACKUP" = 1 ]; then aviso "Sin respaldo (--sin-respaldo)"
    else
      BK="$WORK/respaldos/kodi-${IP%%:*}-$TS.tar"
      say "   Guardando $KD/.kodi (sin miniaturas ni caché) en $BK ..."
      A exec-out "cd $KD && tar -cf - --exclude=.kodi/userdata/Thumbnails --exclude=.kodi/addons/packages --exclude=.kodi/temp .kodi" > "$BK" 2>>"$LOG"
      tar -tf "$BK" >/dev/null 2>&1 && [ -s "$BK" ] || falla "El respaldo salió mal; no se cambió nada en el TV." "Revisa espacio en la computadora."
      bien "Respaldo: $BK ($(( $(wc -c < "$BK") / 1048576 )) MB)"
    fi
  else bien "No había datos de Kodi que respaldar"; fi

  if [ "$DRY" = 1 ]; then
    [ "$need_uninstall" = 1 ] && sim "adb uninstall $KPKG"
    [ "$need_install" = 1 ] && sim "adb install -r -g $(basename "$APK")"
    sim "pm clear $KPKG (solo datos de Kodi), permisos de almacenamiento de Kodi, abrir/cerrar Kodi, copiar el build ($NADD addons, $((KB/1024)) MB) con adb push + tar"
    rm -rf "$STAGE"; say ""; say "${G}${B}Simulación terminada; el TV no se tocó.${N}  Registro: $LOG"; return 0
  fi

  # ---------- 7. instalación ----------
  paso 7 "Instalando"
  if [ "$need_uninstall" = 1 ]; then
    A uninstall $KPKG >>"$LOG" 2>&1 || falla "No se pudo desinstalar el Kodi incompatible."; HAVE=0; bien "Kodi anterior desinstalado"
  fi
  if [ "$need_install" = 1 ]; then
    say "   Instalando Kodi (si el TV muestra un aviso de Play Protect, NO lo aceptes a ciegas: mira qué dice)..."
    out=$(A install -r -g "$APK" 2>&1 | tr -d '\r'); logq "install: $out"
    case "$out" in *Success*) bien "Kodi $KVER instalado" ;; *) falla "La instalación de Kodi falló: $(printf '%s' "$out" | tail -1)" "Si el TV mostró Play Protect, revisa la pantalla." ;; esac
  fi
  # Espacio para el archivo temporal en /data/local/tmp
  local DFREE; DFREE=$(S df -k /data | awk 'NR>1 {v=$4} END {print v+0}')
  [ "${DFREE:-0}" -eq 0 ] || [ "$DFREE" -gt $((KB * 2 + 200000)) ] || falla "No hay espacio en el TV: libres $((DFREE/1024)) MB, se necesitan ~$(((KB*2+200000)/1024)) MB."
  say "   Preparando el archivo para el TV..."
  local TARF="$WORK/kodi-sala.tar"; rm -f "$TARF"
  if tar --version 2>/dev/null | grep -qi bsdtar; then
    COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -cf "$TARF" -C "$ROOT" .kodi 2>>"$LOG" || falla "No se pudo preparar el archivo tar."
  else
    tar --no-xattrs -cf "$TARF" -C "$ROOT" .kodi 2>>"$LOG" || tar -cf "$TARF" -C "$ROOT" .kodi 2>>"$LOG" || falla "No se pudo preparar el archivo tar."
  fi
  # Kodi limpio: borra SOLO los datos de Kodi (el respaldo ya está en la computadora). Ninguna otra app.
  A shell am force-stop $KPKG >/dev/null 2>&1
  out=$(S pm clear $KPKG); logq "pm clear: $out"
  # Permisos de Kodi (solo Kodi): almacenamiento y, en Android 11+, "acceso a todos los archivos" (sin esto Kodi se cierra)
  A shell pm grant $KPKG android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1
  A shell pm grant $KPKG android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1
  [ "$SDK" -ge 30 ] && A shell appops set $KPKG MANAGE_EXTERNAL_STORAGE allow >>"$LOG" 2>&1
  # Kodi crea su propia carpeta (con su dueño correcto); luego se cierra
  say "   Abriendo Kodi unos segundos para que cree su carpeta..."
  A shell am start -n $KPKG/.Splash >>"$LOG" 2>&1
  local i; for i in $(seq 1 45); do [ "$(S "[ -d $KD ] && echo y")" = y ] && break; sleep 2; done
  [ "$(S "[ -d $KD ] && echo y")" = y ] || falla "Kodi no creó su carpeta (¿salió algún aviso en el TV?)."
  sleep 4; A shell am force-stop $KPKG >/dev/null 2>&1; sleep 1
  if [ "$SDK" -ge 30 ]; then
    # Android 11+: adb no puede escribir dentro de un .kodi creado por Kodi; si existe se aparta (lo borra el próximo "pm clear")
    if [ "$(S "[ -d $KD/.kodi ] && echo y")" = y ]; then
      A shell "mv $KD/.kodi $KD/.kodi-inicial-$TS" >>"$LOG" 2>&1 || falla "No se pudo preparar la carpeta de Kodi."
    fi
  else
    A shell "rm -rf $KD/.kodi" >>"$LOG" 2>&1
  fi
  say "   Copiando el build al TV ($NADD addons, $((KB/1024)) MB)..."
  A push "$TARF" /data/local/tmp/kodi-sala.tar >>"$LOG" 2>&1 || falla "Falló la copia del build al TV."
  rm -f "$TARF"
  say "   Descomprimiendo en el TV..."
  out=$(S "mkdir -p $KD/.kodi && cd $KD && tar -xf /data/local/tmp/kodi-sala.tar && echo TAR_OK"); logq "tar: $out"
  A shell rm -f /data/local/tmp/kodi-sala.tar >/dev/null 2>&1
  case "$out" in *TAR_OK*) ;; *) falla "Falló la descompresión en el TV: $(printf '%s' "$out" | tail -1)" ;; esac
  # Kodi tiene que poder escribir en sus archivos (los creó adb, no Kodi)
  [ "$SDK" -ge 30 ] && A shell "chmod -R a+rwX $KD/.kodi" >>"$LOG" 2>&1
  bien "Build copiado"

  # ---------- 8. verificación ----------
  paso 8 "Verificando"
  local tvn tvk; tvn=$(S "ls $KD/.kodi/addons | wc -l" | tr -d ' ')
  tvk=$(S "du -sk $KD/.kodi | cut -f1")
  [ "$tvn" -ge "$NADD" ] || falla "En el TV hay $tvn addons y el build trae $NADD."
  bien "Addons en el TV: $tvn (build: $NADD); tamaño $(( ${tvk:-0} / 1024 )) MB"
  S "[ -f $KD/.kodi/userdata/guisettings.xml ] && grep -o 'skin.arctic.zephyr.mod' $KD/.kodi/userdata/guisettings.xml | head -1" | grep -q arctic \
    && bien "Skin: Arctic Zephyr Mod" || aviso "No pude confirmar la skin en guisettings.xml"
  rm -rf "$STAGE"; STAGE=""
  say ""
  say "${G}${B}  ✔ LISTO: Kodi con el build de la sala instalado en $IP${N}"
  say "  Ábrelo desde Apps del TV. La primera vez tarda un poco (regenera miniaturas)."
  say "  Cuentas a iniciar de nuevo dentro de Kodi: TorBox en POV, Umbrella y ResolveURL (el paquete no lleva credenciales)."
  [ -n "$BK" ] && say "  Respaldo del Kodi anterior: $BK"
  say "  Registro: $LOG"
  trap - INT TERM
}
main "$@"
