# Instalador de Luk Home para clientes - Windows 10/11 (PowerShell 5.1 o 7), sin administrador.
#
#   $IP='192.168.1.50'; $PIN='1234'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
#
# Variables opcionales (antes de irm):  $THEME='mar'   $DRYRUN=1 (simulacion, no escribe en el TV)   $NUEVODOCK=1
#   $THEME='autos,mar,terror'  lista: solo esos temas van al TV, el primero es el inicial ('todos' = todos)
#   $THEME='aleatorio' o 'rotar' (o al principio de la lista: 'rotar,mar,autos'): modos del menu Temas.
#                aleatorio = fotos de todos los temas mezcladas; rotar = un tema completo cada hora
#   Nombres viejos que siguen valiendo: halloween-terror / halloween / horror = terror.
#   $BOTONES='bloquear'  los botones de apps del control (Netflix, Prime, YouTube...) no hacen nada
#                (Fire TV: solo los de apps no instaladas, que abren la tienda); $BOTONES='normal' los deja como vienen.
#   $ESTILO='colores'  tarjetas del inicio de colores (rayas y brillo, logo en una burbuja); $ESTILO='oscuro' tarjetas
#                oscuras con logo blanco y foco verde (el normal). Sin $ESTILO el TV se queda con el que tenga (uno nuevo
#                empieza en oscuro). En el TV se cambia en el boton de Temas (paleta), seccion "Estilo".
#   $NOUPDATE=1  no revisar si hay version nueva de Stremio / TizenTube (las que ya estan) y dejar la IPTV Smarters
#                que tenga el TV aunque no sea la gratis de Troypoint
#   IPTV Smarters: siempre la GRATIS 3.1.5.1 de Troypoint (MediaFire, sha256 fijo). Si el TV tiene otra (ej. la 4.0.6
#                de pago) se cambia por esa: se desinstala primero y se BORRAN el login y las listas de Smarters.
#   $SINAPPS=1   no instalar Stremio / IPTV Smarters / TizenTube si faltan en el TV (normal: se instalan)
#   $CIUDAD='Miami'  ciudad del boton del tiempo (arriba a la derecha): 'Madrid, Espana', '25.76,-80.19' o 'auto'
#                (por internet, segun la IP). Sin $CIUDAD el TV se queda con la que tenga (al principio: auto).
#   $APPS='netflix,youtube,disney'  apps del cliente que tambien van al inicio, despues de Stremio / IPTV Smarters /
#                TizenTube (o el paquete exacto, ej. com.netflix.ninja; 'todas' = todas las que ya tiene). Las que no
#                esten instaladas se saltan con un aviso. Si el TV ya tenia dock, se agregan al final. No instala nada.
#   $RETROARCH=1  ADEMAS instala o actualiza RetroArch oficial (libretro) con la configuracion del TV del cuarto:
#                retroarch.cfg, 7 nucleos (FinalBurn Neo, MAME 2003-Plus, FCEUmm, Mupen64Plus-Next, Flycast, Genesis
#                Plus GX, PCSX ReARMed), opciones de FCEUmm y MAME 2003-Plus, mandos (autoconfig), hiscore.dat y
#                carpetas de juegos vacias en /sdcard/ROMs. Sin ROMs ni BIOS.
#   $KODI=1      ADEMAS instala o actualiza Kodi 21.3 con el build de la sala (repos, addons y ajustes, sin cuentas:
#                TorBox se vuelve a iniciar en POV, Umbrella y ResolveURL). BORRA los datos del Kodi que tenga el TV
#                (antes los respalda en la computadora). $KODIREEMPLAZAR=1: cambia un Kodi incompatible (64 bits u otra version).
#                Sin $RETROARCH / $KODI no se toca RetroArch ni Kodi.
# PIN: 4 numeros, o 'sinpin' para no poner PIN.
# Solo modo "launcher": no borra ni desinstala ninguna app del cliente. Lo unico que toca de apps es
# Stremio / TizenTube (paso 8): si ya estan, las actualiza (adb install -r, conserva datos y sesiones) cuando
# hay una version oficial mas nueva con la misma firma; si no estan, instala la oficial (adb install -g) para el
# procesador y el Android del TV, y las agrega al dock. IPTV Smarters: siempre la GRATIS 3.1.5.1 de Troypoint
# (MediaFire, sha256 fijo). Si falta, se instala; si el TV tiene otra (ej. la 4.0.6 de pago), se cambia por esa
# (se desinstala primero: se borran el login y las listas de Smarters); si ya es esa, no se toca. Nunca se
# actualiza a versiones de pago. Ninguna otra app se toca.
# Pruebas: $LUK_BUNDLE_URL (zip del repo), $LUK_ADB (otro adb.exe), $LUK_HOME_DIR (carpeta de trabajo).
# (Este archivo es solo ASCII a proposito: asi se lee igual en cualquier consola de Windows.)

& {
  param($IP, $PIN, $THEME, $DRYRUN, $NUEVODOCK, $BURL, $ADBOVR, $HOMEDIR, $NOUPDATE, $CIUDAD, $APPS, $BOTONES, $ESTILO, $SINAPPS, $RETROARCH, $KODI, $KODIREEMPLAZAR)

  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  $REPO_ZIP = 'https://github.com/coplic/luk-home-installer/archive/refs/heads/main.zip'
  $PKG = 'com.ivantrj.glasslauncher'
  $SERVICE = "$PKG/$PKG.HomeButtonService"
  $DOCK_APPS = @('com.stremio.one', 'com.nst.iptvsmarterstvbox', 'io.gh.reisxd.tizentube.cobalt')
  $STOCK_HOMES = @('com.amazon.tv.launcher', 'com.google.android.apps.tv.launcherx', 'com.google.android.tvlauncher', 'com.android.tv.launcher', 'android')
  $LAUNCHER_SVC_PKGS = @('com.spocky.projengmenu', 'com.wolf.firelauncher', 'com.wolf.firelaunchermanager', 'com.lauritz.homebutton', 'com.appgenz.launchermanager')
  # Temas renombrados viejo -> nuevo (2026-11-01c: halloween-terror paso a llamarse terror) y alias aceptados en $THEME.
  $TH_RENAMED = @{ 'halloween-terror' = 'terror' }
  $TH_ALIAS = @{ 'halloween-terror' = 'terror'; 'halloween' = 'terror'; 'horror' = 'terror' }

  # Estado compartido (hashtable: las funciones internas lo modifican por referencia)
  $st = @{ adb = ''; serial = ''; accChanged = $false; homeChanged = $false; uopChanged = $false; success = $false
           oldSvc = ''; oldEn = ''; oldHome = ''; oldUop = ''; log = ''; stage = ''; updSum = 'no se revisaron'
           newInst = @(); appsTouched = $false; dockTouched = $false; apkF = ''; raSum = ''; kodiSum = ''; nstep = 8 }

  $IP = "$IP".Trim(); $PIN = "$PIN".Trim(); $THEME = "$THEME".Trim()
  $themeGiven = $THEME -ne ''
  $dry = [bool]$DRYRUN -and "$DRYRUN" -ne '0'
  $newDock = [bool]$NUEVODOCK -and "$NUEVODOCK" -ne '0'
  $noUpd = [bool]$NOUPDATE -and "$NOUPDATE" -ne '0'
  $noApps = [bool]$SINAPPS -and "$SINAPPS" -ne '0'
  $retro = [bool]$RETROARCH -and "$RETROARCH" -ne '0'
  $kodiRepl = [bool]$KODIREEMPLAZAR -and "$KODIREEMPLAZAR" -ne '0'
  $kodiOpt = ([bool]$KODI -and "$KODI" -ne '0') -or $kodiRepl
  $st.nstep = 8 + [int]$retro + [int]$kodiOpt   # 9.o / 10.o paso solo con $RETROARCH / $KODI
  $btn = ''
  $b0 = "$BOTONES".Trim().ToLower()
  if (@('bloquear', 'on', 'si', '1', 'yes', 'true') -contains $b0) { $btn = 'on' }
  elseif (@('normal', 'desbloquear', 'off', 'no', '0', 'false') -contains $b0) { $btn = 'off' }
  # Estilo de las tarjetas del inicio (files/dock-style.txt, 2026-11-02d): oscuro | colores | vacio = no cambiar
  $estilo = ''; $estiloBad = ''
  $e0 = "$ESTILO".Trim().ToLower()
  if (@('oscuro', 'oscura', 'dark', 'negro', 'normal') -contains $e0) { $estilo = 'oscuro' }
  elseif (@('colores', 'color', 'colors', 'colorido', 'colorida', 'brillante') -contains $e0) { $estilo = 'colores' }
  elseif ($e0) { $estiloBad = "$ESTILO" }
  # Ciudad del tiempo (files/weather.txt): una linea, max. 80 caracteres; auto/automatica/ip = por internet
  $city = ("$CIUDAD" -replace "[`r`n`t]", ' ').Trim()
  if ($city.Length -gt 80) { $city = $city.Substring(0, 80).Trim() }
  if (@('auto', 'automatica', 'ip', 'internet') -contains $city.ToLower().Replace([string][char]0xE1, 'a')) { $city = 'auto' }
  # '-' / 'igual' / 'nada' = no cambiar la ciudad
  if (@('-', '_', 'igual', 'nada', 'ninguna', 'sin', 'no') -contains $city.ToLower()) { $city = '' }
  # Apps extra para el inicio: nombres separados por comas (netflix,youtube) o paquetes exactos; 'todas' = todas
  $appsArg = (("$APPS" -replace '\s', '') -replace ';', ',').Trim(',')
  if (@('-', 'no', 'ninguna', 'nada') -contains $appsArg.ToLower()) { $appsArg = '' }
  $extraPkgs = @(); $extraNames = @{}; $launchable = @(); $third = @(); $disabled = @()

  $work = if ($HOMEDIR) { "$HOMEDIR" } else { Join-Path $env:LOCALAPPDATA 'LukHome' }
  New-Item -ItemType Directory -Force -Path (Join-Path $work 'logs') | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $ipName = if ($IP) { ($IP -split ':')[0] } else { 'sin-ip' }
  $st.log = Join-Path $work "logs\instalacion-$ipName-$ts.log"
  Set-Content -Path $st.log -Value "" -Encoding ASCII

  function LogQ([string]$m) { Add-Content -Path $st.log -Value $m -Encoding UTF8 }
  function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c; LogQ $m }
  function Paso([int]$n, [string]$m) { Say ''; Say "[$n/$($st.nstep)] $m" 'Cyan' }
  function Bien([string]$m) { Say "   OK  $m" 'Green' }
  function Aviso([string]$m) { Say "   !   $m" 'Yellow' }
  function Sim([string]$m) { Say "   [simulacion] $m" 'Yellow' }
  function Falla([string]$m, [string]$hint = '') { throw "LUKFAIL|$m|$hint" }

  # ---------- apps extra en el inicio ($APPS) ----------
  # Solo cambia la lista del dock de Luk Home (files/dock.txt). Nunca instala, desinstala, actualiza ni borra
  # datos de ninguna app. Nombres comunes -> paquetes (se usa el primero instalado); con punto = paquete exacto.
  $APP_MAP = [ordered]@{
    'netflix' = @('com.netflix.ninja', 'com.netflix.mediaclient')
    'youtube|yt' = @('com.amazon.firetv.youtube', 'com.google.android.youtube.tv', 'com.google.android.youtube.tvunplugged.youtube', 'com.google.android.youtube')
    'youtubetv|yttv' = @('com.amazon.firetv.youtube.tv', 'com.google.android.youtube.tvunplugged')
    'youtubekids|ytkids' = @('com.amazon.firetv.youtube.kids', 'com.google.android.youtube.tvkids', 'com.google.android.apps.youtube.kids')
    'youtubemusic|ytmusic' = @('com.google.android.youtube.tvmusic', 'com.google.android.apps.youtube.music')
    'smarttube' = @('org.smarttube.stable', 'org.smarttube.beta', 'com.teamsmart.videomanager.tv', 'com.liskovsoft.smarttubetv.beta', 'com.liskovsoft.smarttubetv')
    'prime|primevideo|amazonprime|amazonvideo|amazonprimevideo' = @('com.amazon.avod', 'com.amazon.amazonvideo.livingroom', 'com.amazon.firebat', 'com.amazon.avod.thirdpartyclient')
    'disney|disneyplus' = @('com.disney.disneyplus')
    'hulu' = @('com.hulu.livingroomplus', 'com.hulu.plus')
    'max|hbomax|hbo' = @('com.wbd.stream', 'com.hbo.hbonow', 'com.hbo.max')
    'paramount|paramountplus' = @('com.cbs.ott', 'com.cbs.app')
    'peacock' = @('com.peacock.peacockfiretv', 'com.peacocktv.peacockandroid')
    'appletv' = @('com.apple.atve.amazon.appletv', 'com.apple.atve.androidtv.appletv', 'com.apple.atve.sony.appletv')
    'spotify' = @('com.spotify.tv.android', 'com.spotify.music')
    'pluto|plutotv' = @('tv.pluto.android')
    'tubi|tubitv' = @('com.tubitv', 'com.tubitv.ott')
    'plex' = @('com.plexapp.android')
    'kodi' = @('org.xbmc.kodi')
    'vlc' = @('org.videolan.vlc')
    'espn' = @('com.espn.gtv', 'com.espn.score_center')
    'fubo|fubotv' = @('com.fubo.firetv.screen', 'com.fubotv.android', 'com.fubo.android')
    'sling|slingtv' = @('com.sling')
    'downloader' = @('com.esaba.downloader')
    'stremio' = @('com.stremio.one')
    'smarters|iptvsmarters' = @('com.nst.iptvsmarterstvbox')
    'tizentube' = @('io.gh.reisxd.tizentube.cobalt')
    'tivimate' = @('ar.tvplayer.tv')
    'xciptv' = @('com.nathnetwork.xciptv')
    'nuvio' = @('com.nuvio.tv')
    'crunchyroll' = @('com.crunchyroll.crunchyroid')
    'dazn' = @('com.dazn')
    'twitch' = @('tv.twitch.android.viewer', 'tv.twitch.android.app')
    'vix' = @('com.univision.prendetv')
    'mxplayer|mx' = @('com.mxtech.videoplayer.ad', 'com.mxtech.videoplayer.pro', 'com.mxtech.videoplayer.television')
    'perfectplayer' = @('com.niklabs.pp')
    'ottnavigator' = @('studio.scillarium.ottnavigator')
    'silk' = @('com.amazon.cloud9')
    'starz' = @('com.bydeluxe.d3.android.program.starz')
    'philo' = @('com.philo.philo.google', 'com.philo.philo')
    'directv|directvstream' = @('com.att.tv', 'com.directv.dtvlatam')
    'telemundo' = @('com.telemundo.android.telemundoapp', 'com.nbcuni.telemundo.noticiastelemundo')
  }
  function AppNorm([string]$x) {
    $y = $x.ToLower() -replace '[+ _-]', ''
    foreach ($pr in @(@(0xF3, 'o'), @(0xE9, 'e'), @(0xED, 'i'), @(0xE1, 'a'), @(0xFA, 'u'))) { $y = $y.Replace([string][char]$pr[0], $pr[1]) }
    $y
  }
  function AppCands([string]$n) {
    foreach ($k in $APP_MAP.Keys) { if (($k -split '\|') -contains $n) { return @($APP_MAP[$k]) } }
    @()
  }
  function AppLaunch([string]$p) { ($launchable.Count -eq 0) -or ($launchable -contains $p) }
  function AppResolve([string]$x) {   # -> @{ pkg; why }
    if ($x -match '\.') {
      if ($disabled -contains $x) { return @{ pkg = ''; why = 'esta desactivada en el TV' } }
      if ($installed -contains $x) {
        if (AppLaunch $x) { return @{ pkg = $x; why = '' } }
        return @{ pkg = ''; why = 'esta instalada pero no se abre desde el inicio' }
      }
      return @{ pkg = ''; why = 'no esta instalada' }
    }
    $n = AppNorm $x; $inst = ''; $dis = ''
    foreach ($c in (AppCands $n)) {
      if ($installed -notcontains $c) { continue }
      if ($disabled -contains $c) { $dis = $c; continue }
      $inst = $c; if (AppLaunch $c) { return @{ pkg = $c; why = '' } }
    }
    if ($inst) { return @{ pkg = ''; why = "esta instalada ($inst) pero no se abre desde el inicio" } }
    if ($dis) { return @{ pkg = ''; why = "esta desactivada en el TV ($dis); no se activa" } }
    if ($n.Length -ge 3) {   # busqueda aproximada por nombre de paquete
      $pool = if ($launchable.Count) { $launchable } else { $installed }
      $m = @($pool | Where-Object { $_ -ne $PKG -and (($_.ToLower() -replace '[._]', '').Contains($n)) })
      if ($m.Count -eq 1) { return @{ pkg = $m[0]; why = '' } }
      $m3 = @($m | Where-Object { $third -contains $_ })
      if ($m3.Count -eq 1) { return @{ pkg = $m3[0]; why = '' } }
      if ($m.Count -gt 1) { return @{ pkg = ''; why = ("hay varias que se parecen: " + ($m -join ', ') + ". Escribe el nombre del paquete exacto") } }
    }
    @{ pkg = ''; why = 'no esta instalada' }
  }
  function AppLabel([string]$p) {
    if ($st.extraNames -and $st.extraNames.ContainsKey($p)) { return "$($st.extraNames[$p]) ($p)" }
    $nf = Join-Path $bundle "tiles\$p.txt"
    if (Test-Path $nf) { return ([IO.File]::ReadAllText($nf) -split "`n")[0].Trim() + " ($p)" }
    $p
  }
  function ResolverApps {
    $st.extraPkgs = @(); $st.extraNames = @{}
    if (-not $appsArg) { return }
    $known = @(); foreach ($v in $APP_MAP.Values) { $known += $v }
    foreach ($x in ($appsArg -split ',' | Where-Object { $_ })) {
      if (@('todas', 'todos', 'all') -contains (AppNorm $x)) {
        $pool = if ($launchable.Count) { $launchable } else { $third }
        foreach ($c in ($pool | Sort-Object -Unique)) {
          if ($c -eq $PKG -or $disabled -contains $c) { continue }
          if (($third -contains $c -or $known -contains $c) -and $st.extraPkgs -notcontains $c) { $st.extraPkgs += $c }
        }
        continue
      }
      $r = AppResolve $x
      if ($r.pkg) {
        if ($st.extraPkgs -notcontains $r.pkg) { $st.extraPkgs += $r.pkg; if ($x -notmatch '\.') { $st.extraNames[$r.pkg] = $x } }
        if ($r.pkg -ne $x) { LogQ "apps: $x -> $($r.pkg)" }
      } else { Aviso "App '$x': $($r.why). No va al inicio (no se instala nada)." }
    }
    LogQ "apps=$appsArg extra=$($st.extraPkgs -join ' ')"
  }

  function Adb {
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = & $st.adb @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $eap }
    (($o | Where-Object { $_ -ne $null }) -join "`n") -replace "`r", ''
  }
  function A { Adb -s $st.serial @args }
  function S { (A shell @args).Trim() }
  function Sha256File([string]$f) { (Get-FileHash -Algorithm SHA256 -Path $f).Hash.ToLower() }
  function WriteLF([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text) }
  function Download([string]$url, [string]$out) {
    for ($i = 1; $i -le 3; $i++) {
      try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out; return } catch { LogQ "download $url try $i : $_"; Start-Sleep -Seconds 2 }
    }
    throw "download failed"
  }
  function Unzip([string]$zip, [string]$dir) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir)
  }

  # ---------- RetroArch del cuarto (opcional: $RETROARCH=1) ----------
  # Instala o actualiza (adb install -r, sin desinstalar) el RetroArch OFICIAL de buildbot.libretro.com (sha256 fijo)
  # y deja la configuracion del TV del cuarto: retroarch.cfg, 7 nucleos oficiales, opciones de FCEUmm / MAME 2003-Plus,
  # mandos (autoconfig), hiscore.dat y carpetas de juegos vacias. Nunca lleva ni borra ROMs, partidas, estados ni BIOS.
  # Antes de pisar la configuracion la respalda en la computadora. Lo del TV lo hace bundle\retroarch\tv-retroarch.sh.
  $RA_VER = '1.22.2'
  $RA_CORES = @('fbneo', 'mame2003_plus', 'fceumm', 'mupen64plus_next_gles3', 'flycast', 'genesis_plus_gx', 'pcsx_rearmed')
  function RaInstall([string]$apk) {
    for ($try = 1; $try -le 3; $try++) {
      if ($platform -notlike 'Fire*') { Say '   Si en el TV sale "Bloqueada por Play Protect" / "App no segura": elige Mas detalles > Instalar de todas formas.' 'Yellow' }
      $o = A install -r -g $apk; LogQ "ra install ($try): $o"
      if ($o -match 'Success') { return '' }
      if ($o -match 'VERIFICATION|REJECTED|BLOCKED|ABORTED|Play Protect|USER_RESTRICTED|Session') {
        if ($try -lt 3) {
          Aviso "Play Protect freno la instalacion de RetroArch (intento $try de 3)."
          Say '   En la pantalla del TV: Mas detalles > Instalar de todas formas. No hace falta apagar Play Protect.'
          Say '   Reintentando en 10 segundos...'; Start-Sleep -Seconds 10; continue
        }
        return 'Play Protect no dejo instalar RetroArch (en el TV: Mas detalles > Instalar de todas formas, y repite la linea)'
      }
      if ($o -match 'UPDATE_INCOMPATIBLE|SIGNATURES') { return 'el TV ya tiene un RetroArch con otra firma (no se desinstala; quitalo a mano si quieres el oficial)' }
      if ($o -match 'INSUFFICIENT_STORAGE') { return 'no hay espacio en el TV para RetroArch' }
      return ('la instalacion fallo: ' + (($o -split "`n")[-1]))
    }
    return 'la instalacion fallo'
  }
  function RaElf([string]$f, [int]$bits) {
    if (-not (Test-Path $f)) { return $false }
    $b = New-Object byte[] 5
    $fs = [IO.File]::OpenRead($f); try { [void]$fs.Read($b, 0, 5) } finally { $fs.Close() }
    $cls = 1; if ($bits -eq 64) { $cls = 2 }
    return ($b[0] -eq 0x7f -and $b[1] -eq 0x45 -and $b[2] -eq 0x4c -and $b[3] -eq 0x46 -and $b[4] -eq $cls)
  }
  function DumpVc([string]$p) {
    $d = S dumpsys package $p
    $vc = 0; if ($d -match 'versionCode=(\d+)') { [void][long]::TryParse($Matches[1], [ref]$vc) }
    $ab = ''; if ($d -match 'primaryCpuAbi=(\S+)') { $ab = $Matches[1] }
    @{ vc = $vc; abi = $ab }
  }
  function RetroArchPaso([int]$n) {
    Paso $n 'RetroArch con los emuladores del cuarto ($RETROARCH=1)'
    $al = @("$abis" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $cabi = ''
    if (($installed -contains 'com.retroarch.aarch64') -and -not ($installed -contains 'com.retroarch.ra32')) { $cabi = 'arm64-v8a' }
    elseif ($al -contains 'armeabi-v7a') { $cabi = 'armeabi-v7a' }
    elseif ($al -contains 'arm64-v8a') { $cabi = 'arm64-v8a' }
    if ($cabi -eq 'armeabi-v7a') { $rpkg = 'com.retroarch.ra32'; $rapk = 'RetroArch_ra32.apk'; $bits = 32; $rsha = '9e964f53089a302401a6d5b1451d7ce5539f39b85eb0a305d8d77e6edcbf803f'; $rvc = 1763607285 }
    elseif ($cabi -eq 'arm64-v8a') { $rpkg = 'com.retroarch.aarch64'; $rapk = 'RetroArch_aarch64.apk'; $bits = 64; $rsha = '7bd5d208dfe93cc8e2ea6c04608948ce1a045980f160a58ca2d0993aa20ad213'; $rvc = 1763607214 }
    else { Aviso "Este TV no tiene procesador ARM ($abis): RetroArch no se instala."; $st.raSum = "no (procesador $abis)"; return }
    if ($sdk -lt 21) { Aviso "Android muy viejo para RetroArch (API $sdk)."; $st.raSum = "no (API $sdk)"; return }
    $have = $installed -contains $rpkg; $ivc = 0
    if ($have) { $ivc = (DumpVc $rpkg).vc; Bien "RetroArch ya esta ($rpkg, versionCode $ivc)" }
    else { Bien "RetroArch no esta: se instala el oficial $RA_VER ($cabi)" }
    if ((S dumpsys window) -match "mCurrentFocus[^`n]*$([regex]::Escape($rpkg))") {
      Aviso 'RetroArch esta abierto en el TV ahora mismo (alguien jugando): no se toca. Cierralo y repite la linea.'; $st.raSum = 'no (estaba abierto)'; return
    }
    if (-not $have -and $free -gt 0 -and $free -lt 700000) { Aviso "Poco espacio en el TV ($([int]($free/1024)) MB; RetroArch necesita ~700 MB). No se instala."; $st.raSum = 'no (sin espacio)'; return }
    $dir = Join-Path $work 'apps\retroarch'; $cdir = Join-Path $dir "cores-$cabi"
    New-Item -ItemType Directory -Force -Path $cdir | Out-Null
    $f = Join-Path $dir $rapk
    if (-not (Test-Path $f) -or (Sha256File $f) -ne $rsha) {
      Say "   Descargando RetroArch $RA_VER oficial (buildbot.libretro.com, ~180 MB)..."
      try { Download "https://buildbot.libretro.com/stable/$RA_VER/android/$rapk" "$f.part"; Move-Item -Force "$f.part" $f } catch { Remove-Item -Force -ErrorAction SilentlyContinue "$f.part" }
    }
    if (-not (Test-Path $f) -or (Sha256File $f) -ne $rsha) { Remove-Item -Force -ErrorAction SilentlyContinue $f; Aviso 'No se pudo bajar RetroArch oficial (o no coincide el sha256). No se instala.'; $st.raSum = 'no (descarga)'; return }
    Bien "RetroArch $RA_VER verificado (sha256 $($rsha.Substring(0,12))...)"
    $sroot = Join-Path $dir 'stage'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $sroot
    $stg = Join-Path $sroot 'lukra'
    New-Item -ItemType Directory -Force -Path (Join-Path $stg 'cores'), (Join-Path $stg 'info') | Out-Null
    try {
      Copy-Item -Recurse -Force (Join-Path $bundle 'retroarch\ext') $stg
      Copy-Item -Recurse -Force (Join-Path $bundle 'retroarch\ra') $stg
      Copy-Item -Force (Join-Path $bundle 'retroarch\tv-retroarch.sh') $stg
    } catch { Aviso 'Faltan archivos de RetroArch en el paquete.'; $st.raSum = 'no (paquete incompleto)'; return }
    Say "   Descargando los 7 nucleos oficiales ($cabi) de buildbot.libretro.com..."
    $ok = 0
    foreach ($c in $RA_CORES) {
      $so = "${c}_libretro_android.so"; $tmp = Join-Path $dir 'tmp'
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
      $got = $false
      try { Download "https://buildbot.libretro.com/nightly/android/latest/$cabi/$so.zip" (Join-Path $tmp 'c.zip'); Unzip (Join-Path $tmp 'c.zip') (Join-Path $tmp 'x'); $got = RaElf (Join-Path $tmp "x\$so") $bits } catch { LogQ "core $c : $_" }
      if ($got) { Move-Item -Force (Join-Path $tmp "x\$so") (Join-Path $cdir $so) }
      elseif (Test-Path (Join-Path $cdir $so)) { Aviso "No se pudo bajar $c ahora; se usa el que ya estaba en la computadora" }
      else { Aviso "No se pudo bajar el nucleo $c" }
      if (Test-Path (Join-Path $cdir $so)) { Copy-Item -Force (Join-Path $cdir $so) (Join-Path $stg 'cores'); $ok++ }
    }
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $dir 'tmp')
    Bien "Nucleos listos: $ok de 7"
    try {
      Download 'https://buildbot.libretro.com/assets/frontend/info.zip' (Join-Path $dir 'info.zip')
      Unzip (Join-Path $dir 'info.zip') (Join-Path $stg 'info')
      Bien ("Fichas de nucleos (info) oficiales: " + @(Get-ChildItem -Path (Join-Path $stg 'info') -Filter *.info).Count)
    } catch { Aviso 'No se pudieron bajar las fichas de nucleos (info); RetroArch funciona igual' }
    $nauto = @(Get-ChildItem -Recurse -File -Path (Join-Path $stg 'ext\autoconfig') -Filter *.cfg).Count
    if ($dry) {
      if ($have -and $ivc -gt $rvc) { Sim "RetroArch del TV es mas nuevo ($ivc): no se reinstala" }
      else { Sim "adb install -r -g $rapk  (Google TV: Play Protect > Mas detalles > Instalar de todas formas)" }
      Sim "respaldo de retroarch.cfg y opciones en $work\respaldos; copiar retroarch.cfg, $ok nucleos, $nauto perfiles de mandos, FCEUmm.opt, MAME 2003-Plus.opt, hiscore.dat"
      Sim 'carpetas vacias en /sdcard/ROMs: Nintendo - NES, Arcade - Mame 2003 Plus, Nintendo - N64, SNK - NEO GEO, fbneo_1_0_0_3_best/{games,samples}'
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $sroot; $st.raSum = "simulado ($ok nucleos)"; return
    }
    if ($have -and $ivc -gt $rvc) { Bien "El RetroArch del TV es mas nuevo que el ${RA_VER}: se deja (no se baja de version)" }
    else {
      Say '   Instalando RetroArch (conserva juegos, partidas y ajustes que tenga)...'
      $err = RaInstall $f
      if ($err) { Aviso "RetroArch: $err"; $st.raSum = "no ($err)"; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $sroot; return }
      Bien "RetroArch $RA_VER instalado"
    }
    $extd = "/storage/emulated/0/Android/data/$rpkg/files"; $rad = '/storage/emulated/0/RetroArch'
    if ((S "[ -f $extd/retroarch.cfg ] && echo y") -eq 'y') {
      $bkr = Join-Path $work "respaldos\retroarch-$ipName-$ts"; New-Item -ItemType Directory -Force -Path $bkr | Out-Null
      $pairs = @(@("$extd/retroarch.cfg", 'retroarch.cfg'), @("$rad/config/FCEUmm/FCEUmm.opt", 'FCEUmm.opt'), @("$rad/config/MAME 2003-Plus/MAME 2003-Plus.opt", 'MAME 2003-Plus.opt'))
      foreach ($pr in $pairs) {
        if ((S "[ -f '$($pr[0])' ] && echo y") -eq 'y') { WriteLF (Join-Path $bkr $pr[1]) ((A shell "cat '$($pr[0])'") + "`n") }
      }
      Bien "Respaldo de la configuracion de RetroArch: $bkr"
    }
    Say '   Copiando configuracion, mandos y nucleos (RetroArch se abre y se cierra solo unas veces)...'
    A shell rm -rf /data/local/tmp/lukra | Out-Null
    $out = A push $stg /data/local/tmp/; LogQ "ra push: $out"
    if ($out -match 'error|failed|No space') { Aviso 'No se pudieron copiar los archivos de RetroArch al TV'; $st.raSum = 'no (copia)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $sroot; return }
    $out = A shell sh /data/local/tmp/lukra/tv-retroarch.sh $rpkg $sdk $cabi; LogQ "ra apply: $out"
    A shell rm -rf /data/local/tmp/lukra | Out-Null; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $sroot
    if ($out -match 'RA_OK (.*)') {
      $okline = $Matches[1]
      $cl = ''; if ($out -match 'RA_CORES ([^\n]*)') { $cl = $Matches[1] }
      Bien "Nucleos instalados en RetroArch: $cl"
      Bien "Configuracion del cuarto puesta: $okline"
      if ($cl -match 'FALLARON') { Aviso 'Algun nucleo no se pudo instalar; se puede bajar en RetroArch: Menu principal > Actualizador en linea > Descargar nucleos' }
      $cn = ''; if ($cl -match '^(\d+/\d+)') { $cn = $Matches[1] }
      $st.raSum = "RetroArch $RA_VER listo ($cn nucleos)"
    } else {
      $fl = (($out -split "`n") | Where-Object { $_ -match 'RA_FAIL' } | Select-Object -First 1)
      Aviso "RetroArch quedo instalado, pero la configuracion fallo: $fl"; $st.raSum = 'instalado, configuracion fallo'
    }
    A shell input keyevent KEYCODE_HOME | Out-Null
  }

  # ---------- Kodi de la sala (opcional: $KODI=1) ----------
  # Lo mismo que bundle/kodi/kodi-sala.sh (Mac): Kodi 21.3 oficial de kodi.tv (sha256), revisa ABI/API, respalda el
  # Kodi que haya, pm clear SOLO de Kodi, permisos, primera apertura, copia del build (tar en /data/local/tmp).
  # El build (kodi-sala.zip, >100 MB) se baja del Release kodi-build-2026-11-10 de este repo y se comprueba su sha256.
  function KodiPaso([int]$n) {
    Paso $n 'Kodi con el build de la sala ($KODI=1)'
    $KPKG = 'org.xbmc.kodi'; $KVER = '21.3'; $KVCODE = 2103000
    $apkUrl = 'https://mirrors.kodi.tv/releases/android/arm/kodi-21.3-Omega-armeabi-v7a.apk'
    $apkSha = '12d75e895649f68f217e42c2d881a94fd3177d7b9a7937825852aed545520cc8'
    $zipUrl = 'https://github.com/coplic/luk-home-installer/releases/download/kodi-build-2026-11-10/kodi-sala.zip'
    $zipSha = '67e4e8ddcb6a6f26bf96ffb0a2dba1318135969ae8c3490e5bb20eae1e620eca'
    $kw = Join-Path $work 'kodi'
    New-Item -ItemType Directory -Force -Path (Join-Path $kw 'apk'), (Join-Path $kw 'respaldos') | Out-Null
    $al = @("$abis" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($al -notcontains 'armeabi-v7a') { Aviso "Este TV no acepta apps ARM de 32 bits ($abis): el build de la sala no funcionaria completo. Kodi no se toca."; $st.kodiSum = 'no (procesador)'; return }
    if ($sdk -lt 21) { Aviso "Android demasiado viejo para Kodi 21 (API $sdk)."; $st.kodiSum = 'no (API)'; return }
    if ((S dumpsys window) -match "mCurrentFocus[^`n]*org\.xbmc\.kodi") { Aviso 'Kodi esta abierto en el TV ahora mismo: no se toca. Cierralo y repite la linea.'; $st.kodiSum = 'no (estaba abierto)'; return }
    $pz = Join-Path $kw 'kodi-sala.zip'
    if ((Test-Path $pz) -and (Sha256File $pz) -eq $zipSha) { Bien "Paquete ya descargado antes ($pz)" }
    else {
      Say '   Descargando el build de la sala (~290 MB, tarda unos minutos)...'
      try { Download $zipUrl "$pz.part"; Move-Item -Force "$pz.part" $pz }
      catch { Remove-Item -Force -ErrorAction SilentlyContinue "$pz.part"; Aviso "No se pudo descargar el paquete del Kodi de la sala ($zipUrl). Kodi no se toco."; $st.kodiSum = 'no (descarga)'; return }
      if ((Sha256File $pz) -ne $zipSha) { Remove-Item -Force $pz; Aviso 'El paquete descargado no coincide con el sha256 publicado. Kodi no se toco; repite la linea.'; $st.kodiSum = 'no (sha256)'; return }
    }
    Bien "Paquete verificado (sha256 $($zipSha.Substring(0,12))...)"
    $stg = Join-Path $kw 'stage'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg
    Say '   Descomprimiendo...'
    try { Unzip $pz $stg } catch { Aviso 'El paquete esta danado (no se pudo descomprimir).'; $st.kodiSum = 'no (paquete)'; return }
    $man = Get-ChildItem -Path $stg -Recurse -Depth 2 -Filter MANIFEST.txt | Select-Object -First 1
    if (-not $man) { Aviso 'El paquete esta incompleto (falta MANIFEST.txt).'; $st.kodiSum = 'no (paquete)'; return }
    $root = $man.Directory.FullName
    if (-not (Test-Path (Join-Path $root '.kodi\addons')) -or -not (Test-Path (Join-Path $root '.kodi\userdata'))) { Aviso 'El paquete esta incompleto (faltan .kodi/addons o .kodi/userdata).'; $st.kodiSum = 'no (paquete)'; return }
    $nadd = @(Get-ChildItem -Directory -Path (Join-Path $root '.kodi\addons')).Count
    $kb = [int]((Get-ChildItem -Recurse -File -Force -Path (Join-Path $root '.kodi') | Measure-Object -Property Length -Sum).Sum / 1024)
    Bien "Build: $nadd addons, $([int]($kb/1024)) MB"
    $sfree = 0; $dfl = @((S df -k /sdcard) -split "`n" | Where-Object { $_ -match '\S' })
    if ($dfl.Count -ge 2) { $cols = $dfl[-1] -split '\s+'; if ($cols.Count -ge 4) { [void][int]::TryParse($cols[3], [ref]$sfree) } }
    if ($sfree -gt 0 -and $sfree -lt ($kb * 2 + 250000)) { Aviso "No hay espacio en el TV: libres $([int]($sfree/1024)) MB, se necesitan ~$([int](($kb*2+250000)/1024)) MB. Kodi no se toco."; $st.kodiSum = 'no (sin espacio)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
    $have = $installed -contains $KPKG; $needInst = $false; $needUninst = $false
    if ($have) {
      $kv = DumpVc $KPKG
      Say "   Kodi ya instalado: versionCode $($kv.vc), ABI $($kv.abi)"
      if ($kv.abi -ne 'armeabi-v7a' -or $kv.vc -lt 2100000 -or $kv.vc -ge 2200000) {
        if (-not $kodiRepl) { Aviso "El Kodi del TV no es compatible con el build (ABI $($kv.abi), version $($kv.vc)). Repite con `$KODIREEMPLAZAR=1 (se respalda, se desinstala y se pone el $KVER de 32 bits)."; $st.kodiSum = 'no (Kodi incompatible)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
        $needUninst = $true; $needInst = $true
      } elseif ($kv.vc -lt $KVCODE) { $needInst = $true; Say "   Se actualiza a $KVER." }
      else { Bien 'Kodi compatible; no se reinstala' }
    } else { $needInst = $true; Say '   Kodi no esta instalado: se instala.' }
    $apk = Join-Path $kw 'apk\kodi-21.3-Omega-armeabi-v7a.apk'
    if ($needInst) {
      if (-not (Test-Path $apk) -or (Sha256File $apk) -ne $apkSha) {
        Say "   Descargando Kodi $KVER armeabi-v7a de mirrors.kodi.tv..."
        try { Download $apkUrl "$apk.part"; Move-Item -Force "$apk.part" $apk } catch { Aviso 'No se pudo descargar Kodi de mirrors.kodi.tv.'; $st.kodiSum = 'no (descarga)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
      }
      if ((Sha256File $apk) -ne $apkSha) { Remove-Item -Force $apk; Aviso 'El APK de Kodi descargado no coincide con el SHA256 oficial.'; $st.kodiSum = 'no (sha256)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
      Bien "APK verificado (sha256 $($apkSha.Substring(0,12))...)"
    }
    $kd = "/sdcard/Android/data/$KPKG/files"; $kbk = ''
    if ($have -and (S "[ -d $kd/.kodi ] && echo y") -eq 'y') {
      $kbk = Join-Path $kw "respaldos\kodi-$ipName-$ts.tar"
      Say "   Respaldo del Kodi que tiene el TV (sin miniaturas ni cache) en $kbk ..."
      $o = S "cd $kd && tar -cf /data/local/tmp/kodi-respaldo.tar --exclude=.kodi/userdata/Thumbnails --exclude=.kodi/addons/packages --exclude=.kodi/temp .kodi && echo TAR_OK"
      LogQ "kodi backup: $o"
      if ($o -notmatch 'TAR_OK') { A shell rm -f /data/local/tmp/kodi-respaldo.tar | Out-Null; Aviso 'No se pudo respaldar el Kodi del TV; no se cambio nada.'; $st.kodiSum = 'no (respaldo)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
      $o = A pull /data/local/tmp/kodi-respaldo.tar $kbk; LogQ "kodi pull: $o"
      A shell rm -f /data/local/tmp/kodi-respaldo.tar | Out-Null
      if (-not (Test-Path $kbk) -or (Get-Item $kbk).Length -lt 1024) { Aviso 'El respaldo salio mal; no se cambio nada en el TV.'; $st.kodiSum = 'no (respaldo)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
      Bien "Respaldo: $kbk ($([int]((Get-Item $kbk).Length/1MB)) MB)"
    } else { Bien 'No habia datos de Kodi que respaldar' }
    if ($dry) {
      if ($needUninst) { Sim "adb uninstall $KPKG" }
      if ($needInst) { Sim "adb install -r -g $(Split-Path $apk -Leaf)" }
      Sim "pm clear $KPKG (solo datos de Kodi), permisos de almacenamiento de Kodi, abrir/cerrar Kodi, copiar el build ($nadd addons, $([int]($kb/1024)) MB) con adb push + tar"
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; $st.kodiSum = 'simulado'; return
    }
    if ($needUninst) { $o = A uninstall $KPKG; LogQ "kodi uninstall: $o"; if ($o -notmatch 'Success') { Aviso 'No se pudo desinstalar el Kodi incompatible.'; $st.kodiSum = 'no (desinstalar)'; return }; Bien 'Kodi anterior desinstalado' }
    if ($needInst) {
      if ($platform -notlike 'Fire*') { Say '   (Si en el TV sale un aviso de Play Protect, elige Mas detalles > Instalar de todas formas.)' 'Yellow' }
      $o = A install -r -g $apk; LogQ "kodi install: $o"
      if ($o -notmatch 'Success') { Aviso ("La instalacion de Kodi fallo: " + (($o -split "`n")[-1])); $st.kodiSum = 'no (instalacion)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
      Bien "Kodi $KVER instalado"
    }
    $dfree = 0; $dfl = @((S df -k /data) -split "`n" | Where-Object { $_ -match '\S' })
    if ($dfl.Count -ge 2) { $cols = $dfl[-1] -split '\s+'; if ($cols.Count -ge 4) { [void][int]::TryParse($cols[3], [ref]$dfree) } }
    if ($dfree -gt 0 -and $dfree -lt ($kb * 2 + 200000)) { Aviso "No hay espacio en el TV para copiar el build ($([int]($dfree/1024)) MB libres)."; $st.kodiSum = 'no (sin espacio)'; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg; return }
    Say '   Preparando el archivo para el TV...'
    $tarf = Join-Path $kw 'kodi-sala.tar'; Remove-Item -Force -ErrorAction SilentlyContinue $tarf
    $tarExe = Get-Command tar.exe -ErrorAction SilentlyContinue
    if (-not $tarExe) { Aviso 'Esta Windows no tiene tar.exe (Windows 10 de 2018 o mas nuevo lo trae). Kodi no se copio.'; $st.kodiSum = 'no (falta tar.exe)'; return }
    & $tarExe.Source -cf $tarf -C $root .kodi 2>&1 | ForEach-Object { LogQ "tar: $_" }
    if (-not (Test-Path $tarf)) { Aviso 'No se pudo preparar el archivo tar.'; $st.kodiSum = 'no (tar)'; return }
    A shell am force-stop $KPKG | Out-Null
    LogQ ("pm clear: " + (S pm clear $KPKG))
    A shell pm grant $KPKG android.permission.READ_EXTERNAL_STORAGE | Out-Null
    A shell pm grant $KPKG android.permission.WRITE_EXTERNAL_STORAGE | Out-Null
    if ($sdk -ge 30) { LogQ (A shell appops set $KPKG MANAGE_EXTERNAL_STORAGE allow) }
    Say '   Abriendo Kodi unos segundos para que cree su carpeta...'
    LogQ (A shell am start -n "$KPKG/.Splash")
    for ($i = 0; $i -lt 45; $i++) { if ((S "[ -d $kd ] && echo y") -eq 'y') { break }; Start-Sleep -Seconds 2 }
    if ((S "[ -d $kd ] && echo y") -ne 'y') { Aviso 'Kodi no creo su carpeta (salio algun aviso en el TV?).'; $st.kodiSum = 'no (carpeta)'; Remove-Item -Force -ErrorAction SilentlyContinue $tarf; return }
    Start-Sleep -Seconds 4; A shell am force-stop $KPKG | Out-Null; Start-Sleep -Seconds 1
    if ($sdk -ge 30) {
      if ((S "[ -d $kd/.kodi ] && echo y") -eq 'y') { LogQ (A shell "mv $kd/.kodi $kd/.kodi-inicial-$ts") }
    } else { LogQ (A shell "rm -rf $kd/.kodi") }
    Say "   Copiando el build al TV ($nadd addons, $([int]($kb/1024)) MB)..."
    $o = A push $tarf /data/local/tmp/kodi-sala.tar; LogQ "kodi push: $o"
    Remove-Item -Force -ErrorAction SilentlyContinue $tarf
    if ($o -match 'error|failed|No space') { Aviso 'Fallo la copia del build al TV.'; $st.kodiSum = 'no (copia)'; return }
    Say '   Descomprimiendo en el TV...'
    $o = S "mkdir -p $kd/.kodi && cd $kd && tar -xf /data/local/tmp/kodi-sala.tar && echo TAR_OK"; LogQ "kodi tar: $o"
    A shell rm -f /data/local/tmp/kodi-sala.tar | Out-Null
    if ($o -notmatch 'TAR_OK') { Aviso ("Fallo la descompresion en el TV: " + (($o -split "`n")[-1])); $st.kodiSum = 'no (descompresion)'; return }
    if ($sdk -ge 30) { LogQ (A shell "chmod -R a+rwX $kd/.kodi") }
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stg
    $tvn = 0; [void][int]::TryParse((S "ls $kd/.kodi/addons | wc -l"), [ref]$tvn)
    if ($tvn -lt $nadd) { Aviso "En el TV hay $tvn addons y el build trae $nadd."; $st.kodiSum = "incompleto ($tvn de $nadd addons)"; return }
    Bien "Addons en el TV: $tvn (build: $nadd)"
    if ((S "grep -o skin.arctic.zephyr.mod $kd/.kodi/userdata/guisettings.xml | head -1") -match 'arctic') { Bien 'Skin: Arctic Zephyr Mod' } else { Aviso 'No pude confirmar la skin en guisettings.xml' }
    Say '   Cuentas a iniciar de nuevo dentro de Kodi: TorBox en POV, Umbrella y ResolveURL (el paquete no lleva credenciales).'
    if ($kbk) { Say "   Respaldo del Kodi anterior: $kbk" }
    $st.kodiSum = 'Kodi con el build de la sala listo (TorBox: iniciar sesion otra vez en POV, Umbrella y ResolveURL)'
  }
  function Extras {
    $k = 9
    if ($retro) { try { RetroArchPaso $k } catch { Aviso "RetroArch: error inesperado: $($_.Exception.Message)"; LogQ ($_ | Out-String); $st.raSum = 'no (error)' }; $k++ }
    if ($kodiOpt) { try { KodiPaso $k } catch { Aviso "Kodi: error inesperado: $($_.Exception.Message)"; LogQ ($_ | Out-String); $st.kodiSum = 'no (error)' } }
  }

  # ---------- apps del cliente (paso 8) ----------
  # Stremio y TizenTube (IPTV Smarters va aparte: SmartersPaso, siempre la gratis de Troypoint).
  # Si ya estan: solo a una version oficial MAS NUEVA (versionCode
  # mayor) y con "adb install -r" (conserva datos y sesiones). Si NO estan: se instala la oficial con
  # "adb install -g" para el procesador (ABI) y el Android (minSdk) del TV, y se agrega al dock ($SINAPPS=1 = no).
  # Nunca desinstala, baja de version ni borra datos (salvo SmartersPaso). Si algo falla, avisa y sigue. Descargas en <carpeta>\apps\.
  $KNOWN_VC = @{}; $KNOWN_SHA = @{}
  # IPTV Smarters: SIEMPRE la gratis 3.1.5.1 de Troypoint (Troypoint Toolbox -> MediaFire), fija con su sha256.
  # Nunca se instala ni se actualiza a las de pago de iptvsmarters.com / smartersott.app (4.x, 5.x).
  $SMARTERS_FILE = 'iptv-smarters-pro-3.1.5.1-troypoint.apk'; $SMARTERS_VN = '3.1.5.1'; $SMARTERS_VC = 112
  $SMARTERS_SHA = '2791f5346f95269c9254c547ee641a80eb5d86f0a9045dc4ae41e79210a5dbdc'
  $SMARTERS_URL = 'https://www.mediafire.com/file_premium/xrlnqh9kppx349u/IPTV_Smarters_Pro_%255B3.1.5.1%255D.apk/file'
  $SMARTERS_ALT = 'https://www.mediafire.com/file/xrlnqh9kppx349u/IPTV_Smarters_Pro_%255B3.1.5.1%255D.apk/file'
  # Firma (certificado, sha256) de las Smarters de Troypoint: una version mas nueva del Toolbox solo se acepta con esta firma.
  $SMARTERS_CERT = '6100ac4577ec668ff4e5d7a18cbb070a68fba7f1b301900628665ce521cd09f1'
  $TOOLBOX_URL = if ($env:LUK_TOOLBOX_URL) { $env:LUK_TOOLBOX_URL } else { 'https://troypoint.com/troypoint-toolbox/' }
  $UA_FIREFOX = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
  $UA_BROWSER = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
  $UA = @{ 'User-Agent' = 'Mozilla/5.0 (luk-home-installer)' }

  function ApkInfo([string]$apk) {   # lee el AndroidManifest binario: pkg, vc, vn, min
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zf = [IO.Compression.ZipFile]::OpenRead($apk)
    try {
      $e = $zf.GetEntry('AndroidManifest.xml'); if (-not $e) { return $null }
      $ms = New-Object IO.MemoryStream; $es = $e.Open(); $es.CopyTo($ms); $es.Close(); $d = $ms.ToArray()
    } finally { $zf.Dispose() }
    $L = $d.Length; $strs = @(); $rm = @(); $v = @{}; $o = 8
    while ($o + 8 -le $L) {
      $t = [BitConverter]::ToUInt16($d, $o); $csz = [BitConverter]::ToUInt32($d, $o + 4); if ($csz -lt 8) { break }
      if ($t -eq 1) {
        $n = [BitConverter]::ToUInt32($d, $o + 8); $f = [BitConverter]::ToUInt32($d, $o + 16); $ss = [BitConverter]::ToUInt32($d, $o + 20)
        $u8 = ($f -band 256) -ne 0; $list = New-Object 'System.Collections.Generic.List[string]'
        for ($i = 0; $i -lt $n; $i++) {
          $p = $o + $ss + [BitConverter]::ToUInt32($d, $o + 28 + 4 * $i)
          if ($u8) {
            if ($d[$p] -band 128) { $p += 2 } else { $p += 1 }
            $b = [int]$d[$p]; $p++; if ($b -band 128) { $b = (($b -band 127) -shl 8) -bor $d[$p]; $p++ }
            $list.Add([Text.Encoding]::UTF8.GetString($d, $p, $b))
          } else {
            $c = [int][BitConverter]::ToUInt16($d, $p); $p += 2
            if ($c -band 32768) { $c = (($c -band 32767) -shl 16) -bor [BitConverter]::ToUInt16($d, $p); $p += 2 }
            $list.Add([Text.Encoding]::Unicode.GetString($d, $p, 2 * $c))
          }
        }
        $strs = $list.ToArray()
      }
      elseif ($t -eq 0x180) { $cnt = ($csz - 8) / 4; $rm = @(for ($i = 0; $i -lt $cnt; $i++) { [BitConverter]::ToUInt32($d, $o + 8 + 4 * $i) }) }
      elseif ($t -eq 0x102) {
        $el = $strs[[BitConverter]::ToUInt32($d, $o + 20)]
        if ($el -eq 'manifest' -or $el -eq 'uses-sdk') {
          $as = [BitConverter]::ToUInt16($d, $o + 24); $asz = [BitConverter]::ToUInt16($d, $o + 26); $ac = [BitConverter]::ToUInt16($d, $o + 28)
          for ($i = 0; $i -lt $ac; $i++) {
            $a = $o + 16 + $as + $i * $asz; $ni = [BitConverter]::ToUInt32($d, $a + 4)
            $nm = if ($ni -lt $strs.Length) { $strs[$ni] } else { '' }
            $id = if ($ni -lt $rm.Count) { $rm[$ni] } else { 0 }
            $raw = [BitConverter]::ToUInt32($d, $a + 8); $ty = $d[$a + 15]; $dt = [BitConverter]::ToUInt32($d, $a + 16)
            $val = if ($ty -eq 3) { $strs[$raw] } else { [string]$dt }
            $k = ''
            if ($id -eq 0x0101021b -or ($id -eq 0 -and $nm -eq 'versionCode')) { $k = 'vc' }
            elseif ($id -eq 0x0101021c -or ($id -eq 0 -and $nm -eq 'versionName')) { $k = 'vn' }
            elseif ($id -eq 0x0101020c -or ($id -eq 0 -and $nm -eq 'minSdkVersion')) { $k = 'min' }
            elseif ($el -eq 'manifest' -and $nm -eq 'package') { $k = 'pkg' }
            if ($k -and -not $v.ContainsKey($k)) { $v[$k] = $val }
          }
        }
      }
      $o += $csz
    }
    if (-not $v.ContainsKey('min')) { $v['min'] = '1' }
    return $v
  }
  function GetPage([string]$url) {
    try { return (Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $UA -TimeoutSec 60).Content } catch { LogQ "page $url : $_"; return '' }
  }
  function VerGt([string]$a, [string]$b) {   # versionName a > b (solo numeros)
    $x = @($a -split '[^0-9]+' | Where-Object { $_ -ne '' }); $y = @($b -split '[^0-9]+' | Where-Object { $_ -ne '' })
    for ($i = 0; $i -lt [Math]::Max($x.Count, $y.Count); $i++) {
      $xi = if ($i -lt $x.Count) { [long]$x[$i] } else { 0 }; $yi = if ($i -lt $y.Count) { [long]$y[$i] } else { 0 }
      if ($xi -gt $yi) { return $true }; if ($xi -lt $yi) { return $false }
    }
    return $false
  }
  function RemoteInfo([string]$app, [string]$abi, [int]$idx = 0) {   # version oficial: 0 = la ultima; 1, 2... = anteriores
    $r = @{ url = ''; alt = ''; file = ''; vn = ''; vc = $null; sha = '' }
    if ($app -eq 'stremio') {   # www.stremio.com/downloads: solo APK de Android TV, sin rc/beta
      $page = GetPage 'https://www.stremio.com/downloads'
      $seen = @{}; $list = @()
      foreach ($m in [regex]::Matches($page, 'https://dl\.strem\.io/android/v[0-9][A-Za-z0-9._-]*-androidTV/com\.stremio\.one-([0-9.]+)-([0-9]+)-' + [regex]::Escape($abi) + '\.apk')) {
        $c = [long]$m.Groups[2].Value
        if (-not $seen.ContainsKey($c)) { $seen[$c] = 1; $list += ,@($c, $m.Value, $m.Groups[1].Value) }
      }
      $list = @($list | Sort-Object -Property @{ Expression = { $_[0] } } -Descending)
      if ($idx -lt $list.Count) { $e = $list[$idx]; $r.vc = [long]$e[0]; $r.url = $e[1]; $r.file = ($e[1] -split '/')[-1]; $r.vn = $e[2] }
    }
    elseif ($app -eq 'tizentube') {   # GitHub reisxd/TizenTubeCobalt (ultima release; trae el sha256)
      $asset = if ($abi -eq 'arm64-v8a') { 'cobalt-arm64.apk' } elseif ($abi -eq 'armeabi-v7a') { 'cobalt-arm.apk' } else { '' }
      if (-not $asset) { return $null }
      $tag = ''
      if ($idx -gt 0) {   # versiones anteriores: lista de releases (sin borradores ni pre-releases), con sha256
        try {
          $rels = Invoke-RestMethod -Uri 'https://api.github.com/repos/reisxd/TizenTubeCobalt/releases?per_page=15' -Headers @{ 'User-Agent' = 'luk-home-installer'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 60
        } catch { LogQ "github releases: $_"; return $null }
        $ok = @()
        foreach ($rl in @($rels)) {
          if ($rl.draft -or $rl.prerelease) { continue }
          $as = @($rl.assets | Where-Object { $_.name -eq $asset }) | Select-Object -First 1
          if ($as -and "$($as.digest)" -match '^sha256:([0-9a-f]{64})$') { $ok += ,@("$($rl.tag_name)", $Matches[1]) }
        }
        if ($idx -ge $ok.Count) { return $null }
        $tag = $ok[$idx][0]; $r.sha = $ok[$idx][1]
        if ($tag -notmatch '^[A-Za-z0-9._-]+$') { return $null }
        $r.url = "https://github.com/reisxd/TizenTubeCobalt/releases/download/$tag/$asset"
        $r.vn = $tag -replace '^v', ''; $r.file = "tizentube-$($r.vn)-$asset"
        return $r
      }
      try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/reisxd/TizenTubeCobalt/releases/latest' -Headers @{ 'User-Agent' = 'luk-home-installer'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 60
        $tag = "$($rel.tag_name)"
        $as = @($rel.assets | Where-Object { $_.name -eq $asset }) | Select-Object -First 1
        if ($as -and "$($as.digest)" -match '^sha256:([0-9a-f]{64})$') { $r.sha = $Matches[1] }
      } catch { LogQ "github api: $_" }
      if (-not $tag) {
        try {
          $resp = Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/reisxd/TizenTubeCobalt/releases/latest' -Headers $UA -TimeoutSec 60
          $u = if ($resp.BaseResponse.ResponseUri) { "$($resp.BaseResponse.ResponseUri)" } else { "$($resp.BaseResponse.RequestMessage.RequestUri)" }
          if ($u -match '/tag/([^/?#]+)$') { $tag = $Matches[1] }
        } catch { LogQ "github latest: $_" }
      }
      if ($tag -notmatch '^[A-Za-z0-9._-]+$') { return $null }
      $r.url = "https://github.com/reisxd/TizenTubeCobalt/releases/download/$tag/$asset"
      $r.vn = $tag -replace '^v', ''; $r.file = "tizentube-$($r.vn)-$asset"
    }
    elseif ($app -eq 'smarters') {   # solo Troypoint: la del Toolbox (si es mas nueva y con la misma firma) o la 3.1.5.1 fija
      if ($idx -gt 0) { return $null }
      $t = SmartersTarget
      $r.file = $t.file; $r.url = $t.url; $r.alt = $t.alt; $r.vn = $t.vn; $r.vc = [long]$t.vc; $r.sha = $t.sha
    }
    if (-not $r.url) { return $null }
    if ($KNOWN_VC.ContainsKey($r.file)) { $r.vc = [long]$KNOWN_VC[$r.file] }
    if ($KNOWN_SHA.ContainsKey($r.file)) { $r.sha = $KNOWN_SHA[$r.file] }
    return $r
  }
  function FreeKb {
    $fk = 0
    $dfl = @((S df -k /data) -split "`n" | Where-Object { $_ -match '\S' })
    if ($dfl.Count -ge 2) { $cols = $dfl[-1] -split '\s+'; if ($cols.Count -ge 4) { [void][int]::TryParse($cols[3], [ref]$fk) } }
    return $fk
  }
  function UpdAdd([string]$m) { if ($st.updSum) { $st.updSum += " - $m" } else { $st.updSum = $m } }
  function DumpVer([string]$p) {
    $dump = S dumpsys package $p
    $r = @{ vc = $null; vn = ''; abi = '' }
    if ($dump -match 'versionCode=([0-9]+)') { $r.vc = [long]$Matches[1] }
    if ($dump -match 'versionName=([^\s]+)') { $r.vn = $Matches[1] }
    if ($dump -match 'primaryCpuAbi=([^\s]+)') { $r.abi = $Matches[1] }
    return $r
  }
  function UpdApp([string]$app, [string]$p, [string]$nm) {
    if ($installed -notcontains $p -and $st.newInst -notcontains $p) { LogQ "upd ${p}: no instalada"; return }
    $iv = DumpVer $p; $ivn = $iv.vn
    $iabi = $iv.abi; if (-not $iabi -or $iabi -eq 'null') { $iabi = ("$abis" -split ',')[0] }
    $abi = if ($iabi -like 'arm64*') { 'arm64-v8a' } elseif ($iabi -like 'armeabi*') { 'armeabi-v7a' } else { $iabi }
    LogQ "upd ${p}: instalada vc=$($iv.vc) vn=$ivn abi=$iabi -> $abi"
    if ($null -eq $iv.vc) { Aviso "${nm}: no pude leer la version instalada; se deja como esta"; UpdAdd "$nm sin revisar"; return }
    $r = RemoteInfo $app $abi
    if (-not $r) { Aviso "${nm}: no pude consultar la ultima version oficial (internet o la pagina cambio); se deja la $ivn"; UpdAdd "$nm sin revisar"; return }
    LogQ "upd ${p}: oficial file=$($r.file) vn=$($r.vn) vc=$($r.vc) sha=$($r.sha) url=$($r.url)"
    if (($null -ne $r.vc -and $r.vc -le $iv.vc) -or ($null -eq $r.vc -and $r.vn -eq $ivn)) { Bien "$nm al dia ($ivn)"; UpdAdd "$nm al dia"; return }
    $dir = Join-Path $work "apps\$app"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $f = Join-Path $dir $r.file; $info = $null
    if ((Test-Path $f) -and (-not $r.sha -or (Sha256File $f) -eq $r.sha)) { try { $info = ApkInfo $f } catch { $info = $null } }
    if ($info) { Say "   $nm $($r.vn) ya estaba descargada en esta computadora" }
    else {
      Remove-Item -Force -ErrorAction SilentlyContinue $f, "$f.part"
      Say "   Descargando $nm $($r.vn) para comparar (solo esta vez; queda guardada; puede tardar unos minutos)..."
      $ok = $false
      foreach ($u in @($r.url, $r.alt)) {
        if (-not $u) { continue }
        try {
          Download $u "$f.part"
          $fs = [IO.File]::OpenRead("$f.part"); $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte(); $fs.Close()
          if ($b0 -eq 0x50 -and $b1 -eq 0x4B) { $ok = $true; break }
        } catch { LogQ "upd ${p}: descarga fallo desde $u : $_" }
        Remove-Item -Force -ErrorAction SilentlyContinue "$f.part"
      }
      if (-not $ok) { Aviso "${nm}: no se pudo descargar la version $($r.vn); se deja la $ivn"; UpdAdd "$nm sin revisar"; return }
      if ($r.sha -and (Sha256File "$f.part") -ne $r.sha) { Remove-Item -Force "$f.part"; Aviso "${nm}: el archivo descargado no coincide con el oficial (sha256); no se instala"; UpdAdd "$nm sin revisar"; return }
      Move-Item -Force "$f.part" $f
      Get-ChildItem -Path $dir -Filter '*.apk' | Where-Object { $_.FullName -ne (Get-Item $f).FullName } | Remove-Item -Force -ErrorAction SilentlyContinue
      try { $info = ApkInfo $f } catch { $info = $null }
    }
    LogQ "upd ${p}: archivo $f -> $(if ($info) { "$($info.pkg) $($info.vc) $($info.vn) $($info.min)" })"
    $avc = [long]0
    if (-not $info -or $info.pkg -ne $p -or -not [long]::TryParse("$($info.vc)", [ref]$avc)) {
      Remove-Item -Force -ErrorAction SilentlyContinue $f
      Aviso "${nm}: el archivo descargado no es valido; no se instala"; UpdAdd "$nm sin revisar"; return
    }
    $avn = $info.vn; $amin = 1; [void][int]::TryParse("$($info.min)", [ref]$amin)
    if ($avc -le $iv.vc) { Bien "$nm al dia ($ivn)"; UpdAdd "$nm al dia"; return }
    if ($amin -gt $sdk) { Aviso "$nm $avn necesita Android API $amin y este TV es API $sdk; se deja la $ivn"; UpdAdd "$nm $ivn (la nueva no es compatible)"; return }
    $need = [long]((Get-Item $f).Length / 1024) * 2 + 50000; $fk = FreeKb
    if ($fk -gt 0 -and $fk -lt $need) { Aviso "${nm}: no hay espacio en el TV para actualizar ($([int]($fk/1024)) MB libres, hacen falta ~$([int]($need/1024)) MB); se deja la $ivn"; UpdAdd "$nm sin espacio"; return }
    if ($dry) { Sim "adb install -r $($r.file)   ($nm $ivn -> $avn; conserva datos y sesiones)"; UpdAdd "$nm $ivn -> $avn (simulado)"; return }
    Say "   Actualizando $nm $ivn -> $avn (conserva datos y sesiones; puede tardar 1-2 minutos)..."
    if ($platform -like 'Google*') { Say '   (Si en el TV sale un aviso de Play Protect, elige "Instalar de todas formas".)' }
    $out = A install -r $f; LogQ "upd $p install: $out"
    if ($out -match 'Success') {
      $nv = DumpVer $p
      $st.appsTouched = $true
      if ($nv.vc -eq $avc) { Say "   ^   $nm actualizada $ivn -> $($nv.vn)" 'Green'; UpdAdd "$nm $ivn -> $($nv.vn)" }
      else { Aviso "${nm}: el TV acepto la actualizacion pero sigue mostrando la $($nv.vn); revisa la app"; UpdAdd "$nm $($nv.vn) (revisar)" }
    }
    elseif ($out -match 'UPDATE_INCOMPATIBLE|SIGNATURE') { Aviso "${nm}: la que tiene el TV viene de otra fuente (firma distinta). No se actualiza y NO se desinstala: sigue igual."; UpdAdd "$nm $ivn (firma distinta, no se toco)" }
    elseif ($out -match 'VERSION_DOWNGRADE') { Bien "$nm al dia ($ivn)"; UpdAdd "$nm al dia" }
    elseif ($out -match 'OLDER_SDK|NO_MATCHING_ABIS') { Aviso "$nm $avn no es compatible con este TV; se deja la $ivn"; UpdAdd "$nm $ivn (la nueva no es compatible)" }
    elseif ($out -match 'INSUFFICIENT_STORAGE') { Aviso "${nm}: el TV no tiene espacio para actualizar; se deja la $ivn"; UpdAdd "$nm sin espacio" }
    else { Aviso ("${nm}: la actualizacion fallo (" + (($out -split "`n")[-1]) + "); se deja la $ivn"); UpdAdd "$nm $ivn (fallo la actualizacion)" }
  }
  # Baja el APK oficial ($r.url / $r.alt) a <carpeta>\apps\<app>\ y comprueba el sha256 oficial (si se conoce).
  # Deja la ruta en $st.apkF. $false = no se pudo (ya aviso).
  # sha256 del certificado que firma un APK (firma v1, META-INF/*.RSA|DSA|EC). '' = no se pudo leer.
  function ApkCert([string]$apk) {
    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $z = [IO.Compression.ZipFile]::OpenRead($apk)
      try {
        $e = $z.Entries | Where-Object { $_.FullName -match '^META-INF/[^/]+\.(RSA|DSA|EC)$' } | Select-Object -First 1
        if (-not $e) { return '' }
        $ms = New-Object IO.MemoryStream; $es = $e.Open(); $es.CopyTo($ms); $es.Close(); $b = $ms.ToArray()
      } finally { $z.Dispose() }
      $col = New-Object Security.Cryptography.X509Certificates.X509Certificate2Collection
      $col.Import($b)
      if ($col.Count -lt 1) { return '' }
      $h = [Security.Cryptography.SHA256]::Create().ComputeHash($col[0].RawData)
      return (($h | ForEach-Object { $_.ToString('x2') }) -join '')
    } catch { LogQ "apkcert $apk : $_"; return '' }
  }
  # IPTV Smarters: SOLO de Troypoint. Lee el enlace de IPTV Smarters del Troypoint Toolbox (MediaFire) cada vez.
  # Si es el de la 3.1.5.1 (o no se pudo leer la pagina) => la 3.1.5.1 fija (sha256 conocido). Si Troypoint enlaza
  # otro archivo, se baja y solo se usa si es com.nst.iptvsmarterstvbox, MAS NUEVA (versionCode mayor) y firmada
  # con el mismo certificado que la 3.1.5.1; si no, se usa la 3.1.5.1. Una vez por corrida (queda en $st.smT).
  function SmartersTarget {
    if ($st.smT) { return $st.smT }
    $t = @{ file = $SMARTERS_FILE; url = $SMARTERS_URL; alt = $SMARTERS_ALT; vn = $SMARTERS_VN; vc = [long]$SMARTERS_VC; sha = $SMARTERS_SHA }
    $st.smT = $t
    $page = ''
    try { $page = (Invoke-WebRequest -UseBasicParsing -Uri $TOOLBOX_URL -UserAgent $UA_FIREFOX -TimeoutSec 60).Content } catch { LogQ "toolbox $TOOLBOX_URL : $_" }
    $u = ''
    $m = [regex]::Match("$page", '(?i)https?://[A-Za-z0-9.]*mediafire\.com/[^"''<>\s]*smarters[^"''<>\s]*')
    if ($m.Success) { $u = $m.Value }
    LogQ ("smarters: Troypoint Toolbox -> " + $(if ($u) { $u } else { '(no se pudo leer; se usa la 3.1.5.1 fija)' }))
    if (-not $u) { return $t }
    if ($u -match '/xrlnqh9kppx349u/') { LogQ 'smarters: Troypoint sigue con la 3.1.5.1'; return $t }
    $key = 'nuevo'; if ($u -match 'mediafire\.com/file[a-z_]*/([A-Za-z0-9]+)/') { $key = $Matches[1] }
    $dir = Join-Path $work 'apps\smarters'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $f = Join-Path $dir "iptv-smarters-troypoint-$key.apk"
    if (-not (IsApk $f)) {
      Say '   Troypoint tiene otro archivo de IPTV Smarters; se revisa (version y firma)...'
      try { Remove-Item -Force -ErrorAction SilentlyContinue "$f.part"; DownloadMF $u "$f.part" } catch { LogQ "smarters toolbox download: $_" }
      if (-not (IsApk "$f.part")) { Remove-Item -Force -ErrorAction SilentlyContinue "$f.part"; Aviso "IPTV Smarters: no se pudo bajar el archivo nuevo de Troypoint; se usa la $SMARTERS_VN"; return $t }
      Move-Item -Force "$f.part" $f
    }
    $info = $null; try { $info = ApkInfo $f } catch { $info = $null }
    $cert = ApkCert $f
    LogQ "smarters: Troypoint nuevo $f -> $(if ($info) { "$($info.pkg) $($info.vc) $($info.vn) $($info.min)" }) cert=$cert"
    $tvc = 0L; if ($info) { [void][long]::TryParse("$($info.vc)", [ref]$tvc) }
    if (-not $info -or $info.pkg -ne 'com.nst.iptvsmarterstvbox' -or $tvc -le 0) { Aviso "IPTV Smarters: el archivo de Troypoint no es IPTV Smarters; se usa la $SMARTERS_VN"; Remove-Item -Force $f; return $t }
    if ($cert -ne $SMARTERS_CERT) { Aviso "IPTV Smarters $($info.vn) de Troypoint no tiene la misma firma que la $SMARTERS_VN; se usa la $SMARTERS_VN"; Remove-Item -Force $f; return $t }
    if ($tvc -le [long]$SMARTERS_VC) { LogQ "smarters: Troypoint $($info.vn) (vc $tvc) no es mas nueva que la $SMARTERS_VN; se usa la fija"; Remove-Item -Force $f; return $t }
    $t = @{ file = (Split-Path $f -Leaf); url = $u; alt = ''; vn = "$($info.vn)"; vc = $tvc; sha = (Sha256File $f) }
    $st.smT = $t
    Bien "Troypoint tiene IPTV Smarters $($info.vn) (misma firma que la $SMARTERS_VN): se usa esa"
    return $t
  }
  function IsApk([string]$f) {
    if (-not (Test-Path $f) -or (Get-Item $f).Length -lt 2) { return $false }
    $fs = [IO.File]::OpenRead($f); $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte(); $fs.Close()
    return ($b0 -eq 0x50 -and $b1 -eq 0x4B)
  }
  # MediaFire: la pagina redirige al archivo (el enlace directo trae una clave que cambia cada vez) o trae el
  # enlace en el HTML (href="https://downloadNNNN.mediafire.com/..." o data-scrambled-url en base64); se saca cada vez.
  function DownloadMF([string]$url, [string]$out) {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out -UserAgent $UA_BROWSER -TimeoutSec 600
    if (IsApk $out) { return }
    $pg = [IO.File]::ReadAllText($out); Remove-Item -Force -ErrorAction SilentlyContinue $out
    $d = ''
    $m = [regex]::Match($pg, 'https?://download[0-9]*\.mediafire\.com/[^"''<>\s]+')
    if ($m.Success) { $d = $m.Value }
    else {
      $m = [regex]::Match($pg, 'data-scrambled-url="([A-Za-z0-9+/=]+)"')
      if ($m.Success) { try { $d = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($m.Groups[1].Value)) } catch { $d = '' } }
      if ($d -notmatch '^https://download[0-9]*\.mediafire\.com/') { $d = '' }
    }
    LogQ "mediafire $url -> enlace directo: $d"
    if (-not $d) { throw 'mediafire: no se encontro el enlace directo' }
    Invoke-WebRequest -UseBasicParsing -Uri $d -OutFile $out -UserAgent $UA_BROWSER -TimeoutSec 600
  }
  function BajarApk([string]$app, [string]$nm, $r) {
    $dir = Join-Path $work "apps\$app"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $f = Join-Path $dir $r.file; $st.apkF = $f; $info = $null
    if ((Test-Path $f) -and (-not $r.sha -or (Sha256File $f) -eq $r.sha)) { try { $info = ApkInfo $f } catch { $info = $null } }
    if ($info) { Say "   $nm $($r.vn) ya estaba descargada en esta computadora"; return $true }
    Remove-Item -Force -ErrorAction SilentlyContinue $f, "$f.part"
    if ($app -eq 'smarters') { Say "   Descargando $nm $($r.vn) gratis (Troypoint; solo esta vez, queda guardada; puede tardar unos minutos)..." }
    else { Say "   Descargando $nm $($r.vn) (oficial; solo esta vez, queda guardada; puede tardar unos minutos)..." }
    $ok = $false
    foreach ($u in @($r.url, $r.alt)) {
      if (-not $u) { continue }
      try {
        if ($u -match 'mediafire\.com') { DownloadMF $u "$f.part" } else { Download $u "$f.part" }
        $fs = [IO.File]::OpenRead("$f.part"); $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte(); $fs.Close()
        if ($b0 -eq 0x50 -and $b1 -eq 0x4B) { $ok = $true; break }
      } catch { LogQ "inst ${app}: descarga fallo desde $u : $_" }
      Remove-Item -Force -ErrorAction SilentlyContinue "$f.part"
    }
    if (-not $ok) { Aviso "${nm}: no se pudo descargar la version $($r.vn); no se instala"; return $false }
    if ($r.sha -and (Sha256File "$f.part") -ne $r.sha) { Remove-Item -Force "$f.part"; Aviso "${nm}: el archivo descargado no coincide con el oficial (sha256); no se instala"; return $false }
    Move-Item -Force "$f.part" $f
    return $true
  }
  # La app NO esta en el TV: se instala la version oficial (adb install -g) para el procesador y el Android del TV.
  # Si la ultima pide un Android mas nuevo, prueba versiones oficiales anteriores; si ninguna sirve, avisa y sigue.
  function InstApp([string]$app, [string]$p, [string]$nm) {
    if ($noApps) { LogQ "inst ${p}: no instalada, SINAPPS"; Bien "$nm no esta en el TV (no se instala: `$SINAPPS=1)"; UpdAdd "$nm no instalada"; return }
    if ($app -eq 'smarters') { $abiList = @('universal') }   # un solo APK para todos los procesadores
    elseif ($cpuAbi -like 'arm64*') { $abiList = @('arm64-v8a', 'armeabi-v7a') }   # si no hay de 64 bits, la de 32 bits tambien corre
    elseif ($cpuAbi -like 'armeabi*' -or -not $cpuAbi) { $abiList = @('armeabi-v7a') }
    else { $abiList = @($cpuAbi) }
    LogQ "inst ${p}: no instalada; abi=$cpuAbi -> $($abiList -join ' ') api=$sdk"
    $tried = @(); $got = $false
    foreach ($abi in $abiList) {
      $next = $false
      for ($idx = 0; $idx -le 3; $idx++) {
        $r = RemoteInfo $app $abi $idx
        if (-not $r) { break }
        $got = $true
        LogQ "inst ${p}: oficial[$idx] abi=$abi file=$($r.file) vn=$($r.vn) vc=$($r.vc) sha=$($r.sha) url=$($r.url)"
        if (-not (BajarApk $app $nm $r)) { UpdAdd "$nm no se pudo instalar"; return }
        $f = $st.apkF; $info = $null
        try { $info = ApkInfo $f } catch { $info = $null }
        LogQ "inst ${p}: archivo $f -> $(if ($info) { "$($info.pkg) $($info.vc) $($info.vn) $($info.min)" })"
        $avc = [long]0
        if (-not $info -or $info.pkg -ne $p -or -not [long]::TryParse("$($info.vc)", [ref]$avc)) {
          Remove-Item -Force -ErrorAction SilentlyContinue $f
          Aviso "${nm}: el archivo descargado no es valido; no se instala"; UpdAdd "$nm no se pudo instalar"; return
        }
        $avn = $info.vn; $amin = 1; [void][int]::TryParse("$($info.min)", [ref]$amin)
        if ($amin -gt $sdk) { Aviso "$nm $avn necesita Android API $amin y este TV es API $sdk; busco una version oficial anterior que sirva..."; $tried += $avn; continue }
        $need = [long]((Get-Item $f).Length / 1024) * 2 + 50000; $fk = FreeKb
        if ($fk -gt 0 -and $fk -lt $need) { Aviso "${nm}: no hay espacio en el TV para instalarla ($([int]($fk/1024)) MB libres, hacen falta ~$([int]($need/1024)) MB); no se instala"; UpdAdd "$nm sin espacio"; return }
        if ($dry) { Sim "adb install -g $($r.file)   ($nm $avn, $abi, Android API $amin+; no estaba en el TV)"; $st.newInst += $p; UpdAdd "$nm $avn instalada (simulado)"; return }
        Say "   Instalando $nm $avn (no estaba en el TV; puede tardar 1-2 minutos)..."
        if ($platform -like 'Google*') { Say '   (Si en el TV sale un aviso de Play Protect, elige "Instalar de todas formas".)' }
        $out = A install -g $f; LogQ "inst $p install: $out"
        if ($out -match 'Success') {
          if ((S pm path $p) -match 'package:') { $st.newInst += $p; Say "   +   $nm $avn instalada" 'Green'; UpdAdd "$nm $avn instalada" }
          else { Aviso "${nm}: el TV dijo que la instalo pero no aparece; revisa la app"; UpdAdd "$nm (revisar)" }
        }
        elseif ($out -match 'NO_MATCHING_ABIS|CPU_ABI_INCOMPATIBLE') {
          if ($abi -eq 'arm64-v8a') { Aviso "$nm $avn de 64 bits no sirve en este TV; pruebo la de 32 bits..."; $next = $true; break }
          Aviso "$nm $avn no es para el procesador de este TV; no se instala"; UpdAdd "$nm no compatible con este TV"
        }
        elseif ($out -match 'OLDER_SDK') { Aviso "$nm $avn no es compatible con este TV (API $sdk); busco una version oficial anterior que sirva..."; $tried += $avn; continue }
        elseif ($out -match 'INSUFFICIENT_STORAGE') { Aviso "${nm}: el TV no tiene espacio para instalarla; no se instala"; UpdAdd "$nm sin espacio" }
        elseif ($out -match 'ALREADY_EXISTS|UPDATE_INCOMPATIBLE|SIGNATURE|DUPLICATE') { Aviso "${nm}: el TV ya tiene una copia escondida o de otra fuente; no se toca"; UpdAdd "$nm no se toco" }
        else { Aviso ("${nm}: la instalacion fallo (" + (@($out -split "`n" | Where-Object { $_ -notmatch '^Performing' })[-1]) + "); se sigue con lo demas"); UpdAdd "$nm no se pudo instalar" }
        return
      }
      if ($next) { continue }
    }
    if ($tried.Count) { Aviso "${nm}: ninguna version oficial reciente funciona en este TV (Android API $sdk; probadas: $($tried -join ' ')); no se instala"; UpdAdd "$nm no compatible con este TV" }
    elseif (-not $got) { Aviso "${nm}: no pude consultar la version oficial para este TV (internet, la pagina cambio o no hay para $cpuAbi); no se instala"; UpdAdd "$nm no se pudo instalar" }
    else { Aviso "${nm}: no se encontro una version oficial para este TV; no se instala"; UpdAdd "$nm no se pudo instalar" }
  }
  function TileName([string]$p) {
    $nf = Join-Path $bundle "tiles\$p.txt"
    if (Test-Path $nf) { return ([IO.File]::ReadAllText($nf) -split "`n")[0].Trim() }
    $p
  }
  # Apps recien instaladas en el paso 8: se agregan al dock de Luk Home (con su icono).
  # Dock nuevo de esta corrida: orden Stremio, IPTV Smarters, TizenTube y luego las apps extra.
  # Dock que ya tenia el TV: se deja tal cual y se agregan al final las que falten.
  function DockNuevas {
    if (-not $st.newInst.Count) { return }
    $root = Join-Path ([IO.Path]::GetTempPath()) ("lukapps-" + [guid]::NewGuid().ToString('N'))
    $d = Join-Path $root 'lukhome'; New-Item -ItemType Directory -Force -Path (Join-Path $d 'tiles') | Out-Null
    $cur = ''
    if ($dockMode -ne 'nuevo') {
      if ($dry) {
        $fb = Join-Path $bk 'dock-antes.txt'; if (Test-Path $fb) { $cur = [IO.File]::ReadAllText($fb) }
        if ($dockMode -eq 'extra') { $cur = $cur.TrimEnd("`r", "`n") + "`n" + (($extraPkgs | ForEach-Object { "$_`n" }) -join '') }
      } else { $cur = S run-as $PKG cat files/dock.txt }
      if ($cur -match 'No such file|run-as:') { $cur = '' }
    }
    $cur = $cur -replace "`r", ''
    $curPk = @($cur -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    $added = @()
    if ($dockMode -eq 'nuevo' -or $curPk.Count -eq 0) {
      $dk = @()
      foreach ($p in $DOCK_APPS) { if ($installed -contains $p -or $st.newInst -contains $p) { $dk += $p } }
      foreach ($p in $extraPkgs) { if ($DOCK_APPS -notcontains $p -and $dk -notcontains $p) { $dk += $p } }
      foreach ($p in $st.newInst) { $added += (TileName $p) }
      $txt = "# Apps del inicio, en orden`n" + (($dk | ForEach-Object { "$_`n" }) -join '')
    } else {
      $dk = @($curPk); $txt = $cur.TrimEnd("`n") + "`n"
      foreach ($p in $DOCK_APPS) {
        if ($st.newInst -notcontains $p -or $dk -contains $p) { continue }
        $dk += $p; $txt += "$p`n"; $added += (TileName $p)
      }
    }
    WriteLF (Join-Path $d 'dock.txt') $txt
    $nt = 0
    foreach ($p in $st.newInst) {
      $tp = Join-Path $bundle "tiles\$p.png"
      if (Test-Path $tp) {
        Copy-Item $tp -Destination (Join-Path $d 'tiles')
        $tt = Join-Path $bundle "tiles\$p.txt"; if (Test-Path $tt) { Copy-Item $tt -Destination (Join-Path $d 'tiles') }
        $nt++
      }
    }
    Copy-Item -Path (Join-Path $bundle 'tv-apply.sh') -Destination $d
    LogQ "dock_nuevas: mode=$(if ($dockMode) { $dockMode } else { 'existente' }) new=$($st.newInst -join ' ') dock=$($dk -join ' ')"
    try {
      if (-not $added.Count) { Bien 'Dock: las apps nuevas ya estaban en el inicio'; return }
      if ($dry) {
        Sim "adb push lukhome\ -> /data/local/tmp/ y tv-apply.sh  (escribe: tiles/ ($nt iconos), dock.txt)"
        Sim ("dock.txt = " + ($dk -join ' '))
        return
      }
      A shell rm -rf /data/local/tmp/lukhome | Out-Null
      $out = A push $d /data/local/tmp/; LogQ "push apps: $out"
      $out = A shell sh /data/local/tmp/lukhome/tv-apply.sh; LogQ "apply apps: $out"
      if ($out -match 'LUK_APPLY_OK') { $st.dockTouched = $true; Bien ("Dock: se agregan al inicio: " + ($added -join ', ')) }
      else {
        A shell rm -rf /data/local/tmp/lukhome | Out-Null
        Aviso ("No pude agregar las apps nuevas al dock (" + ((($out -split "`n") | Where-Object { $_ -match 'LUK_APPLY_FAIL' } | Select-Object -First 1)) + '); estan en "Otras apps". Vuelve a correr la linea para ponerlas.')
      }
    } finally { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $root }
  }
  # Despues de instalar o actualizar apps: Luk Home de nuevo en pantalla (y recarga el dock). Sin teclas.
  function VolverLuk {
    if (-not $st.newInst.Count -and -not $st.appsTouched) { return }
    if ($dry) { Sim 'abrir Luk Home otra vez (am start --ez reload true) para que muestre el dock al dia'; return }
    LogQ (A shell am start -n "$PKG/.HomeActivity" --ez reload true)
    $top = ''
    for ($i = 0; $i -lt 6; $i++) {
      Start-Sleep -Milliseconds 1500
      $top = ((S dumpsys activity activities) -split "`n" | Where-Object { $_ -match 'mResumedActivity|topResumedActivity' } | Select-Object -First 1)
      if ("$top" -match [regex]::Escape($PKG)) { break }
    }
    LogQ "volver_luk: $top"
    if ("$top" -match [regex]::Escape($PKG)) { Bien ("Luk Home de nuevo en pantalla" + $(if ($st.dockTouched) { ', con el dock al dia' } else { '' })) }
    else { Aviso 'Pulsa el boton Inicio (la casita) del control para volver a Luk Home.' }
  }
  # IPTV Smarters (2026-11-03b): siempre la gratis de Troypoint (ver SmartersTarget). Si falta, se instala.
  # Si el TV tiene una de Troypoint (misma firma) mas vieja, se actualiza con "adb install -r" (conserva login y
  # listas); igual o mas nueva, no se toca. Si tiene otra (por ejemplo la 4.0.6 de pago, que no funciona), se cambia:
  # se guarda una copia, se desinstala (se borran su login y sus listas) y se instala la de Troypoint; si eso falla,
  # se vuelve a poner la copia. Nunca se instala ni se actualiza a las de pago (iptvsmarters.com, smartersott.app).
  function SmartersPaso([string]$app, [string]$p, [string]$nm) {
    $iv = DumpVer $p; $ivn = $iv.vn
    if ($noUpd) { LogQ "smarters: vc=$($iv.vc) vn=$ivn, NOUPDATE, no se toca"; Bien "$nm $ivn se deja como esta (`$NOUPDATE=1)"; UpdAdd "$nm sin revisar"; return }
    $r = RemoteInfo 'smarters' 'universal' 0
    LogQ "smarters: instalada vc=$($iv.vc) vn=$ivn; Troypoint = vc $($r.vc) vn $($r.vn) ($($r.file))"
    if ($iv.vc -eq $r.vc -and $ivn -eq $r.vn) { Bien "$nm $ivn (la gratis de Troypoint) ya esta; no se toca"; UpdAdd "$nm $ivn al dia"; return }
    if (-not (BajarApk 'smarters' $nm $r)) { UpdAdd "$nm $ivn (no se pudo bajar la de Troypoint, no se toco)"; return }
    $f = $st.apkF; $info = $null
    try { $info = ApkInfo $f } catch { $info = $null }
    LogQ "smarters: archivo $f -> $(if ($info) { "$($info.pkg) $($info.vc) $($info.vn) $($info.min)" })"
    if (-not $info -or $info.pkg -ne $p -or "$($info.vc)" -ne "$($r.vc)") { Remove-Item -Force -ErrorAction SilentlyContinue $f; Aviso "${nm}: el archivo descargado no es el esperado; no se toca"; UpdAdd "$nm $ivn (no se toco)"; return }
    $avn = $info.vn; $avc = [long]$info.vc; $amin = 1; [void][int]::TryParse("$($info.min)", [ref]$amin)
    # Copia de la que tiene el TV (lectura; tambien en simulacion): sirve para ver su firma y para volver atras.
    $paths = @((S pm path $p) -split "`n" | Where-Object { $_ -match '^package:' } | ForEach-Object { ($_ -replace '^package:', '').Trim() })
    $bkd = Join-Path $work "apps\smarters\respaldo-$ivn-$ts"; New-Item -ItemType Directory -Force -Path $bkd | Out-Null
    $files = @(); $n = 0
    foreach ($q in $paths) {
      $n++; $dst = Join-Path $bkd ("$n-" + ($q -split '/')[-1])
      $o = A pull $q $dst; LogQ "smarters pull: $o"
      if (-not (Test-Path $dst)) { $files = @(); break }
      $files += $dst
    }
    if (-not $files.Count) { Aviso "${nm}: no pude leer la que tiene el TV; por seguridad no se toca"; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bkd; UpdAdd "$nm $ivn (no se toco)"; return }
    $icert = ApkCert $files[0]; LogQ "smarters: firma de la instalada = $icert"
    $quit = { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bkd }
    if (-not $icert) { & $quit; Aviso "${nm}: no pude leer la firma de la que tiene el TV; por seguridad no se toca"; UpdAdd "$nm $ivn (no se toco)"; return }
    if ($amin -gt $sdk) { & $quit; Aviso "$nm $avn necesita Android API $amin y este TV es API $sdk; se deja la $ivn"; UpdAdd "$nm $ivn (no se toco)"; return }
    $al = @("$abis" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($al.Count -and $al -notcontains 'armeabi-v7a' -and $al -notcontains 'armeabi') { & $quit; Aviso "$nm $avn no es para el procesador de este TV ($abis); se deja la $ivn"; UpdAdd "$nm $ivn (no se toco)"; return }
    $need = [long]((Get-Item $f).Length / 1024) * 2 + 50000; $fk = FreeKb
    if ($fk -gt 0 -and $fk -lt $need) { & $quit; Aviso "${nm}: no hay espacio en el TV ($([int]($fk/1024)) MB libres); se deja la $ivn"; UpdAdd "$nm sin espacio"; return }
    if ($icert -eq $SMARTERS_CERT) {   # ya es de Troypoint (misma firma)
      & $quit
      if ($null -eq $iv.vc -or $iv.vc -ge $avc) { Bien "$nm $ivn (de Troypoint) ya esta; no se toca"; UpdAdd "$nm $ivn al dia"; return }
      if ($dry) { Sim "adb install -r $($r.file)   ($nm $ivn -> $avn de Troypoint; conserva login y listas)"; UpdAdd "$nm $ivn -> $avn (simulado)"; return }
      Say "   Actualizando $nm $ivn -> $avn de Troypoint (conserva login y listas)..."
      $out = A install -r $f; LogQ "smarters install -r: $out"
      if ($out -match 'Success') { $st.appsTouched = $true; Say "   ^   $nm actualizada a $avn" 'Green'; UpdAdd "$nm $ivn -> $avn" }
      else { Aviso ("${nm}: no se pudo actualizar (" + (@($out -split "`n" | Where-Object { $_ -notmatch '^Performing' })[-1]) + "); sigue la $ivn"); UpdAdd "$nm $ivn (no se pudo actualizar)" }
      return
    }
    Aviso "$nm $ivn no es la gratis de Troypoint: se cambia por la $avn de Troypoint."
    if ($dry) {
      & $quit
      Sim "adb uninstall $p   (se BORRAN el login y las listas de $nm)"
      Sim "adb install -g $($r.file)   ($nm $avn gratis de Troypoint)"
      $st.newInst += $p; UpdAdd "$nm $ivn -> $avn gratis (simulado; se borran login y listas)"; return
    }
    Say "   Ojo: al cambiar $nm se borran su login y sus listas; hay que volver a ponerlos en la app." 'Yellow'
    Say "   Quitando $nm $ivn (copia guardada en esta computadora)..."
    $out = A uninstall $p; LogQ "smarters uninstall: $out"
    if ($out -notmatch 'Success') { Aviso "${nm}: el TV no dejo desinstalarla; sigue la $ivn"; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bkd; UpdAdd "$nm $ivn (no se toco)"; return }
    $st.appsTouched = $true
    Say "   Instalando $nm $avn gratis (Troypoint; puede tardar 1-2 minutos)..."
    if ($platform -like 'Google*') { Say '   (Si en el TV sale un aviso de Play Protect, elige "Instalar de todas formas".)' }
    $out = A install -g $f; LogQ "smarters install: $out"
    if ($out -match 'Success' -and (S pm path $p) -match 'package:') {
      $st.newInst += $p
      Say "   +   $nm cambiada: $ivn -> $avn gratis (abre la app y pon otra vez el usuario y la lista)" 'Green'
      UpdAdd "$nm $ivn -> $avn gratis (login y listas borrados)"
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bkd; return
    }
    Aviso ("$nm $avn no se pudo instalar (" + (@($out -split "`n" | Where-Object { $_ -notmatch '^Performing' })[-1]) + "); vuelvo a poner la $ivn...")
    if ($files.Count -eq 1) { $back = A install -g $files[0] } else { $back = A install-multiple -g @files }
    LogQ "smarters restore: $back"
    if ($back -match 'Success') { Aviso "$nm $ivn quedo puesta otra vez (sin login: hay que volver a ponerlo)"; UpdAdd "$nm $ivn (la gratis fallo, se volvio a poner)"; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bkd }
    else { Aviso "$nm no se pudo volver a poner. La copia quedo en $bkd"; UpdAdd "$nm FALTA (copia en $bkd)" }
  }
  function AppPaso([string]$app, [string]$p, [string]$nm) {   # actualiza si esta, instala si falta
    if ($app -eq 'smarters' -and $installed -contains $p) { SmartersPaso $app $p $nm; return }
    if ($installed -contains $p) {
      if ($noUpd) { LogQ "upd ${p}: instalada, NOUPDATE"; UpdAdd "$nm sin revisar"; return }
      UpdApp $app $p $nm
    } else { InstApp $app $p $nm }
  }
  function ActualizarApps {
    Paso 8 'Apps: Stremio, IPTV Smarters (gratis, Troypoint) y TizenTube (instalar o actualizar)'
    $st.newInst = @(); $st.appsTouched = $false; $st.dockTouched = $false
    if ($noUpd -and $noApps) { Bien 'Omitido ($NOUPDATE=1 y $SINAPPS=1)'; $st.updSum = 'no se revisaron ($NOUPDATE=1 $SINAPPS=1)'; return }
    if ($noUpd) { Bien 'Las que ya estan no se actualizan ($NOUPDATE=1)' }
    if ($noApps) { Bien 'Las que faltan no se instalan ($SINAPPS=1)' }
    $st.updSum = ''
    foreach ($x in @(@('stremio', 'com.stremio.one', 'Stremio'), @('smarters', 'com.nst.iptvsmarterstvbox', 'IPTV Smarters'), @('tizentube', 'io.gh.reisxd.tizentube.cobalt', 'TizenTube'))) {
      try { AppPaso $x[0] $x[1] $x[2] }
      catch { LogQ ($_ | Out-String); Aviso "$($x[2]): no se pudo revisar ($($_.Exception.Message)); se deja como esta"; UpdAdd "$($x[2]) sin revisar" }
    }
    try { DockNuevas } catch { LogQ ($_ | Out-String); Aviso "No pude agregar las apps nuevas al dock ($($_.Exception.Message)); estan en 'Otras apps'" }
    try { VolverLuk } catch { LogQ ($_ | Out-String); Aviso 'Pulsa el boton Inicio (la casita) del control para volver a Luk Home.' }
  }

  function RestoreAcc {
    if (-not $st.accChanged -and -not $st.homeChanged -and -not $st.uopChanged) { return }
    Say '   Devolviendo el TV como estaba (boton Inicio)...'
    if ($st.accChanged) {
      if (-not $st.oldSvc -or $st.oldSvc -eq 'null') { A shell settings delete secure enabled_accessibility_services | Out-Null }
      else { A shell "settings put secure enabled_accessibility_services '$($st.oldSvc)'" | Out-Null }
      if (-not $st.oldEn -or $st.oldEn -eq 'null') { A shell settings delete secure accessibility_enabled | Out-Null }
      else { A shell settings put secure accessibility_enabled $st.oldEn | Out-Null }
    }
    if ($st.homeChanged -and $st.oldHome) { A shell cmd package set-home-activity $st.oldHome | Out-Null }
    if ($st.uopChanged) { $u = if ($st.oldUop) { $st.oldUop } else { 'default' }; A shell appops set $PKG GET_USAGE_STATS $u | Out-Null }
    $st.accChanged = $false; $st.homeChanged = $false; $st.uopChanged = $false
    Say '   Listo: el boton Inicio quedo como antes.'
  }

  try {
    Say ''
    Say '=================================================' 'White'
    Say '   Instalador de Luk Home' 'White'
    if ($dry) { Say '   MODO SIMULACION: no se cambia nada en el TV' 'Yellow' }
    Say '=================================================' 'White'

    # ---------- validar ----------
    if (-not $IP) { Falla 'Falta la IP del TV.' "La linea debe empezar asi: `$IP='192.168.1.50'; `$PIN='1234'; ..." }
    if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?$') { Falla "La IP '$IP' no es valida." 'Debe verse como 192.168.1.50 (Ajustes > Mi Fire TV > Acerca de > Red).' }
    if (@('sinpin', 'none', '-') -contains $PIN) { $PIN = '' }
    elseif (-not $PIN) { Falla 'Falta el PIN (4 numeros).' "Agrega `$PIN='1234'; al principio de la linea." }
    elseif ($PIN -notmatch '^\d{4}$') { Falla 'El PIN debe tener exactamente 4 numeros.' }
    $pinHash = ''
    if ($PIN) {
      $sha = [Security.Cryptography.SHA256]::Create()
      $pinHash = ($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($PIN)) | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    $st.serial = if ($IP -match ':') { $IP } else { "$($IP):5555" }
    LogQ "ip=$IP theme=$THEME city=$city apps=$appsArg dry=$dry new_dock=$newDock noupdate=$noUpd noapps=$noApps buttons=$btn estilo=$estilo retroarch=$retro kodi=$kodiOpt pin_set=$([bool]$PIN) ps=$($PSVersionTable.PSVersion) os=$([Environment]::OSVersion.VersionString)"

    # ---------- 1. herramientas ----------
    Paso 1 'Preparando las herramientas (solo la primera vez tarda un poco)'
    if ($ADBOVR) { $st.adb = "$ADBOVR" }
    else {
      $st.adb = Join-Path $work 'platform-tools\adb.exe'
      $okAdb = $false
      if (Test-Path $st.adb) { $okAdb = (Adb version) -match 'Android Debug Bridge' }
      if (-not $okAdb) {
        Say '   Descargando las herramientas de Google (platform-tools)...'
        $ptz = Join-Path $work 'pt.zip'
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $work 'platform-tools'), $ptz
        try { Download 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' $ptz }
        catch { Falla 'No se pudo descargar platform-tools de Google.' 'Revisa que la computadora tenga internet.' }
        try { Unzip $ptz $work } catch { Falla 'No se pudo descomprimir platform-tools.' "$_" }
        Remove-Item -Force -ErrorAction SilentlyContinue $ptz
      }
    }
    $ver = Adb version
    if ($ver -notmatch 'Android Debug Bridge') { Falla 'La herramienta adb no funciona en esta computadora.' "Ruta: $($st.adb)" }
    Bien ("adb listo (" + (($ver -split "`n" | Where-Object { $_ -like 'Version *' }) -replace 'Version ', '') + ")")

    Say '   Descargando Luk Home, temas e iconos...'
    $bdir = Join-Path $work 'bundle'; $bzip = Join-Path $work 'bundle.zip'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $bdir, $bzip
    $url = if ($BURL) { "$BURL" } else { $REPO_ZIP }
    try { Download $url $bzip } catch { Falla 'No se pudo descargar el paquete de Luk Home.' 'Revisa el internet de la computadora y vuelve a intentar.' }
    try { Unzip $bzip $bdir } catch { Falla 'El paquete descargado esta danado. Vuelve a correr la linea.' }
    Remove-Item -Force -ErrorAction SilentlyContinue $bzip
    $apkMain = Get-ChildItem -Path $bdir -Recurse -Filter 'luk-home.apk' | Where-Object { $_.Directory.Name -eq 'apks' } | Select-Object -First 1
    if (-not $apkMain) { Falla 'El paquete descargado esta incompleto (falta luk-home.apk).' }
    $bundle = $apkMain.Directory.Parent.FullName
    $sums = Join-Path $bundle 'SHA256SUMS'
    if (Test-Path $sums) {
      foreach ($l in Get-Content $sums) {
        $p = $l -split '\s+', 2
        if ($p.Count -eq 2 -and $p[1] -like 'apks/*') {
          if ((Sha256File (Join-Path $bundle $p[1])) -ne $p[0]) { Falla "El archivo $($p[1]) llego danado. Vuelve a correr la linea." }
        }
      }
    }
    # Temas: los de order.txt (incluidos) + carpetas extra de bundle\themes\ (temas personalizados de clientes:
    # solo van al TV si se nombran). Un tema = carpeta con fotos (jpg/png/webp) + name.txt (nombre en la pastilla Temas).
    $slugRe = '^[a-z0-9][a-z0-9_-]*$'
    function ThPics([string]$t) { @(Get-ChildItem -File -Path (Join-Path $bundle "themes\$t") -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' }).Count }
    $thBuiltin = @(Get-Content (Join-Path $bundle 'themes\order.txt') | ForEach-Object { $_.Trim() } | Where-Object { $_ -cmatch $slugRe -and (ThPics $_) -gt 0 })
    $thCustom = @(Get-ChildItem -Directory -Path (Join-Path $bundle 'themes') | ForEach-Object { $_.Name } | Where-Object { $_ -cmatch $slugRe -and $thBuiltin -notcontains $_ -and (ThPics $_) -gt 0 } | Sort-Object)
    $THEME = ($THEME.ToLower() -replace '\s', '')
    $THEME = (($THEME -split ',') | ForEach-Object { if ($TH_ALIAS.ContainsKey($_)) { $TH_ALIAS[$_] } else { $_ } }) -join ','
    # Modos del menu Temas: 'aleatorio' (fotos de todos los temas mezcladas) o 'rotar' (un tema completo cada hora)
    $thMode = ''; $t3 = @()
    foreach ($t in ($THEME -split ',' | Where-Object { $_ -ne '' })) {
      if (@('aleatorio', 'aleatoria', 'random', 'mezclar', 'mezcla', 'shuffle') -contains $t) { $thMode = 'aleatorio' }
      elseif (@('rotar', 'rotartemas', 'rotar-temas', 'rotacion', 'rotate') -contains $t) { $thMode = 'rotar' }
      else { $t3 += $t }
    }
    if ($thMode) { $THEME = if ($t3.Count -eq 0) { 'todos' } else { ($t3 -join ',') + ',' } }
    $sel = @(); $bad = @(); $thList = $false
    if ($THEME -match ',') {
      $thList = $true
      foreach ($t in ($THEME -split ',' | Where-Object { $_ -ne '' })) {
        if ($t -eq 'todos') { foreach ($b in $thBuiltin) { if ($sel -notcontains $b) { $sel += $b } } }
        elseif ($thBuiltin -contains $t -or $thCustom -contains $t) { if ($sel -notcontains $t) { $sel += $t } }
        else { $bad += "'$t'" }
      }
    }
    elseif ($THEME -eq '' -or $THEME -eq 'todos') { $sel = $thBuiltin; $themeGiven = $false }
    elseif ($thBuiltin -contains $THEME) { $sel = $thBuiltin }
    elseif ($thCustom -contains $THEME) { $sel = @($THEME) + $thBuiltin }
    else { $bad += "'$THEME'" }
    if ($bad.Count -or -not $sel.Count) {
      $valid = 'Temas validos: ' + ($thBuiltin -join ', '); if ($thCustom.Count) { $valid += '. Personalizados: ' + ($thCustom -join ', ') }
      Falla ('Tema no valido: ' + ($bad -join ', ')) ($valid + ". Para varios: `$THEME='autos,mar,espacio' (el primero es el inicial) o 'todos'.")
    }
    if ($thList) { $THEME = $sel[0]; $themeGiven = $true }
    elseif (-not $themeGiven) { $THEME = if ($sel -contains 'paisajes') { 'paisajes' } else { $sel[0] } }
    if ($thList) { Bien "Paquete listo ($($sel.Count) temas elegidos: $($sel -join ', '))" } else { Bien "Paquete listo ($($sel.Count) temas)" }
    if ($thMode) { $themeGiven = $true }
    LogQ "themes builtin=$($thBuiltin -join ' ') custom=$($thCustom -join ' ') sel=$($sel -join ' ') list=$thList default=$THEME mode=$thMode given=$themeGiven"

    # ---------- 2. conexion ----------
    Paso 2 "Conectando con el TV $IP"
    Adb start-server | Out-Null
    $start = Get-Date; $asked = $false; $lastAsk = $start; $refused = 0; $unreach = 0; $kind = ''
    while ($true) {
      $out = Adb connect $st.serial; LogQ "connect: $out"
      $state = Adb -s $st.serial get-state; LogQ "state: $state"
      $el = ((Get-Date) - $start).TotalSeconds
      if ($state -match '^device') { break }
      elseif ($state -match 'unauthorized') {
        $kind = 'unauth'
        if (-not $asked -or ((Get-Date) - $lastAsk).TotalSeconds -ge 30) {
          Say ''
          Say '   >>> MIRA LA PANTALLA DEL TV <<<' 'Yellow'
          Say '   Aparece "Permitir depuracion USB?" (Allow USB debugging?).' 'Yellow'
          Say '   Marca "Permitir siempre desde esta computadora" y pulsa Permitir / Aceptar / OK con el control.' 'Yellow'
          Say '   Esperando... (hasta 2 minutos)'
          $asked = $true; $lastAsk = Get-Date
        }
        if ($el -ge 120) { Falla 'No se acepto el permiso en el TV a tiempo.' 'Vuelve a correr la linea y, cuando salga el aviso en el TV, marca "Permitir siempre" y pulsa Permitir/OK.' }
        Start-Sleep -Seconds 3
      }
      elseif ($state -match 'offline') {
        $kind = 'offline'; Adb disconnect $st.serial | Out-Null; Start-Sleep -Seconds 2
        if ($el -ge 120) { Falla 'El TV responde pero la conexion queda "offline".' 'Apaga y prende la Depuracion ADB en el TV y vuelve a intentar.' }
      }
      else {
        if ($out -match 'refused|actively refused|10061') { $refused++ } else { $unreach++ }
        if ($refused -ge 4) { Falla "El TV en $IP contesta, pero la Depuracion ADB esta apagada (o esa IP no es el TV)." 'En el TV: Ajustes > Mi Fire TV > Opciones para desarrolladores > Depuracion ADB: ACTIVADO. Revisa tambien la IP.' }
        if ($unreach -ge 4) { Falla "No encuentro ningun TV en $IP." 'Revisa que el TV este prendido, que la IP sea correcta y que la computadora este en el MISMO WiFi que el TV.' }
        if (($refused + $unreach) -eq 1) { Say '   Buscando el TV... (TV prendido, mismo WiFi, Depuracion ADB activada)' }
        Start-Sleep -Seconds 4
      }
    }
    if ($kind -eq 'unauth') { Bien 'Permiso aceptado en el TV' }
    Bien 'Conectado'

    # ---------- 3. revision ----------
    Paso 3 'Revisando el TV (sin cambiar nada)'
    $sdkS = S getprop ro.build.version.sdk; $fos = S getprop ro.build.version.fireos
    $model = S getprop ro.product.model; $maker = S getprop ro.product.manufacturer
    $sdk = 0; if (-not [int]::TryParse($sdkS, [ref]$sdk)) { Falla 'El TV no responde a los comandos de ADB.' 'Desconecta y vuelve a correr la linea.' }
    if ((S pm path com.amazon.tv.launcher) -match 'package:') { $platform = "Fire TV (Fire OS $fos)" }
    elseif ((S pm path com.google.android.apps.tv.launcherx) -match 'package:' -or (S pm path com.google.android.tvlauncher) -match 'package:') { $platform = 'Google TV / Android TV' }
    else {
      $platform = 'Android'
      if ((S pm list features) -notmatch 'android.software.leanback|android.hardware.type.television') { Falla "El aparato en $IP no es un TV ($maker $model)." 'Revisa la IP en el TV: Ajustes > Mi Fire TV > Acerca de > Red.' }
    }
    if ($sdk -ge 30) { $apkName = 'luk-home.apk' } elseif ($sdk -ge 28) { $apkName = 'luk-home-fos7.apk' }
    elseif ($sdk -ge 25) { $apkName = 'luk-home-fos6.apk' }   # Fire OS 6 (Android 7.1)
    else { Falla "Este TV es demasiado viejo para Luk Home (Android API $sdk)." 'Luk Home necesita Fire OS 6 o mas nuevo (Fire TV Stick 4K, Fire TV Cube, Stick 2.a gen. o mas nuevos; Android 7.1 o mas nuevo).' }
    Bien "$maker $model - $platform, API $sdk -> $apkName"
    # Android 7.1-8.1: Luk Home vigila la app de enfrente con "acceso de uso". En Fire OS 6 Amazon no deja correr
    # servicios de accesibilidad instalados por fuera (A11yAuthorizer), asi que ahi solo se usa el acceso de uso.
    $useUop = $sdk -lt 28; $useAcc = -not ($useUop -and $platform -like 'Fire*')

    $free = 0
    $dfl = @((S df -k /data) -split "`n" | Where-Object { $_ -match '\S' })
    if ($dfl.Count -ge 2) { $cols = $dfl[-1] -split '\s+'; if ($cols.Count -ge 4) { [void][int]::TryParse($cols[3], [ref]$free) } }
    if ($free -gt 0 -and $free -lt 60000) { Falla "El TV casi no tiene espacio libre ($([int]($free/1024)) MB)." 'Se necesitan unos 60 MB. Borra cache de alguna app o desinstala algo que no use, y repite.' }
    if ($free -gt 0) { Bien "Espacio libre: $([int]($free/1024)) MB" }

    $st.oldSvc = S settings get secure enabled_accessibility_services
    $st.oldEn = S settings get secure accessibility_enabled
    $h = @((S cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME) -split "`n")[-1].Trim()
    $st.oldHome = if ($h -match '/') { $h } else { '' }
    $installed = @((S pm list packages) -split "`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ })
    if ($appsArg) {   # apps extra: que hay instalado y que se puede abrir (solo lectura)
      $disabled = @((S pm list packages -d) -split "`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ })
      $third = @((S pm list packages -3) -split "`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ })
      $qa = (S cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER) + "`n" + (S cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER)
      $launchable = @($qa -split "`n" | ForEach-Object { if ($_ -match '^\s*([A-Za-z0-9_.]+)/') { $Matches[1] } } | Sort-Object -Unique)
      LogQ "apps: third=$($third -join ' ') launchable=$($launchable -join ' ')"
      ResolverApps; $extraPkgs = $st.extraPkgs; $extraNames = $st.extraNames
    }
    $lukPresent = $installed -contains $PKG; $lukSha = ''; $hasDock = $false; $hasTheme = $false; $tvThemes = @(); $thPrev = @()
    $abis = S getprop ro.product.cpu.abilist; if (-not $abis) { $abis = S getprop ro.product.cpu.abi }
    # ABI principal (la que usa el sistema): Fire TV de 64 bits con Android de 32 bits dicen armeabi-v7a
    $cpuAbi = S getprop ro.product.cpu.abi; if (-not $cpuAbi) { $cpuAbi = ("$abis" -split ',')[0] }
    LogQ "abi=$cpuAbi abilist=$abis"
    if ($lukPresent) {
      $lp = ((S pm path $PKG) -split "`n")[0] -replace '^package:', ''
      $lukSha = ((S sha256sum $lp) -split '\s+')[0]   # Fire OS 6 no tiene sha256sum: vacio = se reinstala (conserva los datos)
      if ((S appops get $PKG GET_USAGE_STATS) -match 'GET_USAGE_STATS: ([a-z]+)') { $st.oldUop = $Matches[1] }
      $hasDock = (S run-as $PKG ls files/dock.txt) -match '^files/dock.txt$'
      $hasTheme = (S run-as $PKG ls files/theme.txt) -match '^files/theme.txt$'
      $tvThemes = @((S run-as $PKG ls files/themes) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -cmatch $slugRe })
      $thPrev = @((S run-as $PKG cat files/themes/.instalador.txt) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -cmatch $slugRe })
      Bien 'Luk Home ya estaba instalado (se actualiza sin perder nada)'
    }

    $bk = Join-Path $work "respaldos\$ipName-$ts"; if ($dry) { $bk = "$bk-simulacion" }
    New-Item -ItemType Directory -Force -Path $bk | Out-Null
    WriteLF (Join-Path $bk 'antes.txt') ("fecha=$ts ip=$IP modelo=$maker $model plataforma=$platform api=$sdk apk=$apkName`n" +
      "enabled_accessibility_services=$($st.oldSvc)`naccessibility_enabled=$($st.oldEn)`nhome=$($st.oldHome)`nget_usage_stats=$(if ($st.oldUop) { $st.oldUop } else { 'default' })`nluk_instalado=$lukPresent luk_sha256=$lukSha`n")
    WriteLF (Join-Path $bk 'paquetes.txt') (($installed -join "`n") + "`n")
    if ($hasDock) { WriteLF (Join-Path $bk 'dock-antes.txt') ((S run-as $PKG cat files/dock.txt) + "`n") }
    Bien 'Respaldo de la configuracion guardado en la computadora'
    LogQ "backup=$bk old_svc=$($st.oldSvc) old_en=$($st.oldEn) old_home=$($st.oldHome)"

    $keep = @(); $removed = @()
    foreach ($s in ("$($st.oldSvc)" -split ':')) {
      if (-not $s -or $s -eq 'null') { continue }
      $spkg = ($s -split '/')[0]
      if ($spkg -eq $PKG) { continue }
      if ($LAUNCHER_SVC_PKGS -contains $spkg -or $spkg -match 'launcher|projengmenu' -or ($st.oldHome -and $spkg -eq ($st.oldHome -split '/')[0])) { $removed += $s }
      else { $keep += $s }
    }
    $newSvc = (@($keep) + $SERVICE) -join ':'
    if (-not $useAcc) { $newSvc = $st.oldSvc; $removed = @() }   # Fire OS 6: la accesibilidad no se toca
    if ($removed.Count) { Aviso "Otro launcher controlaba el boton Inicio: $($removed -join ' '). Se reemplaza por Luk Home (la app NO se desinstala)." }
    $setHome = $st.oldHome -and -not ((@($STOCK_HOMES) + $PKG) -contains ($st.oldHome -split '/')[0])

    # ---------- 4. instalar ----------
    Paso 4 'Instalando Luk Home'
    $apk = Join-Path $bundle "apks\$apkName"; $want = Sha256File $apk
    if ($lukPresent -and $lukSha -eq $want) { Bien 'Ya tiene la version mas nueva' }
    elseif ($dry) { Sim "adb install -r -g $apkName ($([int]((Get-Item $apk).Length/1024)) KB)" }
    else {
      if ($platform -like 'Google*') { Say '   (Si en el TV sale un aviso de Play Protect, elige "Instalar de todas formas".)' }
      $out = A install -r -g $apk; LogQ "install: $out"
      if ($out -match 'Success') { Bien 'Luk Home instalado' }
      elseif ($out -match 'UPDATE_INCOMPATIBLE|SIGNATURES') { Falla 'Este TV ya tiene otro Luk Home con una firma distinta.' 'Desinstalalo desde Ajustes > Aplicaciones > Luk Home y vuelve a correr la linea.' }
      elseif ($out -match 'OLDER_SDK') { Falla "Esta version de Luk Home no es compatible con este TV (API $sdk)." }
      elseif ($out -match 'INSUFFICIENT_STORAGE') { Falla 'El TV no tiene espacio para instalar Luk Home.' 'Libera espacio y vuelve a correr la linea.' }
      else { Falla 'La instalacion de Luk Home fallo.' ("Mensaje del TV: " + (($out -split "`n")[-1])) }
    }

    # ---------- 5. archivos ----------
    Paso 5 'Copiando temas, iconos, dock y PIN'
    $stRoot = Join-Path ([IO.Path]::GetTempPath()) ("lukstage-" + [guid]::NewGuid().ToString('N'))
    $st.stage = Join-Path $stRoot 'lukhome'
    New-Item -ItemType Directory -Force -Path (Join-Path $st.stage 'tiles'), (Join-Path $st.stage 'themes') | Out-Null
    foreach ($t in $sel) { Copy-Item -Recurse -Path (Join-Path $bundle "themes\$t") -Destination (Join-Path $st.stage "themes\$t") }
    WriteLF (Join-Path $st.stage 'themes\order.txt') (($sel | ForEach-Object { "$_`n" }) -join '')
    # Lista de temas que puso el instalador (files/themes/.instalador.txt en el TV). Con una LISTA de temas,
    # se quitan del TV solo los temas que puso el instalador y ya no estan en la lista; nunca otros archivos.
    $thRm = @(); $thKeep = @($sel)
    if ($thList) {
      foreach ($t in (@($thBuiltin) + @($thCustom) + @($thPrev))) { if ($sel -notcontains $t -and $thRm -notcontains $t -and $tvThemes -contains $t) { $thRm += $t } }
    } else {
      foreach ($t in $thPrev) { if ($thKeep -notcontains $t -and $tvThemes -contains $t) { $thKeep += $t } }
    }
    # Temas renombrados: si el TV tiene la carpeta vieja, se borra (el tema nuevo ya va en la lista, o no se quiere)
    # y el registro .instalador.txt no la guarda mas.
    $thMig = @(); $thRmMsg = @($thRm | Where-Object { -not $TH_RENAMED.ContainsKey($_) })
    foreach ($o in $TH_RENAMED.Keys) {
      if ($tvThemes -contains $o) {
        if ($thRm -notcontains $o) { $thRm += $o }
        if ($sel -contains $TH_RENAMED[$o]) { $thMig += "$o -> $($TH_RENAMED[$o])" } else { $thRmMsg += $o }
      }
    }
    $thKeep = @($thKeep | Where-Object { -not $TH_RENAMED.ContainsKey($_) })
    WriteLF (Join-Path $st.stage 'themes\installed.txt') (($thKeep | ForEach-Object { "$_`n" }) -join '')
    if ($thRm.Count) { WriteLF (Join-Path $st.stage 'themes\remove.txt') (($thRm | ForEach-Object { "$_`n" }) -join '') }
    Copy-Item -Path (Join-Path $bundle 'tv-apply.sh') -Destination $st.stage
    $hasLogo = Test-Path (Join-Path $bundle 'logo.png')
    if ($hasLogo) { Copy-Item -Path (Join-Path $bundle 'logo.png') -Destination $st.stage }
    WriteLF (Join-Path $st.stage 'rotate.txt') "20`n"
    $ntile = 0
    foreach ($t in Get-ChildItem -Path (Join-Path $bundle 'tiles') -Filter '*.png') {
      $p = $t.BaseName
      if ($installed -contains $p) { Copy-Item $t.FullName, (Join-Path $bundle "tiles\$p.txt") -Destination (Join-Path $st.stage 'tiles'); $ntile++ }
    }
    $wroteDock = $false; $dockMode = ''
    if ($hasDock -and -not $newDock -and $extraPkgs.Count -eq 0) {
      Bien 'El dock ya existia: se deja como esta (para reescribirlo: $NUEVODOCK=1)'
      if ($appsArg) { Aviso 'Ninguna de las apps extra se pudo poner en el inicio (ver avisos de arriba)' }
    }
    elseif ($hasDock -and -not $newDock) {
      # $APPS con un dock que ya existe: se deja el dock del TV tal cual y se agregan al final las que falten
      $prevTxt = ([IO.File]::ReadAllText((Join-Path $bk 'dock-antes.txt')) -replace "`r", '').TrimEnd("`n")
      $dock = @($prevTxt -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
      $added = @(); $already = @()
      foreach ($p in $extraPkgs) { if ($dock -contains $p) { $already += (AppLabel $p) } else { $dock += $p; $added += (AppLabel $p); $prevTxt += "`n$p" } }
      if ($added.Count) {
        WriteLF (Join-Path $st.stage 'dock.txt') ($prevTxt + "`n"); $wroteDock = $true; $dockMode = 'extra'
        Bien ("Dock: se deja el que tenia el TV y se agregan al final: " + ($added -join ', '))
      } else { Bien 'Dock: se deja como esta' }
      if ($already.Count) { Bien ("Ya estaban en el inicio: " + ($already -join ', ')) }
    }
    else {
      $dock = @(); $missing = @()
      foreach ($p in $DOCK_APPS) {
        $nf = Join-Path $bundle "tiles\$p.txt"
        $name = if (Test-Path $nf) { [IO.File]::ReadAllText($nf).Trim() } else { $p }
        if ($installed -contains $p) { $dock += $p } else { $missing += $name }
      }
      $added = @()
      foreach ($p in $extraPkgs) { if ($DOCK_APPS -notcontains $p -and $dock -notcontains $p) { $dock += $p; $added += (AppLabel $p) } }
      WriteLF (Join-Path $st.stage 'dock.txt') ("# Apps del inicio, en orden`n" + (($dock | ForEach-Object { "$_`n" }) -join ''))
      $wroteDock = $true; $dockMode = 'nuevo'
      Bien "Dock: $($dock.Count) app(s) en el inicio; las demas quedan en 'Otras apps'"
      if ($added.Count) { Bien ("Apps extra en el inicio: " + ($added -join ', ')) }
      if ($missing.Count) {
        if ($noApps) { Aviso ("No estan instaladas (no van al dock; `$SINAPPS=1): " + ($missing -join ', ')) }
        else { Bien ("Todavia no estan en el TV: " + ($missing -join ', ') + " (se instalan en el paso 8 y se agregan al dock)") }
      }
    }
    if ($wroteDock -and $dock.Count -gt 20) { Aviso "El inicio muestra maximo 20 apps; las que pasen de 20 quedan en 'Otras apps'" }
    $wroteTheme = $false; $curTheme = ''
    if ($hasTheme) { $curTheme = ((S run-as $PKG cat files/theme.txt) -split "`n")[0].Trim() }
    if ($thMig.Count) { Bien ("Tema renombrado en el TV: " + ($thMig -join ', ') + " (se reemplaza la carpeta vieja)") }
    $curNew = if ($curTheme -and $TH_RENAMED.ContainsKey($curTheme)) { $TH_RENAMED[$curTheme] } else { '' }
    if (-not $themeGiven -and $hasTheme -and $curNew -and $sel -contains $curNew) {
      WriteLF (Join-Path $st.stage 'theme.txt') "$curNew`n"; $wroteTheme = $true
      $nf = Join-Path $bundle "themes\$curNew\name.txt"
      Bien ("Se mantiene el tema que ya tenia el TV, con su nombre nuevo: " + $(if (Test-Path $nf) { ([IO.File]::ReadAllText($nf) -split "`n")[0].Trim() } else { $curNew }))
    }
    elseif ($thMode) {
      WriteLF (Join-Path $st.stage 'theme.txt') "@$thMode`n"; $wroteTheme = $true
      if ($thMode -eq 'aleatorio') { Bien 'Temas: Aleatorio (fotos de todos los temas, mezcladas)' }
      else { Bien 'Temas: Rotar temas (un tema completo cada hora, en el orden de la lista)' }
    }
    elseif ($themeGiven -or -not $hasTheme -or $thRm -contains $curTheme) {
      WriteLF (Join-Path $st.stage 'theme.txt') "$THEME`n"; $wroteTheme = $true
      $nf = Join-Path $bundle "themes\$THEME\name.txt"
      Bien ("Tema inicial: " + $(if (Test-Path $nf) { ([IO.File]::ReadAllText($nf) -split "`n")[0].Trim() } else { $THEME }))
    } else { Bien 'Se mantiene el tema que ya tenia el TV' }
    if ($thRmMsg.Count) { Bien ("Se quitan del TV los temas que ya no van: " + ($thRmMsg -join ', ') + " (solo temas puestos por el instalador)") }
    if ($PIN) { WriteLF (Join-Path $st.stage 'pin.txt') "$pinHash`n" }
    if ($btn -eq 'on') { WriteLF (Join-Path $st.stage 'block-app-buttons.txt') "on`n"; Bien 'Botones de apps del control: bloqueados (para volver: $BOTONES=''normal'')' }
    elseif ($btn -eq 'off') { WriteLF (Join-Path $st.stage 'block-app-buttons.txt') "off`n"; Bien 'Botones de apps del control: normales' }
    if ($estilo -eq 'colores') { WriteLF (Join-Path $st.stage 'dock-style.txt') "colores`n"; Bien 'Estilo del inicio: Colores (se cambia en el TV: boton de Temas > Estilo)' }
    elseif ($estilo -eq 'oscuro') { WriteLF (Join-Path $st.stage 'dock-style.txt') "oscuro`n"; Bien 'Estilo del inicio: Oscuro' }
    elseif ($estiloBad) { Aviso "Estilo desconocido '$estiloBad' (usa `$ESTILO='oscuro' o 'colores'); el TV se queda con el que tenga" }
    if ($city) {
      WriteLF (Join-Path $st.stage 'weather.txt') "# Luk Home: ciudad del tiempo (auto = por internet). Puesta por el instalador.`n$city`n"
      if ($city -eq 'auto') { Bien 'Tiempo: ciudad automatica (por internet)' } else { Bien "Tiempo: ciudad fija '$city' (se cambia en el TV con 'Cambiar ciudad')" }
    }
    $njpg = @(Get-ChildItem -Recurse -File -Path (Join-Path $st.stage 'themes') | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' }).Count
    $kb = [int]((Get-ChildItem -Recurse -File -Path $st.stage | Measure-Object -Sum Length).Sum / 1024)
    LogQ "stage=$($st.stage) themes=$($sel.Count) jpg=$njpg tiles=$ntile kb=$kb"
    if ($dry) {
      Sim "adb push lukhome\ -> /data/local/tmp/ ($($sel.Count) temas, $njpg fotos, $ntile iconos, $kb KB)"
      $w = 'themes/, tiles/, rotate.txt'; if ($hasLogo) { $w += ', logo.png' }; if ($wroteDock) { $w += ', dock.txt' }; if ($wroteTheme) { $w += ', theme.txt' }; if ($city) { $w += ', weather.txt' }; if ($PIN) { $w += ', pin.txt' }; if ($btn) { $w += ', block-app-buttons.txt' }; if ($estilo) { $w += ', dock-style.txt' }
      Sim "adb shell sh /data/local/tmp/lukhome/tv-apply.sh  (escribe: $w)"
      if ($wroteDock) { Sim ("dock.txt = " + ($dock -join ' ')) }
      $rmTxt = ''; if ($thRm.Count) { $rmTxt = "   (se borrarian del TV: $($thRm -join ', '))" }
      Sim ("temas = " + ($sel -join ', ') + $rmTxt)
    }
    else {
      A shell rm -rf /data/local/tmp/lukhome | Out-Null
      Say "   Copiando $($sel.Count) temas ($([int]($kb/1024)) MB)..."
      $out = A push $st.stage /data/local/tmp/; LogQ "push: $out"
      if ($out -match 'error|failed|No space') { Falla 'No se pudieron copiar los archivos al TV.' (($out -split "`n")[-1]) }
      $out = A shell sh /data/local/tmp/lukhome/tv-apply.sh; LogQ "apply: $out"
      if ($out -notmatch 'LUK_APPLY_OK') {
        A shell rm -rf /data/local/tmp/lukhome | Out-Null
        Falla 'No se pudieron guardar los archivos dentro de Luk Home.' ((($out -split "`n") | Where-Object { $_ -match 'LUK_APPLY_FAIL' } | Select-Object -First 1))
      }
      if ($out -match 'REMOVED ([1-9][0-9]*)') { Bien "Temas quitados: $($Matches[1])" }
      $extra = ''; if ($PIN) { $extra = ', PIN guardado' }
      if ($hasLogo) { $extra = ', logo' + $extra }
      Bien "$($sel.Count) temas, $ntile iconos, rotacion 20 s$extra"
    }
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stRoot; $st.stage = ''

    # ---------- 6. boton Inicio ----------
    Paso 6 'Haciendo que el boton Inicio abra Luk Home'
    if ($useUop) {
      if ($st.oldUop -eq 'allow') { Bien 'Acceso de uso ya estaba permitido' }
      elseif ($dry) { Sim "appops set $PKG GET_USAGE_STATS allow   (antes: $(if ($st.oldUop) { $st.oldUop } else { 'default' }))" }
      else { $st.uopChanged = $true; LogQ (A shell appops set $PKG GET_USAGE_STATS allow); Bien 'Acceso de uso permitido (asi Luk Home ve cuando aparece el inicio de Amazon)' }
    }
    if (-not $useAcc) { Bien 'Fire OS 6: no usa accesibilidad (Amazon no la permite en apps instaladas por fuera)' }
    elseif ($st.oldSvc -eq $newSvc -and $st.oldEn -eq '1') { Bien 'Ya estaba activado' }
    elseif ($dry) {
      Sim "settings put secure enabled_accessibility_services $newSvc   (antes: $($st.oldSvc))"
      Sim "settings put secure accessibility_enabled 1   (antes: $($st.oldEn))"
    }
    else {
      $st.accChanged = $true
      LogQ (A shell "settings put secure enabled_accessibility_services '$newSvc'")
      LogQ (A shell settings put secure accessibility_enabled 1)
      Bien 'Activado'
    }
    if ($setHome) {
      if ($dry) { Sim "cmd package set-home-activity $PKG/.HomeActivity   (antes: $($st.oldHome))" }
      else { $st.homeChanged = $true; LogQ (A shell cmd package set-home-activity "$PKG/.HomeActivity"); Bien "Luk Home es ahora la pantalla de inicio (antes: $(($st.oldHome -split '/')[0]))" }
    }

    # ---------- 7. comprobacion ----------
    Paso 7 'Comprobando'
    if ($dry) {
      Sim 'abrir Luk Home (am start --ez reload true) y pulsar Inicio para comprobar'
      $st.success = $true
      ActualizarApps
      Extras
      Say ''
      Say '  SIMULACION TERMINADA SIN ERRORES - no se cambio nada en el TV.' 'Green'
      Say "  Apps: $($st.updSum)"
      if ($st.raSum) { Say "  RetroArch: $($st.raSum)" }
      if ($st.kodiSum) { Say "  Kodi: $($st.kodiSum)" }
      Say "  Respaldo de lectura: $bk"
      Say "  Registro: $($st.log)"
      return
    }
    if ($useAcc) {
      $vSvc = S settings get secure enabled_accessibility_services; $vEn = S settings get secure accessibility_enabled
      if ((":" + $vSvc + ":") -notlike "*:$($SERVICE):*") { Falla 'El TV no acepto el ajuste del boton Inicio.' "Valor leido: $vSvc" }
      if ($vEn -ne '1') { Falla "El TV no acepto activar la accesibilidad (accessibility_enabled=$vEn)." }
    }
    if ($useUop) {
      $vUop = S appops get $PKG GET_USAGE_STATS
      if ($vUop -notmatch 'GET_USAGE_STATS: allow') { Falla 'El TV no acepto el acceso de uso para Luk Home.' "Valor leido: $vUop" }
    }
    if ((S pm path $PKG) -notmatch 'package:') { Falla 'Luk Home no aparece instalado.' }
    $vTheme = ((S run-as $PKG cat files/theme.txt) -split "`n")[0].Trim(); if (-not $vTheme -or $vTheme.StartsWith('@')) { $vTheme = $THEME }
    $vJpg = @((S run-as $PKG ls "files/themes/$vTheme") -split "`n" | Where-Object { $_ -match '\.(jpe?g|png|webp)$' }).Count
    if ($vJpg -lt 1) { Falla 'Los temas no quedaron guardados en el TV.' }
    if ($PIN) { if (((S run-as $PKG cat files/pin.txt) -split "`n")[0].Trim() -ne $pinHash) { Falla 'El PIN no quedo guardado bien.' } }
    Bien "Ajustes, temas ($vJpg fotos en '$vTheme') y PIN comprobados"
    LogQ (A shell am start -n "$PKG/.HomeActivity" --ez reload true)
    Start-Sleep -Seconds 2
    LogQ (A shell input keyevent KEYCODE_HOME)
    $top = ''
    for ($i = 0; $i -lt 8; $i++) {
      Start-Sleep -Milliseconds 1500
      $top = ((S dumpsys activity activities) -split "`n" | Where-Object { $_ -match 'mResumedActivity|topResumedActivity' } | Select-Object -First 1)
      if ("$top" -match [regex]::Escape($PKG)) { break }
    }
    if ("$top" -match [regex]::Escape($PKG)) { Bien 'El boton Inicio abre Luk Home' }
    else { Aviso 'El TV todavia no muestra Luk Home. Pulsa el boton Inicio (la casita) del control; en Fire TV viejos tarda unos 5 segundos.' }
    $st.success = $true
    $st.accChanged = $false; $st.homeChanged = $false; $st.uopChanged = $false   # comprobado: se queda aunque falle el paso 8
    ActualizarApps
    Extras
    Say ''
    Say '  ##      ##  #######  ########  ######  ' 'Green'
    Say '  ##      ##  ##          ##    ##    ## ' 'Green'
    Say '  ##      ##  #######     ##    ##    ## ' 'Green'
    Say '  ##      ##       ##     ##    ##    ## ' 'Green'
    Say '  ######  ##  #######     ##     ######  ' 'Green'
    Say ''
    Say '  LISTO! Luk Home quedo instalado en el TV.' 'Green'
    Say '  - Boton "Temas" (arriba a la derecha) para cambiar el fondo.'
    Say '  - Boton del tiempo (arriba a la derecha): temperatura, pronostico y "Cambiar ciudad".'
    Say '  - Ajustes queda protegido con PIN.'
    Say "  - Apps: $($st.updSum)"
    if ($st.raSum) { Say "  - RetroArch: $($st.raSum) (juegos en /sdcard/ROMs o en una memoria USB; sin ROMs ni BIOS)" }
    if ($st.kodiSum) { Say "  - Kodi: $($st.kodiSum)" }
    Say '  - Ya puedes cerrar esta ventana.'
    Say ''
    Say "  (Respaldo: $bk)"
  }
  catch {
    $msg = "$($_.Exception.Message)"
    if ($msg -like 'LUKFAIL|*') { $parts = $msg -split '\|', 3; $title = $parts[1]; $hint = $parts[2] }
    else { $title = 'Error inesperado.'; $hint = $msg; LogQ ($_ | Out-String) }
    Say ''
    Say '  X  NO SE PUDO TERMINAR' 'Red'
    Say "  $title" 'Red'
    if ($hint) { Say "  $hint" }
    try { RestoreAcc } catch { LogQ "restore failed: $_" }
    if ($st.stage) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Split-Path $st.stage -Parent) }
    Say ''
    Say "  Detalle tecnico guardado en: $($st.log)"
    Say '  Puedes volver a pegar la misma linea cuando este corregido; es seguro repetirla.'
  }
  finally {
    if (-not $st.success) { try { RestoreAcc } catch { } }
  }
} $IP $PIN $THEME $DRYRUN $NUEVODOCK $LUK_BUNDLE_URL $LUK_ADB $LUK_HOME_DIR $NOUPDATE $CIUDAD $APPS $BOTONES $ESTILO $SINAPPS $RETROARCH $KODI $KODIREEMPLAZAR
