#!/usr/bin/env bash
# Instalador de Luk Home para clientes (Mac; también funciona en Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- <IP> <PIN> [TEMA]
#
#   <IP>    IP del Fire TV / Google TV (Ajustes > Mi Fire TV > Acerca de > Red)
#   <PIN>   4 números para bloquear Ajustes (o "sinpin" para no poner PIN)
#   [TEMA]  tema inicial (por defecto: paisajes), "todos", o una LISTA separada por comas
#           (ej. autos,mar,terror): solo esos temas van al TV y el primero es el inicial.
#           Nombres viejos que siguen valiendo: halloween-terror / halloween / horror = terror.
#           Temas: carpetas de bundle/themes/ (las de order.txt + temas personalizados de clientes).
#
# Opciones (después de la IP y el PIN):
#   --dry-run        hace todo (descargas, conexión, lecturas, respaldo) pero NO escribe nada en el TV ni pulsa teclas
#   --nuevo-dock     reescribe el dock (Stremio, IPTV Smarters, TizenTube) aunque Luk Home ya tenga uno
#   --sin-actualizar no revisa si hay versión nueva de Stremio / IPTV Smarters / TizenTube (también LUK_NOUPDATE=1)
#
# Solo modo "launcher": no borra ni desinstala ninguna app del cliente. Lo único que toca de sus apps es
# actualizar (adb install -r, conserva datos y sesiones) Stremio / IPTV Smarters / TizenTube si ya están
# instaladas y hay una versión oficial más nueva con la misma firma.
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
  local IP="" PIN="" THEME="" THEME_GIVEN=0 DRY=0 NEW_DOCK=0 NOUPD="${LUK_NOUPDATE:-0}" a
  for a in "$@"; do
    case "$a" in
      --dry-run|--simular) DRY=1 ;;
      --nuevo-dock) NEW_DOCK=1 ;;
      --sin-actualizar|--no-update) NOUPD=1 ;;
      -h|--help) sed -n '2,22p' "$0" 2>/dev/null || true; return 0 ;;
      -*) printf 'Opción desconocida: %s\n' "$a"; return 2 ;;
      *) if [ -z "$IP" ]; then IP="$a"; elif [ -z "$PIN" ]; then PIN="$a"; elif [ -z "$THEME" ]; then THEME="$a"; THEME_GIVEN=1
         else printf 'Sobra este dato: %s\n' "$a"; return 2; fi ;;
    esac
  done
  IP="${IP:-${LUK_IP:-}}"; PIN="${PIN:-${LUK_PIN:-}}"
  if [ -z "$THEME" ] && [ -n "${LUK_THEME:-}" ]; then THEME="$LUK_THEME"; THEME_GIVEN=1; fi
  case "$NOUPD" in 1|si|sí|yes|true) NOUPD=1 ;; *) NOUPD=0 ;; esac

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
  NSTEP=8
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
  trap 'say ""; if [ "$SUCCESS" = 1 ]; then rm -f "$WORK"/apps/*/*.part 2>/dev/null; say "  Se canceló la revisión de apps. Luk Home ya quedó instalado; las apps siguen como estaban."; exit 130; fi; falla "Se canceló la instalación (Ctrl+C)."' INT TERM

  A() { "$ADB" -s "$SERIAL" "$@" </dev/null; }
  S() { A shell "$@" 2>/dev/null | tr -d '\r'; }
  inlist() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
  sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
  unz() { if command -v unzip >/dev/null 2>&1; then unzip -qo "$1" -d "$2"; else python3 -m zipfile -e "$1" "$2"; fi; }
  dl() { curl -fL --retry 3 --connect-timeout 20 -sS -o "$2" "$1" >>"$LOG" 2>&1; }

  # ---------- actualizar apps del cliente (paso 8) ----------
  # Solo Stremio, IPTV Smarters y TizenTube, solo si ya están instaladas, solo a una versión oficial MÁS NUEVA
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
  isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
  vgt() { awk -v a="$1" -v b="$2" 'BEGIN{n=split(a,x,/[^0-9]+/);m=split(b,y,/[^0-9]+/);k=n>m?n:m;for(i=1;i<=k;i++){if(x[i]+0>y[i]+0)exit 0;if(x[i]+0<y[i]+0)exit 1}exit 1}'; }
  # Versiones oficiales conocidas cuyo versionCode no viene en el nombre (evita bajar 78 MB solo para leerlo).
  local KNOWN_VC="iptv-smarters-4.0.6.apk=106"
  local KNOWN_SHA="iptv-smarters-4.0.6.apk=07768dd9b805d129a84698e4d3163d1fbb2340c80ba118dbaa7bbcfe4cf5e01b"
  local SMARTERS_PIN="iptv-smarters-4.0.6.apk"   # si www.iptvsmarters.com no contesta
  local R_URL R_ALT R_FILE R_VN R_VC R_SHA
  # Última versión oficial: $1=app $2=abi (arm64-v8a | armeabi-v7a)
  remote_info() {
    R_URL="" R_ALT="" R_FILE="" R_VN="" R_VC="" R_SHA=""
    local page u f v c best=0 tag asset kv
    case "$1" in
      stremio)   # www.stremio.com/downloads: solo los APK de Android TV, sin rc/beta
        page=$(curl -fsSL --connect-timeout 15 -m 60 https://www.stremio.com/downloads 2>>"$LOG") || return 1
        for u in $(printf '%s' "$page" | grep -oE 'https://dl\.strem\.io/android/v[0-9][A-Za-z0-9._-]*-androidTV/com\.stremio\.one-[A-Za-z0-9._-]*\.apk' | sort -u); do
          f=${u##*/}
          case "$f" in *-"$2".apk) ;; *) continue ;; esac
          v=${f#com.stremio.one-}; v=${v%-"$2".apk}; c=${v##*-}; v=${v%-*}
          case "$v" in ''|*[!0-9.]*) continue ;; esac
          isnum "$c" || continue
          if [ "$c" -gt "$best" ]; then best=$c; R_URL=$u; R_FILE=$f; R_VN=$v; R_VC=$c; fi
        done ;;
      tizentube)  # GitHub reisxd/TizenTubeCobalt (última release; trae el sha256 de cada archivo)
        case "$2" in arm64-v8a) asset=cobalt-arm64.apk ;; armeabi-v7a) asset=cobalt-arm.apk ;; *) return 1 ;; esac
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
      smarters)   # www.iptvsmarters.com ("Download Latest Version"); copia oficial en www.smartersott.app
        page=$(curl -fsSL -A 'Mozilla/5.0' --connect-timeout 15 -m 60 https://www.iptvsmarters.com/ 2>>"$LOG")
        for f in $(printf '%s' "$page" | grep -oE 'iptv-smarters-[0-9][0-9.]*[0-9]\.apk' | sort -u); do
          if [ -z "$R_FILE" ] || vgt "${f#iptv-smarters-}" "${R_FILE#iptv-smarters-}"; then R_FILE=$f; fi
        done
        [ -n "$R_FILE" ] || R_FILE=$SMARTERS_PIN
        R_URL="https://www.iptvsmarters.com/$R_FILE"; R_ALT="https://www.smartersott.app/$R_FILE"
        R_VN=${R_FILE#iptv-smarters-}; R_VN=${R_VN%.apk} ;;
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
  actualizar_apps() {
    paso 8 "Revisando actualizaciones de apps"
    if [ "$NOUPD" = 1 ]; then bien "Omitido (--sin-actualizar)"; UPD_SUM="no se revisaron (--sin-actualizar)"; return 0; fi
    if ! inlist com.stremio.one "$INSTALLED" && ! inlist com.nst.iptvsmarterstvbox "$INSTALLED" && ! inlist io.gh.reisxd.tizentube.cobalt "$INSTALLED"; then
      bien "Ni Stremio, ni IPTV Smarters, ni TizenTube están instaladas: nada que revisar"; UPD_SUM="ninguna instalada"; return 0
    fi
    command -v perl >/dev/null 2>&1 || aviso "Esta computadora no tiene perl: solo se puede comparar sin descargar"
    UPD_SUM=""
    upd_app stremio com.stremio.one "Stremio"
    upd_app smarters com.nst.iptvsmarterstvbox "IPTV Smarters"
    upd_app tizentube io.gh.reisxd.tizentube.cobalt "TizenTube"
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
  logq "ip=$IP theme=$THEME dry=$DRY new_dock=$NEW_DOCK noupdate=$NOUPD pin_set=$([ -n "$PIN" ] && echo yes || echo no) os=$(uname -a)"

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
  local nsel; nsel=$(printf '%s\n' $TH_SEL | grep -c .)
  if [ "$TH_LIST" = 1 ]; then bien "Paquete listo ($nsel temas elegidos: $(printf '%s' "$TH_SEL" | sed 's/ /, /g'))"
  else bien "Paquete listo ($nsel temas)"; fi
  logq "themes builtin=$TH_BUILTIN custom=$TH_CUSTOM sel=$TH_SEL list=$TH_LIST default=$THEME given=$THEME_GIVEN"

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
  local LUK_PRESENT=0 LUK_SHA="" HAS_DOCK=0 HAS_THEME=0 TV_THEMES="" TH_PREV=""
  local ABIS; ABIS=$(S getprop ro.product.cpu.abilist); [ -n "$ABIS" ] || ABIS=$(S getprop ro.product.cpu.abi)
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
  local CUR_THEME=""; [ "$HAS_THEME" = 1 ] && CUR_THEME=$(S run-as "$PKG" cat files/theme.txt | head -1 | tr -d '\r')
  local CUR_NEW=""; for pr in $TH_RENAMED; do [ "$CUR_THEME" = "${pr%%:*}" ] && CUR_NEW="${pr#*:}"; done
  [ -n "$TH_MIG" ] && bien "Tema renombrado en el TV:$(printf '%s' "$TH_MIG" | sed 's/ /, /g; s/^,//') (se reemplaza la carpeta vieja)"
  if [ "$THEME_GIVEN" = 0 ] && [ "$HAS_THEME" = 1 ] && [ -n "$CUR_NEW" ] && inlist "$CUR_NEW" "$TH_SEL"; then
    printf '%s\n' "$CUR_NEW" > "$STAGE/theme.txt"; bien "Se mantiene el tema que ya tenía el TV, con su nombre nuevo: $(head -1 "$BUNDLE/themes/$CUR_NEW/name.txt" 2>/dev/null || echo "$CUR_NEW")"
  elif [ "$THEME_GIVEN" = 1 ] || [ "$HAS_THEME" = 0 ] || inlist "$CUR_THEME" "$TH_RM"; then printf '%s\n' "$THEME" > "$STAGE/theme.txt"; bien "Tema inicial: $(head -1 "$BUNDLE/themes/$THEME/name.txt" 2>/dev/null || echo "$THEME")"
  else bien "Se mantiene el tema que ya tenía el TV"; fi
  [ -n "$TH_RM_MSG" ] && bien "Se quitan del TV los temas que ya no van: $(printf '%s' "${TH_RM_MSG# }" | sed 's/ /, /g') (solo temas puestos por el instalador)"
  [ -n "$PIN" ] && printf '%s\n' "$PIN_HASH" > "$STAGE/pin.txt"
  local nth njpg kb
  nth=$(grep -c . "$STAGE/themes/order.txt"); njpg=$(find "$STAGE/themes" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')
  kb=$(du -sk "$STAGE" | cut -f1)
  logq "stage=$STAGE themes=$nth jpg=$njpg tiles=$ntile kb=$kb files=$(find "$STAGE" -maxdepth 1 | tr '\n' ' ')"
  if [ "$DRY" = 1 ]; then
    bash -n "$STAGE/tv-apply.sh" 2>>"$LOG" || falla "tv-apply.sh tiene un error de sintaxis."
    sim "adb push lukhome/ → /data/local/tmp/ ($nth temas, $njpg fotos, $ntile íconos, $kb KB)"
    sim "adb shell sh /data/local/tmp/lukhome/tv-apply.sh  (escribe: themes/, tiles/, rotate.txt$( [ -f "$STAGE/logo.png" ] && echo ', logo.png')$( [ -f "$STAGE/dock.txt" ] && echo ', dock.txt')$( [ -f "$STAGE/theme.txt" ] && echo ', theme.txt')$( [ -n "$PIN" ] && echo ', pin.txt'))"
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
    say ""
    say "${G}${B}  SIMULACIÓN TERMINADA SIN ERRORES — no se cambió nada en el TV.${N}"
    say "  Apps: $UPD_SUM"
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
  say "  • Apps: $UPD_SUM"
  say "  • Ya puedes cerrar esta ventana."
  say ""
  say "  (Respaldo: $BK)"
  return 0
}

main "$@"
exit $?
