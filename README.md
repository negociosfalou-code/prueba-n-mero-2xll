# Smallville Offline

Pueblo con **25 agentes autónomos** inspirado en el proyecto *Generative Agents*
(Stanford "Smallville"), ejecutado **100% offline** en el dispositivo.
Sin internet, sin permisos, sin cuentas.

- **Motor:** Godot 4.3+ (renderizador GL Compatibility, ideal para móvil).
- **Mini-LLM local:** modelo de trigramas entrenado al arrancar sobre un corpus
  embebido en español; genera diálogos y pensamientos de los agentes en el
  dispositivo, sin servidor ni conexión.
- **Simulación:** rutinas diarias por hora para cada agente (dormir, trabajar,
  comer en el Café Hobbs, pasear por el parque, estudiar en la biblioteca),
  memoria de hasta 60 recuerdos, relaciones entre habitantes y conversaciones
  espontáneas con globos de diálogo.
- **Jugador:** toca el mapa para mover a tu agente, toca un habitante para ver
  su memoria, relaciones y actividad; cambia de agente controlado cuando quieras.

## Requisitos objetivo

- Android 12 (API 31) — funciona también en versiones cercanas.
- 8 GB de RAM recomendados; el juego consume muy poco (< 150 MB).
- Sin permisos: no usa red, almacenamiento ni ubicación.

## Cómo abrir el proyecto

1. Instala [Godot 4.3+](https://godotengine.org/download) (versión estándar).
2. Abre Godot → **Importar** → selecciona la carpeta de este repositorio
   (el archivo `project.godot`).
3. Pulsa **Play** (F5) para probar en escritorio.

## Cómo generar el APK para Android 12

Resumen; la guía completa está en [docs/EXPORTAR_ANDROID.md](docs/EXPORTAR_ANDROID.md).

1. Instala Android Studio (o solo el SDK + JDK 17).
2. En Godot: `Editor → Manage Export Templates` → descarga las plantillas.
3. `Editor → Editor Settings → Export → Android`: configura el SDK y el keystore.
4. `Project → Export… → Android → Export Project` para generar `builds/SmallvilleOffline.apk`.
5. Copia el APK al móvil e instálalo (activa "Instalar apps de fuentes desconocidas").

## Controles

| Acción | Móvil | Escritorio |
|---|---|---|
| Mover tu agente | Toque en el mapa | Clic en el mapa |
| Seleccionar habitante | Toque sobre él | Clic sobre él |
| Mover cámara | Arrastrar | Arrastrar |
| Zoom | Pellizco / botones ＋－ | Botones ＋－ |
| Pausa / reanudar | Botones ▶ ⏸ | Barra espaciadora |
| Ver info de agente | Panel derecho | `Esc` oculta/muestra |
| Dar una idea a un agente | Ficha → campo "Darle una idea" | Igual + Enter |

## Estructura

```
project.godot            Configuración del proyecto (Godot 4.3)
scenes/Main.tscn         Escena principal
scripts/main.gd          Bucle de simulación, conversaciones, cámara y entrada
scripts/town_map.gd      Mapa en cuadrícula, edificios y pathfinding A*
scripts/agent.gd         Habitante autónomo: rutina, memoria, relaciones
scripts/mini_llm.gd      Mini modelo de lenguaje local (trigramas) + plantillas
scripts/game_time.gd     Reloj del mundo (autoload "Game")
scripts/personas.gd      Los 25 habitantes
scripts/ui/hud.gd        Interfaz: reloj, velocidad, panel de agente, registro
docs/EXPORTAR_ANDROID.md Guía de exportación a APK
docs/COMO_JUGAR.md       Guía de juego
```
