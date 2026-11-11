# Luk Home — instalador para clientes

Instala el launcher **Luk Home** en el Fire TV / Google TV de un cliente desde **su** computadora (Mac o Windows), con una sola línea.
Modo **solo launcher**: no borra apps, no desinstala nada (tampoco Projectivy u otros launchers), no cambia ajustes de otras apps.
Lo único que toca de las apps del cliente son **Stremio, IPTV Smarters y TizenTube**: si ya están y hay una versión oficial
**más nueva**, las actualiza con `adb install -r` (conserva datos y sesiones); si **no están**, descarga la oficial, la instala
con `adb install -g` y la pone en el dock de Luk Home. Ninguna otra app se instala, se quita ni se actualiza. Ver paso 8.
**IPTV Smarters es siempre la gratis de Troypoint** (Troypoint Toolbox → MediaFire, la 3.1.5.1): nunca la de pago de
`iptvsmarters.com` / `smartersott.app`. Única excepción a "no desinstala nada": si el TV tiene otra IPTV Smarters (por
ejemplo la 4.0.6 de pago), se cambia por la de Troypoint y **se borran su login y sus listas** (hay que volver a ponerlos).
Para no instalar las que faltan: `--sin-apps` (Windows `$SINAPPS=1;`); para no actualizar las que ya están: `--sin-actualizar`
(Windows `$NOUPDATE=1;`).

## Copiar y pegar: línea con todos los temas

La línea tiene 7 partes separadas por **espacios**: IP, PIN, TEMAS, CIUDAD, APPS, BOTONES y ESTILO.

- **IP**: cambia `192.168.0.x` por la IP del TV (también puede empezar con `10.0.0.`).
- **PIN**: cambia `1234` por el PIN del cliente.
- **TEMAS**: solo se instalan los temas que dejes en la línea. Si dejas solo `real-madrid`, el TV tendrá solo ese tema. El primero es el inicial; borra los que no quieras y deja las comas sin espacios. Para que se vayan mezclando, pon `aleatorio,` al principio (imágenes de todos los temas) o `rotar,` (cambia de tema cada hora). Ejemplo: `aleatorio,real-madrid,navidad,autos`.
- **CIUDAD** (para el tiempo): `auto` = el TV la detecta solo. O pon la ciudad, por ejemplo `Miami`. Si tiene dos palabras, va entre comillas: `"Fort Lauderdale"`.
- **APPS** extra en el inicio, junto a Stremio, IPTV Smarters y TizenTube: cambia `netflix,youtube,disney` por las apps del cliente, o pon `todas`. Si no quieres apps extra, borra esa última parte (en Windows borra `$APPS='...';`).
- **BOTONES**: `--bloquear-botones` deja sin efecto los botones de apps del control (Netflix, Prime, etc.) para que no abran la tienda a descargar apps. En Fire TV solo se frenan los de apps que no están instaladas. Si no lo quieres, borra esa parte (en Windows borra `$BOTONES='bloquear';`).
- **ESTILO** de las tarjetas del inicio: `--estilo=oscuro` = tarjetas oscuras con el logo blanco que se pone verde al pasar por encima (el normal). Cambia `oscuro` por `colores` para tarjetas de colores (con rayas, brillo y el logo en una bolita). En Windows es `$ESTILO='oscuro';` o `$ESTILO='colores';`. Si borras esa parte, el TV se queda con el estilo que ya tenga (un TV nuevo empieza en oscuro). El cliente también lo puede cambiar después con el control: botón de **Temas** (la paleta, arriba) > **Estilo** > **Oscuro** o **Colores**.

Además, sin escribir nada: el paso 8 **instala Stremio, IPTV Smarters y TizenTube si faltan** (y las agrega al dock) y
**actualiza** las que ya están. IPTV Smarters siempre es la **gratis de Troypoint**: si el TV tiene otra (p. ej. la 4.0.6 de
pago) se cambia sola por la de Troypoint, y su login y sus listas se borran (hay que volver a ponerlos en la app); no hay
que agregar ninguna opción. Para no instalar las que faltan, agrega al final `--sin-apps` (Windows: `$SINAPPS=1;` antes de `[Net...`);
para no actualizar las que ya están, `--sin-actualizar` (Windows: `$NOUPDATE=1;`).

**Mac** (app Terminal):
```bash
curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.0.x 1234 real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes auto netflix,youtube,disney --bloquear-botones --estilo=oscuro
```

**Windows** (PowerShell normal, sin administrador; es una sola línea):
```powershell
$IP='192.168.0.x'; $PIN='1234'; $THEME='real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes'; $CIUDAD='auto'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
```

| Nombre en la línea | Botón Temas | Tipo |
|---|---|---|
| `real-madrid` | Real Madrid | personalizado (solo si está en la línea) |
| `real-madrid-2` | Real Madrid 2 | personalizado (solo si está en la línea) |
| `navidad` | Navidad | personalizado (solo si está en la línea) |
| `terror` | Terror | incluido |
| `american-sports` | Deportes americanos | incluido |
| `autos` | Autos | incluido |
| `animales` | Animales | incluido |
| `mar` | Mar | incluido |
| `barcos` | Barcos | incluido |
| `espacio` | Espacio | incluido |
| `paisajes` | Paisajes | incluido |

`terror` antes se llamaba `halloween-terror`; ese nombre (y `halloween` / `horror`) sigue valiendo y da `terror`.
Si el TV ya tenía la carpeta vieja `halloween-terror`, al repetir el instalador se cambia por `terror` (no quedan las dos).

## 1. Qué le mandas al cliente

1. El archivo **[CLIENTE.md](CLIENTE.md)** (o su texto), con los 4 pasos que verá.
2. **La línea de su sistema**, ya con **su IP y su PIN** puestos (cambia `192.168.1.50` y `1234`). Trae todos los temas, la ciudad y las apps extra
   (lee arriba qué es cada parte; solo se instalan los temas que dejes en la línea; `--estilo=oscuro` o `--estilo=colores` elige las tarjetas).

**Mac** (app Terminal):
```bash
curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.1.50 1234 real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes auto netflix,youtube,disney --bloquear-botones --estilo=oscuro
```

**Windows** (PowerShell normal, sin administrador; es una sola línea):
```powershell
$IP='192.168.1.50'; $PIN='1234'; $THEME='real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes'; $CIUDAD='auto'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
```

- **IP**: la del TV del cliente (ver abajo).
- **PIN**: 4 números, protege Ajustes de Luk Home. En Windows **siempre entre comillas** (`'0123'`) para no perder ceros. Para no poner PIN: `sinpin`.
- **Tema** (opcional): `paisajes`, `mar`, `espacio`, `autos`, `animales`, `barcos`, `american-sports`, `terror` (antes `halloween-terror`, que sigue valiendo),
  o un tema personalizado (ver abajo; ya vienen `real-madrid`, `real-madrid-2`, `navidad`, `barcelona`, `real-madrid-3`, `barcelona-cule` e `inter-miami-messi`). En Mac va como 3.er valor; en Windows `$THEME='mar';` (o quítalo, y van todos los incluidos).
  - **Un solo nombre** (`mar`): van al TV **todos** los temas y `mar` queda como tema inicial.
  - **Una lista con comas, sin espacios** (`autos,mar,espacio`): van al TV **solo esos**; el **primero** es el inicial.
    `todos` dentro de la lista agrega todos los incluidos (p. ej. `terror,todos`).
  - **Sin tema o `todos`**: todos los incluidos, como antes; si el TV ya tenía tema, se mantiene (si no, `paisajes`).
  - Si un nombre no existe, el instalador se detiene antes de tocar el TV y muestra los nombres válidos (antes caía a `paisajes`).
  - **`aleatorio`** o **`rotar`** (solos, o **al principio** de la lista): el TV arranca en ese modo del botón Temas.
    `aleatorio` = fotos de **todos** los temas del TV, mezcladas (cambia de foto cada 20 s).
    `rotar` = un tema completo cada **hora**, en el orden del menú (dentro del tema las fotos siguen cambiando cada 20 s).
    Ejemplos: `aleatorio` (todos los temas incluidos + modo Aleatorio), `rotar,real-madrid,navidad,mar` (solo esos tres, rotando).
    El cliente lo puede cambiar después desde el botón Temas (filas **Aleatorio** y **Rotar temas**, al final del menú).

### Temas personalizados de un cliente

1. Crea la carpeta `bundle/themes/<nombre>/` (nombre en minúsculas, solo `a-z 0-9 - _`, p. ej. `bundle/themes/taller-perez/`).
2. Pon dentro las fotos (`.jpg`, `.png` o `.webp`; ideal 1920×1080, menos de ~1 MB cada una) y un `name.txt` con el nombre que
   verá el cliente en el botón Temas (p. ej. `Taller Pérez`).
3. **No** lo agregues a `order.txt` (así no les llega a los demás clientes). No hace falta tocar `SHA256SUMS`. Haz push.
4. En la línea de ese cliente usa el nombre: `taller-perez` (sale primero, y además todos los incluidos) o
   `taller-perez,mar,autos` (solo esos tres).

Un tema personalizado solo llega a los TV en cuya línea aparece su nombre.

Temas personalizados que ya vienen en el paquete (fuera de `order.txt`, solo para quien los pida):

| Nombre en la línea | Botón Temas | Contenido |
|---|---|---|
| `real-madrid` | Real Madrid | estadio de noche, afición con bufandas blancas, copa, balón blanco y oro, "HALA MADRID", Cibeles y Gran Vía de noche |
| `real-madrid-2` | Real Madrid 2 | las mismas 8 fotos del club que `real-madrid` (escudo, estadio, jugadores, "¡HALA MADRID!") y 2 fotos nuevas de otro amigo: con su niño en hombros en el Bernabéu, y levantando la Champions |
| `navidad` | Navidad | chimenea, árbol decorado, pueblo nevado, trineo de Santa, adornos, regalos, cabaña nevada |
| `barcelona` | Barcelona | Camp Nou, túnel, balón, bufanda, vestuario, portería, botas, blaugrana, y 2 fotos de una amiga en el estadio y en la tribuna |
| `real-madrid-3` | Real Madrid Amiga | las 8 fotos del club de `real-madrid` y 2 fotos de una amiga: en el Bernabéu y con la Champions |
| `barcelona-cule` | Barcelona culé | Camp Nou al atardecer y de noche, cinco Champions, La Liga, Copa del Rey, vitrina, banderas blaugrana, escudo oficial y Supercopa de la UEFA (sin personas; escudo oficial en las 10) |
| `inter-miami-messi` | Inter Miami Messi | Messi con la camiseta rosa oficial de Inter Miami, MLS Cup y Leagues Cup, estadio y playa de Miami; 2 fotos con un amigo (MLS Cup de noche y playa al atardecer); escudo oficial en las 10 |

`barcelona`, `real-madrid-3`, `barcelona-cule` e `inter-miami-messi` **no** están en las líneas de arriba ni en `order.txt`. Solo llegan si la línea de ese cliente los nombra.

Ejemplos: Mac `… 1234 real-madrid` (Real Madrid inicial + todos los incluidos), `… 1234 real-madrid,navidad` (solo esos dos),
`… 1234 barcelona` (Barcelona inicial + todos los incluidos) o `… 1234 barcelona,real-madrid-3` (solo esos dos);
`… 1234 barcelona-cule,` o `… 1234 inter-miami-messi,` (solo ese tema; la coma final = únicamente los nombrados);
Windows `$THEME='real-madrid';`, `$THEME='navidad,todos';`, `$THEME='barcelona';`, `$THEME='real-madrid-3';`,
`$THEME='barcelona-cule,';` o `$THEME='inter-miami-messi,';`.

Extras opcionales:

| Qué | Mac (al final de la línea) | Windows (antes de `irm`) |
|---|---|---|
| Probar sin cambiar nada en el TV | `--simular` (o `--dry-run`) | `$DRYRUN=1;` |
| Rehacer el dock aunque ya exista | `--nuevo-dock` | `$NUEVODOCK=1;` |
| No actualizar Stremio / IPTV Smarters / TizenTube si ya están (las que faltan se instalan igual) | `--sin-actualizar` (o `LUK_NOUPDATE=1`) | `$NOUPDATE=1;` |
| No instalar Stremio / IPTV Smarters / TizenTube si faltan (las que están se actualizan igual) | `--sin-apps` (o `LUK_SINAPPS=1`) | `$SINAPPS=1;` |
| Ciudad del tiempo (ver abajo) | 4.º valor después del tema, o `CIUDAD="Miami"` antes de `bash` | `$CIUDAD='Miami';` |
| Apps extra en el inicio (ver abajo) | 5.º valor, o `--apps netflix,youtube`, o `APPS=netflix,youtube` antes de `bash` | `$APPS='netflix,youtube';` |
| Botones de apps del control sin efecto (ver abajo) | `--bloquear-botones` (volver: `--desbloquear-botones`) | `$BOTONES='bloquear';` (volver: `$BOTONES='normal';`) |
| Estilo de las tarjetas del inicio (ver abajo) | `--estilo=oscuro` o `--estilo=colores` (o `ESTILO=colores` antes de `bash`) | `$ESTILO='oscuro';` o `$ESTILO='colores';` |
| **RetroArch** con los emuladores del cuarto (ver abajo) | `--retroarch` (o `RETROARCH=1` antes de `bash`) | `$RETROARCH=1;` |
| **Kodi** con el build de la sala (ver abajo) | `--kodi` (o `KODI=1` antes de `bash`) | `$KODI=1;` |
| Con `--kodi`: cambiar un Kodi incompatible (64 bits u otra versión) | `--reemplazar-kodi` | `$KODIREEMPLAZAR=1;` |

### RetroArch y Kodi (opcionales, 2026-11-10a)

Sin `--retroarch` / `--kodi` (Windows `$RETROARCH` / `$KODI`) el instalador **no toca RetroArch ni Kodi** y hace
exactamente lo mismo que antes (pasos 1–8). Con ellos agrega el paso 9 y/o 10, **después** de que Luk Home quedó instalado
y comprobado (si fallan, Luk Home queda bien igual). Se pueden usar juntos o por separado y con cualquier otra opción.

**Mac** (Luk Home + RetroArch + Kodi):
```bash
curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.0.x 1234 real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes auto netflix,youtube,disney --bloquear-botones --estilo=oscuro --retroarch --kodi
```

**Windows** (Luk Home + RetroArch + Kodi):
```powershell
$IP='192.168.0.x'; $PIN='1234'; $THEME='real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes'; $CIUDAD='auto'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; $RETROARCH=1; $KODI=1; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
```

Solo uno de los dos: quita `--kodi` / `$KODI=1;` o `--retroarch` / `$RETROARCH=1;`.

**RetroArch (`--retroarch`, paso 9)** — deja el TV como el **cuarto** (onn 192.168.0.249):
- Si falta, instala el **RetroArch 1.22.2 oficial** de `buildbot.libretro.com/stable/1.22.2/android/`
  (`RetroArch_ra32.apk`, sha256 `9e964f53…803f`, el mismo de la sala y el cuarto; en un TV solo de 64 bits,
  `RetroArch_aarch64.apk` sha256 `7bd5d208…d213`). Si ya está, lo actualiza **en su lugar** (`adb install -r`, sin
  desinstalar, conserva todo); si el TV tiene uno **más nuevo**, no lo toca (nunca baja de versión).
- **7 núcleos oficiales** para el procesador del TV (armeabi-v7a o arm64-v8a), bajados en el momento de
  `buildbot.libretro.com/nightly/android/latest/`: FinalBurn Neo, MAME 2003-Plus, FCEUmm, Mupen64Plus-Next GLES3,
  Flycast, Genesis Plus GX y PCSX ReARMed. Los instala el propio RetroArch con su `CoreSideloadActivity` oficial
  (RetroArch se abre y se cierra solo unas veces). Más las fichas oficiales de núcleos (`info.zip`).
- `retroarch.cfg` del cuarto (menú Ozone, mandos, 8BitDo Pro 2 reservado para el jugador 1, etc.). Se quedan los valores
  propios del TV (ruta del APK, carpeta de núcleos, versión de recursos, audio); las fichas van a `Android/data/<app>/files/info`.
- Opciones de núcleo `FCEUmm.opt` y `MAME 2003-Plus.opt`, 438 perfiles de mandos (`autoconfig`, incl. 8BitDo) y
  `hiscore.dat` de MAME 2003-Plus (solo si falta).
- Carpetas de juegos **vacías** en `/sdcard/ROMs/`: `Nintendo - NES`, `Arcade - Mame 2003 Plus`, `Nintendo - N64`,
  `SNK - NEO GEO`, `fbneo_1_0_0_3_best/games` y `fbneo_1_0_0_3_best/samples`.
- **No lleva ROMs, BIOS ni partidas** (saves/states). Nunca borra ni pisa ROMs, partidas, estados ni BIOS del TV: solo
  agrega. Antes de pisar `retroarch.cfg` y las `.opt` los **respalda en la computadora** (`respaldos/retroarch-IP-fecha/`).
- **Play Protect (Google TV / onn):** puede frenar la instalación ("Bloqueada por Play Protect" / "App no segura"). En
  la pantalla del TV elige **Más detalles > Instalar de todas formas**; el instalador avisa y reintenta (3 veces). No hace
  falta (ni se debe) apagar Play Protect.
- Si RetroArch está abierto en el TV (alguien jugando), no se toca. Si un núcleo no se pudo bajar, se puede bajar luego en
  RetroArch: Menú principal > Actualizador en línea > Descargar núcleos.

**Kodi (`--kodi`, paso 10)** — el **Kodi del TV del cuarto** (onn 4K Pro, 192.168.0.249; build 2026-11-10), con todos sus repos, addons, skin, menú, fondo,
favoritos y ajustes, igual que `bundle/kodi/kodi-sala.sh` (Mac) / la función `KodiPaso` (Windows):
- Kodi **21.3 oficial** de `mirrors.kodi.tv` (armeabi-v7a, sha256 `12d75e89…20cc8`), instalado si falta o si es más
  viejo. Necesita un TV que acepte apps de 32 bits ARM. Si el TV tiene un Kodi incompatible (64 bits u otra versión),
  avisa y no lo toca; con `--reemplazar-kodi` (Windows `$KODIREEMPLAZAR=1;`) lo respalda, lo desinstala y pone el 21.3.
- El build (`kodi-sala.zip`, ~290 MB) se baja del **Release `kodi-build-2026-11-10`** de este repo y se comprueba su
  sha256 (`67e4e8dd…0eca`). El build anterior (sala, `kodi-build-2026-11-09`) sigue en su Release. Se guarda en la computadora para la próxima vez.
- **Respalda** el Kodi que ya tenga el TV en la computadora (`kodi/respaldos/`), luego **borra solo los datos de Kodi**
  (`pm clear org.xbmc.kodi`), le da permisos de almacenamiento (Android 11+: también "acceso a todos los archivos"), lo
  abre una vez para que cree su carpeta y copia el build (tar por `/data/local/tmp`). Ninguna otra app se toca.
- **Sin cuentas ni contraseñas**: después hay que volver a iniciar **TorBox en POV, Umbrella y ResolveURL**.
- Si Kodi está abierto en el TV, no se toca.


### Estilo de las tarjetas del inicio (Oscuro o Colores)

- **Oscuro** (el normal): tarjetas grafito con el logo oficial en blanco; la que tiene el foco se pone con el logo verde y un borde verde que "respira".
- **Colores**: tarjetas de colores (13 colores, con rayas suaves y brillo) y el logo de la app en una bolita redonda.

Se elige con `--estilo=oscuro` / `--estilo=colores` (Windows `$ESTILO='oscuro';` / `$ESTILO='colores';`). Sin la opción
no se cambia el TV (uno nuevo empieza en **Oscuro**). En el TV, sin PIN: subir con el control hasta el botón de **Temas**
(la paleta), OK, bajar hasta **Estilo** y elegir **Oscuro** o **Colores** con OK; cambia al momento y se queda guardado
aunque se apague el TV. Se guarda en `files/dock-style.txt` (`oscuro` / `colores`).

### Botones de apps del control (opcional)

Los controles traen botones de marca (Netflix, Prime Video, YouTube, Disney+, Hulu…) que abren esa app o, si no está
instalada, su página en la tienda. Con `--bloquear-botones` (Windows `$BOTONES='bloquear';`) Luk Home los deja sin efecto:

- **Google TV / onn:** el botón no hace nada (Luk Home se come la tecla antes de que el sistema la use).
- **Fire TV:** Amazon procesa esos botones antes que Luk Home, así que no se pueden cortar del todo: si la app **no está
  instalada**, la página de la tienda que se abre se cierra sola en menos de un segundo y se vuelve a lo que estaba en
  pantalla. Si la app **sí está instalada** (p. ej. Prime Video, Disney+), se abre normal.

Sin la opción no se cambia nada. Se guarda en `files/block-app-buttons.txt` (`on` / `off`). Deshacer en un TV:
`--desbloquear-botones` o `adb shell run-as com.ivantrj.glasslauncher rm files/block-app-buttons.txt`.
Cada tecla rara que llega se anota en el log: `adb logcat -s LukKeys` (sirve para identificar un botón nuevo).

### Tiempo en vivo (botón del clima)

Luk Home muestra arriba a la derecha, antes de Temas, un botón con el ícono del clima y la temperatura (`79°`). Al pulsarlo
abre una tarjeta en español: ciudad, temperatura, condición, sensación térmica, calidad del aire, los próximos 3 días y el
botón **Cambiar ciudad** (lista de ciudades o **Buscar ciudad…** con el teclado del TV). Datos de **Open-Meteo** (gratis, sin
cuenta); se actualiza cada 30 minutos y al volver la conexión. °F en EE. UU., °C en el resto. Sin internet muestra el último
dato guardado (o solo el ícono) sin mensajes de error.

Por defecto la ciudad es **automática** (por la IP de internet del cliente). Para fijarla desde el instalador (opcional):

- **Mac:** 4.º valor después del tema (usa `todos` si no quieres elegir tema), entre comillas si lleva espacios:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.0.x 1234 todos "Miami" netflix,youtube,disney --bloquear-botones --estilo=oscuro
  ```
  o con variable: `curl -fsSL …/install.sh | CIUDAD="Madrid, España" bash -s -- 192.168.0.x 1234`
- **Windows:** agrega `$CIUDAD='Miami';` antes de `irm`, p. ej.:
  ```powershell
  $IP='192.168.0.x'; $PIN='1234'; $THEME='todos'; $CIUDAD='Miami'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
  ```
- Valores: un nombre (`Miami`, `Madrid, España`, `Ciudad de México`), coordenadas `25.76,-80.19`, o `auto` (volver a automática).
- Sin CIUDAD el instalador no toca la ciudad que el cliente ya eligió en el TV. Con CIUDAD se conserva la línea `unidad=F` / `unidad=C` si el TV ya la tenía.

### Apps extra en el inicio (APPS, opcional)

Pon en la fila de inicio otras apps **que el cliente ya tiene instaladas** (el instalador nunca instala, quita ni actualiza
apps por esto; solo Stremio, IPTV Smarters y TizenTube se instalan o actualizan, en el paso 8). Van **después** de Stremio, IPTV Smarters y TizenTube, en el orden que escribas, sin repetir.
Nombres separados por comas, **sin espacios**. Si una app no está en el TV, se salta y avisa (no se detiene).

En Mac es el **5.º valor**: IP, PIN, TEMA, CIUDAD, APPS. Si no quieres cambiar el tema pon todos; para la ciudad pon auto
(automática) o - (no tocar la ciudad). Al final va `--bloquear-botones` (en Windows `$BOTONES='bloquear';`), que deja sin
efecto los botones de apps del control; bórralo si no lo quieres. Después `--estilo=oscuro` (o `colores`; Windows `$ESTILO='oscuro';`).

Mac (app Terminal), línea lista para copiar:

curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 10.0.0.250 1234 real-madrid auto netflix,youtube,disney --bloquear-botones --estilo=oscuro

Windows (PowerShell), línea lista para copiar:

$IP='10.0.0.250'; $PIN='1234'; $THEME='real-madrid'; $CIUDAD='auto'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex

Con todos los temas y apps extra, sin tocar la ciudad que ya tiene el TV (`-` en Mac, `$CIUDAD='-';` en Windows):

curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.0.x 1234 real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes - netflix,youtube,disney --bloquear-botones --estilo=oscuro

$IP='192.168.0.x'; $PIN='1234'; $THEME='real-madrid,real-madrid-2,navidad,terror,american-sports,autos,animales,mar,barcos,espacio,paisajes'; $CIUDAD='-'; $APPS='netflix,youtube,disney'; $BOTONES='bloquear'; $ESTILO='oscuro'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex

Nombres que entiende (sirven en Fire TV y en Google TV / onn; mayúsculas, espacios, guiones y "+" dan igual):

| Nombre | App |
|---|---|
| netflix | Netflix |
| youtube (yt) | YouTube |
| youtubetv, youtubekids, youtubemusic | YouTube TV / Kids / Music |
| smarttube | SmartTube |
| prime (primevideo) | Prime Video |
| disney (disneyplus) | Disney+ |
| hulu | Hulu |
| max (hbomax, hbo) | Max |
| paramount (paramountplus) | Paramount+ |
| peacock | Peacock |
| appletv | Apple TV |
| spotify | Spotify |
| pluto (plutotv), tubi | Pluto TV, Tubi |
| plex, kodi, vlc | Plex, Kodi, VLC |
| espn, fubo, sling, dazn, directv, philo, starz | deportes / TV en vivo |
| vix, telemundo, crunchyroll, twitch | ViX, Telemundo, Crunchyroll, Twitch |
| downloader, silk | Downloader, navegador Silk |
| stremio, smarters, tizentube, nuvio | (las del dock normal; sirven para cambiar el orden) |
| tivimate, xciptv, perfectplayer, ottnavigator, mxplayer | reproductores IPTV / video |
| todas (o all) | todas las apps del cliente que se pueden abrir |

- También vale el **nombre del paquete** (lleva un punto), p. ej. com.disney.disneyplus.
- Si el nombre no está en la tabla, busca una app instalada cuyo paquete se parezca (p. ej. pandora).
- Si el TV ya tenía su fila de inicio, se **conserva** y las apps nuevas se agregan al final (las que ya estaban no se repiten).
  Con --nuevo-dock (Windows $NUEVODOCK=1;) se rehace: Stremio, IPTV Smarters, TizenTube + las de APPS.
- Una app **desactivada** en el TV se salta con aviso. Máximo 20 apps en la fila.
- Las apps sin ícono propio de Luk Home salen con el **marco con estilo** (franjas, brillo y reflejo) en un **color distinto** al de los demás tiles del inicio, y en la burbuja redonda solo el logo de la app, sin el cuadrito de fondo de su ícono.

> El PIN queda visible en la línea y en el historial de la terminal del cliente (aceptado). En el TV solo se guarda su hash SHA-256.

## 2. Cómo encontrar la IP del TV

- **Fire TV:** Ajustes → **Mi Fire TV** → **Acerca de** → **Red** → "Dirección IP".
- **Google TV / onn:** Ajustes → **Red e Internet** → toca la red WiFi conectada → "Dirección IP".

La computadora tiene que estar **en el mismo WiFi** que el TV.

## 3. Cómo activar ADB en el TV

**Fire TV (Fire OS 6, 7 y 8):**
1. Ajustes → Mi Fire TV → **Acerca de** → pulsa **7 veces** el nombre del dispositivo ("Fire TV Stick 4K", etc.) hasta que diga que ya eres desarrollador.
2. Atrás → **Opciones para desarrolladores** → **Depuración ADB: Activado**. ("Apps de origen desconocido" no hace falta.)

**Google TV / onn / Chromecast con Google TV:**
1. Ajustes → **Sistema** → **Acerca de** → pulsa **7 veces** "Compilación del SO de Android TV".
2. Ajustes → Sistema → **Opciones para desarrolladores** → **Depuración por USB: Activado**.

La primera vez el TV pregunta **"¿Permitir la depuración USB?"** → marcar "Permitir siempre" → **Permitir**. El script lo avisa y espera hasta 2 minutos.

## 4. Qué hace el script (pasos 1–8, y 9–10 con `--retroarch` / `--kodi`)

1. **Herramientas**: descarga las *platform-tools* oficiales de Google (`dl.google.com/android/repository/platform-tools-latest-{darwin,windows}.zip`) a una carpeta del usuario (se reutilizan en la siguiente vez) y el paquete de este repo (`github.com/coplic/luk-home-installer/archive/refs/heads/main.zip`, ~18 MB: APKs + temas + íconos). Comprueba los APK con `bundle/SHA256SUMS`.
2. **Conexión**: `adb connect IP:5555`. Si el TV pide permiso, muestra el aviso grande y espera. Detecta TV apagado / IP equivocada / ADB apagado.
3. **Revisión (solo lectura)**: modelo, versión de Android (API), espacio libre, ajustes de accesibilidad y launcher actual, lista de apps. Guarda un **respaldo** en la computadora.
4. **Instala** el APK correcto con `adb install -r` (actualiza sin borrar datos; si ya está la misma versión, no hace nada):
   - API 25–27 (Fire OS 6, Android 7.1) → `luk-home-fos6.apk` (en Fire OS 6 no hay `sha256sum`: reinstalla siempre, sin borrar datos)
   - API 28–29 (Fire OS 7) → `luk-home-fos7.apk`
   - API 30 o más (Fire OS 8, Google TV) → `luk-home.apk`
5. **Archivos** dentro de Luk Home (solo su carpeta privada): los temas elegidos, íconos personalizados de las apps instaladas, rotación de fondo cada 20 s, tema inicial, PIN y **dock** con solo Stremio, IPTV Smarters y TizenTube (las que estén instaladas; las que faltan se instalan en el paso 8 y ahí se agregan al dock). Las demás apps quedan en "Otras apps".
6. **Botón Inicio**: activa el servicio de accesibilidad de Luk Home. Si otro launcher (p. ej. Projectivy) tenía ese servicio, **solo se reemplaza su entrada** (la app no se toca ni se desinstala); otros servicios de accesibilidad se conservan. En Google TV con un launcher de terceros como inicio, pone Luk Home como inicio.
   **Fire OS 6 (API 25–27):** Amazon no deja correr servicios de accesibilidad de apps instaladas por fuera, así que ahí no se toca la accesibilidad: se da a Luk Home el **acceso de uso** (`appops set com.ivantrj.glasslauncher GET_USAGE_STATS allow`) y Luk Home vigila qué app está al frente.
7. **Comprueba** ajustes, temas y PIN, abre Luk Home y pulsa Inicio.
8. **Stremio, IPTV Smarters y TizenTube: instalar o actualizar** (solo estas tres; nunca toca otras apps del cliente):
   - **Si ya está** en el TV: compara su `versionCode` con la última versión oficial y, solo si la oficial es **más nueva**,
     actualiza con `adb install -r` (conserva datos y sesiones). Se salta con `--sin-actualizar` / `$NOUPDATE=1`.
     (IPTV Smarters tiene reglas propias, ver abajo.)
   - **Si no está**: descarga la oficial y la instala con `adb install -g`. Luego la **agrega al dock** de Luk Home (al
     final de la fila si el TV ya tenía dock) con su ícono, y vuelve a abrir Luk Home para que se vea. Se salta con
     `--sin-apps` (o `LUK_SINAPPS=1`) / `$SINAPPS=1`. Con las dos opciones, el paso 8 no hace nada.

   Fuentes oficiales (las mismas para instalar y actualizar):
   - Stremio: APK de Android TV de `www.stremio.com/downloads` (`dl.strem.io`), sin versiones rc/beta.
   - TizenTube: releases de `github.com/reisxd/TizenTubeCobalt` (`cobalt-arm.apk` / `cobalt-arm64.apk`, con su sha256).
   - IPTV Smarters: **solo Troypoint** (la gratis; la de pago de `iptvsmarters.com` / `smartersott.app` no funciona y nunca
     se usa). En cada corrida lee el enlace de "IPTV Smarters Pro" de `https://troypoint.com/troypoint-toolbox/` (MediaFire).
     - Si enlaza la 3.1.5.1 (o la página no se puede leer) usa la **3.1.5.1 fija**:
       `https://www.mediafire.com/file_premium/xrlnqh9kppx349u/IPTV_Smarters_Pro_%255B3.1.5.1%255D.apk/file`
       (`com.nst.iptvsmarterstvbox`, versionCode 112, minSdk 17, armeabi-v7a, sha256
       `2791f5346f95269c9254c547ee641a80eb5d86f0a9045dc4ae41e79210a5dbdc`). MediaFire da un enlace de descarga distinto
       cada vez: el script lo sigue solo y comprueba el sha256.
     - Si Troypoint enlaza **otro archivo**, lo baja y solo lo usa si es IPTV Smarters, **más nueva** que la 3.1.5.1 y con
       **la misma firma** (certificado sha256 `6100ac45…ce521cd09f1`); si no, usa la 3.1.5.1.
     - **No está** en el TV → instala la de Troypoint (`adb install -g`) y la agrega al dock.
     - **Ya es de Troypoint** (misma firma; se comprueba con una copia de la del TV): si la de Troypoint es más nueva,
       `adb install -r` (conserva login y listas); si es igual o más nueva, no se toca.
     - **Es otra** (firma distinta, p. ej. la 4.0.6 de pago): avisa, guarda una copia en la computadora
       (`apps/smarters/respaldo-<versión>-<fecha>/`), la desinstala (**se borran su login y sus listas**) e instala la de
       Troypoint. Si esa instalación falla, vuelve a poner la copia. Si no puede leer la del TV, no hay espacio o el TV no
       es ARM, no la toca.
     - `--sin-actualizar` / `$NOUPDATE=1` la deja como esté. Con `--simular` solo muestra lo que haría.

   Arquitectura: para una app instalada usa la misma que tiene (armeabi-v7a / arm64-v8a); para una nueva usa la del TV
   (`ro.product.cpu.abi`), y si el TV rechaza la de 64 bits prueba la de 32 bits. Comprueba que el `minSdk` del APK sirva
   para el TV (Fire OS 6 = API 25); si la última no sirve, prueba versiones oficiales anteriores y, si ninguna sirve, avisa
   (`… no se instala`) y sigue. Nunca desinstala, baja de versión ni borra datos (salvo el cambio de IPTV Smarters explicado arriba). Si la app del TV vino de otra fuente
   (**firma distinta**, p. ej. la de Play Store), avisa y la deja como está. Cualquier fallo de una app (sin internet, sin
   espacio, no compatible) solo avisa y sigue con las demás. Los APK descargados se guardan en la carpeta del instalador
   (`apps/`) para la próxima vez. Con `--simular` descarga y compara, pero no instala ni cambia el dock. Al final muestra
   **LISTO** con una línea `Apps: …` (p. ej. `Stremio 1.9.12 → 1.10.4 · IPTV Smarters 4.0.6 → 3.1.5.1 gratis (login y listas borrados) · TizenTube al día`).
   El paso 8 corre cuando Luk Home ya quedó instalado y comprobado: si falla o se cancela, Luk Home queda bien igual.

9. **RetroArch** (solo con `--retroarch` / `$RETROARCH=1`): ver "RetroArch y Kodi (opcionales)" arriba.
10. **Kodi** (solo con `--kodi` / `$KODI=1`): ver "RetroArch y Kodi (opcionales)" arriba.

Si algo falla en los pasos 6–7, **devuelve los ajustes del botón Inicio (y el acceso de uso en Fire OS 6) como estaban** antes de salir.

**Se puede repetir sin problema** (idempotente): no reinstala si ya está igual, **no pisa el dock** ni el tema que el cliente ya tenga (salvo `--nuevo-dock` o pasar un tema explícito), actualiza temas/íconos y el PIN.

**Quitar temas al repetir:** el instalador anota en el TV qué temas puso (`files/themes/.instalador.txt`). Solo cuando se
pasa una **lista** (`autos,mar`), borra del TV los temas que **ya no están en la lista** y que son del instalador (los
incluidos en `order.txt`, los personalizados del paquete o los anotados en esa lista). Nunca borra otras carpetas ni otros
archivos. Con un solo nombre, `todos` o sin tema no se borra nada (solo agrega). Si el tema que tenía el TV se borra,
el primero de la lista queda como tema.

## 5. Dónde quedan respaldos y registros (en la computadora del cliente)

| | Mac | Windows |
|---|---|---|
| Carpeta | `~/.luk-home/` | `%LOCALAPPDATA%\LukHome\` |
| APK de actualizaciones (paso 8) | `apps/<app>/` | `apps\<app>\` |
| Registro de cada corrida | `logs/instalacion-<ip>-<fecha>.log` | `logs\instalacion-<ip>-<fecha>.log` |
| Respaldo previo | `respaldos/<ip>-<fecha>/antes.txt` (accesibilidad, inicio, versión), `paquetes.txt`, `dock-antes.txt` | igual |

El registro **no** contiene el PIN.

## 6. Problemas frecuentes

| Mensaje | Qué hacer |
|---|---|
| **No encuentro ningún TV en …** | TV prendido, IP correcta, computadora en el mismo WiFi (no en red de invitados ni con VPN). |
| **contesta, pero la Depuración ADB está apagada** | Activar Depuración ADB (sección 3). Si ya está activada, la IP es de otro aparato. |
| **No se aceptó el permiso en el TV a tiempo** | Repetir la línea y pulsar **Permitir** en el TV. Si el aviso no aparece: apagar y prender Depuración ADB, repetir. |
| **la conexión queda "offline"** | Apagar/prender Depuración ADB o reiniciar el TV; repetir. |
| **otro Luk Home con una firma distinta** | El TV tiene un Luk Home de otra compilación. Desinstalarlo (Ajustes → Aplicaciones) y repetir. |
| **demasiado viejo** | Fire OS 5 o anterior (API < 25, Android 5.1 o 6): no compatible. |
| **casi no tiene espacio libre** | Hacen falta ~60 MB. Liberar espacio y repetir. |
| Google TV: aviso de **Play Protect** | Elegir "Instalar de todas formas". |
| Fire TV 7: Inicio muestra el menú de Amazon un instante | Normal: Luk Home aparece a los ~5 s. |
| Fire TV 6: Inicio muestra el menú de Amazon un instante | Normal: Luk Home vuelve en menos de 1 s. Después de reiniciar el TV, el inicio de Amazon se ve ~1 minuto y luego aparece Luk Home solo. |
| Windows: "no se reconoce irm" / errores rojos de TLS | Usar **Windows PowerShell** (no CMD) y copiar la línea completa, incluido `[Net.ServicePointManager]...`. |
| **firma distinta… NO se desinstala** (paso 8) | La app del TV vino de otra fuente (p. ej. Play Store). Se deja como está; se actualiza desde su tienda. |
| **no se pudo descargar / consultar la última versión** (paso 8) | Sin internet o la página cambió. Luk Home quedó bien; se puede repetir o usar `--sin-actualizar` / `--sin-apps`. |
| **ninguna version oficial reciente funciona en este TV… no se instala** (paso 8) | El TV es muy viejo para esa app (p. ej. Stremio pide Android API 24+). Las otras apps y Luk Home quedan bien. |
| **la instalacion fallo… se sigue con lo demas** (paso 8) | Casi siempre falta espacio. Liberar espacio y repetir la línea (las que ya quedaron no se repiten). |
| **Tema no válido** | Revisar el nombre (minúsculas, sin espacios, separados por comas); el mensaje muestra los válidos. |
| Mac: "xcrun"/"developer tools" | No hace falta; si macOS lo ofrece, se puede cancelar. Solo usa `curl`, `unzip` y `bash` del sistema. |

Para casos raros, pedir al cliente el archivo `.log` de la carpeta de registros.

## 7. Deshacer / quitar el PIN

- **Quitar el PIN:** correr la línea con `sinpin` deja el PIN que ya existía; para borrarlo:
  `adb shell run-as com.ivantrj.glasslauncher rm files/pin.txt`
- **Devolver el botón Inicio al launcher anterior:** los valores originales están en `respaldos/<ip>-<fecha>/antes.txt`:
  `adb shell settings put secure enabled_accessibility_services '<valor de antes>'`
  (si antes decía `null`: `adb shell settings delete secure enabled_accessibility_services`).
- **Quitar Luk Home por completo:** Ajustes → Aplicaciones → Luk Home → Desinstalar (o `adb uninstall com.ivantrj.glasslauncher`).

## 8. Contenido del repo

```
install.sh            instalador Mac (bash 3.2+, también Linux)
install.ps1           instalador Windows (PowerShell 5.1+, solo ASCII)
CLIENTE.md            pasos para el cliente
bundle/
  apks/luk-home.apk         Fire OS 8 / Google TV (API 30+)
  apks/luk-home-fos7.apk    Fire OS 7 (API 28-29)
  apks/luk-home-fos6.apk    Fire OS 6 (API 25-27)
  SHA256SUMS, VERSION
  tv-apply.sh               se ejecuta en el TV; copia los archivos dentro de Luk Home con run-as
  themes/<8 temas>/ (10 JPG + name.txt) y order.txt (temas incluidos para todos)
  themes/<personalizado>/   temas de clientes (fotos + name.txt), fuera de order.txt
  tiles/<paquete>.png + .txt   íconos y nombres personalizados
  logo.png                  logo de la marca (Coplic), arriba a la derecha debajo de Temas/Ajustes
  rotate.txt                20 (segundos)
  retroarch/                --retroarch: tv-retroarch.sh (corre en el TV), cores.txt, ext/retroarch.cfg,
                            ext/autoconfig/ (mandos), ra/config/*/*.opt, ra/system/mame2003-plus/hiscore.dat
                            (el APK y los núcleos se bajan de buildbot.libretro.com; sin ROMs ni BIOS)
  kodi/kodi-sala.sh         --kodi en Mac (el instalador del Kodi de la sala); el build va en el Release kodi-build-2026-11-10
```

Los tres APK son compilaciones *debug* firmadas con la misma llave (necesario para `run-as`). Al actualizar un APK: reemplazarlo en `bundle/apks/`, regenerar `bundle/SHA256SUMS` (`cd bundle && shasum -a 256 apks/*.apk logo.png > SHA256SUMS`) y hacer push. GitHub puede tardar ~5 min en servir el archivo nuevo.

## Cambios

- **2026-11-11a:** Temas personalizados nuevos **`barcelona-cule`** (botón Temas: "Barcelona culé") e **`inter-miami-messi`**
  (botón Temas: "Inter Miami Messi"). Cada uno tiene 10 fondos 1920×1080. No están en `order.txt` ni en las líneas
  genéricas de copiar y pegar: un cliente genérico no los recibe. Se piden por nombre (`barcelona-cule`, `inter-miami-messi`,
  o con coma final `barcelona-cule,` / `inter-miami-messi,` para instalar solo ese). Los APK, `SHA256SUMS`, el paso 8
  (Troypoint, Stremio, TizenTube) y las opciones no cambian.
- **2026-11-10c:** El build de Kodi de `--kodi` (Windows `$KODI=1;`) ahora es el del **TV del cuarto** (onn 4K Pro,
  192.168.0.249), tomado el 2026-11-10 en solo lectura: Release **`kodi-build-2026-11-10`**, `kodi-sala.zip` de
  303.572.756 bytes, sha256 `67e4e8dd…0eca`. Trae el menú principal del cuarto (Películas / series, Deportes live,
  Repeticiones, TV, Anime / novelas, Juegos, Ajustes, X) con sus submenús, `game.controller.remote` 1.0.33 y la lista de
  decodificadores de la onn; los otros 109 addons, repos y skin tienen las mismas versiones que el build de la sala.
  Sin cuentas (TorBox se vuelve a iniciar en POV, Umbrella y ResolveURL), sin partidas guardadas, ROMs ni BIOS. El
  build anterior (`kodi-build-2026-11-09`) sigue publicado. Los APK de Luk Home (2026-11-10b), `SHA256SUMS`, temas,
  `--retroarch` y los pasos 1–9 no cambian.
- **2026-11-10b:** Luk Home nuevo (los 3 APK, versión `2026-11-10b`, versionCode 2026111002, misma firma: se
  actualiza encima y conserva PIN, inicio, temas y ajustes). **Mantener OK** en una app del inicio ya no pide el PIN
  directo: abre un menú con **Borrar caché** (abre la info de esa app: forzar detención / borrar caché, **sin PIN**,
  igual que la tecla Menú corta) y **Editar inicio** (pide el PIN como antes y abre el menú de edición). Así los
  controles sin tecla Menú (onn / Google TV) también pueden borrar la caché. La tecla Info (si el control la tiene) hace
  lo mismo que Menú corta. La info de **Luk Home** nunca se abre sin PIN (ni desde el menú ni llegando por la lista de
  apps de Fire OS): forzar su detención quitaría el bloqueo y borrar sus datos borraría el PIN. Ojo: en la info de la app
  el cliente también ve "Borrar datos" (borra el login de esa app). Lo demás (pasos 1–10, temas, `--retroarch`, `--kodi`)
  no cambia.
- **2026-11-10a:** Dos opciones nuevas, **apagadas por defecto** (sin ellas todo funciona igual que en 2026-11-07a):
  `--retroarch` (Windows `$RETROARCH=1;`) instala o actualiza RetroArch 1.22.2 oficial con la configuración del TV del
  cuarto (cfg, 7 núcleos oficiales, opciones de FCEUmm / MAME 2003-Plus, mandos, hiscore.dat, carpetas de juegos vacías en
  `/sdcard/ROMs`; sin ROMs ni BIOS; Play Protect: Más detalles > Instalar de todas formas), y `--kodi` (Windows `$KODI=1;`,
  `--reemplazar-kodi` / `$KODIREEMPLAZAR=1;`) instala Kodi 21.3 con el build de la sala desde el Release
  `kodi-build-2026-11-09` (sha256 fijo; TorBox se vuelve a iniciar en POV, Umbrella y ResolveURL). Pasos 9 y 10. Nuevos
  `bundle/retroarch/` y `bundle/kodi/`. Los APK de Luk Home, temas, `SHA256SUMS` y el paso 8 no cambian.
- **2026-11-07a:** Temas personalizados nuevos **`barcelona`** (botón Temas: "Barcelona") y **`real-madrid-3`**
  (botón Temas: "Real Madrid Amiga"). Cada uno tiene 10 fondos 1920×1080. No están en `order.txt` ni en las líneas
  genéricas de copiar y pegar: un cliente genérico no los recibe. Se piden por nombre (`barcelona`, `real-madrid-3`,
  o `barcelona,real-madrid-3`). Los APK, `SHA256SUMS`, el paso 8 (Troypoint, Stremio, TizenTube) y las opciones
  (`--sin-apps`, `--sin-actualizar`, `--bloquear-botones`, `--estilo`) no cambian.
- **2026-11-03b:** **IPTV Smarters ahora es la gratis de Troypoint.** La de `iptvsmarters.com` / `smartersott.app` (4.0.6,
  de pago) no funcionaba: esas fuentes se quitaron. El paso 8 lee en cada corrida el enlace de IPTV Smarters del Troypoint
  Toolbox (MediaFire) y usa la 3.1.5.1 fija (sha256 `2791f534…a5dbdc`), o una más nueva de Troypoint solo si tiene la misma
  firma. Si falta, se instala; si ya es de Troypoint y hay una más nueva, `adb install -r` (conserva login y listas); si es
  otra (p. ej. la 4.0.6 de pago), se cambia: copia en la computadora, desinstalar, instalar la de Troypoint (se borran su
  login y sus listas; si falla, vuelve la copia). Sin opciones nuevas. Stremio y TizenTube sin cambios (fuentes oficiales).
- **2026-11-03a:** **El paso 8 también instala las que faltan.** Stremio, IPTV Smarters y TizenTube: si ya están se
  actualizan (como antes, `adb install -r`, solo a una oficial más nueva); si **no están**, se descarga la oficial (mismas
  fuentes y sha256) y se instala con `adb install -g`, con la arquitectura del TV (`ro.product.cpu.abi`; si rechaza 64 bits,
  32 bits) y respetando el `minSdk` (prueba versiones oficiales anteriores o avisa y la salta). Las nuevas se **agregan al
  dock** de Luk Home y Luk Home vuelve a la pantalla. Un fallo de una app nunca para la instalación. Nueva opción
  `--sin-apps` (o `LUK_SINAPPS=1`; Windows `$SINAPPS=1;`) para no instalar las que faltan; `--sin-actualizar` /
  `$NOUPDATE=1` ahora solo frena las actualizaciones (las que faltan se instalan igual). IPTV Smarters 5.0 agregado a los
  sha256 conocidos. Ninguna otra app del cliente se toca. Los APK de Luk Home y los temas no cambian.

- **2026-11-02e:** Tema personalizado nuevo **`real-madrid-2`** (botón Temas: "Real Madrid 2"), 10 fondos 1920×1080:
  las 8 fotos del club de `real-madrid` sin cambios y 2 fotos nuevas de otro amigo (`01-amigo2-bernabeu-familia.jpg`,
  con su niño en hombros en el Bernabéu, y `02-amigo2-champions.jpg`, levantando la Champions). `real-madrid` no cambia.
  No está en `order.txt`: solo llega a los TV cuya línea lo nombra. Las líneas para copiar lo traen después de `real-madrid`
  (bórralo si no es para ese cliente). Los APK y los scripts no cambian.

- **2026-11-02d:** **Opción de estilo: Oscuro o Colores.** En el botón de Temas hay una sección nueva **Estilo** con
  **Oscuro** (las tarjetas grafito con logo blanco y foco verde de 2026-11-02c) y **Colores** (las tarjetas de colores de
  2026-11-01h: rayas, brillo y el logo en una bolita). Cambia al momento, sin PIN, y se guarda (`files/dock-style.txt`).
  Nuevo `--estilo=oscuro|colores` (Windows `$ESTILO='oscuro'|'colores'`); sin la opción el TV se queda como esté (nuevo = Oscuro).
  APK nuevos (misma firma; se conservan datos, tema, PIN y dock).
- **2026-11-02c:** **Esquinas de las tarjetas arregladas.** Detrás de cada tarjeta del inicio se veía un "pico"
  cuadrado en las esquinas (sobre todo arriba), porque el relleno de la tarjeta no se recortaba a la forma redondeada;
  solo el borde fino era redondo. Ahora todo (relleno, degradados, brillo, borde y foco verde) usa la misma esquina
  redondeada y no se ve nada cuadrado. Nada más cambia. APK nuevos (misma firma; se actualizan con `adb install -r`,
  conservan tema, PIN, dock y ajustes).
- **2026-11-02b:** **Foco verde también en el logo.** Al seleccionar una app del inicio, además del borde verde
  luminoso, el **logo de la app se pinta del mismo verde** (los logos oficiales blancos y la silueta blanca de las demás
  apps). Aparece suave en ~0.3 s junto con el borde y vuelve a blanco al salir. Nada más cambia. APK nuevos (misma
  firma; se actualizan con `adb install -r`, conservan tema, PIN, dock y ajustes).
- **2026-11-02a:** **Dock nuevo "cálido" (diseño calido-b, tamaño B).** Todas las apps del inicio son ahora tarjetas
  iguales de vidrio ahumado grafito cálido (196×122 px a 1080p, separación ~22 px): degradado más claro arriba y más
  oscuro abajo, brillo suave arriba, sombra suave debajo y un borde fino luminoso más claro arriba. Se quitaron la
  paleta de colores, las franjas, la burbuja y los colores por app; también los tiles personalizados se muestran como
  tarjeta. En cada tarjeta va el logo oficial en blanco (~45 % de la altura; incluidos en el APK para Stremio, Nuvio,
  TizenTube, IPTV Smarters, Prime Video, HBO Max, Kodi, SmartTube, Surfshark, Netflix, YouTube, Disney+, Hulu,
  Paramount+, Spotify, Plex, Pluto TV, Crunchyroll, Tubi, Twitch, Apple TV y YouTube Music; las demás apps usan la
  silueta blanca de su ícono) y el nombre en letra blanca pequeña debajo. La barra del dock tiene un tinte cálido con
  borde fino claro. **Foco:** borde verde luminoso con resplandor y la tarjeta crece a 1.08×; el resplandor aparece en
  ~0.3 s, "respira" suave cada ~2 s y se apaga al salir; el resaltado de vidrio conserva su movimiento con resorte.
  **Nuevo `--bloquear-botones` / `$BOTONES='bloquear'`** (ver "Botones de apps del control"). APK nuevos (misma firma;
  se actualizan con `adb install -r`, conservan tema, PIN, dock y ajustes).
- **2026-11-01h:** **Cada tile de un color distinto.** Las apps del dock sin tile propio ya no toman el color de su
  ícono tal cual (Prime Video, Kodi y Surfshark salían del mismo azul/turquesa): ahora salen de una paleta de
  degradados (naranja, amarillo, lima, verde, turquesa, celeste, azul, índigo, morado, magenta, rosa, rojo y plateado).
  Los tiles propios conservan su color y reservan el de la paleta más parecido (Películas y Series naranja, Movies & TV
  verde, YouTube Premium morado, Live TV azul, YouTube rojo); las demás apps se reparten los colores libres de modo que
  ningún color se repite y los más parecidos del inicio queden lo más distintos posible a la vista (más aún entre
  vecinos). Siempre el mismo color para el mismo dock. En la TV de la sala: Prime Video rosa, HBO Max plateado, Kodi
  magenta, Surfshark lima. El resto igual que 11-01g (franjas, brillo, reflejo, logo sin su fondo). APK nuevos (misma
  firma; se conservan dock, PIN y temas): `luk-home.apk` `881a1feb…dc73fd4d`, `luk-home-fos7.apk` `c4f7e71e…2122a481`, `luk-home-fos6.apk` `f9bcb94f…cc631cb9`.

- **2026-11-01g:** **Vuelve el marco con estilo; el logo sin su fondo.** Se deshace lo transparente de 11-01f: las apps del
  dock sin tile propio vuelven a tener el fondo de color, las franjas, el brillo y el reflejo de 11-01e. Lo único que
  cambia es dentro de la burbuja redonda: ya no sale el cuadrito de fondo del ícono de la app (p. ej. el azul oscuro/negro
  de HBO Max, el azul de Prime Video o de Surfshark), solo el logo/las letras con una sombra suave. Íconos adaptativos:
  se usa la capa del logo; íconos normales: se borra el color plano o degradado del borde; si no se puede separar bien,
  el ícono se recorta en círculo. Los tiles propios no cambian. APK nuevos (misma firma; se conservan dock, PIN y temas):
  `luk-home.apk` `27335e20…e2314e86`, `luk-home-fos7.apk` `2d5cce7b…c94d976c`, `luk-home-fos6.apk` `4e3ddfb8…163d6649`.

- **2026-11-01f:** **Apps sin tile propio, ahora transparentes.** *(revertido en 11-01g)* Las apps del dock que no traen tile propio (p. ej. Prime Video,
  HBO Max, Kodi) ya no llevan fondo de color ni franjas: el tile es transparente y solo se ve la burbuja redonda con el logo
  de la app dentro (el logo tal cual) y su nombre debajo. Al seleccionarla se agranda y sale el recuadro de cristal, como
  las demás. Los tiles propios (Stremio, Smarters, TizenTube y los de `files/tiles/`) no cambian. Se apaga con `off` en
  `files/tiles-style.txt`. APK nuevos (misma firma; se conservan dock, PIN y temas):
  `luk-home.apk` `3b4d48ce…f28753de`, `luk-home-fos7.apk` `56248788…37d999d8`, `luk-home-fos6.apk` `beb5f2e7…34d23d05`.

- **2026-11-01e:** **Apps extra en el inicio** (APPS, 5.º valor / `--apps` / `APPS=`; Windows `$APPS='netflix,youtube';`):
  nombres fáciles (Fire TV y Google TV), nombre de paquete o `todas`; van después de Stremio / IPTV Smarters / TizenTube,
  sin repetir; las que falten se saltan con aviso. No instala ni quita apps. CIUDAD acepta `-` para no tocarla.
  **Marco con estilo**: las apps del dock sin tile propio salen con el mismo marco (franjas, brillo y reflejo) y su ícono real
  en el centro (sin cambiar el ícono). Se apaga con `off` en `files/tiles-style.txt` del TV.
  **Botón Temas**: dos filas nuevas al final, **Aleatorio** (fotos de todos los temas mezcladas, cada 20 s) y **Rotar temas**
  (un tema completo cada hora, en orden; cada 20 s cambia la foto dentro del tema). Se guardan como un tema normal (siguen
  tras reiniciar). Minutos por tema en `files/theme-rotate.txt` (5–10080, por defecto 60). El instalador los pone con
  `aleatorio` o `rotar` como tema (solos o primero en la lista). APK nuevos (misma firma; se conservan dock, PIN y temas):
  `luk-home.apk` `7c2bea28…47f7e8db`, `luk-home-fos7.apk` `fbc3c149…5952f8f9`, `luk-home-fos6.apk` `7845cd3c…5568314f`.

- **2026-11-01d:** **Tiempo en vivo.** Nuevo botón del clima arriba a la derecha (ícono + temperatura, p. ej. `79°`), antes de
  Temas / red / Ajustes. Al pulsarlo abre una tarjeta (fondo azul grisáceo): ciudad en mayúsculas, temperatura grande,
  condición, "Sensación", calidad del aire (AQI), 3 días, botón blanco **Cambiar ciudad** y "Actualizado h:mm · Open-Meteo".
  Datos de Open-Meteo sin clave; ciudad automática por IP o elegida en el TV (lista o **Buscar ciudad…**); °F en EE. UU., °C
  en el resto; se refresca cada 30 min y al volver la conexión; sin internet muestra lo último guardado sin errores.
  **CIUDAD opcional** en el instalador (4.º valor o `CIUDAD=` en Mac, `$CIUDAD=` en Windows) → `files/weather.txt`.
  Luk Home pide ahora el permiso INTERNET (solo para el tiempo). Nuevos `luk-home.apk`, `luk-home-fos7.apk` y
  `luk-home-fos6.apk` (misma firma: se conservan dock, PIN y temas): `11c80769…74a40191`,
  `edd18dbc…140b328d`, `7571de10…aa70f1e1` (ver `bundle/SHA256SUMS`).
- **2026-11-01c:** El tema `halloween-terror` ahora se llama **`terror`** (botón Temas: "Terror"); mismas 10 fotos.
  `halloween-terror`, `halloween` y `horror` siguen valiendo como nombres viejos y dan `terror`. Al repetir el instalador en
  un TV que tenía la carpeta `halloween-terror`, se reemplaza por `terror` (no quedan las dos), el tema elegido en el TV pasa
  a `terror` si era ese, y el registro `.instalador.txt` queda con el nombre nuevo. Las líneas para copiar (arriba y en el
  paso 1) traen ahora **todos los temas** (`real-madrid,real-madrid-2,navidad,terror,…`) para borrar los que no se quieran. Los APK no cambian.
- **2026-11-01b:** Dos temas personalizados nuevos (10 fondos cada uno, 1920×1080): `real-madrid` (Real Madrid) y
  `navidad` (Navidad). No están en `order.txt`: solo llegan a los TV cuya línea los nombra. **Botones solo íconos:** los
  tres botones de arriba a la derecha (Temas, red y Ajustes) ahora son círculos con solo el ícono, sin palabras, con un
  aro claro cuando el control está encima. El ícono de **red** está **verde** si el TV tiene conexión (Wi-Fi o cable) y
  **rojo con una raya** si no la tiene; cambia solo al momento. Todo lo demás igual (menú de Temas, PIN de Ajustes, el
  botón de red abre los ajustes de Wi-Fi, el logo sigue alineado con Ajustes). Nuevos `luk-home.apk`, `luk-home-fos7.apk`
  y `luk-home-fos6.apk` (misma firma: al actualizar se conservan el dock, el PIN y los temas): `62d46ff8…b24b154`,
  `6dcaf0d2…6c17904a`, `c6e4b65e…c9f555a` (ver `bundle/SHA256SUMS`). Sin cambios en los scripts.
- **2026-11-01a:** **Actualización de apps** (paso 8 nuevo): si Stremio, IPTV Smarters o TizenTube ya están instaladas y
  hay una versión oficial más nueva, se actualizan con `adb install -r` (sin perder datos ni sesiones). Nunca instala apps
  que falten, nunca desinstala ni baja de versión; con firma distinta solo avisa. Se salta con `--sin-actualizar` /
  `$NOUPDATE=1`. Resumen `Apps: …` al final. **Temas por cliente:** el tema puede ser una lista (`autos,mar,espacio`:
  solo esos, el primero es el inicial; `todos` = todos), y se pueden poner temas personalizados en `bundle/themes/<nombre>/`.
  Un nombre de tema equivocado ahora da error con la lista de válidos (antes caía a `paisajes`). Al repetir con una lista,
  se borran del TV solo los temas que puso el instalador y ya no van. Los APK de Luk Home no cambian.

- **2026-10-31d:** Soporte para **Fire OS 6** (API 25–27; p. ej. Fire TV Stick 4K de 1.a generación "AFTMM"). Nuevo
  `bundle/apks/luk-home-fos6.apk` (mismo Luk Home: dock, fondos que rotan, 8 temas, íconos, logo, PIN). En Fire OS 6
  Amazon no permite el servicio de accesibilidad, así que el botón Inicio funciona con el **acceso de uso**
  (`GET_USAGE_STATS`), que el instalador da en el paso 6 y devuelve si algo falla. API 28–29 sigue con `luk-home-fos7.apk`,
  30+ con `luk-home.apk`; por debajo de 25 sale el mensaje "demasiado viejo". Probado en un AFTMM con Fire OS 6.7.1.1.
- **2026-10-31c:** Logo **Coplic** en el inicio de Luk Home, arriba a la derecha, debajo de Temas / Wi-Fi / Ajustes y
  alineado con Ajustes. El instalador copia `bundle/logo.png` a `files/logo.png` dentro de Luk Home. Para cambiarlo, reemplaza
  `bundle/logo.png` (PNG transparente, ~26 KB; se muestra a 52dp de alto); para quitarlo en un TV:
  `adb shell run-as com.ivantrj.glasslauncher rm files/logo.png` (sin archivo no se muestra nada). Si borras `bundle/logo.png`
  del repo, el instalador no pone logo. APKs nuevos: `luk-home.apk` `3d5ed036…ba88bdf`, `luk-home-fos7.apk` `2ca08d7a…f609352d`.
  Volver a correr la línea del cliente actualiza Luk Home y pone el logo sin borrar nada.
- **2026-10-31b:** Luk Home ya no se va al inicio cuando una app se actualiza sola (TizenTube, Downloader…). El instalador de
  Android abría la pantalla "Instalar apps desconocidas" y el bloqueo de Ajustes con PIN la cerraba. Ahora esa pantalla pasa
  sin PIN solo cuando la abre el instalador. Si un TV ya tuvo el problema, reinícialo una vez después de actualizar.
  APKs nuevos: `luk-home.apk` `3c8bb3a3…f444615`, `luk-home-fos7.apk` `45b0ec0b…4509573`. Volver a correr la línea del
  cliente actualiza Luk Home sin borrar nada (`install -r -g`, misma llave).
