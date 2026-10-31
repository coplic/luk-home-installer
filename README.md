# Luk Home — instalador para clientes

Instala el launcher **Luk Home** en el Fire TV / Google TV de un cliente desde **su** computadora (Mac o Windows), con una sola línea.
Modo **solo launcher**: no borra apps, no desinstala nada (tampoco Projectivy u otros launchers), no cambia ajustes de otras apps.

## 1. Qué le mandas al cliente

1. El archivo **[CLIENTE.md](CLIENTE.md)** (o su texto), con los 4 pasos que verá.
2. **La línea de su sistema**, ya con **su IP y su PIN** puestos (cambia `192.168.1.50` y `1234`):

**Mac** (app Terminal):
```bash
curl -fsSL https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.sh | bash -s -- 192.168.1.50 1234 paisajes
```

**Windows** (PowerShell normal, sin administrador; es una sola línea):
```powershell
$IP='192.168.1.50'; $PIN='1234'; $THEME='paisajes'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/coplic/luk-home-installer/main/install.ps1 | iex
```

- **IP**: la del TV del cliente (ver abajo).
- **PIN**: 4 números, protege Ajustes de Luk Home. En Windows **siempre entre comillas** (`'0123'`) para no perder ceros. Para no poner PIN: `sinpin`.
- **Tema** (opcional, por defecto `paisajes`): `paisajes`, `mar`, `espacio`, `autos`, `animales`, `barcos`, `american-sports`, `halloween-terror`.
  En Mac va como 3.er valor; en Windows `$THEME='mar';` (o quítalo).

Extras opcionales:

| Qué | Mac (al final de la línea) | Windows (antes de `irm`) |
|---|---|---|
| Probar sin cambiar nada en el TV | `--simular` (o `--dry-run`) | `$DRYRUN=1;` |
| Rehacer el dock aunque ya exista | `--nuevo-dock` | `$NUEVODOCK=1;` |

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

## 4. Qué hace el script (pasos 1–7)

1. **Herramientas**: descarga las *platform-tools* oficiales de Google (`dl.google.com/android/repository/platform-tools-latest-{darwin,windows}.zip`) a una carpeta del usuario (se reutilizan en la siguiente vez) y el paquete de este repo (`github.com/coplic/luk-home-installer/archive/refs/heads/main.zip`, ~18 MB: APKs + temas + íconos). Comprueba los APK con `bundle/SHA256SUMS`.
2. **Conexión**: `adb connect IP:5555`. Si el TV pide permiso, muestra el aviso grande y espera. Detecta TV apagado / IP equivocada / ADB apagado.
3. **Revisión (solo lectura)**: modelo, versión de Android (API), espacio libre, ajustes de accesibilidad y launcher actual, lista de apps. Guarda un **respaldo** en la computadora.
4. **Instala** el APK correcto con `adb install -r` (actualiza sin borrar datos; si ya está la misma versión, no hace nada):
   - API 25–27 (Fire OS 6, Android 7.1) → `luk-home-fos6.apk` (en Fire OS 6 no hay `sha256sum`: reinstalla siempre, sin borrar datos)
   - API 28–29 (Fire OS 7) → `luk-home-fos7.apk`
   - API 30 o más (Fire OS 8, Google TV) → `luk-home.apk`
5. **Archivos** dentro de Luk Home (solo su carpeta privada): los 8 temas, íconos personalizados de las apps instaladas, rotación de fondo cada 20 s, tema inicial, PIN y **dock** con solo Stremio, IPTV Smarters y TizenTube (las que estén instaladas; avisa cuáles faltan). Las demás apps quedan en "Otras apps".
6. **Botón Inicio**: activa el servicio de accesibilidad de Luk Home. Si otro launcher (p. ej. Projectivy) tenía ese servicio, **solo se reemplaza su entrada** (la app no se toca ni se desinstala); otros servicios de accesibilidad se conservan. En Google TV con un launcher de terceros como inicio, pone Luk Home como inicio.
   **Fire OS 6 (API 25–27):** Amazon no deja correr servicios de accesibilidad de apps instaladas por fuera, así que ahí no se toca la accesibilidad: se da a Luk Home el **acceso de uso** (`appops set com.ivantrj.glasslauncher GET_USAGE_STATS allow`) y Luk Home vigila qué app está al frente.
7. **Comprueba** ajustes, temas y PIN, abre Luk Home, pulsa Inicio y muestra **LISTO**.

Si algo falla después del paso 6, **devuelve los ajustes del botón Inicio (y el acceso de uso en Fire OS 6) como estaban** antes de salir.

**Se puede repetir sin problema** (idempotente): no reinstala si ya está igual, **no pisa el dock** ni el tema que el cliente ya tenga (salvo `--nuevo-dock` o pasar un tema explícito), actualiza temas/íconos y el PIN.

## 5. Dónde quedan respaldos y registros (en la computadora del cliente)

| | Mac | Windows |
|---|---|---|
| Carpeta | `~/.luk-home/` | `%LOCALAPPDATA%\LukHome\` |
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
  themes/<8 temas>/ (10 JPG + name.txt) y order.txt
  tiles/<paquete>.png + .txt   íconos y nombres personalizados
  logo.png                  logo de la marca (Coplic), arriba a la derecha debajo de Temas/Ajustes
  rotate.txt                20 (segundos)
```

Los tres APK son compilaciones *debug* firmadas con la misma llave (necesario para `run-as`). Al actualizar un APK: reemplazarlo en `bundle/apks/`, regenerar `bundle/SHA256SUMS` (`cd bundle && shasum -a 256 apks/*.apk logo.png > SHA256SUMS`) y hacer push. GitHub puede tardar ~5 min en servir el archivo nuevo.

## Cambios

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
