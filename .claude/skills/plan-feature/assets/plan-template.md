# Plan: <título breve>

- **Tipo:** feature | fix
- **Fecha:** AAAA-MM-DD
- **Estado:** Propuesto
- **Estimación total:** <suma de las tareas> min

## 1. Contexto

<Qué se pide y por qué. En un bug: comportamiento actual, comportamiento esperado y pasos para reproducirlo.>

## 2. Objetivo y criterios de aceptación

- [ ] <Criterio verificable 1>
- [ ] <Criterio verificable 2>

## 3. Fuera de alcance

- <Lo que explícitamente no se hará en este plan>

## 4. Análisis

### Código afectado

| Capa | Fichero | Cambio |
|------|---------|--------|
| <models/services/...> | `src/...` | <nuevo/modificado: qué> |

### Causa raíz (solo bugs)

<Explicación de por qué ocurre el fallo, con referencia a fichero y línea.>

## 5. Diseño de la solución

<Enfoque elegido y alternativas descartadas. Incluir cuando aplique:>

- **Endpoints:** `MÉTODO /ruta` — petición, respuesta y códigos de estado
- **Base de datos:** cambios de esquema o migraciones
- **Errores:** nuevos errores de dominio (`AppError`) y su código HTTP
- **Validaciones:** reglas en el modelo

## 6. Tareas

> Cada tarea debe llevar entre 5 y 10 minutos.

- [ ] **T1 — <título>** (~5 min)
  - Ficheros: `...`
  - Qué hacer: <descripción concreta>
  - Hecho cuando: <test, comando o comprobación>
- [ ] **T2 — <título>** (~10 min)
  - Ficheros: `...`
  - Qué hacer: ...
  - Hecho cuando: ...
- [ ] **Tn — Verificación final** (~5 min)
  - Qué hacer: ejecutar `npm test` y repasar los criterios de aceptación
  - Hecho cuando: todos los tests pasan y los criterios están marcados

## 7. Estrategia de pruebas

- **Unitarias (`test/unit/`):** <casos>
- **Integración (`test/integration/`):** <casos>

## 8. Riesgos y preguntas abiertas

- <Riesgo o duda y cómo mitigarlo / a quién preguntar>
