<p align="center">
  <a href="CHANGELOG.md">English</a> · <b>Español</b>
</p>

# Registro de cambios

Todas las versiones de unattended-dev, desde la primera. Desde la 8.1.1
son públicas y cada una tiene su
[release en GitHub](https://github.com/Aresdgi/unattended-dev/releases).
Las anteriores vivían en un repo privado y con otros nombres:
`modo-nocturno` (1 y 2) y `modo-desatendido` (de la 3 a la 8.1.0).

## [8.8.0] - 2026-10-08

Candados. Las reglas que impiden que llegue a DONE trabajo roto o
manipulado las hace cumplir `queue.sh`, no el orquestador: si un worker o
el orquestador se equivocan, el comando se niega con un código de salida
claro.

### Añadido
- `queue.sh qa <tarea> <tipo> PASS|FAIL "<resumen>"` registra un
  veredicto de QA para el código exacto que revisó.
- `queue.sh outside <tarea>` lista los archivos que una tarea cambió desde
  que empezó (con commit o sin él) y que no puede tocar, y
  `queue.sh restore-outside <tarea>` los devuelve a su estado, con una
  copia en una rama de copia.
- `con-limite.sh`: límite de tiempo para cualquier comando, que para todo
  su grupo de procesos, también lo que el comando deja en segundo plano
  al terminar. Lo usan `lanzar-worker.sh` y `bucle.sh`.
- La fase cero deja el gate en `.desatendido/gate.sh` y los archivos que
  puede tocar cada tarea en `.desatendido/allowed/Txx` (y
  `.desatendido/qa/Txx` para las tareas que necesitan QA de diseño).

### Cambiado
- `queue.sh done` comprueba antes de cerrar: nada fuera de la tarea
  (sale con 6), el gate pasa y no cambia ningún archivo, lo que hay en
  staging ni hace commit, ejecutado por el propio `done` (sale con 7), y hay un QA PASS de cada tipo para el código
  tal como está (sale con 8). Si se niega, la tarea sigue IN PROGRESS y el
  árbol queda como estaba: lo que cambió el gate se devuelve. Así el
  commit de DONE es siempre el código que vio la QA. Si el gate cambia de
  rama, `done` se para con 4 sin mover ninguna referencia.
- Mientras una tarea está IN PROGRESS, `STATUS.md` y `docs/DECISIONES.md`
  tienen que estar exactamente como los dejó `queue.sh`. Si no, `fix`,
  `decide`, `note`, `qa` y `set` se niegan (salen con 6) en vez de hacer
  commit del cambio de otro, y `recover` rehace la tabla aunque un worker
  la haya vaciado o borrado.
- `queue.sh start` se niega si una dependencia no está DONE, si hay otra
  tarea IN PROGRESS o si la tarea no tiene lista de archivos permitidos.
- `block` y `recover` guardan el trabajo de la tarea en una rama
  `queue/backup/<tarea>-<fecha>` en vez de un stash, y devuelven todos los
  archivos que tocó la tarea a como estaban al empezar, incluido lo que el
  worker llegó a commitear. La historia no se reescribe.
- `bucle.sh` corta cada vuelta a los `ROUND_TIMEOUT` segundos (1 hora por
  defecto) o al tiempo que quede de `MAX_HOURS`; la tarea vuelve a PENDING
  y el bucle se para con 124.
- El gate ejecuta los tests de aceptación por su nombre, tiene que fallar
  si no ejecuta ninguno y no puede cambiar archivos. La fase cero
  comprueba las dos cosas: excluye un momento la carpeta de aceptación, y
  ejecuta el gate dos veces sobre un árbol limpio con `git status` vacío.
- `queue.sh set` se apunta en el Log y solo admite PENDING y BLOCKED: DONE
  pasa siempre por `done`, IN PROGRESS por `start`.
- Los commits de `queue.sh` que solo llevan `STATUS.md` o
  `docs/DECISIONES.md` se saltan los hooks de git del proyecto; `done`,
  `block`, `recover` y `restore-outside`, que llevan código, los ejecutan.
- La fase cero mete en `.gitignore` `.DS_Store`, los archivos de
  intercambio de los editores (`*.swp`, `*~`), `.vite/`, `__pycache__/` y
  `coverage/`, para que nunca cuenten como fuera de tarea, y una tarea que
  necesita una dependencia de desarrollo lista `package.json` y el
  lockfile entre sus archivos.
- El orquestador sigue los candados: registra cada veredicto de QA con
  `queue.sh qa`, devuelve los archivos de un worker que se salió de su
  tarea (`restore-outside`) antes del arreglo y ya no lanza el gate antes
  de `done`, que lo ejecuta él. Las salidas 6 y 7 de `done` van al camino
  del arreglo; con 8 repite la QA que se indica.
- Mientras trabaja un worker, `lanzar-worker.sh` y `vigilar-worker.sh`
  ponen también `.desatendido/` en solo lectura, para que un worker no
  pueda cambiar los scripts que juzgan su trabajo.

### Corregido
- Un cambio fuera de tarea (por ejemplo `package.json` con un script de
  test que solo hace `exit 0`) sobrevivía a un arreglo y entraba en el
  commit de DONE, porque el segundo worker se medía contra el árbol que el
  primero ya había cambiado. Ahora cada tarea se mide contra el commit del
  que partió.
- `block` y `recover` solo guardaban en un stash los cambios sin commit:
  los commits de un worker se quedaban dentro, con el código roto.
- `done` cerraba una tarea sin que se hubieran ejecutado el gate ni la QA.
- `start` arrancaba una tarea cuya dependencia seguía PENDING.
- Una vuelta colgada de `bucle.sh` no se cortaba nunca, y `lanzadores.md`
  decía que `MAX_HOURS` la limitaba.
- Tras una sesión cortada entre `vigilar-worker.sh begin` y `end`, los
  tests se quedaban en solo lectura y `recover` fallaba. Ahora primero les
  devuelve el permiso de escritura.
- 353 tests.

### Limitaciones conocidas
- Si el propio gate ejecuta un comando de `queue.sh` que hace commit (por
  ejemplo `queue.sh note`), `done` devuelve HEAD y `STATUS.md` pero no el
  estado de confianza de la cola, y los siguientes comandos se niegan con
  6. Un gate solo debería llamar a `queue.sh tests`.
- Con `STATUS_FILE` o `DECISIONS_FILE` en una ruta con espacios, `recover`
  no puede devolver esos archivos. La fase cero usa siempre `STATUS.md` y
  `docs/DECISIONES.md`.
- Cambiar a otra rama que ya existía en el mismo worktree durante una
  tarea: `recover` aplica el estado de la cola de la rama en la que empezó
  la tarea y devuelve los archivos de la tarea a como estaban al empezar,
  en la rama nueva (antes guarda todo en una rama de copia).
- Los candados cazan errores, no sabotajes deliberados: un worker que se
  da permiso de escritura en `.desatendido/` y edita `queue.sh`, mueve
  `refs/worktree/queue-state` con `git update-ref` o reescribe la historia
  con `git reset --hard` puede saltárselos.

## [8.7.2] - 2026-10-08

Notas de la cola en el Log.

De la tercera ejecución real (un CLI para repartir gastos, con Orca): 7 de
7 tareas DONE en 36 minutos, una decisión tomada por su cuenta, arreglos
dentro del límite y el goal cerrado solo.

### Corregido
- El modo Orca pedía al orquestador apuntar en el Log el id del Run y
  cualquier diferencia de modelo, pero no puede editar STATUS.md y
  `queue.sh` no tenía comando para eso. Nuevo `queue.sh note "<texto>"`:
  añade una línea libre al Log y hace commit solo de STATUS.md.
- 132 tests.

## [8.7.1] - 2026-10-08

De la segunda ejecución real, con Orca como lanzador de workers: las 5
tareas DONE, todas las QA en PASS y ninguna decisión necesaria.

### Corregido
- El modo Orca comprobaba que corre dentro de una terminal de Orca con
  `caller.orcaSessionId` de `orca status --json`, que Orca 1.4.221 no
  muestra. Ahora comprueba `$ORCA_TERMINAL_HANDLE`, como ya hacía la
  referencia de lanzamiento.
- Las pestañas de workers que Orca conserva como tuyas (`user_takeover`)
  salen en el informe final, para que sepas cuáles cerrar.

## [8.7.0] - 2026-10-08

Un goal que siempre termina. En una ejecución real la cola terminó (3
DONE, 2 BLOCKED, gate en verde) pero la sesión siguió dando vueltas más de
veinte turnos: el `/goal` pedía que el trabajo se hubiera hecho "siguiendo
ORQUESTADOR.md" y leyendo "nada más", y tras un solo desliz eso ya no
podía cumplirse nunca.

### Corregido
- El `/goal` solo pide un estado final: `queue.sh summary` muestra 0
  PENDING y el gate pasa, o el orquestador tuvo que parar y dijo por qué,
  o se acabaron las horas. Cómo se hizo el trabajo no forma parte de él.
- El orquestador cuenta sus propios deslices una vez en el informe final y
  nunca revierte trabajo terminado ni espera respuesta para compensarlos.
- El primer prompt y la prueba en seco ya no dicen "nada más".

### Añadido
- Un fusible de tiempo que para la sesión al acabar las horas elegidas
  aunque su goal no termine nunca. Con "sin límite" queda a las 24 horas
  como red de seguridad.
- El límite de tiempo se pregunta al lanzar (unos 30 minutos por tarea
  por defecto), y el orquestador imprime la hora al empezar.
- Tests de que el goal es el mismo en las dos plantillas y solo pide un
  estado final. 124 tests.

## [8.6.0] - 2026-10-08

Autonomía proactiva y lo que enseñó la primera ejecución real. En ella (una
calculadora de ritmo, con Codex orquestando) 4 de 5 tareas se bloquearon
por un único hueco de la SPEC, el Log se quedó vacío, una tarea recibió 3
arreglos con un límite de 2 y el informe final salió en inglés.

### Añadido
- **Autonomía**, que se elige en la ronda del equipo. *Proactiva*
  (recomendada): ante un hueco de la SPEC el orquestador apunta la regla
  más prudente con `queue.sh decide` en `docs/DECISIONES.md` y sigue.
  *Conservadora*: bloquea la tarea con la pregunta. Lo que cambie el
  producto o no se pueda deshacer siempre se queda para ti.
- `queue.sh fix` cuenta los arreglos y avisa cuando no quedan (una decisión
  da uno más).
- La entrevista pregunta los límites de cada dato de entrada (mínimo,
  máximo, unidades y error).
- La fase cero añade una revisión adversarial de la SPEC por otro papel
  antes de escribir los tests, para cerrar los huecos contigo en una ronda.

### Cambiado
- `queue.sh` escribe él mismo cada línea del Log: inicio, arreglo,
  decisión, DONE, BLOCKED (con la dependencia que lo causó) e
  interrupciones.
- El orquestador informa en tu idioma y termina con las decisiones que
  tomó y las preguntas abiertas. La revisión empieza por las decisiones.
- 119 tests.

## [8.5.0] - 2026-10-08

Un modo Orca de verdad.

### Corregido
- Elegir Orca como lanzador de workers no servía de nada: la plantilla del
  orquestador tenía `lanzar-worker.sh` fijo, así que los workers iban por
  la CLI sin avisarte.

### Añadido
- El modo Orca sigue la guía de orquestación del propio Orca: una pestaña
  por worker para que los veas, los arreglos reutilizan la pestaña del
  implementador y las pestañas se cierran con `worker-release` en cuanto
  no hacen falta (al final no queda ninguna por liberar).
- `vigilar-worker.sh`: las protecciones de los workers (tests en solo
  lectura, archivos fuera de la tarea) en dos pasos, para workers que
  arrancan y terminan solos. `lanzar-worker.sh` también lo usa.

### Cambiado
- La plantilla del orquestador recibe solo el bloque de workers que
  elegiste (CLI u Orca). La fase cero mantiene esa elección, para y
  pregunta si no se puede usar y hace la prueba de humo con ella. La
  revisión lo comprueba.
- 92 tests.

## [8.4.0] - 2026-10-07

La cola solo hace commit de su propio trabajo.

### Cambiado
- `queue.sh start` no empieza una tarea si el árbol tiene cambios que no
  son de la cola, y dice cuáles, así que cerrar una tarea nunca se lleva
  archivos ajenos.
- `bucle.sh` comprueba lo mismo antes de cada ronda y para con un mensaje
  claro.
- Documentación: no edites la carpeta del proyecto mientras corre la cola;
  usa un worktree tuyo. Diagrama de cada tarea en el README, en SVG para
  que se vea en el móvil.
- 83 tests.

## [8.3.0] - 2026-10-07

Estado de la cola en commits y cierre atómico.

### Corregido
- Un stash podía devolver un estado antiguo: una T02 bloqueada volvía a
  poner en IN PROGRESS una T01 terminada. Ahora cada cambio de estado va en
  un commit.
- `recover` ignoraba un `git stash` fallido, y `bucle.sh` perdía su código
  de salida en una tubería. Los dos paran ahora con salida 4 sin marcar
  nada.

### Añadido
- `queue.sh done` y `queue.sh block` cierran una tarea en un solo paso
  (estado y commit del trabajo, o stash y BLOCKED). El orquestador nunca
  hace commit, stash ni edita `STATUS.md` por su cuenta.
- 76 tests.

## [8.2.0] - 2026-10-07

Arreglos de una revisión externa, tests y CI.

### Añadido
- `queue.sh`: las decisiones de la cola en código y no en el modelo:
  siguiente tarea, dependencias, propagación de BLOCKED, quitar el skip del
  test de la tarea al empezar y recuperar tareas cortadas.
- `tests/run.sh` con 53 casos, en CI con Linux y macOS.

### Corregido
- `bucle.sh` paraba cuando solo quedaba una tarea interrumpida.
- `lanzar-worker.sh` no veía archivos prohibidos cambiados dentro de
  commits, y devolvía 0 si al worker lo mataba una señal (ahora 128+N).
  Nuevo `--readonly` para los tests.
- `guardia-tests.sh` aceptaba borrar una aserción junto con su skip, y
  usaba `\b`, que el sed de macOS no entiende.

### Cambiado
- README: estado experimental, explicación honesta de los tests y sección
  de pruebas.

## [8.1.1] - 2026-10-07

Primera versión pública.

### Añadido
- Repo propio, instalable como plugin de Claude Code desde su propio
  marketplace y con `npx skills` para Codex, opencode y otros.
- README en inglés y en español, incluido cómo instalarla pidiéndoselo a
  tu agente.
- Lanzamiento de Codex en tmux, probado: modo sin sandbox, la pregunta
  "Trust this folder?" y los estados del goal.

## 8.1.0 - 2026-10-07

### Cambiado
- Nuevo nombre: **unattended-dev**. La skill está escrita en inglés y te
  sigue hablando en tu idioma.
- Lanzamiento automático: la skill arranca ella misma el orquestador en una
  sesión nueva y limpia (`claude --bg`, tmux o una pestaña de Orca) después
  de un ensayo, en vez de darte un prompt para pegar.

## 8.0 - 2026-10-07

### Añadido
- **Modo rápido** (por defecto con 6 tareas o menos y nada arriesgado): una
  o dos rondas de entrevista, una sola aprobación, un `docs/SPEC.md` corto
  y un `PLAN.md`. El modo completo queda para proyectos grandes o con
  riesgo.
- Scripts incluidos: `lanzar-worker.sh` (lanza un worker con tiempo límite
  y comprueba que solo tocó sus archivos) y `guardia-tests.sh` (los tests de
  aceptación no se pueden editar, borrar ni saltar).

### Cambiado
- Menos ceremonia: desaparecen el archivo por tarea y la referencia de
  inventario. El equipo de siempre se guarda fuera del proyecto.

## 7.0 - 2026-10-07

### Cambiado
- **Cualquier herramienta, cualquier modelo.** Cada papel (orquestador,
  implementa, diseño, QA) lo ocupa lo que elijas: Claude Code, Codex,
  opencode, Command Code u otros, con o sin Orca. Avisa una vez si una
  elección parece ineficiente y luego hace lo que digas.
- Primero un inventario de lo instalado; nunca ofrece una herramienta que
  no haya visto.
- `AGENTS.md` es el archivo de convenciones y `CLAUDE.md` un enlace a él.

### Añadido
- `bucle.sh`, un orquestador nuevo por ronda para herramientas sin goal
  nativo, y una referencia para cada lanzador.
- Una prueba de humo de todo el equipo antes de lanzar.

## 6.1 - 2026-10-07

### Cambiado
- El equipo se elige durante el plan, y se recuerda tu equipo de siempre.

## 6.0 - 2026-10-07

De un script que recorre una cola a una skill que prepara el proyecto
entero.

### Añadido
- Cinco fases: **entrevista** hasta que la SPEC no tenga huecos, **plan**
  (tareas que un worker termina solo, lo arriesgado fuera), **fase cero**
  (esqueleto, gate y tests de aceptación escritos antes y verificados),
  **lanzamiento** y **revisión**.
- Una sola sesión de orquestador con `/goal` lleva toda la cola, delegando
  en workers baratos. QA de otro proveedor (Codex) por defecto.

### Quitado
- `desatendido.sh`, `DESATENDIDO.md` y los fusibles de las versiones 1 a 5.

## 5 - 2026-10-04

### Corregido
- Tras un incidente real: un orquestador cerró la terminal que llevaba el
  bucle mientras limpiaba y mató la sesión entera. Ahora solo cierra las
  terminales de los workers que lanzó él.
- Los comandos del gate se ejecutan en un subshell, así que uno que cambie
  de carpeta no rompe el resto.
- Las interrupciones (terminal cerrada, kill, Ctrl+C) quedan en el
  registro.

## 4 - 2026-10-04

### Añadido
- QA con workers de Claude Sonnet, nunca quien construyó el código,
  comprobando que el modelo lanzado es el esperado.
- Tres tipos de QA: técnica (siempre), fidelidad (si hay fuentes de
  verdad) y diseño (si la tarea toca la interfaz; sin capturas no hay
  PASS). La QA solo informa; los arreglos vuelven a un worker.

## 3 - 2026-10-03

### Cambiado
- Nuevo nombre: **modo-desatendido** (a cualquier hora, no solo de noche).
- Planificar hablando: cuentas lo que quieres, Claude propone la cola
  separando tareas claras, decisiones tuyas, lo arriesgado y lo rápido, y
  la escribe después de tu visto bueno.
- Guardada en un repo privado de skills, enlazado en `~/.claude/skills`.

## 2 - 2026-10-03

### Añadido
- Fase cero para proyectos nuevos: specs, stack, esqueleto y gate contigo
  delante antes de cualquier trabajo desatendido.
- Más comprobaciones al arrancar: sin commits, huecos sin rellenar, sin
  gate. El gate se pasa antes de empezar.

## 1 - 2026-10-03

Primera versión, como **modo-nocturno**.

- `noche.sh` recorre una cola de `STATUS.md` y lanza un orquestador de
  Claude nuevo por tarea en una pestaña de Orca, con workers de opencode.
- Fusibles: `AGENT_STOP` (le pides que pare), `AGENT_BLOCKED` (una decisión
  te necesita) y `AGENT_FAILED` (fallos repetidos).
- Un cierre por tarea y un informe de mañana que comprueba los commits que
  cita.
- Comprobaciones al arrancar: jq, Orca, estar dentro de una terminal de
  Orca, permisos de opencode, fusibles y cola vacía.

[8.8.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.8.0
[8.7.2]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.2
[8.7.1]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.1
[8.7.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.7.0
[8.6.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.6.0
[8.5.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.5.0
[8.4.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.4.0
[8.3.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.3.0
[8.2.0]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.2.0
[8.1.1]: https://github.com/Aresdgi/unattended-dev/releases/tag/v8.1.1
