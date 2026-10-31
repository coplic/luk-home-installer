#!/usr/bin/env bash
# Instalador de Luk Home para clientes (Mac; también funciona en Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- <IP> <PIN> [TEMA]
#
#   <IP>    IP del Fire TV / Google TV (Ajustes > Mi Fire TV > Acerca de > Red)
#   <PIN>   4 números para bloquear Ajustes (o "sinpin" para no poner PIN)
#   [TEMA]  carpeta del tema inicial (por defecto: paisajes). Lista en bundle/themes/order.txt
#
# Opciones (después de la IP y el PIN):
#   --dry-run      hace todo (descargas, conexión, lecturas, respaldo) pero NO escribe nada en el TV ni pulsa teclas
#   --nuevo-dock   reescribe el dock (Stremio, IPTV Smarters, TizenTube) aunque Luk Home ya tenga uno
#
# Solo modo "launcher": no borra, no desinstala y no cambia ninguna app del cliente.
# Variables para pruebas: LUK_BUNDLE_URL (zip del repo), LUK_ADB (usar otro adb), LUK_HOME_DIR (carpeta de trabajo).

main() {
  set -u
  exec </dev/null   # el script llega por una tubería (curl | bash): nada debe leer de stdin

  # ---------- constantes ----------
  local REPO_ZIP="https://github.com/coplic/luk-home-installer/archive/refs/heads/main.zip"
  local PKG=com.ivantrj.glasslauncher
  local SERVICE="$PKG/$PKG.HomeButtonService"
  local DOCK_APPS="com.stremio.one com.nst.iptvsmarterstvbox io.gh.reisxd.tizentube.cobalt"
  local STOCK_HOMES="com.amazon.tv.launcher com.google.android.apps.tv.launcherx com.google.android.tvlauncher com.android.tv.launcher android"
  # Servicios de accesibilidad de otros launchers que capturan el botón Inicio (se quitan; las apps NO se desinstalan).
  local LAUNCHER_SVC_PKGS="com.spocky.projengmenu com.wolf.firelauncher com.wolf.firelaunchermanager com.lauritz.homebutton com.appgenz.launchermanager"

  # ---------- argumentos ----------
  local IP="" PIN="" THEME="" THEME_GIVEN=0 DRY=0 NEW_DOCK=0 a
  for a in "$@"; do
    case "$a" in
      --dry-run|--simular) DRY=1 ;;
      --nuevo-dock) NEW_DOCK=1 ;;
      -h|--help) sed -n '2,17p' "$0" 2>/dev/null || true; return 0 ;;
      -*) printf 'Opción desconocida: %s\n' "$a"; return 2 ;;
      *) if [ -z "$IP" ]; then IP="$a"; elif [ -z "$PIN" ]; then PIN="$a"; elif [ -z "$THEME" ]; then THEME="$a"; THEME_GIVEN=1
         else printf 'Sobra este dato: %s\n' "$a"; return 2; fi ;;
    esac
  done
  IP="${IP:-${LUK_IP:-}}"; PIN="${PIN:-${LUK_PIN:-}}"
  if [ -z "$THEME" ] && [ -n "${LUK_THEME:-}" ]; then THEME="$LUK_THEME"; THEME_GIVEN=1; fi
  THEME="${THEME:-paisajes}"

  # ---------- salida ----------
  local B="" G="" Y="" R="" C="" N=""
  if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'; fi
  local WORK="${LUK_HOME_DIR:-$HOME/.luk-home}"
  local TS; TS=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$WORK/logs" || { echo "No pude crear $WORK"; return 1; }
  local LOG="$WORK/logs/instalacion-${IP:-sin-ip}-$TS.log"
  : > "$LOG"
  say()   { printf '%s\n' "$*"; printf '%s\n' "$*" | sed $'s/\033\\[[0-9;]*m//g' >> "$LOG"; }
  logq()  { printf '%s\n' "$*" >> "$LOG"; }
  NSTEP=7
  paso()  { say ""; say "${B}${C}[$1/$NSTEP] $2${N}"; }
  bien()  { say "   ${G}✔${N} $*"; }
  aviso() { say "   ${Y}!${N} $*"; }
  sim()   { say "   ${Y}[simulación]${N} $*"; }

  SERIAL="" ADB="" ACC_CHANGED=0 HOME_CHANGED=0 UOP_CHANGED=0 SUCCESS=0
  OLD_SVC="" OLD_EN="" OLD_HOME="" OLD_UOP="" BK="" STAGE="" BUNDLE=""
  USE_ACC=1 USE_UOP=0   # Fire OS 6: sin accesibilidad (Amazon no la deja correr), con "acceso de uso" (GET_USAGE_STATS)

  restore_acc() {
    [ "$ACC_CHANGED" = 1 ] || [ "$HOME_CHANGED" = 1 ] || [ "$UOP_CHANGED" = 1 ] || return 0
    say "   Devolviendo el TV como estaba (botón Inicio)..."
    if [ "$ACC_CHANGED" = 1 ]; then
      if [ -z "$OLD_SVC" ] || [ "$OLD_SVC" = null ]; then A shell settings delete secure enabled_accessibility_services >/dev/null 2>&1
      else A shell "settings put secure enabled_accessibility_services '$OLD_SVC'" >/dev/null 2>&1; fi
      if [ -z "$OLD_EN" ] || [ "$OLD_EN" = null ]; then A shell settings delete secure accessibility_enabled >/dev/null 2>&1
      else A shell settings put secure accessibility_enabled "$OLD_EN" >/dev/null 2>&1; fi
    fi
    if [ "$HOME_CHANGED" = 1 ] && [ -n "$OLD_HOME" ]; then A shell cmd package set-home-activity "$OLD_HOME" >/dev/null 2>&1; fi
    if [ "$UOP_CHANGED" = 1 ]; then A shell appops set "$PKG" GET_USAGE_STATS "${OLD_UOP:-default}" >/dev/null 2>&1; fi
    ACC_CHANGED=0; HOME_CHANGED=0; UOP_CHANGED=0
    say "   Listo: el botón Inicio quedó como antes."
  }
  falla() {
    say ""
    say "${R}${B}  ✘ NO SE PUDO TERMINAR${N}"
    say "${R}  $1${N}"
    [ $# -ge 2 ] && say "  $2"
    restore_acc
    [ -n "$STAGE" ] && rm -rf "$STAGE"
    say ""
    say "  Detalle técnico guardado en: $LOG"
    say "  Puedes volver a correr la misma línea cuando esté corregido; es seguro repetirla."
    exit 1
  }
  trap 'if [ "$SUCCESS" != 1 ]; then restore_acc; fi' EXIT
  trap 'say ""; falla "Se canceló la instalación (Ctrl+C)."' INT TERM

  A() { "$ADB" -s "$SERIAL" "$@" </dev/null; }
  S() { A shell "$@" 2>/dev/null | tr -d '\r'; }
  inlist() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
  sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
  unz() { if command -v unzip >/dev/null 2>&1; then unzip -qo "$1" -d "$2"; else python3 -m zipfile -e "$1" "$2"; fi; }
  dl() { curl -fL --retry 3 --connect-timeout 20 -sS -o "$2" "$1" >>"$LOG" 2>&1; }

  say ""
  say "${B}=================================================${N}"
  say "${B}   Instalador de Luk Home${N}"
  [ "$DRY" = 1 ] && say "${Y}   MODO SIMULACIÓN: no se cambia nada en el TV${N}"
  say "${B}=================================================${N}"

  # ---------- validar datos ----------
  case "$IP" in
    '') falla "Falta la IP del TV." "La línea debe terminar así: ... | bash -s -- 192.168.1.50 1234" ;;
  esac
  if ! printf '%s' "$IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]{1,5})?$'; then
    falla "La IP \"$IP\" no es válida." "Debe verse como 192.168.1.50 (Ajustes > Mi Fire TV > Acerca de > Red)."
  fi
  case "$PIN" in
    sinpin|none|-) PIN="" ;;
    '') falla "Falta el PIN (4 números)." "La línea debe terminar así: ... | bash -s -- $IP 1234" ;;
    *) printf '%s' "$PIN" | grep -Eq '^[0-9]{4}$' || falla "El PIN debe tener exactamente 4 números." ;;
  esac
  local PIN_HASH=""
  if [ -n "$PIN" ]; then
    PIN_HASH=$(printf '%s' "$PIN" | { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; } | awk '{print $1}')
  fi
  case "$IP" in *:*) SERIAL="$IP" ;; *) SERIAL="$IP:5555" ;; esac
  logq "ip=$IP theme=$THEME dry=$DRY new_dock=$NEW_DOCK pin_set=$([ -n "$PIN" ] && echo yes || echo no) os=$(uname -a)"

  # ---------- 1. herramientas ----------
  paso 1 "Preparando las herramientas (solo la primera vez tarda un poco)"
  command -v curl >/dev/null 2>&1 || falla "Esta computadora no tiene 'curl'."
  if [ -n "${LUK_ADB:-}" ]; then
    ADB="$LUK_ADB"
  else
    local os; case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) falla "Sistema no soportado: $(uname -s). Usa la versión de Windows (install.ps1)." ;; esac
    ADB="$WORK/platform-tools/adb"
    if ! "$ADB" version >/dev/null 2>&1; then
      say "   Descargando las herramientas de Google (platform-tools)..."
      rm -rf "$WORK/platform-tools" "$WORK/pt.zip"
      dl "https://dl.google.com/android/repository/platform-tools-latest-$os.zip" "$WORK/pt.zip" \
        || falla "No se pudo descargar platform-tools de Google." "Revisa que la computadora tenga internet."
      unz "$WORK/pt.zip" "$WORK" || falla "No se pudo descomprimir platform-tools."
      rm -f "$WORK/pt.zip"; chmod +x "$ADB" 2>/dev/null
    fi
  fi
  "$ADB" version >/dev/null 2>&1 || falla "La herramienta adb no funciona en esta computadora." "Ruta: $ADB"
  bien "adb listo ($("$ADB" version | sed -n 's/^Version //p' | head -1))"

  say "   Descargando Luk Home, temas e íconos..."
  rm -rf "$WORK/bundle" "$WORK/bundle.zip"; mkdir -p "$WORK/bundle"
  dl "${LUK_BUNDLE_URL:-$REPO_ZIP}" "$WORK/bundle.zip" || falla "No se pudo descargar el paquete de Luk Home." "Revisa el internet de la computadora y vuelve a intentar."
  unz "$WORK/bundle.zip" "$WORK/bundle" || falla "El paquete descargado está dañado. Vuelve a correr la línea."
  rm -f "$WORK/bundle.zip"
  BUNDLE=$(dirname "$(dirname "$(find "$WORK/bundle" -path '*/bundle/apks/luk-home.apk' | head -1)")")
  [ -f "$BUNDLE/apks/luk-home.apk" ] || falla "El paquete descargado está incompleto (falta luk-home.apk)."
  if [ -f "$BUNDLE/SHA256SUMS" ]; then
    local want file
    while read -r want file; do
      case "$file" in apks/*) [ "$(sha "$BUNDLE/$file")" = "$want" ] || falla "El archivo $file llegó dañado. Vuelve a correr la línea." ;; esac
    done < "$BUNDLE/SHA256SUMS"
  fi
  bien "Paquete listo ($(grep -c . "$BUNDLE/themes/order.txt") temas)"
  if ! grep -qx "$THEME" "$BUNDLE/themes/order.txt"; then
    aviso "El tema \"$THEME\" no existe; uso \"paisajes\". Temas: $(tr '\n' ' ' < "$BUNDLE/themes/order.txt")"
    THEME=paisajes; THEME_GIVEN=1
  fi

  # ---------- 2. conexión ----------
  paso 2 "Conectando con el TV $IP"
  "$ADB" start-server >/dev/null 2>&1
  local start now out state kind="" asked=0 refused=0 unreach=0
  start=$(date +%s)
  while :; do
    out=$("$ADB" connect "$SERIAL" 2>&1 </dev/null | tr -d '\r'); logq "connect: $out"
    state=$("$ADB" -s "$SERIAL" get-state 2>&1 </dev/null | tr -d '\r'); logq "state: $state"
    now=$(date +%s)
    case "$state" in
      device) break ;;
      *unauthorized*)
        kind=unauth
        if [ "$asked" = 0 ] || [ $(( (now - start) % 30 )) -lt 3 ]; then
          say ""
          say "   ${Y}${B}>>> MIRA LA PANTALLA DEL TV <<<${N}"
          say "   ${Y}Aparece \"¿Permitir depuración USB?\" (Allow USB debugging?).${N}"
          say "   ${Y}Marca \"Permitir siempre desde esta computadora\" y pulsa ${B}Permitir / Aceptar / OK${N}${Y} con el control.${N}"
          say "   Esperando... (hasta 2 minutos)"
          asked=1
        fi
        [ $((now - start)) -lt 120 ] || falla "No se aceptó el permiso en el TV a tiempo." \
          "Vuelve a correr la línea y, cuando salga el aviso en el TV, marca \"Permitir siempre\" y pulsa Permitir/OK."
        sleep 3 ;;
      *offline*) kind=offline; "$ADB" disconnect "$SERIAL" >/dev/null 2>&1; sleep 2
        [ $((now - start)) -lt 120 ] || falla "El TV responde pero la conexión queda \"offline\"." "Apaga y prende la Depuración ADB en el TV y vuelve a intentar." ;;
      *)
        case "$out" in
          *refused*) kind=refused; refused=$((refused + 1)) ;;
          *"timed out"*|*"No route"*|*unreachable*|*"Host is down"*|*"cannot connect"*|*"failed to connect"*) kind=unreach; unreach=$((unreach + 1)) ;;
          *) kind=other; unreach=$((unreach + 1)) ;;
        esac
        if [ "$refused" -ge 4 ]; then
          falla "El TV en $IP contesta, pero la Depuración ADB está apagada (o esa IP no es el TV)." \
            "En el TV: Ajustes > Mi Fire TV > Opciones para desarrolladores > Depuración ADB: ACTIVADO. Revisa también la IP."
        fi
        if [ "$unreach" -ge 4 ]; then
          falla "No encuentro ningún TV en $IP." \
            "Revisa que el TV esté prendido, que la IP sea correcta y que la computadora esté en el MISMO WiFi que el TV."
        fi
        [ "$refused$unreach" = 01 ] || [ "$refused$unreach" = 10 ] && say "   Buscando el TV... (TV prendido, mismo WiFi, Depuración ADB activada)"
        sleep 4 ;;
    esac
  done
  [ "$kind" = unauth ] && bien "Permiso aceptado en el TV"
  bien "Conectado"

  # ---------- 3. revisión y respaldo ----------
  paso 3 "Revisando el TV (sin cambiar nada)"
  local SDK FOS MODEL MAKER PLATFORM APK_NAME TVKIND
  SDK=$(S getprop ro.build.version.sdk); FOS=$(S getprop ro.build.version.fireos)
  MODEL=$(S getprop ro.product.model); MAKER=$(S getprop ro.product.manufacturer)
  [ -n "$SDK" ] || falla "El TV no responde a los comandos de ADB." "Desconecta y vuelve a correr la línea."
  if S pm path com.amazon.tv.launcher | grep -q package:; then PLATFORM="Fire TV (Fire OS ${FOS:-?})"
  elif S pm path com.google.android.apps.tv.launcherx | grep -q package: || S pm path com.google.android.tvlauncher | grep -q package:; then PLATFORM="Google TV / Android TV"
  else
    PLATFORM="Android"
    TVKIND=$(S pm list features | grep -c -E 'android.software.leanback$|android.hardware.type.television$')
    [ "${TVKIND:-0}" -gt 0 ] || falla "El aparato en $IP no es un TV ($MAKER $MODEL)." "Revisa la IP en el TV: Ajustes > Mi Fire TV > Acerca de > Red."
  fi
  if [ "$SDK" -ge 30 ]; then APK_NAME=luk-home.apk
  elif [ "$SDK" -ge 28 ]; then APK_NAME=luk-home-fos7.apk
  elif [ "$SDK" -ge 25 ]; then APK_NAME=luk-home-fos6.apk   # Fire OS 6 (Android 7.1)
  else falla "Este TV es demasiado viejo para Luk Home (Android API $SDK)." "Luk Home necesita Fire OS 6 o más nuevo (Fire TV Stick 4K, Fire TV Cube, Stick 2.ª gen. o más nuevos; Android 7.1 o más nuevo)."; fi
  bien "$MAKER $MODEL — $PLATFORM, API $SDK → $APK_NAME"
  # Android 7.1-8.1: Luk Home vigila la app de enfrente con "acceso de uso". En Fire OS 6 Amazon no deja correr
  # servicios de accesibilidad instalados por fuera (A11yAuthorizer), así que ahí solo se usa el acceso de uso.
  if [ "$SDK" -lt 28 ]; then USE_UOP=1; case "$PLATFORM" in Fire*) USE_ACC=0 ;; esac; fi

  local FREE; FREE=$(S df -k /data | awk 'NR>1 {v=$4} END {print v+0}')
  if [ "${FREE:-0}" -gt 0 ] && [ "$FREE" -lt 60000 ]; then
    falla "El TV casi no tiene espacio libre ($((FREE / 1024)) MB)." "Se necesitan unos 60 MB. Borra caché de alguna app o desinstala algo que no use, y repite."
  fi
  [ "${FREE:-0}" -gt 0 ] && bien "Espacio libre: $((FREE / 1024)) MB"

  OLD_SVC=$(S settings get secure enabled_accessibility_services)
  OLD_EN=$(S settings get secure accessibility_enabled)
  OLD_HOME=$(S cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)
  case "$OLD_HOME" in */*) ;; *) OLD_HOME="" ;; esac
  local INSTALLED; INSTALLED=" $(S pm list packages | sed 's/^package://' | tr '\n' ' ') "
  local LUK_PRESENT=0 LUK_SHA="" HAS_DOCK=0 HAS_THEME=0
  if inlist "$PKG" "$INSTALLED"; then
    LUK_PRESENT=1
    OLD_UOP=$(S appops get "$PKG" GET_USAGE_STATS | sed -n 's/^GET_USAGE_STATS: \([a-z]*\).*/\1/p' | head -1)
    LUK_SHA=$(S sha256sum "$(S pm path "$PKG" | head -1 | sed 's/^package://')" | awk '{print $1}')   # Fire OS 6 no tiene sha256sum: vacío = se reinstala (conserva los datos)
    S run-as "$PKG" ls files/dock.txt | grep -q '^files/dock.txt$' && HAS_DOCK=1
    S run-as "$PKG" ls files/theme.txt | grep -q '^files/theme.txt$' && HAS_THEME=1
    bien "Luk Home ya estaba instalado (se actualiza sin perder nada)"
  fi

  BK="$WORK/respaldos/${IP%%:*}-$TS"; [ "$DRY" = 1 ] && BK="$BK-simulacion"
  mkdir -p "$BK"
  {
    echo "fecha=$TS ip=$IP modelo=$MAKER $MODEL plataforma=$PLATFORM api=$SDK apk=$APK_NAME"
    echo "enabled_accessibility_services=$OLD_SVC"
    echo "accessibility_enabled=$OLD_EN"
    echo "home=$OLD_HOME"
    echo "get_usage_stats=${OLD_UOP:-default}"
    echo "luk_instalado=$LUK_PRESENT luk_sha256=$LUK_SHA"
  } > "$BK/antes.txt"
  printf '%s\n' "$INSTALLED" | tr ' ' '\n' | grep . > "$BK/paquetes.txt"
  [ "$HAS_DOCK" = 1 ] && S run-as "$PKG" cat files/dock.txt > "$BK/dock-antes.txt"
  bien "Respaldo de la configuración guardado en la computadora"
  logq "backup=$BK old_svc=$OLD_SVC old_en=$OLD_EN old_home=$OLD_HOME old_uop=${OLD_UOP:-default} use_acc=$USE_ACC use_uop=$USE_UOP"

  # Nuevo valor de accesibilidad: quita solo los redirects de otros launchers y el nuestro, conserva el resto.
  local NEW_SVC="" REMOVED="" s spkg
  while read -r s; do
    case "$s" in ''|null) continue ;; esac
    spkg="${s%%/*}"
    if [ "$spkg" = "$PKG" ]; then continue; fi
    if inlist "$spkg" "$LAUNCHER_SVC_PKGS" || printf '%s' "$spkg" | grep -qiE 'launcher|projengmenu' \
       || { [ -n "$OLD_HOME" ] && [ "$spkg" = "${OLD_HOME%%/*}" ]; }; then
      REMOVED="$REMOVED $s"
    else NEW_SVC="${NEW_SVC:+$NEW_SVC:}$s"; fi
  done <<EOS
$(printf '%s' "$OLD_SVC" | tr ':' '\n')
EOS
  NEW_SVC="${NEW_SVC:+$NEW_SVC:}$SERVICE"
  if [ "$USE_ACC" = 0 ]; then NEW_SVC="$OLD_SVC"; REMOVED=""; fi   # Fire OS 6: la accesibilidad no se toca
  [ -n "$REMOVED" ] && aviso "Otro launcher controlaba el botón Inicio:${REMOVED}. Se reemplaza por Luk Home (la app NO se desinstala)."
  local SET_HOME=0
  if [ -n "$OLD_HOME" ] && ! inlist "${OLD_HOME%%/*}" "$STOCK_HOMES $PKG"; then SET_HOME=1; fi

  # ---------- 4. instalar ----------
  paso 4 "Instalando Luk Home"
  local APK="$BUNDLE/apks/$APK_NAME" WANT; WANT=$(sha "$APK")
  if [ "$LUK_PRESENT" = 1 ] && [ "$LUK_SHA" = "$WANT" ]; then
    bien "Ya tiene la versión más nueva"
  elif [ "$DRY" = 1 ]; then
    sim "adb install -r -g $APK_NAME ($(( $(wc -c < "$APK") / 1024 )) KB)"
  else
    case "$PLATFORM" in Google*) say "   (Si en el TV sale un aviso de Play Protect, elige \"Instalar de todas formas\".)" ;; esac
    out=$(A install -r -g "$APK" 2>&1 | tr -d '\r'); logq "install: $out"
    case "$out" in
      *Success*) bien "Luk Home instalado" ;;
      *UPDATE_INCOMPATIBLE*|*SIGNATURES*) falla "Este TV ya tiene otro Luk Home con una firma distinta." "Desinstálalo desde Ajustes > Aplicaciones > Luk Home y vuelve a correr la línea." ;;
      *OLDER_SDK*) falla "Esta versión de Luk Home no es compatible con este TV (API $SDK)." ;;
      *INSUFFICIENT_STORAGE*) falla "El TV no tiene espacio para instalar Luk Home." "Libera espacio y vuelve a correr la línea." ;;
      *) falla "La instalación de Luk Home falló." "Mensaje del TV: $(printf '%s' "$out" | tail -1)" ;;
    esac
  fi

  # ---------- 5. archivos ----------
  paso 5 "Copiando temas, íconos, dock y PIN"
  STAGE=$(mktemp -d "${TMPDIR:-/tmp}/lukstage.XXXXXX")/lukhome
  mkdir -p "$STAGE/themes" "$STAGE/tiles"
  cp -R "$BUNDLE/themes/." "$STAGE/themes/"
  cp "$BUNDLE/tv-apply.sh" "$STAGE/tv-apply.sh"
  [ -f "$BUNDLE/logo.png" ] && cp "$BUNDLE/logo.png" "$STAGE/logo.png"   # logo de la marca (debajo de Temas/Ajustes)
  printf '20\n' > "$STAGE/rotate.txt"
  local p name ndock=0 missing="" ntile=0
  for p in "$BUNDLE"/tiles/*.png; do
    p=$(basename "$p" .png)
    if inlist "$p" "$INSTALLED"; then cp "$BUNDLE/tiles/$p.png" "$BUNDLE/tiles/$p.txt" "$STAGE/tiles/"; ntile=$((ntile + 1)); fi
  done
  if [ "$HAS_DOCK" = 1 ] && [ "$NEW_DOCK" = 0 ]; then
    bien "El dock ya existía: se deja como está (para reescribirlo: --nuevo-dock)"
  else
    printf '# Apps del inicio, en orden\n' > "$STAGE/dock.txt"
    for p in $DOCK_APPS; do
      name=$(cat "$BUNDLE/tiles/$p.txt" 2>/dev/null || echo "$p")
      if inlist "$p" "$INSTALLED"; then echo "$p" >> "$STAGE/dock.txt"; ndock=$((ndock + 1)); else missing="$missing, $name"; fi
    done
    bien "Dock: $ndock app(s) en el inicio; las demás quedan en \"Otras apps\""
    [ -n "$missing" ] && aviso "No están instaladas (no van al dock):${missing#,}"
  fi
  if [ "$THEME_GIVEN" = 1 ] || [ "$HAS_THEME" = 0 ]; then printf '%s\n' "$THEME" > "$STAGE/theme.txt"; bien "Tema inicial: $(cat "$BUNDLE/themes/$THEME/name.txt")"
  else bien "Se mantiene el tema que ya tenía el TV"; fi
  [ -n "$PIN" ] && printf '%s\n' "$PIN_HASH" > "$STAGE/pin.txt"
  local nth njpg kb
  nth=$(grep -c . "$STAGE/themes/order.txt"); njpg=$(find "$STAGE/themes" -name '*.jpg' | wc -l | tr -d ' ')
  kb=$(du -sk "$STAGE" | cut -f1)
  logq "stage=$STAGE themes=$nth jpg=$njpg tiles=$ntile kb=$kb files=$(find "$STAGE" -maxdepth 1 | tr '\n' ' ')"
  if [ "$DRY" = 1 ]; then
    bash -n "$STAGE/tv-apply.sh" 2>>"$LOG" || falla "tv-apply.sh tiene un error de sintaxis."
    sim "adb push lukhome/ → /data/local/tmp/ ($nth temas, $njpg fotos, $ntile íconos, $kb KB)"
    sim "adb shell sh /data/local/tmp/lukhome/tv-apply.sh  (escribe: themes/, tiles/, rotate.txt$( [ -f "$STAGE/logo.png" ] && echo ', logo.png')$( [ -f "$STAGE/dock.txt" ] && echo ', dock.txt')$( [ -f "$STAGE/theme.txt" ] && echo ', theme.txt')$( [ -n "$PIN" ] && echo ', pin.txt'))"
    [ -f "$STAGE/dock.txt" ] && sim "dock.txt = $(grep -v '^#' "$STAGE/dock.txt" | tr '\n' ' ')"
  else
    A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
    say "   Copiando $nth temas ($((kb / 1024)) MB)..."
    out=$(A push "$STAGE" /data/local/tmp/ 2>&1 | tr -d '\r'); logq "push: $out"
    case "$out" in *error*|*failed*|*"No space"*) falla "No se pudieron copiar los archivos al TV." "$(printf '%s' "$out" | tail -1)" ;; esac
    out=$(A shell sh /data/local/tmp/lukhome/tv-apply.sh 2>&1 | tr -d '\r'); logq "apply: $out"
    case "$out" in *LUK_APPLY_OK*) ;; *) A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
      falla "No se pudieron guardar los archivos dentro de Luk Home." "$(printf '%s' "$out" | grep LUK_APPLY_FAIL | head -1)" ;; esac
    bien "$nth temas, $ntile íconos$( [ -f "$STAGE/logo.png" ] && echo ', logo'), rotación 20 s$( [ -n "$PIN" ] && echo ', PIN guardado')"
  fi
  rm -rf "$(dirname "$STAGE")"; STAGE=""

  # ---------- 6. botón Inicio ----------
  paso 6 "Haciendo que el botón Inicio abra Luk Home"
  if [ "$USE_UOP" = 1 ]; then
    if [ "$OLD_UOP" = allow ]; then bien "Acceso de uso ya estaba permitido"
    elif [ "$DRY" = 1 ]; then sim "appops set $PKG GET_USAGE_STATS allow   (antes: ${OLD_UOP:-default})"
    else
      UOP_CHANGED=1
      A shell appops set "$PKG" GET_USAGE_STATS allow >>"$LOG" 2>&1
      bien "Acceso de uso permitido (así Luk Home ve cuándo aparece el inicio de Amazon)"
    fi
  fi
  if [ "$USE_ACC" = 0 ]; then
    bien "Fire OS 6: no usa accesibilidad (Amazon no la permite en apps instaladas por fuera)"
  elif [ "$OLD_SVC" = "$NEW_SVC" ] && [ "$OLD_EN" = 1 ]; then
    bien "Ya estaba activado"
  elif [ "$DRY" = 1 ]; then
    sim "settings put secure enabled_accessibility_services $NEW_SVC   (antes: $OLD_SVC)"
    sim "settings put secure accessibility_enabled 1   (antes: $OLD_EN)"
  else
    ACC_CHANGED=1
    A shell "settings put secure enabled_accessibility_services '$NEW_SVC'" >>"$LOG" 2>&1
    A shell settings put secure accessibility_enabled 1 >>"$LOG" 2>&1
    bien "Activado"
  fi
  if [ "$SET_HOME" = 1 ]; then
    if [ "$DRY" = 1 ]; then sim "cmd package set-home-activity $PKG/.HomeActivity   (antes: $OLD_HOME)"
    else HOME_CHANGED=1; A shell cmd package set-home-activity "$PKG/.HomeActivity" >>"$LOG" 2>&1; bien "Luk Home es ahora la pantalla de inicio (antes: ${OLD_HOME%%/*})"; fi
  fi

  # ---------- 7. comprobación ----------
  paso 7 "Comprobando"
  if [ "$DRY" = 1 ]; then
    sim "abrir Luk Home (am start --ez reload true) y pulsar Inicio para comprobar"
    SUCCESS=1
    say ""
    say "${G}${B}  SIMULACIÓN TERMINADA SIN ERRORES — no se cambió nada en el TV.${N}"
    say "  Respaldo de lectura: $BK"
    say "  Registro: $LOG"
    return 0
  fi
  local v_svc v_en v_pin v_jpg v_theme v_uop
  if [ "$USE_ACC" = 1 ]; then
    v_svc=$(S settings get secure enabled_accessibility_services); v_en=$(S settings get secure accessibility_enabled)
    case ":$v_svc:" in *":$SERVICE:"*) ;; *) falla "El TV no aceptó el ajuste del botón Inicio." "Valor leído: $v_svc" ;; esac
    [ "$v_en" = 1 ] || falla "El TV no aceptó activar la accesibilidad (accessibility_enabled=$v_en)."
  fi
  if [ "$USE_UOP" = 1 ]; then
    v_uop=$(S appops get "$PKG" GET_USAGE_STATS)
    case "$v_uop" in *"GET_USAGE_STATS: allow"*) ;; *) falla "El TV no aceptó el acceso de uso para Luk Home." "Valor leído: $v_uop" ;; esac
  fi
  S pm path "$PKG" | grep -q package: || falla "Luk Home no aparece instalado."
  v_theme=$(S run-as "$PKG" cat files/theme.txt | head -1)
  v_jpg=$(S run-as "$PKG" ls "files/themes/${v_theme:-$THEME}" | grep -ci '\.jpg$')
  [ "${v_jpg:-0}" -ge 1 ] || falla "Los temas no quedaron guardados en el TV."
  if [ -n "$PIN" ]; then
    v_pin=$(S run-as "$PKG" cat files/pin.txt | head -1)
    [ "$v_pin" = "$PIN_HASH" ] || falla "El PIN no quedó guardado bien."
  fi
  bien "Ajustes, temas ($v_jpg fotos en \"${v_theme:-$THEME}\") y PIN comprobados"
  A shell am start -n "$PKG/.HomeActivity" --ez reload true >>"$LOG" 2>&1
  sleep 2
  A shell input keyevent KEYCODE_HOME >>"$LOG" 2>&1
  local top=""
  for _ in 1 2 3 4 5 6 7 8; do
    sleep 1.5
    top=$(S dumpsys activity activities | grep -m1 -E 'mResumedActivity|topResumedActivity')
    case "$top" in *"$PKG"*) break ;; esac
  done
  case "$top" in
    *"$PKG"*) bien "El botón Inicio abre Luk Home" ;;
    *) aviso "El TV todavía no muestra Luk Home. Pulsa el botón Inicio (la casita) del control; en Fire TV viejos tarda unos 5 segundos." ;;
  esac
  SUCCESS=1
  say ""
  say "${G}${B}  ██      ██  ███████  ████████  ██████  ${N}"
  say "${G}${B}  ██      ██  ██          ██    ██    ██ ${N}"
  say "${G}${B}  ██      ██  ███████     ██    ██    ██ ${N}"
  say "${G}${B}  ██      ██       ██     ██    ██    ██ ${N}"
  say "${G}${B}  ██████  ██  ███████     ██     ██████  ${N}"
  say ""
  say "${G}${B}  ¡LISTO! Luk Home quedó instalado en el TV.${N}"
  say "  • Botón \"Temas\" (arriba a la derecha) para cambiar el fondo."
  say "  • Ajustes queda protegido con PIN."
  say "  • Ya puedes cerrar esta ventana."
  say ""
  say "  (Respaldo: $BK)"
  return 0
}

main "$@"
exit $?
