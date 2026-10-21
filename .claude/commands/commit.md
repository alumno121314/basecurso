---
description: Crea un commit siguiendo la especificación Conventional Commits
argument-hint: "[descripción opcional o pista del cambio]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*)
---

## Contexto

- Estado actual: !`git status --short`
- Cambios preparados (staged): !`git diff --cached`
- Cambios sin preparar: !`git diff`
- Rama actual: !`git branch --show-current`
- Últimos commits: !`git log --oneline -10 2>/dev/null || echo "(el repositorio aún no tiene commits)"`

Indicación adicional del usuario (puede estar vacía): $ARGUMENTS

## Tarea

Crea un commit que cumpla la especificación [Conventional Commits 1.0.0](https://www.conventionalcommits.org/es/v1.0.0/).

### Pasos

1. Analiza los cambios. Si no hay nada preparado, añade los ficheros relevantes con `git add`
   (nunca añadas `.env`, secretos ni ficheros generados ignorados).
2. Si los cambios mezclan propósitos distintos (p. ej. una funcionalidad y un arreglo no relacionado),
   propón dividirlos en varios commits y prepara cada uno por separado.
3. Redacta el mensaje cumpliendo las reglas anteriores y muestraselo al usuario utilizando la tool `AskUserQuestion` para preguntarle si le parece bien el mensaje. Si no le parece bien, genera otro mensaje y le vuelves a preguntar. Cuando lo de por válido sigue con el paso 4.
4. Ejecuta `git commit` pasando el mensaje con un heredoc para respetar los saltos de línea.
5. Muestra el resultado con `git log -1 --stat`.

### Reglas del mensaje

- **Tipos permitidos:**
  - `feat` — nueva funcionalidad
  - `fix` — corrección de un error
  - `docs` — solo documentación
  - `style` — formato, sin cambios de lógica
  - `refactor` — cambio de código que ni añade funcionalidad ni corrige errores
  - `perf` — mejora de rendimiento
  - `test` — añadir o corregir tests
  - `build` — sistema de build o dependencias (`package.json`, etc.)
  - `ci` — configuración de integración continua
  - `chore` — tareas de mantenimiento que no tocan `src/` ni `test/`
  - `revert` — revierte un commit anterior
- **Ámbito** (opcional, en minúsculas): la entidad o capa afectada, p. ej.
  `vendehumo`, `usuario`, `auth`, `database`, `config`, `middlewares`.
- **Descripción:** en español, en imperativo, en minúscula, sin punto final y de 72 caracteres como máximo
  (p. ej. `feat(vendehumo): añade filtro por categoría`).
- **Cuerpo:** explica el *qué* y el *porqué* (no el cómo), separado por una línea en blanco,
  con líneas de 72 caracteres como máximo.
- **Cambios incompatibles:** añade `!` tras el tipo/ámbito y un pie
  `BREAKING CHANGE: <explicación>`.
- **Pies:** formato `Token: valor` (p. ej. `Refs: #12`, `Closes: #34`).
- No añadas nunca la línea `Co-Authored-By` ni ninguna otra atribución a Claude.

### Restricciones

- No uses `--no-verify` ni `--amend` salvo que el usuario lo pida explícitamente.
- No hagas `git push`.
- Si un hook de pre-commit falla, corrige el problema y crea un commit nuevo.
