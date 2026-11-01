# Instalador de Luk Home para clientes - Windows 10/11 (PowerShell 5.1 o 7), sin administrador.
#
#   $IP='192.168.1.50'; $PIN='1234'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
#
# Variables opcionales (antes de irm):  $THEME='mar'   $DRYRUN=1 (simulacion, no escribe en el TV)   $NUEVODOCK=1
#   $THEME='autos,mar,halloween-terror'  lista: solo esos temas van al TV, el primero es el inicial ('todos' = todos)
#   $NOUPDATE=1  no revisar si hay version nueva de Stremio / IPTV Smarters / TizenTube
# PIN: 4 numeros, o 'sinpin' para no poner PIN.
# Solo modo "launcher": no borra ni desinstala ninguna app del cliente. Lo unico que toca de sus apps es
# actualizar (adb install -r, conserva datos y sesiones) Stremio / IPTV Smarters / TizenTube si ya estan
# instaladas y hay una version oficial mas nueva con la misma firma.
# Pruebas: $LUK_BUNDLE_URL (zip del repo), $LUK_ADB (otro adb.exe), $LUK_HOME_DIR (carpeta de trabajo).
# (Este archivo es solo ASCII a proposito: asi se lee igual en cualquier consola de Windows.)

& {
  param($IP, $PIN, $THEME, $DRYRUN, $NUEVODOCK, $BURL, $ADBOVR, $HOMEDIR, $NOUPDATE)

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
           oldSvc = ''; oldEn = ''; oldHome = ''; oldUop = ''; log = ''; stage = ''; updSum = 'no se revisaron' }

  $IP = "$IP".Trim(); $PIN = "$PIN".Trim(); $THEME = "$THEME".Trim()
  $themeGiven = $THEME -ne ''
  $dry = [bool]$DRYRUN -and "$DRYRUN" -ne '0'
  $newDock = [bool]$NUEVODOCK -and "$NUEVODOCK" -ne '0'
  $noUpd = [bool]$NOUPDATE -and "$NOUPDATE" -ne '0'

  $work = if ($HOMEDIR) { "$HOMEDIR" } else { Join-Path $env:LOCALAPPDATA 'LukHome' }
  New-Item -ItemType Directory -Force -Path (Join-Path $work 'logs') | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $ipName = if ($IP) { ($IP -split ':')[0] } else { 'sin-ip' }
  $st.log = Join-Path $work "logs\instalacion-$ipName-$ts.log"
  Set-Content -Path $st.log -Value "" -Encoding ASCII

  function LogQ([string]$m) { Add-Content -Path $st.log -Value $m -Encoding UTF8 }
  function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c; LogQ $m }
  function Paso([int]$n, [string]$m) { Say ''; Say "[$n/8] $m" 'Cyan' }
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

  # ---------- actualizar apps del cliente (paso 8) ----------
  # Solo Stremio, IPTV Smarters y TizenTube, solo si ya estan instaladas, solo a una version oficial MAS NUEVA
  # (versionCode mayor) y con "adb install -r" (conserva datos y sesiones). Nunca instala, desinstala, baja de
  # version ni borra datos. Si algo falla, avisa y sigue. Las descargas se guardan en <carpeta>\apps\.
  $KNOWN_VC = @{ 'iptv-smarters-4.0.6.apk' = 106 }
  $KNOWN_SHA = @{ 'iptv-smarters-4.0.6.apk' = '07768dd9b805d129a84698e4d3163d1fbb2340c80ba118dbaa7bbcfe4cf5e01b' }
  $SMARTERS_PIN = 'iptv-smarters-4.0.6.apk'   # si www.iptvsmarters.com no contesta
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
  function RemoteInfo([string]$app, [string]$abi) {   # ultima version oficial
    $r = @{ url = ''; alt = ''; file = ''; vn = ''; vc = $null; sha = '' }
    if ($app -eq 'stremio') {   # www.stremio.com/downloads: solo APK de Android TV, sin rc/beta
      $page = GetPage 'https://www.stremio.com/downloads'
      $best = [long]0
      foreach ($m in [regex]::Matches($page, 'https://dl\.strem\.io/android/v[0-9][A-Za-z0-9._-]*-androidTV/com\.stremio\.one-([0-9.]+)-([0-9]+)-' + [regex]::Escape($abi) + '\.apk')) {
        $c = [long]$m.Groups[2].Value
        if ($c -gt $best) { $best = $c; $r.url = $m.Value; $r.file = ($m.Value -split '/')[-1]; $r.vn = $m.Groups[1].Value; $r.vc = $c }
      }
    }
    elseif ($app -eq 'tizentube') {   # GitHub reisxd/TizenTubeCobalt (ultima release; trae el sha256)
      $asset = if ($abi -eq 'arm64-v8a') { 'cobalt-arm64.apk' } elseif ($abi -eq 'armeabi-v7a') { 'cobalt-arm.apk' } else { '' }
      if (-not $asset) { return $null }
      $tag = ''
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
    elseif ($app -eq 'smarters') {   # www.iptvsmarters.com ("Download Latest Version"); copia oficial en www.smartersott.app
      $page = GetPage 'https://www.iptvsmarters.com/'
      foreach ($m in [regex]::Matches($page, 'iptv-smarters-[0-9][0-9.]*[0-9]\.apk')) {
        if (-not $r.file -or (VerGt ($m.Value -replace '^iptv-smarters-|\.apk$', '') ($r.file -replace '^iptv-smarters-|\.apk$', ''))) { $r.file = $m.Value }
      }
      if (-not $r.file) { $r.file = $SMARTERS_PIN }
      $r.url = "https://www.iptvsmarters.com/$($r.file)"; $r.alt = "https://www.smartersott.app/$($r.file)"
      $r.vn = $r.file -replace '^iptv-smarters-|\.apk$', ''
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
    if ($installed -notcontains $p) { LogQ "upd ${p}: no instalada"; return }
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
      if ($nv.vc -eq $avc) { Say "   ^   $nm actualizada $ivn -> $($nv.vn)" 'Green'; UpdAdd "$nm $ivn -> $($nv.vn)" }
      else { Aviso "${nm}: el TV acepto la actualizacion pero sigue mostrando la $($nv.vn); revisa la app"; UpdAdd "$nm $($nv.vn) (revisar)" }
    }
    elseif ($out -match 'UPDATE_INCOMPATIBLE|SIGNATURE') { Aviso "${nm}: la que tiene el TV viene de otra fuente (firma distinta). No se actualiza y NO se desinstala: sigue igual."; UpdAdd "$nm $ivn (firma distinta, no se toco)" }
    elseif ($out -match 'VERSION_DOWNGRADE') { Bien "$nm al dia ($ivn)"; UpdAdd "$nm al dia" }
    elseif ($out -match 'OLDER_SDK|NO_MATCHING_ABIS') { Aviso "$nm $avn no es compatible con este TV; se deja la $ivn"; UpdAdd "$nm $ivn (la nueva no es compatible)" }
    elseif ($out -match 'INSUFFICIENT_STORAGE') { Aviso "${nm}: el TV no tiene espacio para actualizar; se deja la $ivn"; UpdAdd "$nm sin espacio" }
    else { Aviso ("${nm}: la actualizacion fallo (" + (($out -split "`n")[-1]) + "); se deja la $ivn"); UpdAdd "$nm $ivn (fallo la actualizacion)" }
  }
  function ActualizarApps {
    Paso 8 'Revisando actualizaciones de apps'
    if ($noUpd) { Bien 'Omitido ($NOUPDATE=1)'; $st.updSum = 'no se revisaron ($NOUPDATE=1)'; return }
    $any = @($DOCK_APPS | Where-Object { $installed -contains $_ }).Count
    if (-not $any) { Bien 'Ni Stremio, ni IPTV Smarters, ni TizenTube estan instaladas: nada que revisar'; $st.updSum = 'ninguna instalada'; return }
    $st.updSum = ''
    foreach ($x in @(@('stremio', 'com.stremio.one', 'Stremio'), @('smarters', 'com.nst.iptvsmarterstvbox', 'IPTV Smarters'), @('tizentube', 'io.gh.reisxd.tizentube.cobalt', 'TizenTube'))) {
      try { UpdApp $x[0] $x[1] $x[2] }
      catch { LogQ ($_ | Out-String); Aviso "$($x[2]): no se pudo revisar ($($_.Exception.Message)); se deja como esta"; UpdAdd "$($x[2]) sin revisar" }
    }
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
    LogQ "ip=$IP theme=$THEME dry=$dry new_dock=$newDock noupdate=$noUpd pin_set=$([bool]$PIN) ps=$($PSVersionTable.PSVersion) os=$([Environment]::OSVersion.VersionString)"

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
    LogQ "themes builtin=$($thBuiltin -join ' ') custom=$($thCustom -join ' ') sel=$($sel -join ' ') list=$thList default=$THEME given=$themeGiven"

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
    $lukPresent = $installed -contains $PKG; $lukSha = ''; $hasDock = $false; $hasTheme = $false; $tvThemes = @(); $thPrev = @()
    $abis = S getprop ro.product.cpu.abilist; if (-not $abis) { $abis = S getprop ro.product.cpu.abi }
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
    $wroteTheme = $false; $curTheme = ''
    if ($hasTheme) { $curTheme = ((S run-as $PKG cat files/theme.txt) -split "`n")[0].Trim() }
    if ($themeGiven -or -not $hasTheme -or $thRm -contains $curTheme) {
      WriteLF (Join-Path $st.stage 'theme.txt') "$THEME`n"; $wroteTheme = $true
      $nf = Join-Path $bundle "themes\$THEME\name.txt"
      Bien ("Tema inicial: " + $(if (Test-Path $nf) { ([IO.File]::ReadAllText($nf) -split "`n")[0].Trim() } else { $THEME }))
    } else { Bien 'Se mantiene el tema que ya tenia el TV' }
    if ($thRm.Count) { Bien ("Se quitan del TV los temas que ya no van: " + ($thRm -join ', ') + " (solo temas puestos por el instalador)") }
    if ($PIN) { WriteLF (Join-Path $st.stage 'pin.txt') "$pinHash`n" }
    $njpg = @(Get-ChildItem -Recurse -File -Path (Join-Path $st.stage 'themes') | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' }).Count
    $kb = [int]((Get-ChildItem -Recurse -File -Path $st.stage | Measure-Object -Sum Length).Sum / 1024)
    LogQ "stage=$($st.stage) themes=$($sel.Count) jpg=$njpg tiles=$ntile kb=$kb"
    if ($dry) {
      Sim "adb push lukhome\ -> /data/local/tmp/ ($($sel.Count) temas, $njpg fotos, $ntile iconos, $kb KB)"
      $w = 'themes/, tiles/, rotate.txt'; if ($hasLogo) { $w += ', logo.png' }; if ($wroteDock) { $w += ', dock.txt' }; if ($wroteTheme) { $w += ', theme.txt' }; if ($PIN) { $w += ', pin.txt' }
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
      Say ''
      Say '  SIMULACION TERMINADA SIN ERRORES - no se cambio nada en el TV.' 'Green'
      Say "  Apps: $($st.updSum)"
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
    Say "  - Apps: $($st.updSum)"
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
} $IP $PIN $THEME $DRYRUN $NUEVODOCK $LUK_BUNDLE_URL $LUK_ADB $LUK_HOME_DIR $NOUPDATE
