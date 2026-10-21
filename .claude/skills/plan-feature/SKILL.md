---
name: plan-feature
description: Planifica la implementación de una nueva funcionalidad o la corrección de un bug en la API Vendehumos y genera un plan detallado en docs/plans/ dividido en tareas de 5-10 minutos. Úsala cuando el usuario pida planificar, diseñar o preparar una funcionalidad, un cambio o un arreglo antes de implementarlo.
argument-hint: "<descripción de la funcionalidad o del bug>"
---

# Planificar funcionalidad o corrección de bug

Petición del usuario: $ARGUMENTS

Tu objetivo es **planificar, no implementar**. No modifiques código de `src/` ni `test/`;
el único fichero que debes crear es el plan en `docs/plans/`.

## Pasos

1. **Entender la petición.** Determina si es una funcionalidad (`feature`) o un bug (`fix`).
   Si la petición está vacía o es ambigua en algo que cambie el plan, pregunta al usuario con
   `AskUserQuestion` antes de continuar.
2. **Analizar el código.** Lee `CLAUDE.md`, la documentación de `docs/` que aplique
   (p. ej. `docs/api/api-pagination.md` para colecciones) y los ficheros afectados de cada capa
   (`routes`, `controllers`, `services`, `repositories`, `models`, `migrations`, tests).
   En un bug, localiza la causa raíz y cómo reproducirlo con un test.
3. **Diseñar la solución** respetando la arquitectura en capas, la inyección de dependencias
   en `src/container.js`, SQL parametrizado con `node:sqlite`, errores `AppError` y textos en español.
4. **Desglosar en tareas** siguiendo las reglas de abajo.
5. **Escribir el plan** copiando la estructura de [assets/plan-template.md](assets/plan-template.md)
   en `docs/plans/AAAA-MM-DD-<slug>.md` (fecha de hoy y slug en kebab-case, p. ej.
   `2026-10-15-filtrar-vendehumos-por-nivel.md`). Crea la carpeta si no existe.
   Mantén todas las secciones de la plantilla; si alguna no aplica, escribe "No aplica" y el motivo.
6. **Resumir** al usuario la ruta del plan, el número de tareas, el tiempo total estimado y
   las preguntas abiertas que hayan quedado.

## Reglas de las tareas

- Cada tarea debe poder hacerse en **5-10 minutos**. Si una tarea supera los 10 min, divídela.
- Una tarea = un cambio concreto y verificable: indica los ficheros exactos que toca, qué hacer
  y cómo comprobar que está terminada (test concreto, comando o petición HTTP).
- Ordénalas por dependencias, de abajo arriba en las capas: migración/modelo → repositorio →
  servicio → controller → rutas/container → tests de integración → documentación.
- Sigue TDD cuando sea posible: la tarea del test va antes (o junto) de la implementación.
  En un bug, la primera tarea es siempre un test que reproduzca el fallo.
- Usa casillas `- [ ]` para que el plan sirva de checklist y numera las tareas (`T1`, `T2`...).
- Incluye siempre una tarea final de verificación (`npm test` en verde y revisión del criterio de aceptación).
