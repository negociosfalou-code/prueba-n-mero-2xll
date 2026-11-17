# Exportar el APK para Android 12

Guía paso a paso para generar e instalar el juego en un Android 12
(también válido para Android 10–14).

## 1. Instalar herramientas

1. **Godot 4.3 o superior** (versión estándar, no .NET):
   <https://godotengine.org/download>
2. **JDK 17** (viene con Android Studio).
3. **Android SDK**: lo más fácil es instalar
   [Android Studio](https://developer.android.com/studio) y, desde su asistente,
   instalar "Android SDK Platform" 34 y "SDK Build-Tools".

## 2. Configurar Godot

1. Abre el proyecto (carpeta con `project.godot`).
2. `Editor → Manage Export Templates…` → **Download and Install**.
   (Descarga ~1 GB, solo una vez.)
3. `Editor → Editor Settings → Export → Android`:
   - **Java SDK Path**: la ruta del JDK 17.
   - **Android SDK Path**: normalmente `C:/Users/TU_USUARIO/AppData/Local/Android/Sdk`
     en Windows o `~/Android/Sdk` en Linux/macOS.
   - Godot detectará el debug keystore automáticamente.

## 3. Exportar

1. `Project → Export…` → selecciona el preset **Android** (ya viene creado).
2. Conecta el móvil con **Depuración USB** activada y pulsa
   **One-click Deploy**, o bien pulsa **Export Project** para guardar
   `builds/SmallvilleOffline.apk`.
3. Para release firmado: en el preset, sección *Keystore*, crea un keystore con
   `keytool -genkeypair -v -keystore mi_clave.keystore -alias mi_alias -keyalg RSA -keysize 2048 -validity 10000`.

## 4. Instalar en el móvil

1. Copia el APK al teléfono (cable, Drive, etc.).
2. Al abrirlo, acepta "Instalar de fuentes desconocidas" si lo pide.
3. El juego no pide ningún permiso y funciona sin conexión.

## Notas

- El proyecto usa el renderizador **GL Compatibility**, el más compatible con
  GPUs móviles.
- `architectures/arm64-v8a` está activado (todos los móviles modernos);
  `armeabi-v7a` también, por si tu móvil es antiguo.
- El juego no necesita internet en ningún momento: el mini-LLM se entrena al
  arrancar con un corpus incluido en el propio juego.
