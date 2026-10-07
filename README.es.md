<p align="center">
  <a href="README.md">English</a> · <b>Español</b>
</p>

<p align="center">
  <img src=".github/assets/banner.es.svg" alt="unattended-dev: cuenta la idea, déjalo picando, vuelve a revisar" width="100%">
</p>

<h3 align="center">
  Le cuentas una idea a tu agente. Te hace las preguntas justas, monta el proyecto<br/>
  y deja a un equipo de agentes sacándolo adelante mientras tú haces otra cosa.
</h3>

<p align="center">
  <a href="https://github.com/Aresdgi/unattended-dev"><img src="https://img.shields.io/badge/versión-8.4.0-7c3aed?style=for-the-badge" alt="versión 8.4.0"></a>
  <img src="https://img.shields.io/badge/estado-experimental-f59e0b?style=for-the-badge" alt="experimental">
  <a href="https://github.com/Aresdgi/unattended-dev/actions/workflows/test.yml"><img src="https://github.com/Aresdgi/unattended-dev/actions/workflows/test.yml/badge.svg" alt="tests de los scripts"></a>
  <a href="#licencia"><img src="https://img.shields.io/badge/licencia-MIT-22c55e?style=for-the-badge" alt="licencia MIT"></a>
  <br/>
  <img src="https://img.shields.io/badge/Claude_Code-d97757?style=flat-square" alt="Claude Code">
  <img src="https://img.shields.io/badge/Codex-111827?style=flat-square" alt="Codex">
  <img src="https://img.shields.io/badge/opencode-374151?style=flat-square" alt="opencode">
  <img src="https://img.shields.io/badge/Orca-opcional-0ea5e9?style=flat-square" alt="Orca opcional">
</p>

<p align="center">
  <img src=".github/assets/demo.es.svg" alt="Sesión de ejemplo: entrevista, fase cero, lanzamiento en segundo plano y cola de cinco tareas terminada" width="820">
  <br/>
  <sub>Sesión de ejemplo</sub>
</p>

> [!WARNING]
> **Experimental.** Los scripts tienen tests en Linux y macOS (mira
> [Tests](#-tests)), pero las ejecuciones desatendidas completas solo se han
> probado en unos pocos proyectos pequeños. Revisa lo que construye antes de
> fiarte.

> [!NOTE]
> **Antes se llamaba `modo-desatendido`** y vivía en el marketplace
> `aresdgi`. Si lo tenías instalado así, se pasa solo al nombre nuevo: en
> Claude Code ejecuta una vez
>
> ```text
> /plugin marketplace update aresdgi
> /plugin install unattended-dev@aresdgi
> ```

## 🚀 Pruébalo en 10 segundos

**Claude Code**

```text
/plugin marketplace add Aresdgi/unattended-dev
/plugin install unattended-dev@unattended-dev
```

**Codex, opencode y otros agentes**

```sh
npx skills add Aresdgi/unattended-dev -g -a codex opencode
```

**O deja que lo haga tu agente.** Pega esto en Claude Code, Codex, opencode o
cualquier agente con terminal:

```text
Instala la skill unattended-dev de https://github.com/Aresdgi/unattended-dev
```

Y luego, sin más: *"quiero hacer…"*. Más opciones en [Instalación](#-instalación).

## 💜 Por qué mola

<table>
<tr>
<td width="50%" valign="top">

### 🧠 Una entrevista que no deja huecos

Te pregunta solo lo necesario, con opciones y su recomendación primero. Lo
que te da igual lo decide y lo marca *"(por defecto)"*.

</td>
<td width="50%" valign="top">

### 🛡️ Tests difíciles de trucar

Los escribe quien no implementa, los workers los reciben en solo lectura y
una guardia en el gate caza las trampas habituales: cambiar una
comprobación, volver a poner un skip o borrar un test.

</td>
</tr>
<tr>
<td valign="top">

### 🎛️ Tu equipo, tus modelos

Claude, Codex, opencode… Solo te ofrece lo que tienes instalado, y tú
eliges quién orquesta, quién implementa y quién revisa.

</td>
<td valign="top">

### 🌙 Se lanza solo

Le dices "sí" y deja al orquestador trabajando en segundo plano, con el
Mac despierto. No tienes que abrir ninguna terminal.

</td>
</tr>
<tr>
<td valign="top">

### 🔁 Si se corta, sigue

Todo el estado vive en archivos. Si se acaba la cuota o se duerme el
portátil, se relanza y retoma donde se quedó.

</td>
<td valign="top">

### 🔒 Nada irreversible sin ti

Push, despliegues, borrados y datos reales quedan fuera de la cola. Eso
se hace contigo delante.

</td>
</tr>
</table>

> [!TIP]
> Lo que funciona no es la ceremonia. Son cuatro cosas: **tareas pequeñas y
> verificables**, **tests escritos antes y protegidos**, **una QA que no hace
> quien implementa** y **el estado en archivos** para poder retomar. Todo lo
> demás, lo mínimo.

## 🧭 Cómo funciona

<p align="center">
  <img src=".github/assets/flow.es.svg" alt="Cómo funciona: entrevista, plan y equipo y fase cero contigo; la cola desatendida sin ti; después la revisión" width="720">
</p>

| | Fase | Qué pasa |
| :-: | --- | --- |
| 1 | **Entrevista** | Como mucho 4 preguntas por ronda, con opciones y una recomendación. Termina con un resumen y "¿lo armo así?" |
| 2 | **Plan y equipo** | Tareas pequeñas con sus archivos cerrados. Inventario de lo instalado y un papel para cada herramienta |
| 3 | **Fase cero** | Esqueleto, gate, tests de aceptación en skip, `AGENTS.md`, `ORQUESTADOR.md` y prueba de humo de todo el equipo |
| 4 | **Lanzamiento** | Te pregunta "¿lo lanzo yo?". Con un sí, hace una prueba en seco y deja al orquestador en segundo plano, en una sesión nueva con el contexto limpio |
| 5 | **Revisión** | Al volver, dices "revisa la sesión": comprueba la cola, la guardia, el gate y una prueba a mano |

### Cada tarea de la cola

El orquestador **coordina, no implementa**: trabaja con lo que le devuelven
los scripts, no con el código. Única excepción: tras dos arreglos fallidos
puede leer el test que falla y la función que prueba, para decidir entre
bloquear la tarea o dar una orden más clara.

<p align="center">
  <img src=".github/assets/task.es.svg" alt="Cada tarea: queue.sh next y start, el worker, el gate y la QA, arreglos como mucho dos veces, y queue.sh done o block" width="640">
</p>

- **Gate**: guardia de tests, typecheck, tests y build.
- **QA**: en solo lectura, una por tipo. *Fidelidad* (hace lo que pide la
  SPEC, nada inventado), *técnica* (errores, casos límite, seguridad) y
  *diseño* (capturas en móvil y escritorio, estados vacío y error,
  accesibilidad).

Si la sesión se corta (cuota, portátil dormido…), se vuelve a lanzar igual:
lo que quedó a medias de la tarea IN PROGRESS se guarda en un stash y esa
tarea vuelve a empezar desde limpio.

## 🌙 Lanzamiento automático

Al terminar la fase cero te pregunta **"¿lo lanzo yo?"**. Con un sí elige el
mecanismo según el orquestador, hace una **prueba en seco** con un objetivo
trivial (el orquestador lanzado arranca un worker de prueba y lo libera, para
probar la cadena entera) y solo entonces lanza de verdad.

| Orquestador | Cómo lo lanza | Cómo mirarlo | Cómo pararlo |
| --- | --- | --- | --- |
| **Claude Code** | `claude --bg` con el modelo, el modo de permisos y el `/goal` | `claude agents`, `claude attach <id>`, `claude logs <id>` | `claude stop <id>` |
| **Con `/goal` sin segundo plano** (Codex) | Sesión de tmux en segundo plano y el `/goal` con `tmux send-keys` | `tmux attach -t ud-<proyecto>` | `tmux kill-session -t ud-<proyecto>` |
| **Sin `/goal`** | `.desatendido/bucle.sh` con `nohup` | `tail -f logs/bucle-*.log` | `touch AGENT_STOP` |
| **Workers con Orca** | Pestaña de Orca con `orca terminal create` | La pestaña en Orca | `orca terminal close` |

- Siempre con **`caffeinate`** para que el Mac no se duerma mientras dure.
  Déjalo enchufado: con batería y la tapa cerrada se dormirá igual.
- Si tmux no está instalado, **te pide permiso** antes de instalarlo.
- El CLI de Orca solo funciona dentro de una terminal de Orca. Por eso, si
  los workers van con Orca, el orquestador arranca en una pestaña de Orca; y
  si no se puede, te avisa y te propone el lanzador por CLI, que no depende
  de Orca.
- Si prefieres lanzarlo tú, dile que no y te da `LANZAR.md` rellenado.

## ⚡ Dos modos

| | 🏎️ Rápido · *por defecto* | 🏗️ Completo |
| --- | --- | --- |
| **Cuándo** | 6 tareas o menos y nada arriesgado | Proyecto grande, datos reales, alto riesgo o porque lo pides |
| **Entrevista** | 1 o 2 rondas | Las que hagan falta |
| **Aprobaciones** | Una, al final de la preparación | Al final de cada fase |
| **Documentos** | `docs/SPEC.md` y `PLAN.md` | SPEC, una tarea por archivo y un cierre por tarea |
| **Fase cero** | Unos 15 minutos | Entre 30 y 60 minutos |

Al terminar la entrevista te propone uno, en una línea y con el motivo.

## 🎛️ Tu equipo, tus reglas

No hay equipo fijo. Antes de preguntar, la skill mira qué tienes instalado
(Claude Code, Codex, opencode, Gemini, Orca, tmux…), qué modelos acepta cada
uno y si tiene `/goal` y modo en segundo plano, y **solo te ofrece eso**.

| Papel | Qué hace |
| --- | --- |
| 🎼 **Orquestador** | Reparte la cola (con `queue.sh`, que es quien lleva `STATUS.md`), pasa el gate y decide los arreglos |
| 🛠️ **Implementa** | Hace cada tarea y sus arreglos |
| 🎨 **Diseño** | Las tareas de interfaz, si las hay. Puede ser el mismo que implementa |
| 🔍 **QA** | Revisa en solo lectura. Mejor de un proveedor distinto al que implementa |

Cada papel lo ocupa la herramienta y el modelo que digas, aunque no sea lo
más eficiente: te avisa una vez con el motivo (QA con el mismo modelo que
implementa, un modelo caro en tareas mecánicas, todo el equipo tirando de la
misma cuota…) y hace lo que digas.

Si quieres, lo guarda como "el de siempre" en
`~/.config/modo-desatendido/equipo.md`, y la próxima vez es la primera opción:

```markdown
- Orchestrator: claude / opus
- Implements: opencode / <proveedor/modelo>
- Design: same as implements
- QA: codex / <modelo>
- Worker launcher: cli
```

Antes de lanzar, **prueba de humo**: cada papel responde
`OK <nombre exacto del modelo>` y no se lanza nada hasta que todos estén en verde.

La skill habla siempre en tu idioma, aunque sus archivos estén en inglés.

## 🧰 Scripts incluidos

La fase cero copia cuatro scripts a `.desatendido/` en tu proyecto.
Funcionan con cualquier herramienta y en macOS sin instalar nada. Detectan
los problemas después de que ocurran y toman las decisiones mecánicas; no
son un entorno aislado.

<table>
<tr>
<td width="25%" valign="top">

#### 🚀 `lanzar-worker.sh`

Lanza cualquier worker con **límite de tiempo**, **registro completo** en
`logs/` y solo las últimas 30 líneas de salida. Puede dejar los tests en
**solo lectura** mientras trabaja y avisa de cualquier archivo tocado fuera
de su tarea, **con commit o sin él**.

</td>
<td width="25%" valign="top">

#### 🛡️ `guardia-tests.sh`

Va dentro del gate. **Falla** si alguien cambia un test de aceptación en
algo más que quitar el skip, añade un skip nuevo, borra o crea tests, o
da por hecha una tarea que aún tiene su test en skip.

</td>
<td width="25%" valign="top">

#### 📋 `queue.sh`

Toma las **decisiones mecánicas** con código, no con el modelo: la
siguiente tarea, las dependencias, propagar los BLOCKED, quitar el skip al
empezar una tarea, **cerrar** una tarea en un solo paso atómico y
**recuperar** una tarea que se cortó. Cada cambio de estado lleva su
commit, así que un stash nunca puede deshacerlo.

</td>
<td width="25%" valign="top">

#### 🔁 `bucle.sh`

Mantiene vivo al orquestador si su herramienta no tiene objetivo nativo:
una tarea por vuelta, elegida por `queue.sh`, con el contexto limpio, hasta
vaciar la cola o llegar al límite de horas.

</td>
</tr>
</table>

<details>
<summary><b>Uso y códigos de salida</b></summary>

```zsh
# La cola: siguiente tarea, empezarla (quita el skip de su test) y cerrarla
.desatendido/queue.sh next            # -> T01
.desatendido/queue.sh start T01
.desatendido/queue.sh done T01 "resumen"   # DONE + commit, de una vez
.desatendido/queue.sh block T01 "motivo"   # stash + BLOCKED, de una vez

# Un worker, con sus archivos permitidos y los tests en solo lectura
.desatendido/lanzar-worker.sh implements T01 \
  --allowed "src/dni.ts" --readonly "tests/acceptance" -- \
  opencode run -m <proveedor/modelo> "Implement task T01 of PLAN.md…"

# La guardia, al principio del gate, vigilando las tareas empezadas y DONE
.desatendido/guardia-tests.sh fase-cero tests/acceptance $(.desatendido/queue.sh tests) \
  && npm run typecheck && npm test && npm run build

# El bucle externo: máximo 4 horas y parada limpia
MAX_HOURS=4 .desatendido/bucle.sh
touch AGENT_STOP   # para al terminar la vuelta en curso
```

| `lanzar-worker.sh` sale con | Significa |
| :-: | --- |
| `0` | Terminó bien y no tocó nada fuera de lo permitido |
| `3` | **OUT OF TASK**: tocó archivos no permitidos |
| `124` | **TIMEOUT**: superó el límite (20 minutos por defecto) |
| `128+N` | **KILLED**: el worker se paró por la señal N |

`bucle.sh` recupera cualquier tarea que se quedara IN PROGRESS antes de
empezar, y se para solo si la cola se vacía, si ninguna tarea puede
empezar, si existe `AGENT_STOP`, si se pasa de `MAX_ROUNDS` o `MAX_HOURS`,
o si una vuelta termina sin que su tarea quede DONE o BLOCKED.

</details>

## 🧪 Tests

Los scripts tienen su propia batería de tests, que se ejecuta en Linux y
macOS con cada push:

```zsh
bash tests/run.sh
```

Cubre las trampas encontradas en la revisión (una comprobación borrada junto
a un skip, un archivo prohibido modificado y con commit, un worker matado
por una señal), la recuperación de la cola cuando se corta una sesión, que
el estado de la cola sobreviva a un stash o a un paso de git que falla, y
que tus propios cambios nunca acaben dentro de una tarea.

## 📁 Lo que deja en tu proyecto

```text
mi-proyecto/
├── .desatendido/            scripts de arriba
├── docs/
│   ├── SPEC.md              1 o 2 páginas: qué hace, entradas, errores, límites
│   ├── tareas/Txx.md        solo en modo completo
│   └── cierres/             solo en modo completo
├── tests/acceptance/        uno por tarea, en skip, escritos por quien no implementa
├── AGENTS.md                convenciones (CLAUDE.md es un enlace a él)
├── ORQUESTADOR.md           reglas y comandos reales de cada papel
├── PLAN.md                  tareas con firma, archivos permitidos y casos
└── STATUS.md                la cola: PENDING · IN PROGRESS · DONE · BLOCKED
```

Todo queda en un commit `fase cero` con el tag `fase-cero`, que es la
referencia contra la que la guardia compara los tests.

## 🔒 Reglas de seguridad

Valen siempre, sea cual sea el equipo o el modo:

> [!IMPORTANT]
> - **Nada irreversible en la cola.** Datos reales, borrados, despliegues,
>   publicar o push se hacen contigo delante.
> - **Sin red de seguridad no hay lanzamiento.** Hacen falta tests de
>   aceptación verificados, la guardia en el gate, la prueba de humo en verde
>   y la prueba en seco del lanzamiento superada.
> - **Los huecos se preguntan.** Si falta algo en la SPEC, la skill te
>   pregunta en vez de rellenarlo en silencio.
> - **Las credenciales nunca entran en la cola**, ni `.env`, claves o logs
>   en los commits.
> - **La cola solo hace commit de su propio trabajo.** Una tarea no empieza
>   si la carpeta tiene cambios que no son de la cola. Para seguir
>   trabajando en el repo mientras tanto, usa un worktree tuyo
>   (`git worktree add`).

## 📦 Instalación

### Claude Code

```text
/plugin marketplace add Aresdgi/unattended-dev
/plugin install unattended-dev@unattended-dev
```

Para actualizar: `/plugin marketplace update unattended-dev`. También está en mi
catálogo de plugins, [Aresdgi/claude-plugins](https://github.com/Aresdgi/claude-plugins),
como `unattended-dev@aresdgi`.

### Codex, opencode y otros agentes

Con [skills](https://www.npmjs.com/package/skills), que encuentra la skill
en `skills/unattended-dev`:

```sh
npx skills add Aresdgi/unattended-dev -g -a codex opencode
```

`-g` la instala para tu usuario y `-a` elige los agentes (`-a '*'` para
todos los que soporta). Para actualizar: `npx skills update unattended-dev`.

<details>
<summary><b>A mano, con git</b></summary>

<br/>

```sh
git clone https://github.com/Aresdgi/unattended-dev.git ~/unattended-dev
mkdir -p ~/.agents/skills
ln -s ~/unattended-dev/skills/unattended-dev ~/.agents/skills/unattended-dev
```

Para actualizar: `git -C ~/unattended-dev pull`.

</details>

### 🤖 Para agentes

Si un usuario te ha pedido instalar esta skill, sigue estos pasos según la
herramienta en la que estés. Pide permiso antes de ejecutar nada si tus
permisos lo exigen.

1. **Claude Code**: ejecuta en la terminal
   ```sh
   claude plugin marketplace add Aresdgi/unattended-dev
   claude plugin install unattended-dev@unattended-dev
   ```
   Después dile al usuario que ejecute `/reload-plugins` o abra una sesión
   nueva.
2. **Codex, opencode u otro agente, con Node.js disponible**: ejecuta
   ```sh
   npx skills add Aresdgi/unattended-dev -g -a <agente> -y
   ```
   donde `<agente>` es `codex`, `opencode` o el tuyo (`-a '*'` para todos
   los que soporta).
3. **Sin Node.js**: clona el repo y enlaza la carpeta de la skill en la
   carpeta de skills que lea tu herramienta (`~/.agents/skills` para Codex y
   opencode, `~/.claude/skills` para Claude Code):
   ```sh
   git clone https://github.com/Aresdgi/unattended-dev.git ~/unattended-dev
   mkdir -p ~/.agents/skills
   ln -s ~/unattended-dev/skills/unattended-dev ~/.agents/skills/unattended-dev
   ```

Comprueba que `SKILL.md` está en la carpeta instalada y dile al usuario que
ya está lista y que una sesión nueva la carga. Se activa con "quiero
hacer…" o "modo desatendido".

> [!TIP]
> Funciona en cualquier agente que lea `SKILL.md`. Si tu herramienta tiene
> preguntas con opciones, las usa; si no, te da opciones numeradas.

## 💬 Cómo se usa

Habla normal, en español o en inglés. Se activa con frases como:

> *"quiero hacer…"* · *"monta el proyecto"* · *"prepáralo para que se haga solo"*
> · *"modo desatendido"* · *"modo nocturno"* · *"déjalo picando"* · *"lánzalo"*

En Claude Code también puedes llamarla directamente con
`/unattended-dev:unattended-dev`.

Cuando vuelvas, en la misma sesión donde lo preparaste, di **"revisa la
sesión"**: comprueba el estado de la cola, que los tests sigan intactos, el
gate, una prueba a mano con resultados conocidos y te deja una tabla con
tareas hechas, fallos de QA, duración y uso de cada plan.

<details>
<summary><b>¿Y en un repo que ya existe?</b></summary>

<br/>

Igual, pero la entrevista solo cubre el hito, no se crea esqueleto y el tag
es `<hito>-start`. Si ya hay una SPEC general, la del hito va en
`docs/hitos/<hito>/`. Si encuentra restos de versiones antiguas
(`desatendido.sh`, `DESATENDIDO.md`, un `bucle.sh` en la raíz), te propone
borrarlos y espera tu OK.

</details>

<details>
<summary><b>¿Qué pasa si una tarea no sale?</b></summary>

<br/>

Tiene dos intentos de arreglo. Si sigue fallando, queda **BLOCKED** con el
motivo en `STATUS.md`, sus cambios se guardan en un `git stash` y el
orquestador sigue con la siguiente. Las tareas que dependían de ella también
quedan bloqueadas. En la revisión te propone si arreglar la tarea, la SPEC o
los tests, con supervisión.

</details>

<details>
<summary><b>¿Puede el orquestador cambiar los tests para que pasen?</b></summary>

<br/>

Lo tiene prohibido, y además se lo ponemos difícil: los workers reciben los
tests en solo lectura, quien quita el skip es `queue.sh` y la guardia
revisa cada gate, así que cambiar una comprobación, añadir un skip o borrar
un test lo tumba. Los scripts cazan las trampas habituales, pero no son un
entorno aislado; por eso la revisión final vuelve a comprobar los tests.

</details>

<details>
<summary><b>¿Necesito Orca o tmux?</b></summary>

<br/>

No. Por defecto los workers se lanzan por CLI con `lanzar-worker.sh`, y con
Claude Code como orquestador basta `claude --bg`. Orca es opcional, si
quieres ver cada worker en su propia pestaña. tmux solo hace falta si el
orquestador tiene `/goal` pero no modo en segundo plano, como Codex.

</details>

## Licencia

MIT

<div align="center">
<sub>Hecho por <a href="https://github.com/Aresdgi">Aresdgi</a> · para dejarlo picando 🌙</sub>
</div>
