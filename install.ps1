# Instalador de Luk Home para clientes - Windows 10/11 (PowerShell 5.1 o 7), sin administrador.
#
#   $IP='192.168.1.50'; $PIN='1234'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
#
# Variables opcionales (antes de irm):  $THEME='mar'   $DRYRUN=1 (simulacion, no escribe en el TV)   $NUEVODOCK=1
# PIN: 4 numeros, o 'sinpin' para no poner PIN.
# Solo modo "launcher": no borra, no desinstala y no cambia ninguna app del cliente.
# Pruebas: $LUK_BUNDLE_URL (zip del repo), $LUK_ADB (otro adb.exe), $LUK_HOME_DIR (carpeta de trabajo).
# (Este archivo es solo ASCII a proposito: asi se lee igual en cualquier consola de Windows.)

& {
  param($IP, $PIN, $THEME, $DRYRUN, $NUEVODOCK, $BURL, $ADBOVR, $HOMEDIR)

  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  $REPO_ZIP = 'https://github.com/coplic/luk-home-installer/archive/refs/heads/main.zip'
  $PKG = 'com.ivantrj.glasslauncher'
  $SERVICE = "$PKG/$PKG.HomeButtonService"
  $DOCK_APPS = @('com.stremio.one', 'com.nst.iptvsmarterstvbox', 'io.gh.reisxd.tizentube.cobalt')
  $STOCK_HOMES = @('com.amazon.tv.launcher', 'com.google.android.apps.tv.launcherx', 'com.google.android.tvlauncher', 'com.android.tv.launcher', 'android')
  $LAUNCHER_SVC_PKGS = @('com.spocky.projengmenu', 'com.wolf.firelauncher', 'com.wolf.firelaunchermanager', 'com.lauritz.homebutton', 'com.appgenz.launchermanager')

  # Estado compartido (hashtable: las funciones internas lo modifican por referencia)
  $st = @{ adb = ''; serial = ''; accChanged = $false; homeChanged = $false; uopChanged = $false; success = $false
           oldSvc = ''; oldEn = ''; oldHome = ''; oldUop = ''; log = ''; stage = '' }

  $IP = "$IP".Trim(); $PIN = "$PIN".Trim(); $THEME = "$THEME".Trim()
  $themeGiven = $THEME -ne ''
  if (-not $themeGiven) { $THEME = 'paisajes' }
  $dry = [bool]$DRYRUN -and "$DRYRUN" -ne '0'
  $newDock = [bool]$NUEVODOCK -and "$NUEVODOCK" -ne '0'

  $work = if ($HOMEDIR) { "$HOMEDIR" } else { Join-Path $env:LOCALAPPDATA 'LukHome' }
  New-Item -ItemType Directory -Force -Path (Join-Path $work 'logs') | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $ipName = if ($IP) { ($IP -split ':')[0] } else { 'sin-ip' }
  $st.log = Join-Path $work "logs\instalacion-$ipName-$ts.log"
  Set-Content -Path $st.log -Value "" -Encoding ASCII

  function LogQ([string]$m) { Add-Content -Path $st.log -Value $m -Encoding UTF8 }
  function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c; LogQ $m }
  function Paso([int]$n, [string]$m) { Say ''; Say "[$n/7] $m" 'Cyan' }
  function Bien([string]$m) { Say "   OK  $m" 'Green' }
  function Aviso([string]$m) { Say "   !   $m" 'Yellow' }
  function Sim([string]$m) { Say "   [simulacion] $m" 'Yellow' }
  function Falla([string]$m, [string]$hint = '') { throw "LUKFAIL|$m|$hint" }

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
    LogQ "ip=$IP theme=$THEME dry=$dry new_dock=$newDock pin_set=$([bool]$PIN) ps=$($PSVersionTable.PSVersion) os=$([Environment]::OSVersion.VersionString)"

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
    $order = @(Get-Content (Join-Path $bundle 'themes\order.txt') | Where-Object { $_ -ne '' })
    Bien "Paquete listo ($($order.Count) temas)"
    if ($order -notcontains $THEME) { Aviso "El tema '$THEME' no existe; uso 'paisajes'. Temas: $($order -join ' ')"; $THEME = 'paisajes'; $themeGiven = $true }

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
    $lukPresent = $installed -contains $PKG; $lukSha = ''; $hasDock = $false; $hasTheme = $false
    if ($lukPresent) {
      $lp = ((S pm path $PKG) -split "`n")[0] -replace '^package:', ''
      $lukSha = ((S sha256sum $lp) -split '\s+')[0]   # Fire OS 6 no tiene sha256sum: vacio = se reinstala (conserva los datos)
      if ((S appops get $PKG GET_USAGE_STATS) -match 'GET_USAGE_STATS: ([a-z]+)') { $st.oldUop = $Matches[1] }
      $hasDock = (S run-as $PKG ls files/dock.txt) -match '^files/dock.txt$'
      $hasTheme = (S run-as $PKG ls files/theme.txt) -match '^files/theme.txt$'
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
    New-Item -ItemType Directory -Force -Path (Join-Path $st.stage 'tiles') | Out-Null
    Copy-Item -Recurse -Path (Join-Path $bundle 'themes') -Destination (Join-Path $st.stage 'themes')
    Copy-Item -Path (Join-Path $bundle 'tv-apply.sh') -Destination $st.stage
    $hasLogo = Test-Path (Join-Path $bundle 'logo.png')
    if ($hasLogo) { Copy-Item -Path (Join-Path $bundle 'logo.png') -Destination $st.stage }
    WriteLF (Join-Path $st.stage 'rotate.txt') "20`n"
    $ntile = 0
    foreach ($t in Get-ChildItem -Path (Join-Path $bundle 'tiles') -Filter '*.png') {
      $p = $t.BaseName
      if ($installed -contains $p) { Copy-Item $t.FullName, (Join-Path $bundle "tiles\$p.txt") -Destination (Join-Path $st.stage 'tiles'); $ntile++ }
    }
    $wroteDock = $false
    if ($hasDock -and -not $newDock) { Bien 'El dock ya existia: se deja como esta (para reescribirlo: $NUEVODOCK=1)' }
    else {
      $dock = @(); $missing = @()
      foreach ($p in $DOCK_APPS) {
        $nf = Join-Path $bundle "tiles\$p.txt"
        $name = if (Test-Path $nf) { [IO.File]::ReadAllText($nf).Trim() } else { $p }
        if ($installed -contains $p) { $dock += $p } else { $missing += $name }
      }
      WriteLF (Join-Path $st.stage 'dock.txt') ("# Apps del inicio, en orden`n" + (($dock | ForEach-Object { "$_`n" }) -join ''))
      $wroteDock = $true
      Bien "Dock: $($dock.Count) app(s) en el inicio; las demas quedan en 'Otras apps'"
      if ($missing.Count) { Aviso ("No estan instaladas (no van al dock): " + ($missing -join ', ')) }
    }
    $wroteTheme = $false
    if ($themeGiven -or -not $hasTheme) {
      WriteLF (Join-Path $st.stage 'theme.txt') "$THEME`n"; $wroteTheme = $true
      Bien ("Tema inicial: " + [IO.File]::ReadAllText((Join-Path $bundle "themes\$THEME\name.txt")).Trim())
    } else { Bien 'Se mantiene el tema que ya tenia el TV' }
    if ($PIN) { WriteLF (Join-Path $st.stage 'pin.txt') "$pinHash`n" }
    $njpg = @(Get-ChildItem -Recurse -Path (Join-Path $st.stage 'themes') -Filter '*.jpg').Count
    $kb = [int]((Get-ChildItem -Recurse -File -Path $st.stage | Measure-Object -Sum Length).Sum / 1024)
    LogQ "stage=$($st.stage) themes=$($order.Count) jpg=$njpg tiles=$ntile kb=$kb"
    if ($dry) {
      Sim "adb push lukhome\ -> /data/local/tmp/ ($($order.Count) temas, $njpg fotos, $ntile iconos, $kb KB)"
      $w = 'themes/, tiles/, rotate.txt'; if ($hasLogo) { $w += ', logo.png' }; if ($wroteDock) { $w += ', dock.txt' }; if ($wroteTheme) { $w += ', theme.txt' }; if ($PIN) { $w += ', pin.txt' }
      Sim "adb shell sh /data/local/tmp/lukhome/tv-apply.sh  (escribe: $w)"
      if ($wroteDock) { Sim ("dock.txt = " + ($dock -join ' ')) }
    }
    else {
      A shell rm -rf /data/local/tmp/lukhome | Out-Null
      Say "   Copiando $($order.Count) temas ($([int]($kb/1024)) MB)..."
      $out = A push $st.stage /data/local/tmp/; LogQ "push: $out"
      if ($out -match 'error|failed|No space') { Falla 'No se pudieron copiar los archivos al TV.' (($out -split "`n")[-1]) }
      $out = A shell sh /data/local/tmp/lukhome/tv-apply.sh; LogQ "apply: $out"
      if ($out -notmatch 'LUK_APPLY_OK') {
        A shell rm -rf /data/local/tmp/lukhome | Out-Null
        Falla 'No se pudieron guardar los archivos dentro de Luk Home.' ((($out -split "`n") | Where-Object { $_ -match 'LUK_APPLY_FAIL' } | Select-Object -First 1))
      }
      $extra = ''; if ($PIN) { $extra = ', PIN guardado' }
      if ($hasLogo) { $extra = ', logo' + $extra }
      Bien "$($order.Count) temas, $ntile iconos, rotacion 20 s$extra"
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
      Say ''
      Say '  SIMULACION TERMINADA SIN ERRORES - no se cambio nada en el TV.' 'Green'
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
    $vTheme = ((S run-as $PKG cat files/theme.txt) -split "`n")[0].Trim(); if (-not $vTheme) { $vTheme = $THEME }
    $vJpg = @((S run-as $PKG ls "files/themes/$vTheme") -split "`n" | Where-Object { $_ -match '\.jpg$' }).Count
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
    Say ''
    Say '  ##      ##  #######  ########  ######  ' 'Green'
    Say '  ##      ##  ##          ##    ##    ## ' 'Green'
    Say '  ##      ##  #######     ##    ##    ## ' 'Green'
    Say '  ##      ##       ##     ##    ##    ## ' 'Green'
    Say '  ######  ##  #######     ##     ######  ' 'Green'
    Say ''
    Say '  LISTO! Luk Home quedo instalado en el TV.' 'Green'
    Say '  - Boton "Temas" (arriba a la derecha) para cambiar el fondo.'
    Say '  - Ajustes queda protegido con PIN.'
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
} $IP $PIN $THEME $DRYRUN $NUEVODOCK $LUK_BUNDLE_URL $LUK_ADB $LUK_HOME_DIR
