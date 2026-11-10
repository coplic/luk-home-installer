#!/usr/bin/env bash
# Instalador de Luk Home para clientes (Mac; también funciona en Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- <IP> <PIN> [TEMA] [CIUDAD] [APPS]
#
#   <IP>    IP del Fire TV / Google TV (Ajustes > Mi Fire TV > Acerca de > Red)
#   <PIN>   4 números para bloquear Ajustes (o "sinpin" para no poner PIN)
#   [TEMA]  tema inicial (por defecto: paisajes), "todos", o una LISTA separada por comas
#           (ej. autos,mar,terror): solo esos temas van al TV y el primero es el inicial.
#           Nombres viejos que siguen valiendo: halloween-terror / halloween / horror = terror.
#           "aleatorio" = fotos de todos los temas mezcladas; "rotar" = un tema completo cada hora.
#           Van en el mismo lugar del TEMA (solos, o al principio de la lista: rotar,mar,autos).
#           Temas: carpetas de bundle/themes/ (las de order.txt + temas personalizados de clientes).
#   [CIUDAD] ciudad del botón del tiempo (arriba a la derecha): "Miami", "Madrid, España", "25.76,-80.19"
#           o "auto" (por internet, según la IP). Sin CIUDAD el TV se queda con la que tenga (al principio: auto).
#           Para poner ciudad sin elegir tema use TEMA "todos", o la variable: ... | CIUDAD="Miami" bash -s -- <IP> <PIN>
#           "-" = no cambiar la ciudad (sirve para poner APPS sin tocar el tiempo).
#   [APPS]  apps del cliente que también van al inicio, después de Stremio / IPTV Smarters / TizenTube, separadas
#           por comas y sin espacios: netflix,youtube,disney (o el paquete exacto, ej. com.netflix.ninja).
#           "todas" = todas las apps que ya tiene el cliente. Las que no estén instaladas se saltan con un aviso.
#           Si el TV ya tenía dock, se deja como está y estas se agregan al final. No instala ni toca las apps.
#           También: --apps netflix,youtube   o   APPS="netflix,youtube" antes de bash.
#
# Opciones (después de la IP y el PIN):
#   --dry-run        hace todo (descargas, conexión, lecturas, respaldo) pero NO escribe nada en el TV ni pulsa teclas
#   --nuevo-dock     reescribe el dock (Stremio, IPTV Smarters, TizenTube) aunque Luk Home ya tenga uno
#   --sin-actualizar no revisa si hay versión nueva de Stremio / TizenTube y deja la IPTV Smarters que tenga el TV
#                    aunque no sea la gratis de Troypoint (también LUK_NOUPDATE=1)
#   --sin-apps       no instala Stremio / IPTV Smarters / TizenTube si faltan en el TV (también LUK_SINAPPS=1)
#   --bloquear-botones    los botones de apps del control (Netflix, Prime, YouTube...) no hacen nada (LUK_BOTONES=bloquear)
#                         Google TV / onn: el botón no hace nada. Fire TV: si la app no está instalada, la página
#                         de la tienda que abre se cierra sola; las apps instaladas (ej. Prime Video) sí se abren.
#   --desbloquear-botones vuelve a dejar los botones como vienen (LUK_BOTONES=normal). Sin estas opciones no se cambia.
#   --estilo=oscuro       tarjetas del inicio oscuras con logo blanco y foco verde (el normal)
#   --estilo=colores      tarjetas de colores (rayas y brillo, logo en una burbuja). También ESTILO=colores antes de bash.
#                         Sin --estilo el TV se queda con el que tenga (uno nuevo empieza en oscuro). En el TV se cambia
#                         en el botón de Temas (paleta), sección "Estilo".
#   --retroarch      ADEMÁS instala o actualiza RetroArch oficial (libretro) con la configuración del TV del cuarto:
#                    retroarch.cfg, 7 núcleos (FinalBurn Neo, MAME 2003-Plus, FCEUmm, Mupen64Plus-Next, Flycast,
#                    Genesis Plus GX, PCSX ReARMed), opciones de FCEUmm y MAME 2003-Plus, mandos (autoconfig),
#                    hiscore.dat y carpetas de juegos vacías en /sdcard/ROMs. Sin ROMs ni BIOS. (También RETROARCH=1)
#   --kodi           ADEMÁS instala o actualiza Kodi 21.3 con el build de la sala (repos, addons y ajustes, sin
#                    cuentas: TorBox se vuelve a iniciar en POV, Umbrella y ResolveURL). BORRA los datos del Kodi que
#                    tenga el TV (antes los respalda en la computadora). (También KODI=1)
#   --reemplazar-kodi  con --kodi: si el TV tiene un Kodi incompatible (64 bits u otra versión), lo cambia.
#                    Sin --retroarch / --kodi no se toca RetroArch ni Kodi.
#
# Solo modo "launcher": no borra ni desinstala ninguna app del cliente (salvo cambiar una IPTV Smarters que no sea
# la gratis de Troypoint, ver abajo). Lo único que toca de apps es
# Stremio / TizenTube (paso 8): si ya están, las actualiza (adb install -r, conserva datos y sesiones) cuando
# hay una versión oficial más nueva con la misma firma; si no están, instala la oficial (adb install -g) para el
# procesador y el Android del TV, y las agrega al dock. IPTV Smarters: siempre la GRATIS 3.1.5.1 de Troypoint
# (MediaFire, sha256 fijo). Si falta, se instala; si el TV tiene otra (ej. la 4.0.6 de pago), se cambia por esa
# (se desinstala primero: se borran el login y las listas de Smarters); si ya es esa, no se toca. Nunca se
# actualiza a versiones de pago. Ninguna otra app se toca (RetroArch y Kodi solo con --retroarch / --kodi).
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
  # Temas renombrados "viejo:nuevo" (2026-11-01c: halloween-terror pasó a llamarse terror). Ver th_alias más abajo.
  local TH_RENAMED="halloween-terror:terror" TH_RENAMED_OLD="halloween-terror"

  # ---------- argumentos ----------
  local APPS_ENV="${APPS:-}"   # variable APPS= de afuera (antes de que la tape la local)
  local IP="" PIN="" THEME="" THEME_GIVEN=0 CITY="" CITY_SKIP=0 APPS="" APPS_NEXT=0 NPOS=0 DRY=0 NEW_DOCK=0 NOUPD="${LUK_NOUPDATE:-0}" NOAPPS="${LUK_SINAPPS:-0}" RETRO="${LUK_RETROARCH:-${RETROARCH:-0}}" KODI_OPT="${LUK_KODI:-${KODI:-0}}" KODI_REPL=0 BTN="${LUK_BOTONES:-}" ESTILO_ARG="${ESTILO:-${LUK_ESTILO:-}}" a
  for a in "$@"; do
    if [ "$APPS_NEXT" = 1 ]; then APPS="$a"; APPS_NEXT=0; continue; fi
    case "$a" in
      --dry-run|--simular) DRY=1 ;;
      --nuevo-dock) NEW_DOCK=1 ;;
      --bloquear-botones) BTN=bloquear ;;
      --desbloquear-botones|--botones-normales) BTN=normal ;;
      --sin-actualizar|--no-update) NOUPD=1 ;;
      --sin-apps|--no-apps|--no-instalar-apps) NOAPPS=1 ;;
      --retroarch|--retro|--emuladores) RETRO=1 ;;
      --kodi) KODI_OPT=1 ;;
      --reemplazar-kodi) KODI_OPT=1; KODI_REPL=1 ;;
      --apps) APPS_NEXT=1 ;;
      --apps=*) APPS="${a#--apps=}" ;;
      --estilo=*) ESTILO_ARG="${a#--estilo=}" ;;
      --oscuro) ESTILO_ARG=oscuro ;;
      --colores) ESTILO_ARG=colores ;;
      -h|--help) sed -n '2,57p' "$0" 2>/dev/null || true; return 0 ;;
      -|--) NPOS=$((NPOS + 1))
         case "$NPOS" in 2) PIN="-" ;; 4) CITY_SKIP=1 ;; 3) THEME="todos" ;; esac ;;   # "-" = no cambiar / por defecto
      -*) printf 'Opción desconocida: %s\n' "$a"; return 2 ;;
      *) NPOS=$((NPOS + 1))
         case "$NPOS" in
           1) IP="$a" ;; 2) PIN="$a" ;; 3) THEME="$a"; THEME_GIVEN=1 ;; 4) CITY="$a" ;; 5) APPS="$a" ;;
           *) printf 'Sobra este dato: %s\n' "$a"; return 2 ;;
         esac ;;
    esac
  done
  IP="${IP:-${LUK_IP:-}}"; PIN="${PIN:-${LUK_PIN:-}}"
  if [ -z "$THEME" ] && [ -n "${LUK_THEME:-}" ]; then THEME="$LUK_THEME"; THEME_GIVEN=1; fi
  case "$NOUPD" in 1|si|sí|yes|true) NOUPD=1 ;; *) NOUPD=0 ;; esac
  case "$NOAPPS" in 1|si|sí|yes|true) NOAPPS=1 ;; *) NOAPPS=0 ;; esac
  case "$RETRO" in 1|si|sí|yes|true) RETRO=1 ;; *) RETRO=0 ;; esac
  case "$KODI_OPT" in 1|si|sí|yes|true) KODI_OPT=1 ;; *) KODI_OPT=0 ;; esac
  # Estilo de las tarjetas del inicio (files/dock-style.txt, 2026-11-02d): oscuro | colores | vacío = no cambiar
  case "$(printf '%s' "$ESTILO_ARG" | tr 'A-Z' 'a-z' | tr -d ' ')" in
    '') ESTILO_ARG="" ;;
    oscuro|oscura|dark|negro|normal) ESTILO_ARG=oscuro ;;
    colores|color|colors|colorido|colorida|brillante) ESTILO_ARG=colores ;;
    *) printf 'Estilo desconocido: %s (usa --estilo=oscuro o --estilo=colores)\n' "$ESTILO_ARG"; return 2 ;;
  esac
  case "$(printf '%s' "$BTN" | tr 'A-Z' 'a-z')" in bloquear|on|si|sí|1|yes|true) BTN=on ;; normal|desbloquear|off|no|0|false) BTN=off ;; *) BTN="" ;; esac
  # Ciudad del tiempo (files/weather.txt): 4º dato, o CIUDAD= / LUK_CIUDAD=. Una línea, máx. 80 caracteres.
  [ -n "$CITY" ] || [ "$CITY_SKIP" = 1 ] || CITY="${CIUDAD:-${LUK_CIUDAD:-}}"
  CITY=$(printf '%s' "$CITY" | tr -d '\r\n\t' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | cut -c1-80)
  case "$(printf '%s' "$CITY" | tr 'A-Z' 'a-z')" in auto|automatica|automática|ip|internet) CITY=auto ;; esac
  # "-" / "igual" / "nada" = no cambiar la ciudad (sirve para poner APPS sin tocar el tiempo)
  case "$(printf '%s' "$CITY" | tr 'A-Z' 'a-z')" in -|_|igual|nada|ninguna|sin|sinciudad|no) CITY="" ;; esac
  # Apps extra para el inicio (5º dato, --apps, o APPS= / LUK_APPS=): nombres separados por comas, sin espacios
  [ -n "$APPS" ] || APPS="${LUK_APPS:-${APPS_ENV:-}}"
  APPS=$(printf '%s' "$APPS" | tr -d '\r\n\t ' | tr ';' ',' | sed 's/^,*//; s/,*$//')
  case "$(printf '%s' "$APPS" | tr 'A-Z' 'a-z')" in -|no|ninguna|nada) APPS="" ;; esac
  local EXTRA_PKGS="" EXTRA_NAMES="" DISABLED="" LAUNCHABLE="" THIRD="" KNOWN_PKGS="" RES_PKG="" RES_WHY="" APP_KNOWN=""

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
  NSTEP=$((8 + RETRO + KODI_OPT))   # 9.º / 10.º paso solo con --retroarch / --kodi
  paso()  { say ""; say "${B}${C}[$1/$NSTEP] $2${N}"; }
  bien()  { say "   ${G}✔${N} $*"; }
  aviso() { say "   ${Y}!${N} $*"; }
  sim()   { say "   ${Y}[simulación]${N} $*"; }

  NEW_INST="" APPS_TOUCHED=0 DOCK_TOUCHED=0
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
  trap 'say ""; if [ "$SUCCESS" = 1 ]; then rm -f "$WORK"/apps/*/*.part 2>/dev/null; say "  Se canceló la revisión de apps. Luk Home ya quedó instalado; las apps siguen como estaban."; exit 130; fi; falla "Se canceló la instalación (Ctrl+C)."' INT TERM

  A() { "$ADB" -s "$SERIAL" "$@" </dev/null; }
  S() { A shell "$@" 2>/dev/null | tr -d '\r'; }
  inlist() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
  sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
  unz() { if command -v unzip >/dev/null 2>&1; then unzip -qo "$1" -d "$2"; else python3 -m zipfile -e "$1" "$2"; fi; }
  dl() { curl -fL --retry 3 --connect-timeout 20 -sS -o "$2" "$1" >>"$LOG" 2>&1; }

  # ---------- apps extra en el inicio (APPS) ----------
  # Solo cambia la lista del dock de Luk Home (files/dock.txt). Nunca instala, desinstala, actualiza ni borra
  # datos de ninguna app. Nombres comunes -> paquetes (Fire TV y Google TV usan a veces paquetes distintos;
  # se usa el primero que esté instalado). Un nombre con punto se toma como paquete exacto.
  app_cands() {
    case "$1" in
      netflix) echo com.netflix.ninja com.netflix.mediaclient ;;
      youtube|yt) echo com.amazon.firetv.youtube com.google.android.youtube.tv com.google.android.youtube.tvunplugged.youtube com.google.android.youtube ;;
      youtubetv|yttv) echo com.amazon.firetv.youtube.tv com.google.android.youtube.tvunplugged ;;
      youtubekids|ytkids) echo com.amazon.firetv.youtube.kids com.google.android.youtube.tvkids com.google.android.apps.youtube.kids ;;
      youtubemusic|ytmusic) echo com.google.android.youtube.tvmusic com.google.android.apps.youtube.music ;;
      smarttube) echo org.smarttube.stable org.smarttube.beta com.teamsmart.videomanager.tv com.liskovsoft.smarttubetv.beta com.liskovsoft.smarttubetv ;;
      prime|primevideo|amazonprime|amazonvideo|amazonprimevideo) echo com.amazon.avod com.amazon.amazonvideo.livingroom com.amazon.firebat com.amazon.avod.thirdpartyclient ;;
      disney|disneyplus) echo com.disney.disneyplus ;;
      hulu) echo com.hulu.livingroomplus com.hulu.plus ;;
      max|hbomax|hbo) echo com.wbd.stream com.hbo.hbonow com.hbo.max ;;
      paramount|paramountplus) echo com.cbs.ott com.cbs.app ;;
      peacock) echo com.peacock.peacockfiretv com.peacocktv.peacockandroid ;;
      appletv) echo com.apple.atve.amazon.appletv com.apple.atve.androidtv.appletv com.apple.atve.sony.appletv ;;
      spotify) echo com.spotify.tv.android com.spotify.music ;;
      pluto|plutotv) echo tv.pluto.android ;;
      tubi|tubitv) echo com.tubitv com.tubitv.ott ;;
      plex) echo com.plexapp.android ;;
      kodi) echo org.xbmc.kodi ;;
      vlc) echo org.videolan.vlc ;;
      espn) echo com.espn.gtv com.espn.score_center ;;
      fubo|fubotv) echo com.fubo.firetv.screen com.fubotv.android com.fubo.android ;;
      sling|slingtv) echo com.sling ;;
      downloader) echo com.esaba.downloader ;;
      stremio) echo com.stremio.one ;;
      smarters|iptvsmarters) echo com.nst.iptvsmarterstvbox ;;
      tizentube) echo io.gh.reisxd.tizentube.cobalt ;;
      tivimate) echo ar.tvplayer.tv ;;
      xciptv) echo com.nathnetwork.xciptv ;;
      nuvio) echo com.nuvio.tv ;;
      crunchyroll) echo com.crunchyroll.crunchyroid ;;
      dazn) echo com.dazn ;;
      twitch) echo tv.twitch.android.viewer tv.twitch.android.app ;;
      vix) echo com.univision.prendetv ;;
      mxplayer|mx) echo com.mxtech.videoplayer.ad com.mxtech.videoplayer.pro com.mxtech.videoplayer.television ;;
      perfectplayer) echo com.niklabs.pp ;;
      ottnavigator) echo studio.scillarium.ottnavigator ;;
      silk) echo com.amazon.cloud9 ;;
      starz) echo com.bydeluxe.d3.android.program.starz ;;
      philo) echo com.philo.philo.google com.philo.philo ;;
      directv|directvstream) echo com.att.tv com.directv.dtvlatam ;;
      telemundo) echo com.telemundo.android.telemundoapp com.nbcuni.telemundo.noticiastelemundo ;;
    esac
  }
  APP_KNOWN="netflix youtube youtubetv youtubekids youtubemusic smarttube prime disney hulu max paramount peacock appletv spotify pluto tubi plex kodi vlc espn fubo sling downloader stremio smarters tizentube tivimate xciptv nuvio crunchyroll dazn twitch vix mxplayer perfectplayer ottnavigator silk starz philo directv telemundo"
  app_norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[+ _-]//g; s/ó/o/g; s/é/e/g; s/í/i/g; s/á/a/g; s/ú/u/g'; }
  # 0 si el paquete se puede abrir desde un launcher (sin datos del TV = se asume que sí)
  app_launch() { [ -z "$LAUNCHABLE" ] || inlist "$1" "$LAUNCHABLE"; }
  # $1 = nombre -> RES_PKG (vacío si no) y RES_WHY (motivo)
  app_resolve() {
    local n c hit="" inst="" dis="" m="" nm=0 m3="" n3=0 q
    RES_PKG="" RES_WHY=""
    case "$1" in
      *.*) if inlist "$1" "$DISABLED"; then RES_WHY="está desactivada en el TV"
           elif inlist "$1" "$INSTALLED"; then
             if app_launch "$1"; then RES_PKG=$1; else RES_WHY="está instalada pero no se abre desde el inicio"; fi
           else RES_WHY="no está instalada"; fi; return 0 ;;
    esac
    n=$(app_norm "$1")
    for c in $(app_cands "$n"); do
      inlist "$c" "$INSTALLED" || continue
      if inlist "$c" "$DISABLED"; then dis=$c; continue; fi
      inst=$c; app_launch "$c" && { hit=$c; break; }
    done
    if [ -n "$hit" ]; then RES_PKG=$hit; return 0; fi
    if [ -n "$inst" ]; then RES_WHY="está instalada ($inst) pero no se abre desde el inicio"; return 0; fi
    if [ -n "$dis" ]; then RES_WHY="está desactivada en el TV ($dis); no se activa"; return 0; fi
    # Búsqueda aproximada por nombre de paquete (ej. "cinema" -> com.algo.cinemahd)
    if [ "${#n}" -ge 3 ]; then
      for c in ${LAUNCHABLE:-$INSTALLED}; do
        [ "$c" = "$PKG" ] && continue
        q=$(printf '%s' "$c" | tr 'A-Z' 'a-z' | tr -d '._')
        case "$q" in *"$n"*) m="$m $c"; nm=$((nm + 1)); inlist "$c" "$THIRD" && { m3="$m3 $c"; n3=$((n3 + 1)); } ;; esac
      done
      if [ "$nm" = 1 ]; then RES_PKG=${m# }; return 0; fi
      if [ "$n3" = 1 ]; then RES_PKG=${m3# }; return 0; fi
      if [ "$nm" -gt 1 ]; then RES_WHY="hay varias que se parecen:$(printf '%s' "$m" | sed 's/ /, /g; s/^,//'). Escribe el nombre del paquete exacto"; return 0; fi
    fi
    RES_WHY="no está instalada"
    return 0
  }
  # nombre para mostrar: el que escribió el usuario, si no el de la tile, si no el paquete
  app_label() {
    local kv; for kv in $EXTRA_NAMES; do [ "${kv%%=*}" = "$1" ] && { printf '%s (%s)' "${kv#*=}" "$1"; return 0; }; done
    if [ -f "$BUNDLE/tiles/$1.txt" ]; then printf '%s (%s)' "$(head -1 "$BUNDLE/tiles/$1.txt")" "$1"; else printf '%s' "$1"; fi
  }
  # APPS -> EXTRA_PKGS (en orden, sin repetir) + avisos
  resolver_apps() {
    local x k all="" c
    EXTRA_PKGS="" EXTRA_NAMES=""
    [ -n "$APPS" ] || return 0
    for x in $(printf '%s' "$APPS" | tr ',;' '  '); do
      case "$(app_norm "$x")" in
        todas|todos|all)
          for c in ${LAUNCHABLE:-$THIRD}; do
            [ "$c" = "$PKG" ] && continue
            inlist "$c" "$DISABLED" && continue
            if inlist "$c" "$THIRD" || inlist "$c" "$KNOWN_PKGS"; then all="$all $c"; fi
          done
          for c in $(printf '%s\n' $all | sort -u); do inlist "$c" "$EXTRA_PKGS" || EXTRA_PKGS="$EXTRA_PKGS $c"; done ;;
        *)
          app_resolve "$x"
          if [ -n "$RES_PKG" ]; then
            inlist "$RES_PKG" "$EXTRA_PKGS" || { EXTRA_PKGS="$EXTRA_PKGS $RES_PKG"
              case "$x" in *.*) ;; *) EXTRA_NAMES="$EXTRA_NAMES $RES_PKG=$x" ;; esac; }
            [ "$RES_PKG" = "$x" ] || logq "apps: $x -> $RES_PKG"
          else
            aviso "App \"$x\": $RES_WHY. No va al inicio (no se instala nada)."
          fi ;;
      esac
    done
    EXTRA_PKGS=${EXTRA_PKGS# }
    logq "apps=$APPS extra=$EXTRA_PKGS"
  }

  # ---------- actualizar apps del cliente (paso 8) ----------
  # Stremio y TizenTube (IPTV Smarters va aparte: smarters_paso, siempre la gratis de Troypoint).
  # Solo si ya están instaladas, solo a una versión oficial MÁS NUEVA
  # (versionCode mayor) y con "adb install -r" (conserva datos y sesiones). Nunca instala, desinstala, baja de
  # versión ni borra datos. Si algo falla, avisa y sigue. Las descargas se guardan en ~/.luk-home/apps/.
  local AXML_PL UPD_SUM="no se revisaron"
  AXML_PL=$(cat <<'PLEOF'
binmode STDIN; local $/; my $d=<STDIN>; my $L=length $d;
sub u16{unpack('v',substr($d,$_[0],2))} sub u32{unpack('V',substr($d,$_[0],4))}
my(@s,@rm,%v); my $o=8;
while($o+8<=$L){my($t,$z)=(u16($o),u32($o+4)); last if $z<8;
 if($t==1){my($n,$f,$ss)=(u32($o+8),u32($o+16),u32($o+20)); my $u8=$f&256;
  for my $i(0..$n-1){my $p=$o+$ss+u32($o+28+4*$i); my $x;
   if($u8){my $c=ord substr($d,$p,1);$p+=($c&128)?2:1; my $b=ord substr($d,$p,1);$p++; if($b&128){$b=(($b&127)<<8)|ord substr($d,$p,1);$p++} $x=substr($d,$p,$b)}
   else{my $c=u16($p);$p+=2; if($c&32768){$c=(($c&32767)<<16)|u16($p);$p+=2} $x=join '',map{chr}unpack('v*',substr($d,$p,2*$c))}
   push @s,$x}}
 elsif($t==0x180){@rm=unpack('V*',substr($d,$o+8,$z-8))}
 elsif($t==0x102){my $el=$s[u32($o+20)]; my($as,$asz,$ac)=(u16($o+24),u16($o+26),u16($o+28));
  if($el eq 'manifest'||$el eq 'uses-sdk'){for my $i(0..$ac-1){my $a=$o+16+$as+$i*$asz; my $ni=u32($a+4);
   my $nm=$s[$ni]; my $id=$ni<@rm?$rm[$ni]:0; my($raw,$ty,$dt)=(u32($a+8),ord substr($d,$a+15,1),u32($a+16));
   my $val=($ty==3)?$s[$raw]:$dt;
   my $k=$id==0x0101021b?'vc':$id==0x0101021c?'vn':$id==0x0101020c?'min':($el eq 'manifest'&&$nm eq 'package')?'pkg':'';
   if(!$k&&!$id){$k='vc' if $nm eq 'versionCode'; $k='vn' if $nm eq 'versionName'; $k='min' if $nm eq 'minSdkVersion'}
   $v{$k}=$val if $k && !defined $v{$k}}}}
 $o+=$z}
$v{min}=1 unless defined $v{min};
print join(' ',map{defined $_?$_:'-'}@v{qw(pkg vc vn min)}),"\n";
PLEOF
)
  # <apk> -> "paquete versionCode versionName minSdk" (lee el AndroidManifest binario; necesita perl)
  apkinfo() {
    command -v perl >/dev/null 2>&1 || return 1
    if command -v unzip >/dev/null 2>&1; then unzip -p "$1" AndroidManifest.xml 2>/dev/null
    else python3 -c 'import sys,zipfile;sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read("AndroidManifest.xml"))' "$1" 2>/dev/null; fi \
      | perl -e "$AXML_PL" 2>>"$LOG"
  }
  # sha256 del certificado que firma un APK (firma v1, META-INF/*.RSA|DSA|EC). Vacío/1 = no se pudo leer.
  apkcert() {
    local n c="$WORK/cert-$$.der"
    command -v openssl >/dev/null 2>&1 || return 1
    rm -f "$c"
    if command -v unzip >/dev/null 2>&1; then
      n=$(unzip -Z1 "$1" 2>/dev/null | grep -iE '^META-INF/[^/]+\.(RSA|DSA|EC)$' | head -1); [ -n "$n" ] || return 1
      unzip -p "$1" "$n" 2>/dev/null
    else
      python3 -c 'import sys,re,zipfile;z=zipfile.ZipFile(sys.argv[1]);n=[x for x in z.namelist() if re.match(r"META-INF/[^/]+\.(RSA|DSA|EC)$",x,re.I)];sys.stdout.buffer.write(z.read(n[0]) if n else b"")' "$1" 2>/dev/null
    fi | openssl pkcs7 -inform DER -print_certs 2>/dev/null | openssl x509 -outform DER > "$c" 2>/dev/null
    [ -s "$c" ] || { rm -f "$c"; return 1; }
    sha "$c"; rm -f "$c"
  }
  isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
  vgt() { awk -v a="$1" -v b="$2" 'BEGIN{n=split(a,x,/[^0-9]+/);m=split(b,y,/[^0-9]+/);k=n>m?n:m;for(i=1;i<=k;i++){if(x[i]+0>y[i]+0)exit 0;if(x[i]+0<y[i]+0)exit 1}exit 1}'; }
  # Versiones oficiales conocidas cuyo versionCode no viene en el nombre (evita bajar 78 MB solo para leerlo).
  local KNOWN_VC="" KNOWN_SHA=""
  # IPTV Smarters: SIEMPRE la versión gratis 3.1.5.1 de Troypoint (Troypoint Toolbox → MediaFire), fija con su sha256.
  # Nunca se instala ni se actualiza a las de pago de iptvsmarters.com / smartersott.app (4.x, 5.x).
  local SMARTERS_FILE="iptv-smarters-pro-3.1.5.1-troypoint.apk" SMARTERS_VN="3.1.5.1" SMARTERS_VC=112
  local SMARTERS_SHA="2791f5346f95269c9254c547ee641a80eb5d86f0a9045dc4ae41e79210a5dbdc"
  local SMARTERS_URL="https://www.mediafire.com/file_premium/xrlnqh9kppx349u/IPTV_Smarters_Pro_%255B3.1.5.1%255D.apk/file"
  local SMARTERS_ALT="https://www.mediafire.com/file/xrlnqh9kppx349u/IPTV_Smarters_Pro_%255B3.1.5.1%255D.apk/file"
  # Firma (certificado, sha256) de las Smarters de Troypoint: una versión más nueva del Toolbox solo se acepta con esta firma.
  local SMARTERS_CERT="6100ac4577ec668ff4e5d7a18cbb070a68fba7f1b301900628665ce521cd09f1"
  local TOOLBOX_URL="${LUK_TOOLBOX_URL:-https://troypoint.com/troypoint-toolbox/}"
  local ST_DONE=0 ST_URL="" ST_ALT="" ST_FILE="" ST_VN="" ST_VC="" ST_SHA=""
  local R_URL R_ALT R_FILE R_VN R_VC R_SHA
  # Versión oficial: $1=app $2=abi (arm64-v8a | armeabi-v7a) [$3=0 la última, 1, 2... versiones oficiales
  # anteriores, para un TV donde la última no es compatible]. 1 = no hay (o no se pudo consultar).
  remote_info() {
    R_URL="" R_ALT="" R_FILE="" R_VN="" R_VC="" R_SHA=""
    local page u f v c best=0 tag asset kv idx="${3:-0}" lst
    case "$1" in
      stremio)   # www.stremio.com/downloads: solo los APK de Android TV, sin rc/beta
        page=$(curl -fsSL --connect-timeout 15 -m 60 https://www.stremio.com/downloads 2>>"$LOG") || return 1
        for u in $(printf '%s' "$page" | grep -oE 'https://dl\.strem\.io/android/v[0-9][A-Za-z0-9._-]*-androidTV/com\.stremio\.one-[A-Za-z0-9._-]*\.apk' | sort -u); do
          f=${u##*/}
          case "$f" in *-"$2".apk) ;; *) continue ;; esac
          v=${f#com.stremio.one-}; v=${v%-"$2".apk}; c=${v##*-}; v=${v%-*}
          case "$v" in ''|*[!0-9.]*) continue ;; esac
          isnum "$c" || continue
          lst="${lst:-}$c $u $f $v
"
        done
        [ -n "${lst:-}" ] || return 1
        read -r c u f v <<EOS
$(printf '%s' "$lst" | sort -rn -k1,1 | sed -n "$((idx + 1))p")
EOS
        [ -n "${u:-}" ] || return 1
        R_URL=$u; R_FILE=$f; R_VN=$v; R_VC=$c ;;
      tizentube)  # GitHub reisxd/TizenTubeCobalt (última release; trae el sha256 de cada archivo)
        case "$2" in arm64-v8a) asset=cobalt-arm64.apk ;; armeabi-v7a) asset=cobalt-arm.apk ;; *) return 1 ;; esac
        if [ "$idx" -gt 0 ]; then   # versiones anteriores: lista de releases (sin borradores ni pre-releases), con sha256
          lst=$(curl -fsSL --connect-timeout 15 -m 60 -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/reisxd/TizenTubeCobalt/releases?per_page=15" 2>>"$LOG" | tr ',' '\n' \
            | awk -v a="\"$asset\"" '/"tag_name":/ {t=$0; sub(/.*"tag_name": *"/,"",t); sub(/".*/,"",t); pre=0; dr=0; cur=0}
                /"prerelease": *true/ {pre=1} /"draft": *true/ {dr=1}
                /"name":/ {cur=index($0,a)>0}
                cur && /"digest":/ {d=$0; sub(/.*sha256:/,"",d); sub(/".*/,"",d); if (!pre && !dr && t != "") print t, d; cur=0}' \
            | sed -n "$((idx + 1))p")
          tag=${lst%% *}; R_SHA=${lst#* }
          case "$tag" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
          case "$R_SHA" in *[!0-9a-f]*|'') return 1 ;; esac
          R_URL="https://github.com/reisxd/TizenTubeCobalt/releases/download/$tag/$asset"
          R_VN=${tag#v}; R_FILE="tizentube-$R_VN-$asset"
          return 0
        fi
        page=$(curl -fsSL --connect-timeout 15 -m 60 -H 'Accept: application/vnd.github+json' https://api.github.com/repos/reisxd/TizenTubeCobalt/releases/latest 2>>"$LOG" | tr ',' '\n')
        tag=$(printf '%s\n' "$page" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
        if [ -n "$tag" ]; then
          R_SHA=$(printf '%s\n' "$page" | awk -v a="\"$asset\"" '/"name":/ {cur=index($0,a)>0} cur && /"digest":/ {sub(/.*sha256:/,""); sub(/".*/,""); print; exit}')
        else
          tag=$(curl -fsSI --connect-timeout 15 -m 60 https://github.com/reisxd/TizenTubeCobalt/releases/latest 2>>"$LOG" | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/tag/\(.*\)$#\1#p' | tail -1)
        fi
        case "$tag" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
        R_URL="https://github.com/reisxd/TizenTubeCobalt/releases/download/$tag/$asset"
        R_VN=${tag#v}; R_FILE="tizentube-$R_VN-$asset" ;;
      smarters)   # solo Troypoint: la del Toolbox (si es más nueva y con la misma firma) o la 3.1.5.1 fija
        [ "$idx" -gt 0 ] && return 1
        smarters_target
        R_FILE=$ST_FILE; R_URL=$ST_URL; R_ALT=$ST_ALT; R_VN=$ST_VN; R_VC=$ST_VC; R_SHA=$ST_SHA ;;
    esac
    [ -n "$R_URL" ] || return 1
    for kv in $KNOWN_VC; do [ "${kv%%=*}" = "$R_FILE" ] && R_VC=${kv#*=}; done
    for kv in $KNOWN_SHA; do [ "${kv%%=*}" = "$R_FILE" ] && R_SHA=${kv#*=}; done
    return 0
  }
  upd_add() { UPD_SUM="${UPD_SUM:+$UPD_SUM · }$1"; }
  upd_app() {   # $1=app $2=paquete $3=nombre
    local app=$1 p=$2 nm=$3 dump ivc ivn iabi abi dir f info apkg avc avn amin out u need nvn
    inlist "$p" "$INSTALLED" || { logq "upd $p: no instalada"; return 0; }
    dump=$(S dumpsys package "$p")
    ivc=$(printf '%s\n' "$dump" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
    ivn=$(printf '%s\n' "$dump" | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -1)
    iabi=$(printf '%s\n' "$dump" | sed -n 's/.*primaryCpuAbi=\([^ ]*\).*/\1/p' | head -1)
    case "$iabi" in ''|null) iabi=${ABIS%%,*} ;; esac
    case "$iabi" in arm64*) abi=arm64-v8a ;; armeabi*) abi=armeabi-v7a ;; *) abi=$iabi ;; esac
    logq "upd $p: instalada vc=$ivc vn=$ivn abi=$iabi -> $abi"
    if ! isnum "$ivc"; then aviso "$nm: no pude leer la versión instalada; se deja como está"; upd_add "$nm sin revisar"; return 0; fi
    if ! remote_info "$app" "$abi"; then
      aviso "$nm: no pude consultar la última versión oficial (internet o la página cambió); se deja la ${ivn:-actual}"
      upd_add "$nm sin revisar"; return 0
    fi
    logq "upd $p: oficial file=$R_FILE vn=$R_VN vc=$R_VC sha=$R_SHA url=$R_URL"
    if { [ -n "$R_VC" ] && [ "$R_VC" -le "$ivc" ]; } || { [ -z "$R_VC" ] && [ "$R_VN" = "$ivn" ]; }; then
      bien "$nm al día ($ivn)"; upd_add "$nm al día"; return 0
    fi
    dir="$WORK/apps/$app"; f="$dir/$R_FILE"; mkdir -p "$dir"
    if [ -f "$f" ] && { [ -z "$R_SHA" ] || [ "$(sha "$f")" = "$R_SHA" ]; } && apkinfo "$f" >/dev/null; then
      say "   $nm $R_VN ya estaba descargada en esta computadora"
    else
      rm -f "$f" "$f.part"
      say "   Descargando $nm $R_VN para comparar (solo esta vez; queda guardada)..."
      for u in $R_URL $R_ALT; do
        if [ -t 2 ]; then curl -fL --retry 2 --connect-timeout 20 --progress-bar -o "$f.part" "$u"; else curl -fL --retry 2 --connect-timeout 20 -sS -o "$f.part" "$u" >>"$LOG" 2>&1; fi
        [ -s "$f.part" ] && [ "$(head -c 2 "$f.part")" = PK ] && break
        rm -f "$f.part"; logq "upd $p: descarga falló desde $u"
      done
      if [ ! -s "$f.part" ]; then aviso "$nm: no se pudo descargar la versión $R_VN; se deja la $ivn"; upd_add "$nm sin revisar"; return 0; fi
      if [ -n "$R_SHA" ] && [ "$(sha "$f.part")" != "$R_SHA" ]; then
        rm -f "$f.part"; aviso "$nm: el archivo descargado no coincide con el oficial (sha256); no se instala"; upd_add "$nm sin revisar"; return 0
      fi
      mv "$f.part" "$f"
      for u in "$dir"/*.apk; do [ "$u" = "$f" ] || rm -f "$u"; done   # deja solo la última
    fi
    info=$(apkinfo "$f") || info=""
    set -- $info; apkg=${1:-}; avc=${2:-}; avn=${3:-}; amin=${4:-1}
    logq "upd $p: archivo $f -> $info"
    if [ -z "$info" ]; then aviso "$nm: no pude leer la versión del archivo (falta perl o archivo dañado); no se toca"; rm -f "$f"; upd_add "$nm sin revisar"; return 0; fi
    if [ "$apkg" != "$p" ] || ! isnum "$avc"; then aviso "$nm: el archivo descargado no es $nm ($apkg); no se instala"; rm -f "$f"; upd_add "$nm sin revisar"; return 0; fi
    if [ "$avc" -le "$ivc" ]; then bien "$nm al día ($ivn)"; upd_add "$nm al día"; return 0; fi
    if isnum "$amin" && [ "$amin" -gt "$SDK" ]; then
      aviso "$nm $avn necesita Android API $amin y este TV es API $SDK; se deja la $ivn"; upd_add "$nm $ivn (la nueva no es compatible)"; return 0
    fi
    need=$(( $(wc -c < "$f") / 1024 * 2 + 50000 ))
    FREE=$(S df -k /data | awk 'NR>1 {v=$4} END {print v+0}')
    if [ "${FREE:-0}" -gt 0 ] && [ "$FREE" -lt "$need" ]; then
      aviso "$nm: no hay espacio en el TV para actualizar ($((FREE / 1024)) MB libres, hacen falta ~$((need / 1024)) MB); se deja la $ivn"; upd_add "$nm sin espacio"; return 0
    fi
    if [ "$DRY" = 1 ]; then
      sim "adb install -r $R_FILE   ($nm $ivn → $avn; conserva datos y sesiones)"; upd_add "$nm $ivn → $avn (simulado)"; return 0
    fi
    say "   Actualizando $nm $ivn → $avn (conserva datos y sesiones; puede tardar 1-2 minutos)..."
    case "$PLATFORM" in Google*) say "   (Si en el TV sale un aviso de Play Protect, elige \"Instalar de todas formas\".)" ;; esac
    out=$(A install -r "$f" 2>&1 | tr -d '\r'); logq "upd $p install: $out"
    case "$out" in
      *Success*)
        dump=$(S dumpsys package "$p")
        nvn=$(printf '%s\n' "$dump" | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -1)
        u=$(printf '%s\n' "$dump" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
        APPS_TOUCHED=1
        if [ "$u" = "$avc" ]; then say "   ${G}⬆${N} $nm actualizada $ivn → ${nvn:-$avn}"; upd_add "$nm $ivn → ${nvn:-$avn}"
        else aviso "$nm: el TV aceptó la actualización pero sigue mostrando la ${nvn:-$ivn}; revisa la app"; upd_add "$nm ${nvn:-$ivn} (revisar)"; fi ;;
      *UPDATE_INCOMPATIBLE*|*SIGNATURE*)
        aviso "$nm: la que tiene el TV viene de otra fuente (firma distinta). No se actualiza y NO se desinstala: sigue igual."
        upd_add "$nm $ivn (firma distinta, no se tocó)" ;;
      *VERSION_DOWNGRADE*) bien "$nm al día ($ivn)"; upd_add "$nm al día" ;;
      *OLDER_SDK*) aviso "$nm $avn no es compatible con este TV; se deja la $ivn"; upd_add "$nm $ivn (la nueva no es compatible)" ;;
      *NO_MATCHING_ABIS*) aviso "$nm $avn no es para este procesador; se deja la $ivn"; upd_add "$nm $ivn (la nueva no es compatible)" ;;
      *INSUFFICIENT_STORAGE*) aviso "$nm: el TV no tiene espacio para actualizar; se deja la $ivn"; upd_add "$nm sin espacio" ;;
      *) aviso "$nm: la actualización falló ($(printf '%s' "$out" | grep -v '^Performing' | tail -1)); se deja la $ivn"; upd_add "$nm $ivn (falló la actualización)" ;;
    esac
    return 0
  }
  # Descarga $1 a $2 (1 = no es un APK). MediaFire: la página redirige al archivo (el enlace directo trae una
  # clave que cambia cada vez) o trae el enlace en el HTML (href="https://downloadNNNN.mediafire.com/..." o
  # data-scrambled-url en base64); se saca de ahí cada vez. Otras páginas: igual que antes.
  bajar_url() {
    local u=$1 o=$2 ua="" pg d enc
    case "$u" in *mediafire.com*) ua="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36" ;; esac
    rm -f "$o"
    if [ -t 2 ]; then curl -fL --retry 2 --connect-timeout 20 ${ua:+-A "$ua"} --progress-bar -o "$o" "$u"; else curl -fL --retry 2 --connect-timeout 20 ${ua:+-A "$ua"} -sS -o "$o" "$u" >>"$LOG" 2>&1; fi
    [ -s "$o" ] && [ "$(head -c 2 "$o")" = PK ] && return 0
    [ -n "$ua" ] && [ -s "$o" ] || { rm -f "$o"; return 1; }
    pg=$(head -c 3000000 "$o" | LC_ALL=C tr -d '\000'); rm -f "$o"
    d=$(printf '%s' "$pg" | LC_ALL=C grep -oE 'https?://download[0-9]*\.mediafire\.com/[^"'"'"'<> ]+' | head -1)
    if [ -z "$d" ]; then
      enc=$(printf '%s' "$pg" | LC_ALL=C grep -oE 'data-scrambled-url="[A-Za-z0-9+/=]+"' | head -1 | sed 's/^[^"]*"//; s/"$//')
      [ -n "$enc" ] && d=$(printf '%s' "$enc" | base64 -d 2>/dev/null || printf '%s' "$enc" | base64 -D 2>/dev/null)
      case "$d" in https://download*.mediafire.com/*) ;; *) d="" ;; esac
    fi
    logq "mediafire $u -> enlace directo: ${d:-(no se encontró)}"
    [ -n "$d" ] || return 1
    if [ -t 2 ]; then curl -fL --retry 2 --connect-timeout 20 -A "$ua" --progress-bar -o "$o" "$d"; else curl -fL --retry 2 --connect-timeout 20 -A "$ua" -sS -o "$o" "$d" >>"$LOG" 2>&1; fi
    [ -s "$o" ] && [ "$(head -c 2 "$o")" = PK ] && return 0
    rm -f "$o"; return 1
  }
  # Baja el APK oficial de R_URL / R_ALT a $WORK/apps/<app>/ y comprueba el sha256 oficial (si se conoce).
  # $1=app $2=nombre. Deja la ruta en APK_F. 1 = no se pudo (ya avisó).
  local APK_F=""
  bajar_apk() {
    local dir="$WORK/apps/$1" u
    APK_F="$dir/$R_FILE"; mkdir -p "$dir"
    if [ -f "$APK_F" ] && { [ -z "$R_SHA" ] || [ "$(sha "$APK_F")" = "$R_SHA" ]; } && apkinfo "$APK_F" >/dev/null; then
      say "   $2 $R_VN ya estaba descargada en esta computadora"; return 0
    fi
    rm -f "$APK_F" "$APK_F.part"
    if [ "$1" = smarters ]; then say "   Descargando $2 $R_VN gratis (Troypoint; solo esta vez, queda guardada)..."
    else say "   Descargando $2 $R_VN (oficial; solo esta vez, queda guardada)..."; fi
    for u in $R_URL $R_ALT; do
      bajar_url "$u" "$APK_F.part" && break
      rm -f "$APK_F.part"; logq "inst $1: descarga falló desde $u"
    done
    if [ ! -s "$APK_F.part" ]; then aviso "$2: no se pudo descargar la versión $R_VN; no se instala"; return 1; fi
    if [ -n "$R_SHA" ] && [ "$(sha "$APK_F.part")" != "$R_SHA" ]; then
      rm -f "$APK_F.part"; aviso "$2: el archivo descargado no coincide con el oficial (sha256); no se instala"; return 1
    fi
    mv "$APK_F.part" "$APK_F"
    return 0
  }
  # La app NO está en el TV: se instala la versión oficial (adb install -g) para el procesador y el Android del TV.
  # Si la última pide un Android más nuevo, prueba versiones oficiales anteriores; si ninguna sirve, avisa y sigue.
  inst_app() {   # $1=app $2=paquete $3=nombre
    local app=$1 p=$2 nm=$3 abis abi idx info apkg avc avn amin out need tried="" got=0
    if [ "$NOAPPS" = 1 ]; then logq "inst $p: no instalada, --sin-apps"; bien "$nm no está en el TV (no se instala: --sin-apps)"; upd_add "$nm no instalada"; return 0; fi
    case "$app" in
      smarters) abis=universal ;;   # un solo APK para todos los procesadores
      *) case "$CPU_ABI" in
           arm64*) abis="arm64-v8a armeabi-v7a" ;;   # si no hay de 64 bits, la de 32 bits también corre
           armeabi*|'') abis=armeabi-v7a ;;
           *) abis=$CPU_ABI ;;
         esac ;;
    esac
    logq "inst $p: no instalada; abi=$CPU_ABI -> $abis api=$SDK"
    for abi in $abis; do
      idx=0
      while [ "$idx" -le 3 ]; do
        remote_info "$app" "$abi" "$idx" || break
        idx=$((idx + 1)); got=1
        logq "inst $p: oficial[$((idx - 1))] abi=$abi file=$R_FILE vn=$R_VN vc=$R_VC sha=$R_SHA url=$R_URL"
        bajar_apk "$app" "$nm" || { upd_add "$nm no se pudo instalar"; return 0; }
        info=$(apkinfo "$APK_F") || info=""
        set -- $info; apkg=${1:-}; avc=${2:-}; avn=${3:-}; amin=${4:-1}
        logq "inst $p: archivo $APK_F -> $info"
        if [ -z "$info" ]; then aviso "$nm: no pude leer el archivo descargado (falta perl o archivo dañado); no se instala"; rm -f "$APK_F"; upd_add "$nm no se pudo instalar"; return 0; fi
        if [ "$apkg" != "$p" ] || ! isnum "$avc"; then aviso "$nm: el archivo descargado no es $nm ($apkg); no se instala"; rm -f "$APK_F"; upd_add "$nm no se pudo instalar"; return 0; fi
        if isnum "$amin" && [ "$amin" -gt "$SDK" ]; then
          aviso "$nm $avn necesita Android API $amin y este TV es API $SDK; busco una versión oficial anterior que sirva..."
          tried="$tried $avn"; continue
        fi
        need=$(( $(wc -c < "$APK_F") / 1024 * 2 + 50000 ))
        FREE=$(S df -k /data | awk 'NR>1 {v=$4} END {print v+0}')
        if [ "${FREE:-0}" -gt 0 ] && [ "$FREE" -lt "$need" ]; then
          aviso "$nm: no hay espacio en el TV para instalarla ($((FREE / 1024)) MB libres, hacen falta ~$((need / 1024)) MB); no se instala"; upd_add "$nm sin espacio"; return 0
        fi
        if [ "$DRY" = 1 ]; then
          sim "adb install -g $R_FILE   ($nm $avn, $abi, Android API $amin+; no estaba en el TV)"
          NEW_INST="$NEW_INST $p"; upd_add "$nm $avn instalada (simulado)"; return 0
        fi
        say "   Instalando $nm $avn (no estaba en el TV; puede tardar 1-2 minutos)..."
        case "$PLATFORM" in Google*) say "   (Si en el TV sale un aviso de Play Protect, elige \"Instalar de todas formas\".)" ;; esac
        out=$(A install -g "$APK_F" 2>&1 | tr -d '\r'); logq "inst $p install: $out"
        case "$out" in
          *Success*)
            if S pm path "$p" | grep -q package:; then
              INSTALLED="$INSTALLED$p "; NEW_INST="$NEW_INST $p"
              say "   ${G}✚${N} $nm $avn instalada"; upd_add "$nm $avn instalada"
            else aviso "$nm: el TV dijo que la instaló pero no aparece; revisa la app"; upd_add "$nm (revisar)"; fi ;;
          *NO_MATCHING_ABIS*|*CPU_ABI_INCOMPATIBLE*)
            if [ "$abi" = arm64-v8a ]; then aviso "$nm $avn de 64 bits no sirve en este TV; pruebo la de 32 bits..."; continue 2; fi
            aviso "$nm $avn no es para el procesador de este TV; no se instala"; upd_add "$nm no compatible con este TV" ;;
          *OLDER_SDK*)
            aviso "$nm $avn no es compatible con este TV (API $SDK); busco una versión oficial anterior que sirva..."
            tried="$tried $avn"; continue ;;
          *INSUFFICIENT_STORAGE*) aviso "$nm: el TV no tiene espacio para instalarla; no se instala"; upd_add "$nm sin espacio" ;;
          *ALREADY_EXISTS*|*UPDATE_INCOMPATIBLE*|*SIGNATURE*|*DUPLICATE*)
            aviso "$nm: el TV ya tiene una copia escondida o de otra fuente; no se toca"; upd_add "$nm no se tocó" ;;
          *) aviso "$nm: la instalación falló ($(printf '%s' "$out" | grep -v '^Performing' | tail -1)); se sigue con lo demás"; upd_add "$nm no se pudo instalar" ;;
        esac
        return 0
      done
    done
    if [ -n "$tried" ]; then
      aviso "$nm: ninguna versión oficial reciente funciona en este TV (Android API $SDK; probadas:$tried); no se instala"; upd_add "$nm no compatible con este TV"
    elif [ "$got" = 0 ]; then
      aviso "$nm: no pude consultar la versión oficial para este TV (internet, la página cambió o no hay para $CPU_ABI); no se instala"; upd_add "$nm no se pudo instalar"
    else
      aviso "$nm: no se encontró una versión oficial para este TV; no se instala"; upd_add "$nm no se pudo instalar"
    fi
    return 0
  }
  # Apps recién instaladas en el paso 8: se agregan al dock de Luk Home (con su ícono).
  # Dock nuevo de esta corrida: orden Stremio, IPTV Smarters, TizenTube y luego las apps extra.
  # Dock que ya tenía el TV: se deja tal cual y se agregan al final las que falten.
  dock_nuevas() {
    [ -n "$NEW_INST" ] || return 0
    local d p cur have added="" nt=0 out
    d=$(mktemp -d "${TMPDIR:-/tmp}/lukapps.XXXXXX")/lukhome; mkdir -p "$d/tiles"
    if [ "$DOCK_MODE" != nuevo ]; then
      if [ "$DRY" = 1 ]; then cur=$(cat "$BK/dock-antes.txt" 2>/dev/null); [ "$DOCK_MODE" = extra ] && cur="$cur
$(printf '%s\n' $EXTRA_PKGS)"
      else cur=$(S run-as "$PKG" cat files/dock.txt); fi
      case "$cur" in *"No such file"*|*"run-as:"*) cur="" ;; esac
    fi
    if [ "$DOCK_MODE" = nuevo ] || [ -z "$(printf '%s\n' "$cur" | grep -v '^#' | tr -d ' ')" ]; then
      printf '# Apps del inicio, en orden\n' > "$d/dock.txt"
      for p in $DOCK_APPS; do
        inlist "$p" "$INSTALLED" || inlist "$p" "$NEW_INST" || continue
        echo "$p" >> "$d/dock.txt"
      done
      for p in $EXTRA_PKGS; do inlist "$p" "$DOCK_APPS" || echo "$p" >> "$d/dock.txt"; done
      for p in $NEW_INST; do added="$added, $(cat "$BUNDLE/tiles/$p.txt" 2>/dev/null || echo "$p")"; done
    else
      printf '%s\n' "$cur" > "$d/dock.txt"
      have=" $(grep -v '^#' "$d/dock.txt" | tr -d ' \r' | tr '\n' ' ') "
      for p in $DOCK_APPS; do
        inlist "$p" "$NEW_INST" || continue
        inlist "$p" "$have" && continue
        echo "$p" >> "$d/dock.txt"; have="$have$p "; added="$added, $(cat "$BUNDLE/tiles/$p.txt" 2>/dev/null || echo "$p")"
      done
    fi
    for p in $NEW_INST; do
      if [ -f "$BUNDLE/tiles/$p.png" ]; then cp "$BUNDLE/tiles/$p.png" "$d/tiles/"; [ -f "$BUNDLE/tiles/$p.txt" ] && cp "$BUNDLE/tiles/$p.txt" "$d/tiles/"; nt=$((nt + 1)); fi
    done
    cp "$BUNDLE/tv-apply.sh" "$d/tv-apply.sh"
    logq "dock_nuevas: mode=${DOCK_MODE:-existente} new=$NEW_INST dock=$(grep -v '^#' "$d/dock.txt" | tr '\n' ' ')"
    if [ -z "$added" ]; then bien "Dock: las apps nuevas ya estaban en el inicio"; rm -rf "$(dirname "$d")"; return 0; fi
    if [ "$DRY" = 1 ]; then
      sim "adb push lukhome/ → /data/local/tmp/ y tv-apply.sh  (escribe: tiles/ ($nt íconos), dock.txt)"
      sim "dock.txt = $(grep -v '^#' "$d/dock.txt" | tr '\n' ' ')"
      rm -rf "$(dirname "$d")"; return 0
    fi
    A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
    out=$(A push "$d" /data/local/tmp/ 2>&1 | tr -d '\r'); logq "push apps: $out"
    out=$(A shell sh /data/local/tmp/lukhome/tv-apply.sh 2>&1 | tr -d '\r'); logq "apply apps: $out"
    rm -rf "$(dirname "$d")"
    case "$out" in
      *LUK_APPLY_OK*) DOCK_TOUCHED=1; bien "Dock: se agregan al inicio:${added#,}" ;;
      *) A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
         aviso "No pude agregar las apps nuevas al dock ($(printf '%s' "$out" | grep LUK_APPLY_FAIL | head -1)); están en \"Otras apps\". Vuelve a correr la línea para ponerlas." ;;
    esac
    return 0
  }
  # Después de instalar o actualizar apps: Luk Home de nuevo en pantalla (y recarga el dock). Sin teclas.
  volver_luk() {
    [ -n "$NEW_INST" ] || [ "$APPS_TOUCHED" = 1 ] || return 0
    if [ "$DRY" = 1 ]; then sim "abrir Luk Home otra vez (am start --ez reload true) para que muestre el dock al día"; return 0; fi
    local top=""
    A shell am start -n "$PKG/.HomeActivity" --ez reload true >>"$LOG" 2>&1
    for _ in 1 2 3 4 5 6; do
      sleep 1.5
      top=$(S dumpsys activity activities | grep -m1 -E 'mResumedActivity|topResumedActivity')
      case "$top" in *"$PKG"*) break ;; esac
    done
    logq "volver_luk: $top"
    case "$top" in
      *"$PKG"*) bien "Luk Home de nuevo en pantalla$( [ "$DOCK_TOUCHED" = 1 ] && echo ', con el dock al día')" ;;
      *) aviso "Pulsa el botón Inicio (la casita) del control para volver a Luk Home." ;;
    esac
  }
  # IPTV Smarters: SOLO de Troypoint. Lee el enlace de IPTV Smarters del Troypoint Toolbox (MediaFire) cada vez.
  # Si es el de la 3.1.5.1 (o no se pudo leer la página) => la 3.1.5.1 fija (sha256 conocido). Si Troypoint enlaza
  # otro archivo, se baja y solo se usa si es com.nst.iptvsmarterstvbox, MÁS NUEVA (versionCode mayor) y firmada
  # con el mismo certificado que la 3.1.5.1; si no, se usa la 3.1.5.1. Deja el resultado en ST_* (una vez por corrida).
  smarters_target() {
    [ "$ST_DONE" = 1 ] && return 0
    ST_DONE=1 ST_FILE=$SMARTERS_FILE ST_URL=$SMARTERS_URL ST_ALT=$SMARTERS_ALT ST_VN=$SMARTERS_VN ST_VC=$SMARTERS_VC ST_SHA=$SMARTERS_SHA
    local page u key f info tpkg tvc tvn cert
    page=$(curl -fsSL --connect-timeout 15 -m 60 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0" "$TOOLBOX_URL" 2>>"$LOG") || page=""
    u=$(printf '%s' "$page" | LC_ALL=C grep -oE 'https?://[A-Za-z0-9.]*mediafire\.com/[^"'"'"'<> ]*[Ss][Mm][Aa][Rr][Tt][Ee][Rr][Ss][^"'"'"'<> ]*' | head -1)
    logq "smarters: Troypoint Toolbox -> ${u:-(no se pudo leer; se usa la 3.1.5.1 fija)}"
    [ -n "$u" ] || return 0
    case "$u" in */xrlnqh9kppx349u/*) logq "smarters: Troypoint sigue con la 3.1.5.1"; return 0 ;; esac
    key=$(printf '%s' "$u" | sed -n 's#.*mediafire\.com/file[a-z_]*/\([A-Za-z0-9]*\)/.*#\1#p'); :
    [ -n "$key" ] || key=nuevo
    f="$WORK/apps/smarters/iptv-smarters-troypoint-$key.apk"; mkdir -p "$WORK/apps/smarters"
    if [ ! -s "$f" ] || [ "$(head -c 2 "$f")" != PK ]; then
      say "   Troypoint tiene otro archivo de IPTV Smarters; se revisa (versión y firma)..."
      bajar_url "$u" "$f.part" && mv -f "$f.part" "$f" || { rm -f "$f.part"; aviso "IPTV Smarters: no se pudo bajar el archivo nuevo de Troypoint; se usa la $SMARTERS_VN"; return 0; }
    fi
    info=$(apkinfo "$f") || info=""; set -- $info; tpkg=${1:-}; tvc=${2:-}; tvn=${3:-}
    cert=$(apkcert "$f") || cert=""
    logq "smarters: Troypoint nuevo $f -> $info cert=$cert"
    if [ "$tpkg" != com.nst.iptvsmarterstvbox ] || ! isnum "$tvc"; then aviso "IPTV Smarters: el archivo de Troypoint no es IPTV Smarters; se usa la $SMARTERS_VN"; rm -f "$f"; return 0; fi
    if [ "$cert" != "$SMARTERS_CERT" ]; then aviso "IPTV Smarters $tvn de Troypoint no tiene la misma firma que la $SMARTERS_VN; se usa la $SMARTERS_VN"; rm -f "$f"; return 0; fi
    if [ "$tvc" -le "$SMARTERS_VC" ]; then logq "smarters: Troypoint $tvn (vc $tvc) no es más nueva que la $SMARTERS_VN; se usa la fija"; rm -f "$f"; return 0; fi
    ST_FILE=${f##*/} ST_URL=$u ST_ALT="" ST_VN=$tvn ST_VC=$tvc ST_SHA=$(sha "$f")
    bien "Troypoint tiene IPTV Smarters $tvn (misma firma que la $SMARTERS_VN): se usa esa"
  }
  # IPTV Smarters (2026-11-03b): siempre la gratis de Troypoint (ver smarters_target). Si falta, se instala.
  # Si el TV tiene una de Troypoint (misma firma) más vieja, se actualiza con "adb install -r" (conserva login y
  # listas); igual o más nueva, no se toca. Si tiene otra (por ejemplo la 4.0.6 de pago, que no funciona), se cambia:
  # se guarda una copia, se desinstala (se borran su login y sus listas) y se instala la de Troypoint; si eso
  # falla, se vuelve a poner la copia. Nunca se instala ni se actualiza a las de pago (iptvsmarters.com, smartersott.app).
  smarters_paso() {   # $1=smarters $2=paquete $3=nombre
    local app=$1 p=$2 nm=$3 dump ivc ivn info apkg avc avn amin out need paths bkd q n=0 back icert
    dump=$(S dumpsys package "$p")
    ivc=$(printf '%s\n' "$dump" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
    ivn=$(printf '%s\n' "$dump" | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -1)
    if [ "$NOUPD" = 1 ]; then logq "smarters: vc=$ivc vn=$ivn, --sin-actualizar, no se toca"; bien "$nm ${ivn:-} se deja como está (--sin-actualizar)"; upd_add "$nm sin revisar"; return 0; fi
    remote_info smarters universal 0
    logq "smarters: instalada vc=$ivc vn=$ivn; Troypoint = vc $R_VC vn $R_VN ($R_FILE)"
    if [ "$ivc" = "$R_VC" ] && [ "$ivn" = "$R_VN" ]; then
      bien "$nm $ivn (la gratis de Troypoint) ya está; no se toca"; upd_add "$nm $ivn al día"; return 0
    fi
    bajar_apk smarters "$nm" || { upd_add "$nm ${ivn:-} (no se pudo bajar la de Troypoint, no se tocó)"; return 0; }
    info=$(apkinfo "$APK_F") || info=""
    set -- $info; apkg=${1:-}; avc=${2:-}; avn=${3:-}; amin=${4:-1}
    logq "smarters: archivo $APK_F -> $info"
    if [ "$apkg" != "$p" ] || [ "$avc" != "$R_VC" ]; then aviso "$nm: el archivo descargado no es el esperado ($info); no se toca"; rm -f "$APK_F"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0; fi
    # Copia de la que tiene el TV (lectura; también en simulación): sirve para ver su firma y para volver atrás.
    paths=$(S pm path "$p" | sed -n 's/^package://p')
    bkd="$WORK/apps/smarters/respaldo-${ivn:-x}-$TS"; mkdir -p "$bkd"
    for q in $paths; do
      n=$((n + 1)); A pull "$q" "$bkd/$n-$(basename "$q")" >>"$LOG" 2>&1 || { n=-1; break; }
    done
    if [ "$n" -lt 1 ]; then aviso "$nm: no pude leer la que tiene el TV; por seguridad no se toca"; rm -rf "$bkd"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0; fi
    icert=$(apkcert "$(ls "$bkd"/1-* | head -1)") || icert=""
    logq "smarters: firma de la instalada = ${icert:-?}"
    if [ -z "$icert" ]; then aviso "$nm: no pude leer la firma de la que tiene el TV; por seguridad no se toca"; rm -rf "$bkd"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0; fi
    if isnum "$amin" && [ "$amin" -gt "$SDK" ]; then aviso "$nm $avn necesita Android API $amin y este TV es API $SDK; se deja la ${ivn:-actual}"; rm -rf "$bkd"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0; fi
    case ",$ABIS," in *,armeabi-v7a,*|*,armeabi,*|,,) ;; *) aviso "$nm $avn no es para el procesador de este TV ($ABIS); se deja la ${ivn:-actual}"; rm -rf "$bkd"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0 ;; esac
    need=$(( $(wc -c < "$APK_F") / 1024 * 2 + 50000 ))
    FREE=$(S df -k /data | awk 'NR>1 {v=$4} END {print v+0}')
    if [ "${FREE:-0}" -gt 0 ] && [ "$FREE" -lt "$need" ]; then aviso "$nm: no hay espacio en el TV ($((FREE / 1024)) MB libres); se deja la ${ivn:-actual}"; rm -rf "$bkd"; upd_add "$nm sin espacio"; return 0; fi
    if [ "$icert" = "$SMARTERS_CERT" ]; then   # ya es de Troypoint (misma firma)
      rm -rf "$bkd"
      if ! isnum "$ivc" || [ "$ivc" -ge "$avc" ]; then bien "$nm $ivn (de Troypoint) ya está; no se toca"; upd_add "$nm $ivn al día"; return 0; fi
      if [ "$DRY" = 1 ]; then sim "adb install -r $R_FILE   ($nm ${ivn:-?} → $avn de Troypoint; conserva login y listas)"; upd_add "$nm ${ivn:-?} → $avn (simulado)"; return 0; fi
      say "   Actualizando $nm ${ivn:-?} → $avn de Troypoint (conserva login y listas)..."
      out=$(A install -r "$APK_F" 2>&1 | tr -d '\r'); logq "smarters install -r: $out"
      if printf '%s' "$out" | grep -q Success; then APPS_TOUCHED=1; say "   ${G}↑${N} $nm actualizada a $avn"; upd_add "$nm ${ivn:-?} → $avn"
      else aviso "$nm: no se pudo actualizar ($(printf '%s' "$out" | grep -v '^Performing' | tail -1)); sigue la ${ivn:-actual}"; upd_add "$nm ${ivn:-} (no se pudo actualizar)"; fi
      return 0
    fi
    aviso "$nm ${ivn:-?} no es la gratis de Troypoint: se cambia por la $avn de Troypoint."
    if [ "$DRY" = 1 ]; then
      rm -rf "$bkd"
      sim "adb uninstall $p   (se BORRAN el login y las listas de $nm)"
      sim "adb install -g $R_FILE   ($nm $avn gratis de Troypoint)"
      NEW_INST="$NEW_INST $p"; upd_add "$nm ${ivn:-?} → $avn gratis (simulado; se borran login y listas)"; return 0
    fi
    say "   ${Y}Ojo:${N} al cambiar $nm se borran su login y sus listas; hay que volver a ponerlos en la app."
    say "   Quitando $nm ${ivn:-} (copia guardada en esta computadora)..."
    out=$(A uninstall "$p" 2>&1 | tr -d '\r'); logq "smarters uninstall: $out"
    case "$out" in *Success*) ;; *) aviso "$nm: el TV no dejó desinstalarla ($(printf '%s' "$out" | tail -1)); sigue la ${ivn:-actual}"; rm -rf "$bkd"; upd_add "$nm ${ivn:-} (no se tocó)"; return 0 ;; esac
    INSTALLED=$(printf '%s' "$INSTALLED" | sed "s/ $p / /")
    APPS_TOUCHED=1
    say "   Instalando $nm $avn gratis (Troypoint; puede tardar 1-2 minutos)..."
    case "$PLATFORM" in Google*) say "   (Si en el TV sale un aviso de Play Protect, elige \"Instalar de todas formas\".)" ;; esac
    out=$(A install -g "$APK_F" 2>&1 | tr -d '\r'); logq "smarters install: $out"
    if printf '%s' "$out" | grep -q Success && S pm path "$p" | grep -q package:; then
      INSTALLED="$INSTALLED$p "; NEW_INST="$NEW_INST $p"
      say "   ${G}✚${N} $nm cambiada: ${ivn:-?} → $avn gratis (abre la app y pon otra vez el usuario y la lista)"
      upd_add "$nm ${ivn:-?} → $avn gratis (login y listas borrados)"
      rm -rf "$bkd"; return 0
    fi
    aviso "$nm $avn no se pudo instalar ($(printf '%s' "$out" | grep -v '^Performing' | tail -1)); vuelvo a poner la ${ivn:-anterior}..."
    if [ "$n" = 1 ]; then back=$(A install -g "$bkd"/1-* 2>&1 | tr -d '\r'); else back=$(A install-multiple -g "$bkd"/* 2>&1 | tr -d '\r'); fi
    logq "smarters restore: $back"
    if printf '%s' "$back" | grep -q Success; then
      INSTALLED="$INSTALLED$p "; aviso "$nm ${ivn:-} quedó puesta otra vez (sin login: hay que volver a ponerlo)"; upd_add "$nm ${ivn:-} (la gratis falló, se volvió a poner)"; rm -rf "$bkd"
    else
      aviso "$nm no se pudo volver a poner. La copia quedó en $bkd"; upd_add "$nm FALTA (copia en $bkd)"
    fi
    return 0
  }
  app_paso() {   # $1=app $2=paquete $3=nombre: actualiza si está, instala si falta
    if [ "$1" = smarters ] && inlist "$2" "$INSTALLED"; then smarters_paso "$@"; return 0; fi
    if inlist "$2" "$INSTALLED"; then
      if [ "$NOUPD" = 1 ]; then logq "upd $2: instalada, --sin-actualizar"; upd_add "$3 sin revisar"; return 0; fi
      upd_app "$@"
    else
      inst_app "$@"
    fi
  }
  actualizar_apps() {
    paso 8 "Apps: Stremio, IPTV Smarters (gratis, Troypoint) y TizenTube (instalar o actualizar)"
    NEW_INST="" APPS_TOUCHED=0 DOCK_TOUCHED=0
    if [ "$NOUPD" = 1 ] && [ "$NOAPPS" = 1 ]; then bien "Omitido (--sin-actualizar y --sin-apps)"; UPD_SUM="no se revisaron (--sin-actualizar --sin-apps)"; return 0; fi
    [ "$NOUPD" = 1 ] && bien "Las que ya están no se actualizan (--sin-actualizar)"
    [ "$NOAPPS" = 1 ] && bien "Las que faltan no se instalan (--sin-apps)"
    command -v perl >/dev/null 2>&1 || aviso "Esta computadora no tiene perl: no se pueden revisar los archivos de las apps"
    UPD_SUM=""
    app_paso stremio com.stremio.one "Stremio"
    app_paso smarters com.nst.iptvsmarterstvbox "IPTV Smarters"
    app_paso tizentube io.gh.reisxd.tizentube.cobalt "TizenTube"
    dock_nuevas
    volver_luk
    return 0
  }


  # ---------- RetroArch del cuarto (opcional: --retroarch / RETROARCH=1) ----------
  # Instala o actualiza (adb install -r, sin desinstalar) el RetroArch OFICIAL de buildbot.libretro.com
  # (sha256 fijo) y deja la configuración del TV del cuarto: retroarch.cfg, 7 núcleos oficiales, opciones de
  # FCEUmm / MAME 2003-Plus, perfiles de mandos (autoconfig), hiscore.dat y las carpetas de juegos vacías.
  # Nunca lleva ni borra ROMs, partidas, estados ni BIOS. Antes de pisar la configuración la respalda en la computadora.
  local RA_SUM="" KODI_SUM=""
  local RA_VER=1.22.2
  local RA_CORES="fbneo mame2003_plus fceumm mupen64plus_next_gles3 flycast genesis_plus_gx pcsx_rearmed"
  ra_install() {   # $1 = apk: instala con reintentos si Play Protect lo frena
    local try=1 o
    while :; do
      case "$PLATFORM" in Google*|Android*)
        say "   ${Y}Si en el TV sale \"Bloqueada por Play Protect\" / \"App no segura\": elige ${B}Más detalles${N}${Y} > ${B}Instalar de todas formas${N}${Y}.${N}" ;;
      esac
      o=$(A install -r -g "$1" 2>&1 | tr -d '\r'); logq "ra install ($try): $o"
      case "$o" in
        *Success*) return 0 ;;
        *VERIFICATION*|*REJECTED*|*BLOCKED*|*ABORTED*|*"Play Protect"*|*USER_RESTRICTED*|*"Session"*)
          if [ "$try" -lt 3 ]; then
            aviso "Play Protect frenó la instalación de RetroArch (intento $try de 3)."
            say "   En la pantalla del TV: ${B}Más detalles${N} > ${B}Instalar de todas formas${N}. No hace falta apagar Play Protect."
            say "   Reintentando en 10 segundos..."; sleep 10; try=$((try + 1)); continue
          fi
          RA_ERR="Play Protect no dejó instalar RetroArch (en el TV: Más detalles > Instalar de todas formas, y repite la línea)"; return 1 ;;
        *UPDATE_INCOMPATIBLE*|*SIGNATURES*) RA_ERR="el TV ya tiene un RetroArch con otra firma (no se desinstala; quítalo a mano si quieres el oficial)"; return 1 ;;
        *INSUFFICIENT_STORAGE*) RA_ERR="no hay espacio en el TV para RetroArch"; return 1 ;;
        *) RA_ERR="la instalación falló: $(printf '%s' "$o" | tail -1)"; return 1 ;;
      esac
    done
  }
  ra_elf() {   # $1 = .so ; $2 = 32|64 -> 0 si es un ELF ARM de esa clase
    [ "$(head -c 4 "$1" 2>/dev/null | od -An -c | tr -d ' ')" = '177ELF' ] || return 1
    local cl; cl=$(od -An -tu1 -j4 -N1 "$1" | tr -d ' ')
    { [ "$2" = 32 ] && [ "$cl" = 1 ]; } || { [ "$2" = 64 ] && [ "$cl" = 2 ]; }
  }
  retroarch_paso() {
    local n=$1 RPKG RAPK RSHA RVC CABI BITS IVC have=0 dir st f c u ok=0 out bkr="" RA_ERR=""
    paso "$n" "RetroArch con los emuladores del cuarto (--retroarch)"
    if inlist com.retroarch.aarch64 "$INSTALLED" && ! inlist com.retroarch.ra32 "$INSTALLED"; then CABI=arm64-v8a
    else case ",$ABIS," in *,armeabi-v7a,*) CABI=armeabi-v7a ;; *,arm64-v8a,*) CABI=arm64-v8a ;; *) CABI="" ;; esac; fi
    case "$CABI" in
      armeabi-v7a) RPKG=com.retroarch.ra32; RAPK=RetroArch_ra32.apk; BITS=32
                   RSHA=9e964f53089a302401a6d5b1451d7ce5539f39b85eb0a305d8d77e6edcbf803f; RVC=1763607285 ;;
      arm64-v8a)   RPKG=com.retroarch.aarch64; RAPK=RetroArch_aarch64.apk; BITS=64
                   RSHA=7bd5d208dfe93cc8e2ea6c04608948ce1a045980f160a58ca2d0993aa20ad213; RVC=1763607214 ;;
      *) aviso "Este TV no tiene procesador ARM ($ABIS): RetroArch no se instala."; RA_SUM="no (procesador $ABIS)"; return 0 ;;
    esac
    [ "$SDK" -ge 21 ] || { aviso "Android muy viejo para RetroArch (API $SDK)."; RA_SUM="no (API $SDK)"; return 0; }
    inlist "$RPKG" "$INSTALLED" && have=1
    if [ "$have" = 1 ]; then IVC=$(S dumpsys package "$RPKG" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1); bien "RetroArch ya está ($RPKG, versionCode ${IVC:-?})"
    else bien "RetroArch no está: se instala el oficial $RA_VER ($CABI)"; fi
    case "$(S dumpsys window | grep -m1 mCurrentFocus)" in *"$RPKG"*)
      aviso "RetroArch está abierto en el TV ahora mismo (alguien jugando): no se toca. Ciérralo y repite la línea."; RA_SUM="no (estaba abierto)"; return 0 ;;
    esac
    if [ "$have" = 0 ] && [ "${FREE:-0}" -gt 0 ] && [ "$FREE" -lt 700000 ]; then
      aviso "Poco espacio en el TV ($((FREE / 1024)) MB; RetroArch necesita ~700 MB). No se instala."; RA_SUM="no (sin espacio)"; return 0
    fi
    dir="$WORK/apps/retroarch"; mkdir -p "$dir/cores-$CABI"
    f="$dir/$RAPK"
    if [ ! -f "$f" ] || [ "$(sha "$f")" != "$RSHA" ]; then
      say "   Descargando RetroArch $RA_VER oficial (buildbot.libretro.com, ~180 MB)..."
      dl "https://buildbot.libretro.com/stable/$RA_VER/android/$RAPK" "$f.part" && mv "$f.part" "$f" || rm -f "$f.part"
    fi
    if [ ! -f "$f" ] || [ "$(sha "$f")" != "$RSHA" ]; then rm -f "$f"; aviso "No se pudo bajar RetroArch oficial (o no coincide el sha256). No se instala."; RA_SUM="no (descarga)"; return 0; fi
    bien "RetroArch $RA_VER verificado (sha256 ${RSHA:0:12}…)"
    st="$dir/stage/lukra"; rm -rf "$dir/stage"; mkdir -p "$st/cores" "$st/info"
    cp -R "$BUNDLE/retroarch/ext" "$BUNDLE/retroarch/ra" "$st/" && cp "$BUNDLE/retroarch/tv-retroarch.sh" "$st/" || { aviso "Faltan archivos de RetroArch en el paquete."; RA_SUM="no (paquete incompleto)"; return 0; }
    say "   Descargando los 7 núcleos oficiales ($CABI) de buildbot.libretro.com..."
    for c in $RA_CORES; do
      u="https://buildbot.libretro.com/nightly/android/latest/$CABI/${c}_libretro_android.so.zip"
      rm -rf "$dir/tmp"; mkdir -p "$dir/tmp"
      if dl "$u" "$dir/tmp/c.zip" && unz "$dir/tmp/c.zip" "$dir/tmp" && ra_elf "$dir/tmp/${c}_libretro_android.so" "$BITS"; then
        mv -f "$dir/tmp/${c}_libretro_android.so" "$dir/cores-$CABI/"
      elif [ -f "$dir/cores-$CABI/${c}_libretro_android.so" ]; then aviso "No se pudo bajar $c ahora; se usa el que ya estaba en la computadora"
      else aviso "No se pudo bajar el núcleo $c"; fi
      [ -f "$dir/cores-$CABI/${c}_libretro_android.so" ] && cp "$dir/cores-$CABI/${c}_libretro_android.so" "$st/cores/" && ok=$((ok + 1))
    done
    rm -rf "$dir/tmp"
    bien "Núcleos listos: $ok de 7"
    if dl https://buildbot.libretro.com/assets/frontend/info.zip "$dir/info.zip" && unz "$dir/info.zip" "$st/info"; then
      bien "Fichas de núcleos (info) oficiales: $(find "$st/info" -name '*.info' | wc -l | tr -d ' ')"
    else aviso "No se pudieron bajar las fichas de núcleos (info); RetroArch funciona igual"; fi
    if [ "$DRY" = 1 ]; then
      sh -n "$st/tv-retroarch.sh" 2>>"$LOG" || bash -n "$st/tv-retroarch.sh" 2>>"$LOG" || aviso "tv-retroarch.sh tiene un error de sintaxis"
      if [ "$have" = 1 ] && [ "${IVC:-0}" -gt "$RVC" ]; then sim "RetroArch del TV es más nuevo ($IVC): no se reinstala"
      else sim "adb install -r -g $RAPK  (Google TV: Play Protect > Más detalles > Instalar de todas formas)"; fi
      sim "respaldo de retroarch.cfg y opciones a $WORK/respaldos/; copiar retroarch.cfg, $ok núcleos, $(find "$st/ext/autoconfig" -name '*.cfg' | wc -l | tr -d ' ') perfiles de mandos, FCEUmm.opt, MAME 2003-Plus.opt, hiscore.dat"
      sim "carpetas vacías en /sdcard/ROMs: Nintendo - NES, Arcade - Mame 2003 Plus, Nintendo - N64, SNK - NEO GEO, fbneo_1_0_0_3_best/{games,samples}"
      rm -rf "$dir/stage"; RA_SUM="simulado ($ok núcleos)"; return 0
    fi
    if [ "$have" = 1 ] && [ "${IVC:-0}" -gt "$RVC" ]; then bien "El RetroArch del TV es más nuevo que el $RA_VER: se deja (no se baja de versión)"
    else
      say "   Instalando RetroArch (conserva juegos, partidas y ajustes que tenga)..."
      if ra_install "$f"; then bien "RetroArch $RA_VER instalado"
      else aviso "RetroArch: $RA_ERR"; RA_SUM="no ($RA_ERR)"; rm -rf "$dir/stage"; return 0; fi
    fi
    # Respaldo de la configuración que ya tenía (en la computadora) antes de pisarla
    local EXTD="/storage/emulated/0/Android/data/$RPKG/files" RAD=/storage/emulated/0/RetroArch
    if [ "$(S "[ -f $EXTD/retroarch.cfg ] && echo y")" = y ]; then
      bkr="$WORK/respaldos/retroarch-${IP%%:*}-$TS"; mkdir -p "$bkr"
      A exec-out cat "$EXTD/retroarch.cfg" > "$bkr/retroarch.cfg" 2>>"$LOG"
      A exec-out cat "$RAD/config/FCEUmm/FCEUmm.opt" > "$bkr/FCEUmm.opt" 2>/dev/null
      A exec-out cat "$RAD/config/MAME 2003-Plus/MAME 2003-Plus.opt" > "$bkr/MAME 2003-Plus.opt" 2>/dev/null
      find "$bkr" -type f -size 0 -delete 2>/dev/null
      bien "Respaldo de la configuración de RetroArch: $bkr"
    fi
    say "   Copiando configuración, mandos y núcleos (RetroArch se abre y se cierra solo unas veces)..."
    A shell rm -rf /data/local/tmp/lukra >/dev/null 2>&1
    out=$(A push "$st" /data/local/tmp/ 2>&1 | tr -d '\r'); logq "ra push: $out"
    case "$out" in *error*|*failed*|*"No space"*) aviso "No se pudieron copiar los archivos de RetroArch al TV"; RA_SUM="no (copia)"; rm -rf "$dir/stage"; return 0 ;; esac
    out=$(A shell sh /data/local/tmp/lukra/tv-retroarch.sh "$RPKG" "$SDK" "$CABI" 2>&1 | tr -d '\r'); logq "ra apply: $out"
    A shell rm -rf /data/local/tmp/lukra >/dev/null 2>&1; rm -rf "$dir/stage"
    case "$out" in
      *RA_OK*)
        bien "Núcleos instalados en RetroArch: $(printf '%s' "$out" | sed -n 's/^RA_CORES //p' | head -1)"
        bien "Configuración del cuarto puesta: $(printf '%s' "$out" | sed -n 's/^RA_OK //p' | head -1)"
        case "$out" in *FALLARON*) aviso "Algún núcleo no se pudo instalar; se puede bajar en RetroArch: Menú principal > Actualizador en línea > Descargar núcleos" ;; esac
        RA_SUM="RetroArch $RA_VER listo ($(printf '%s' "$out" | sed -n 's/^RA_CORES \([0-9]*\/[0-9]*\).*/\1/p' | head -1) núcleos)" ;;
      *) aviso "RetroArch quedó instalado, pero la configuración falló: $(printf '%s' "$out" | grep RA_FAIL | head -1)"; RA_SUM="instalado, configuración falló" ;;
    esac
    A shell input keyevent KEYCODE_HOME >/dev/null 2>&1   # volver al inicio (Luk Home) después de abrir/cerrar RetroArch
    return 0
  }

  # ---------- Kodi de la sala (opcional: --kodi / KODI=1) ----------
  # Usa bundle/kodi/kodi-sala.sh (el mismo instalador del Kodi de la sala): Kodi 21.3 oficial con sha256, revisa
  # ABI/API, respalda el Kodi que haya, pm clear SOLO de Kodi, permisos, primera apertura, copia del build por
  # tar en /data/local/tmp. El build (kodi-sala.zip, >100 MB) se baja del Release kodi-build-2026-11-09 de este repo.
  kodi_paso() {
    local n=$1 ka=""
    paso "$n" "Kodi con el build de la sala (--kodi)"
    [ -f "$BUNDLE/kodi/kodi-sala.sh" ] || { aviso "Falta bundle/kodi/kodi-sala.sh en el paquete"; KODI_SUM="no (paquete incompleto)"; return 0; }
    [ "$DRY" = 1 ] && ka="--dry-run"
    [ "$KODI_REPL" = 1 ] && ka="$ka --reemplazar-kodi"
    if KODI_ADB="$ADB" KODI_SALA_DIR="$WORK/kodi" KODI_PASO_PREFIX="Kodi " bash "$BUNDLE/kodi/kodi-sala.sh" "$IP" $ka; then
      if [ "$DRY" = 1 ]; then KODI_SUM="simulado"; else KODI_SUM="Kodi con el build de la sala listo (TorBox: iniciar sesión otra vez en POV, Umbrella y ResolveURL)"; fi
    else
      aviso "Kodi no se pudo terminar (ver arriba). Luk Home y lo demás ya quedaron."; KODI_SUM="no (ver mensaje de Kodi)"
    fi
    return 0
  }
  extras() {   # pasos opcionales después del 8
    local k=9
    if [ "$RETRO" = 1 ]; then retroarch_paso $k; k=$((k + 1)); fi
    if [ "$KODI_OPT" = 1 ]; then kodi_paso $k; fi
    return 0
  }

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
  logq "ip=$IP theme=$THEME city=${CITY:-(sin cambio)} apps=${APPS:-(ninguna)} dry=$DRY new_dock=$NEW_DOCK noupdate=$NOUPD noapps=$NOAPPS buttons=${BTN:-(sin cambio)} estilo=${ESTILO_ARG:-(sin cambio)} retroarch=$RETRO kodi=$KODI_OPT pin_set=$([ -n "$PIN" ] && echo yes || echo no) os=$(uname -a)"

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
  # Temas: los de order.txt (incluidos) + carpetas extra de bundle/themes/ (temas personalizados de clientes:
  # solo van al TV si se nombran). Un tema = carpeta con fotos (jpg/png/webp) + name.txt (nombre en la pastilla Temas).
  thpics() { find "$BUNDLE/themes/$1" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' '; }
  okslug() { case "$1" in ''|-*|*[!a-z0-9_-]*) return 1 ;; esac; return 0; }
  th_alias() { case "$1" in halloween-terror|halloween|horror) echo terror ;; *) echo "$1" ;; esac; }
  local TH_BUILTIN="" TH_CUSTOM="" TH_SEL="" TH_LIST=0 t d bad=""
  for t in $(grep -v '^#' "$BUNDLE/themes/order.txt" | tr -d '\r'); do
    okslug "$t" && [ "$(thpics "$t")" -gt 0 ] && TH_BUILTIN="$TH_BUILTIN $t"
  done
  for d in "$BUNDLE"/themes/*/; do
    t=$(basename "$d")
    okslug "$t" && ! inlist "$t" "$TH_BUILTIN" && [ "$(thpics "$t")" -gt 0 ] && TH_CUSTOM="$TH_CUSTOM $t"
  done
  THEME=$(printf '%s' "$THEME" | tr 'A-Z' 'a-z' | tr -d ' \r')
  # Modos del menú Temas: "aleatorio" (fotos de todos los temas mezcladas) o "rotar" (un tema completo cada hora).
  # Van en la lista de temas (mejor al principio): aleatorio  |  rotar,mar,autos,espacio
  local TH_MODE="" t3=""
  for t in $(printf '%s' "$THEME" | tr ',' ' '); do
    case "$t" in
      aleatorio|aleatoria|random|mezclar|mezcla|shuffle) TH_MODE=aleatorio ;;
      rotar|rotartemas|rotar-temas|rotacion|rotate) TH_MODE=rotar ;;
      *) t3="$t3,$t" ;;
    esac
  done
  if [ -n "$TH_MODE" ]; then
    t3="${t3#,}"
    if [ -z "$t3" ]; then THEME=todos; else case "$t3" in *,*) THEME="$t3" ;; *) THEME="$t3," ;; esac; fi
  fi
  # Nombres viejos de temas (alias): las líneas de antes siguen funcionando.
  case "$THEME" in
    *,*) local t2=""; for t in $(printf '%s' "$THEME" | tr ',' ' '); do t2="$t2,$(th_alias "$t")"; done
         THEME="${t2#,}"; case "$THEME" in *,*) ;; *) THEME="$THEME," ;; esac ;;
    *) THEME=$(th_alias "$THEME") ;;
  esac
  case "$THEME" in
    *,*)   # lista: solo esos temas, en ese orden; el primero es el inicial
      TH_LIST=1
      for t in $(printf '%s' "$THEME" | tr ',' ' '); do
        if [ "$t" = todos ]; then for d in $TH_BUILTIN; do inlist "$d" "$TH_SEL" || TH_SEL="$TH_SEL $d"; done
        elif inlist "$t" "$TH_BUILTIN $TH_CUSTOM"; then inlist "$t" "$TH_SEL" || TH_SEL="$TH_SEL $t"
        else bad="$bad, \"$t\""; fi
      done ;;
    ''|todos) TH_SEL="$TH_BUILTIN"; THEME_GIVEN=0 ;;
    *) if inlist "$THEME" "$TH_BUILTIN"; then TH_SEL="$TH_BUILTIN"
       elif inlist "$THEME" "$TH_CUSTOM"; then TH_SEL=" $THEME$TH_BUILTIN"
       else bad="\"$THEME\""; fi ;;
  esac
  if [ -n "$bad" ] || [ -z "$(printf '%s' "$TH_SEL" | tr -d ' ')" ]; then
    falla "Tema no válido: ${bad#, }" "Temas válidos: $(printf '%s' "$TH_BUILTIN" | sed 's/^ //; s/ /, /g')$( [ -n "$TH_CUSTOM" ] && printf '. Personalizados: %s' "$(printf '%s' "$TH_CUSTOM" | sed 's/^ //; s/ /, /g')"). Para varios: autos,mar,espacio (el primero es el inicial) o \"todos\"."
  fi
  TH_SEL="${TH_SEL# }"
  if [ "$TH_LIST" = 1 ]; then THEME="${TH_SEL%% *}"; THEME_GIVEN=1
  elif [ -z "$THEME" ] || [ "$THEME" = todos ]; then THEME=paisajes; inlist paisajes "$TH_SEL" || THEME="${TH_SEL%% *}"; fi
  [ -n "$TH_MODE" ] && THEME_GIVEN=1
  local nsel; nsel=$(printf '%s\n' $TH_SEL | grep -c .)
  if [ "$TH_LIST" = 1 ]; then bien "Paquete listo ($nsel temas elegidos: $(printf '%s' "$TH_SEL" | sed 's/ /, /g'))"
  else bien "Paquete listo ($nsel temas)"; fi
  logq "themes builtin=$TH_BUILTIN custom=$TH_CUSTOM sel=$TH_SEL list=$TH_LIST default=$THEME mode=${TH_MODE:-no} given=$THEME_GIVEN"

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
  if [ -n "$APPS" ]; then   # apps extra para el inicio: qué hay instalado y qué se puede abrir (solo lectura)
    DISABLED=" $(S pm list packages -d | sed 's/^package://' | tr '\n' ' ') "
    THIRD=" $(S pm list packages -3 | sed 's/^package://' | tr '\n' ' ') "
    LAUNCHABLE=$( { S cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER
                    S cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER; } \
                  | sed -n 's#^[[:space:]]*\([A-Za-z0-9_.]*\)/.*#\1#p' | sort -u | tr '\n' ' ')
    [ -n "$LAUNCHABLE" ] && LAUNCHABLE=" $LAUNCHABLE "
    local kn; for kn in $APP_KNOWN; do KNOWN_PKGS="$KNOWN_PKGS $(app_cands "$kn")"; done; KNOWN_PKGS="$KNOWN_PKGS "
    logq "apps: third=$THIRD launchable=${LAUNCHABLE:-(no se pudo leer)}"
    resolver_apps
  fi
  local LUK_PRESENT=0 LUK_SHA="" HAS_DOCK=0 HAS_THEME=0 TV_THEMES="" TH_PREV=""
  local ABIS; ABIS=$(S getprop ro.product.cpu.abilist); [ -n "$ABIS" ] || ABIS=$(S getprop ro.product.cpu.abi)
  # ABI principal (la que usa el sistema): Fire TV de 64 bits con Android de 32 bits dicen armeabi-v7a
  local CPU_ABI; CPU_ABI=$(S getprop ro.product.cpu.abi); [ -n "$CPU_ABI" ] || CPU_ABI=${ABIS%%,*}
  logq "abi=$CPU_ABI abilist=$ABIS"
  if inlist "$PKG" "$INSTALLED"; then
    LUK_PRESENT=1
    OLD_UOP=$(S appops get "$PKG" GET_USAGE_STATS | sed -n 's/^GET_USAGE_STATS: \([a-z]*\).*/\1/p' | head -1)
    LUK_SHA=$(S sha256sum "$(S pm path "$PKG" | head -1 | sed 's/^package://')" | awk '{print $1}')   # Fire OS 6 no tiene sha256sum: vacío = se reinstala (conserva los datos)
    S run-as "$PKG" ls files/dock.txt | grep -q '^files/dock.txt$' && HAS_DOCK=1
    S run-as "$PKG" ls files/theme.txt | grep -q '^files/theme.txt$' && HAS_THEME=1
    TV_THEMES=" $(S run-as "$PKG" ls files/themes | grep -E '^[a-z0-9][a-z0-9_-]*$' | tr '\n' ' ') "
    TH_PREV=" $(S run-as "$PKG" cat files/themes/.instalador.txt | grep -E '^[a-z0-9][a-z0-9_-]*$' | tr '\n' ' ') "
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
  for t in $TH_SEL; do cp -R "$BUNDLE/themes/$t" "$STAGE/themes/"; done
  printf '%s\n' $TH_SEL > "$STAGE/themes/order.txt"
  # Lista de temas que puso el instalador (files/themes/.instalador.txt en el TV). Con una LISTA de temas,
  # se quitan del TV solo los temas que puso el instalador y ya no están en la lista; nunca otros archivos.
  local TH_RM="" TH_KEEP=""
  if [ "$TH_LIST" = 1 ]; then
    for t in $TH_BUILTIN $TH_CUSTOM $TH_PREV; do
      inlist "$t" "$TH_SEL" || inlist "$t" "$TH_RM" || ! inlist "$t" "$TV_THEMES" || TH_RM="$TH_RM $t"
    done
    TH_KEEP="$TH_SEL"
  else
    TH_KEEP="$TH_SEL"; for t in $TH_PREV; do inlist "$t" "$TH_KEEP" || ! inlist "$t" "$TV_THEMES" || TH_KEEP="$TH_KEEP $t"; done
  fi
  # Temas renombrados (viejo:nuevo). Si el TV tiene la carpeta vieja (de un instalador o kit anterior), se borra:
  # el tema nuevo ya va en la lista (o el cliente no lo quiere), y el registro .instalador.txt no la guarda más.
  local TH_MIG="" TH_RM_MSG="$TH_RM" pr k2=""
  for pr in $TH_RENAMED; do
    inlist "${pr%%:*}" "$TV_THEMES" || continue
    inlist "${pr%%:*}" "$TH_RM" || TH_RM="$TH_RM ${pr%%:*}"
    if inlist "${pr#*:}" "$TH_SEL"; then TH_MIG="$TH_MIG ${pr%%:*}→${pr#*:}"; else k2="$k2 ${pr%%:*}"; fi
  done
  local TH_GONE="$k2"; k2=""
  for t in $TH_RM_MSG; do inlist "$t" "$TH_RENAMED_OLD" || k2="$k2 $t"; done; TH_RM_MSG="$k2$TH_GONE"; k2=""
  for t in $TH_KEEP; do inlist "$t" "$TH_RENAMED_OLD" || k2="$k2 $t"; done; TH_KEEP="${k2# }"
  printf '%s\n' $TH_KEEP > "$STAGE/themes/installed.txt"
  [ -n "$TH_RM" ] && printf '%s\n' $TH_RM > "$STAGE/themes/remove.txt"
  cp "$BUNDLE/tv-apply.sh" "$STAGE/tv-apply.sh"
  [ -f "$BUNDLE/logo.png" ] && cp "$BUNDLE/logo.png" "$STAGE/logo.png"   # logo de la marca (debajo de Temas/Ajustes)
  printf '20\n' > "$STAGE/rotate.txt"
  local p name ndock=0 missing="" ntile=0
  for p in "$BUNDLE"/tiles/*.png; do
    p=$(basename "$p" .png)
    if inlist "$p" "$INSTALLED"; then cp "$BUNDLE/tiles/$p.png" "$BUNDLE/tiles/$p.txt" "$STAGE/tiles/"; ntile=$((ntile + 1)); fi
  done
  local DOCK_MODE=""
  if [ "$HAS_DOCK" = 1 ] && [ "$NEW_DOCK" = 0 ] && [ -z "$EXTRA_PKGS" ]; then
    bien "El dock ya existía: se deja como está (para reescribirlo: --nuevo-dock)"
    [ -n "$APPS" ] && aviso "Ninguna de las apps extra se pudo poner en el inicio (ver avisos de arriba)"
  elif [ "$HAS_DOCK" = 1 ] && [ "$NEW_DOCK" = 0 ]; then
    # APPS con un dock que ya existe: se deja el dock del TV tal cual y se agregan al final las que falten
    awk '{print}' "$BK/dock-antes.txt" > "$STAGE/dock.txt"
    local have added="" already=""
    have=" $(grep -v '^#' "$STAGE/dock.txt" | tr -d ' \r' | tr '\n' ' ') "
    for p in $EXTRA_PKGS; do
      name=$(app_label "$p")
      if inlist "$p" "$have"; then already="$already, $name"; else echo "$p" >> "$STAGE/dock.txt"; have="$have$p "; added="$added, $name"; ndock=$((ndock + 1)); fi
    done
    if [ -n "$added" ]; then DOCK_MODE=extra; bien "Dock: se deja el que tenía el TV y se agregan al final:${added#,}"
    else rm -f "$STAGE/dock.txt"; bien "Dock: se deja como está"; fi
    [ -n "$already" ] && bien "Ya estaban en el inicio:${already#,}"
  else
    printf '# Apps del inicio, en orden\n' > "$STAGE/dock.txt"
    for p in $DOCK_APPS; do
      name=$(cat "$BUNDLE/tiles/$p.txt" 2>/dev/null || echo "$p")
      if inlist "$p" "$INSTALLED"; then echo "$p" >> "$STAGE/dock.txt"; ndock=$((ndock + 1)); else missing="$missing, $name"; fi
    done
    local added=""
    for p in $EXTRA_PKGS; do
      inlist "$p" "$DOCK_APPS" && continue
      echo "$p" >> "$STAGE/dock.txt"; ndock=$((ndock + 1)); added="$added, $(app_label "$p")"
    done
    DOCK_MODE=nuevo
    bien "Dock: $ndock app(s) en el inicio; las demás quedan en \"Otras apps\""
    [ -n "$added" ] && bien "Apps extra en el inicio:${added#,}"
    if [ -n "$missing" ]; then
      if [ "$NOAPPS" = 1 ]; then aviso "No están instaladas (no van al dock; --sin-apps):${missing#,}"
      else bien "Todavía no están en el TV:${missing#,} (se instalan en el paso 8 y se agregan al dock)"; fi
    fi
  fi
  if [ -f "$STAGE/dock.txt" ] && [ "$(grep -v '^#' "$STAGE/dock.txt" | grep -c .)" -gt 20 ]; then
    aviso "El inicio muestra máximo 20 apps; las que pasen de 20 quedan en \"Otras apps\""
  fi
  local CUR_THEME=""; [ "$HAS_THEME" = 1 ] && CUR_THEME=$(S run-as "$PKG" cat files/theme.txt | head -1 | tr -d '\r')
  local CUR_NEW=""; for pr in $TH_RENAMED; do [ "$CUR_THEME" = "${pr%%:*}" ] && CUR_NEW="${pr#*:}"; done
  [ -n "$TH_MIG" ] && bien "Tema renombrado en el TV:$(printf '%s' "$TH_MIG" | sed 's/ /, /g; s/^,//') (se reemplaza la carpeta vieja)"
  if [ "$THEME_GIVEN" = 0 ] && [ "$HAS_THEME" = 1 ] && [ -n "$CUR_NEW" ] && inlist "$CUR_NEW" "$TH_SEL"; then
    printf '%s\n' "$CUR_NEW" > "$STAGE/theme.txt"; bien "Se mantiene el tema que ya tenía el TV, con su nombre nuevo: $(head -1 "$BUNDLE/themes/$CUR_NEW/name.txt" 2>/dev/null || echo "$CUR_NEW")"
  elif [ -n "$TH_MODE" ]; then
    printf '@%s\n' "$TH_MODE" > "$STAGE/theme.txt"
    if [ "$TH_MODE" = aleatorio ]; then bien "Temas: Aleatorio (fotos de todos los temas, mezcladas)"
    else bien "Temas: Rotar temas (un tema completo cada hora, en el orden de la lista)"; fi
  elif [ "$THEME_GIVEN" = 1 ] || [ "$HAS_THEME" = 0 ] || inlist "$CUR_THEME" "$TH_RM"; then printf '%s\n' "$THEME" > "$STAGE/theme.txt"; bien "Tema inicial: $(head -1 "$BUNDLE/themes/$THEME/name.txt" 2>/dev/null || echo "$THEME")"
  else bien "Se mantiene el tema que ya tenía el TV"; fi
  [ -n "$TH_RM_MSG" ] && bien "Se quitan del TV los temas que ya no van: $(printf '%s' "${TH_RM_MSG# }" | sed 's/ /, /g') (solo temas puestos por el instalador)"
  [ -n "$PIN" ] && printf '%s\n' "$PIN_HASH" > "$STAGE/pin.txt"
  if [ "$BTN" = on ]; then printf 'on\n' > "$STAGE/block-app-buttons.txt"; bien "Botones de apps del control: bloqueados (para volver: --desbloquear-botones)"
  elif [ "$BTN" = off ]; then printf 'off\n' > "$STAGE/block-app-buttons.txt"; bien "Botones de apps del control: normales"; fi
  if [ "$ESTILO_ARG" = colores ]; then printf 'colores\n' > "$STAGE/dock-style.txt"; bien "Estilo del inicio: Colores (se cambia en el TV: botón de Temas > Estilo)"
  elif [ "$ESTILO_ARG" = oscuro ]; then printf 'oscuro\n' > "$STAGE/dock-style.txt"; bien "Estilo del inicio: Oscuro"; fi
  if [ -n "$CITY" ]; then   # ciudad del botón del tiempo; Luk Home la busca en Open-Meteo al recargar
    printf '# Luk Home: ciudad del tiempo (auto = por internet). Puesta por el instalador.\n%s\n' "$CITY" > "$STAGE/weather.txt"
    if [ "$CITY" = auto ]; then bien "Tiempo: ciudad automática (por internet)"; else bien "Tiempo: ciudad fija \"$CITY\" (se cambia en el TV con \"Cambiar ciudad\")"; fi
  fi
  local nth njpg kb
  nth=$(grep -c . "$STAGE/themes/order.txt"); njpg=$(find "$STAGE/themes" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')
  kb=$(du -sk "$STAGE" | cut -f1)
  logq "stage=$STAGE themes=$nth jpg=$njpg tiles=$ntile kb=$kb files=$(find "$STAGE" -maxdepth 1 | tr '\n' ' ')"
  if [ "$DRY" = 1 ]; then
    bash -n "$STAGE/tv-apply.sh" 2>>"$LOG" || falla "tv-apply.sh tiene un error de sintaxis."
    sim "adb push lukhome/ → /data/local/tmp/ ($nth temas, $njpg fotos, $ntile íconos, $kb KB)"
    sim "adb shell sh /data/local/tmp/lukhome/tv-apply.sh  (escribe: themes/, tiles/, rotate.txt$( [ -f "$STAGE/logo.png" ] && echo ', logo.png')$( [ -f "$STAGE/dock.txt" ] && echo ', dock.txt')$( [ -f "$STAGE/theme.txt" ] && echo ', theme.txt')$( [ -f "$STAGE/weather.txt" ] && echo ', weather.txt')$( [ -n "$PIN" ] && echo ', pin.txt')$( [ -f "$STAGE/block-app-buttons.txt" ] && echo ', block-app-buttons.txt')$( [ -f "$STAGE/dock-style.txt" ] && echo ', dock-style.txt'))"
    [ -f "$STAGE/dock.txt" ] && sim "dock.txt = $(grep -v '^#' "$STAGE/dock.txt" | tr '\n' ' ')"
    sim "temas = $(printf '%s' "$TH_SEL" | sed 's/ /, /g')$( [ -n "$TH_RM" ] && printf '   (se borrarían del TV: %s)' "$(printf '%s' "${TH_RM# }" | sed 's/ /, /g')")"
  else
    A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
    say "   Copiando $nth temas ($((kb / 1024)) MB)..."
    out=$(A push "$STAGE" /data/local/tmp/ 2>&1 | tr -d '\r'); logq "push: $out"
    case "$out" in *error*|*failed*|*"No space"*) falla "No se pudieron copiar los archivos al TV." "$(printf '%s' "$out" | tail -1)" ;; esac
    out=$(A shell sh /data/local/tmp/lukhome/tv-apply.sh 2>&1 | tr -d '\r'); logq "apply: $out"
    case "$out" in *LUK_APPLY_OK*) ;; *) A shell rm -rf /data/local/tmp/lukhome >/dev/null 2>&1
      falla "No se pudieron guardar los archivos dentro de Luk Home." "$(printf '%s' "$out" | grep LUK_APPLY_FAIL | head -1)" ;; esac
    case "$out" in *"REMOVED "[1-9]*) bien "Temas quitados: $(printf '%s' "$out" | sed -n 's/^REMOVED //p' | head -1)" ;; esac
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
    actualizar_apps
    extras
    say ""
    say "${G}${B}  SIMULACIÓN TERMINADA SIN ERRORES — no se cambió nada en el TV.${N}"
    say "  Apps: $UPD_SUM"
    [ -n "$RA_SUM" ] && say "  RetroArch: $RA_SUM"
    [ -n "$KODI_SUM" ] && say "  Kodi: $KODI_SUM"
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
  v_theme=$(S run-as "$PKG" cat files/theme.txt | head -1 | tr -d '\r')
  case "$v_theme" in @*) v_theme="" ;; esac   # modo Aleatorio / Rotar: se comprueba el primer tema
  v_jpg=$(S run-as "$PKG" ls "files/themes/${v_theme:-$THEME}" | grep -ciE '\.(jpe?g|png|webp)$')
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
  ACC_CHANGED=0; HOME_CHANGED=0; UOP_CHANGED=0   # comprobado: lo hecho se queda aunque falle o se cancele el paso 8
  actualizar_apps
  extras
  say ""
  say "${G}${B}  ██      ██  ███████  ████████  ██████  ${N}"
  say "${G}${B}  ██      ██  ██          ██    ██    ██ ${N}"
  say "${G}${B}  ██      ██  ███████     ██    ██    ██ ${N}"
  say "${G}${B}  ██      ██       ██     ██    ██    ██ ${N}"
  say "${G}${B}  ██████  ██  ███████     ██     ██████  ${N}"
  say ""
  say "${G}${B}  ¡LISTO! Luk Home quedó instalado en el TV.${N}"
  say "  • Botón \"Temas\" (arriba a la derecha) para cambiar el fondo."
  say "  • Botón del tiempo (arriba a la derecha): temperatura, pronóstico y \"Cambiar ciudad\"."
  say "  • Ajustes queda protegido con PIN."
  say "  • Apps: $UPD_SUM"
  [ -n "$RA_SUM" ] && say "  • RetroArch: $RA_SUM (juegos en /sdcard/ROMs o en una memoria USB; sin ROMs ni BIOS)"
  [ -n "$KODI_SUM" ] && say "  • Kodi: $KODI_SUM"
  say "  • Ya puedes cerrar esta ventana."
  say ""
  say "  (Respaldo: $BK)"
  return 0
}

main "$@"
exit $?
