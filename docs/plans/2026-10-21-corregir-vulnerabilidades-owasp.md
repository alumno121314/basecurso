# Plan: Corregir vulnerabilidades OWASP Top 10 en la API y web-empleados

- **Tipo:** fix
- **Fecha:** 2026-10-21
- **Estado:** Propuesto
- **Estimación total:** 250 min (~4 h 10 min)

## 1. Contexto

Una auditoría de seguridad (OWASP Top 10, 2021) de `packages/api` y `packages/web-empleados` (junto con `packages/web-shared`) ha encontrado vulnerabilidades en ambos paquetes. Las más graves son:

- **Secreto JWT hardcodeado** (`'super-secret-resttek-key'`): cualquiera puede firmar un token de `admin`.
- **Pedidos sin control de acceso**: cualquier usuario autenticado, incluido un `cliente` recién registrado, puede leer las comandas de cualquier restaurante y cambiar el estado de sus platos.
- **Platos e ingredientes sin aislamiento entre restaurantes**: un manager de A puede editar o borrar los de B.
- **Login y registro sin rate limiting** y **sin política de contraseñas**.
- **En el frontend**, las rutas `cocina`, `barra` y `salon` solo se protegen ocultando enlaces, y el token se guarda en `localStorage`.

**Cómo reproducirlo (crítico):**
1. `POST /api/v1/auth/register` con un cliente nuevo.
2. Con ese token, `GET /api/v1/orders/active?restaurantId=<id de otro restaurante>` responde 200 con las comandas.
3. Con un JWT firmado con `super-secret-resttek-key` y `role: 'admin'`, cualquier endpoint responde 200.

## 2. Objetivo y criterios de aceptación

- [ ] La API no arranca si falta `JWT_SECRET` o tiene menos de 32 caracteres. No queda ningún secreto en el código.
- [ ] `jwt.verify` solo acepta `HS256` y valida `issuer` y `audience`.
- [ ] `GET /orders/active` y `PATCH /orders/:orderId/items/:itemId/status` devuelven 403 a un `cliente` y a personal de otro restaurante.
- [ ] `GET /orders/:id` solo responde al cliente dueño del pedido, al personal de su restaurante o a un `admin`.
- [ ] El `restaurantId` de `/orders/active` se toma del token para el personal, no de la query.
- [ ] Las rutas `/restaurants/:restaurantId/{dishes,ingredients}` devuelven 403 si `:restaurantId` no coincide con el restaurante del usuario (salvo `admin`). Las operaciones por `:id` devuelven 404 si el recurso es de otro restaurante.
- [ ] `/auth/login` y `/auth/register` devuelven 429 al superar el límite.
- [ ] El registro y el alta de empleados rechazan contraseñas de menos de 12 caracteres o de más de 72 bytes.
- [ ] La creación de pedidos valida `items` y `quantity` (entero entre 1 y 50, como mucho 50 líneas).
- [ ] CORS solo admite los orígenes configurados. `helmet` está activo y `x-powered-by` desactivado.
- [ ] El endpoint público de restaurantes no expone email, teléfono ni nombre del propietario.
- [ ] En web-empleados, un `roleGuard` impide entrar por URL a una vista de otro rol, y el guard rechaza tokens caducados.
- [ ] `npm test` en verde.

## 3. Fuera de alcance

- **Migrar el token de `localStorage` a cookie `HttpOnly` (W1).** Exige rediseñar la autenticación (CSRF, endpoints de refresh y logout) y afecta a las tres webs. Se deja para un plan propio. Mientras tanto se mitiga con la CSP (T26) y con tokens más cortos (T5).
- **Revocación de tokens y refresh tokens (hallazgo 7, parte).** Va en el mismo plan que la cookie.
- **CAPTCHA en el registro y verificación por email** (hallazgo 15).
- **Logging estructurado completo con pino (hallazgo 12).** Aquí solo se registran los 500 y los fallos de autenticación con `console.error` / `console.warn` (T22).
- **web-admin y web-clientes.** No se han auditado. Conviene revisarlos en otra iteración.

## 4. Análisis

### Código afectado

| Capa | Fichero | Cambio |
|------|---------|--------|
| config | `packages/api/src/config/env.ts` | Nuevo: carga dotenv y valida `JWT_SECRET`, `CORS_ORIGINS` y el resto de variables |
| http | `packages/api/src/contexts/shared/infrastructure/http/middlewares.ts` | Usa el secreto de config y fija `algorithms`, `issuer` y `audience`. Nuevo `requireSameRestaurant` |
| infra | `packages/api/src/contexts/employee/infrastructure/BcryptAuthService.ts` | Usa el secreto de config, `issuer`/`audience`, `expiresIn: '1h'` y coste 12 |
| app | `packages/api/src/app.ts` | Añade helmet, CORS con lista blanca, `x-powered-by` desactivado y límite del body |
| rutas | `packages/api/src/routes/order.routes.ts` | Añade `authorize` a `/active` y `PATCH status` |
| controller | `packages/api/src/controllers/order.controller.ts` | Pasa `req.user` al servicio; los errores van a `next(error)` |
| servicio | `packages/api/src/services/order.service.ts` | Comprueba restaurante y propiedad; valida `items` y `quantity` |
| errores | `packages/api/src/errors/DomainErrors.ts` | Nuevos `ForbiddenError` (403), `InvalidOrderItemsError` (400) y `WeakPasswordError` (400) |
| rutas | `packages/api/src/routes/{dish,ingredient}.routes.ts` | Añaden `requireSameRestaurant` |
| repos | `packages/api/src/repositories/{dish,ingredient}.repository.ts` | Nuevo `findByIdAndRestaurant` con `WHERE id = ? AND restaurant_id = ?` |
| servicio | `packages/api/src/services/{dish,ingredient}.service.ts` | getById, update y delete reciben el `restaurantId` |
| rutas | `packages/api/src/routes/restaurant.routes.ts` y `restaurant.public.routes.ts` | Comprobación de propiedad en `getById` y DTO público reducido |
| modelo | `packages/api/src/models/restaurant.model.ts` | Nuevo `toPublicJSON()`; `logoUrl` solo acepta `https://` |
| auth | `packages/api/src/contexts/employee/infrastructure/http/auth.routes.ts` | Rate limiting |
| dominio | `packages/api/src/contexts/employee/domain/value-objects/Password.ts` | Nuevo: política de contraseñas |
| casos de uso | `RegisterClientUseCase.ts`, `CreateEmployeeUseCase.ts` | Validan la contraseña antes de hashearla |
| http | `EmployeeController.ts` | Valida `role` contra `Role` |
| scripts | `packages/api/src/scripts/seed.ts` | Contraseñas desde variables de entorno o aleatorias; no se imprimen; no se ejecuta en producción |
| http | `errorHandler.ts` | Registra los 500 y mapea `ForbiddenError` a 403 |
| repo | `.gitignore` | Excluye `*.db` y `.env` |
| front | `packages/web-shared/src/lib/auth/{auth.store,auth.guard,role.guard}.ts` | Parseo seguro, comprobación de `exp` y nuevo `roleGuard` |
| front | `packages/web-empleados/src/app/app.routes.ts` | Aplica `roleGuard` con `data.roles` |
| front | `packages/web-empleados/src/app/features/orders/**` | Deja de enviar `restaurantId`; para el sondeo al hacer logout |
| front | `packages/web-empleados/src/index.html` | CSP |

### Causa raíz

- **Secreto JWT:** `middlewares.ts:4` y `BcryptAuthService.ts:5` usan `process.env.JWT_SECRET || 'super-secret-resttek-key'`, y `dotenv` no se importa en ningún sitio.
- **Pedidos:** `order.routes.ts:14-18` solo aplica `authenticate`. `OrderController` usa `req.query.restaurantId` y `req.params` sin compararlos con `req.user`.
- **Platos e ingredientes:** `authorize` solo comprueba el rol. Los repositorios buscan por `id` sin `restaurant_id` (`dish.repository.ts:34`, `ingredient.repository.ts:27`).
- **Frontend:** `app.routes.ts:21-32` solo usa `authGuard`, que se limita a comprobar `token !== null`.

## 5. Diseño de la solución

- **Configuración centralizada:** `src/config/env.ts` importa `dotenv/config`, valida las variables y exporta `config` (`jwtSecret`, `jwtIssuer='resttek-api'`, `jwtAudience='resttek-web'`, `corsOrigins` y `nodeEnv`). Si falla la validación, lanza un error al importarse y la API no arranca. En los tests, `vitest.config.ts` define `env.JWT_SECRET`.
- **Autorización de pedidos en el servicio**, no en el controller, para poder probarla con unitarios. Los métodos reciben un `actor: { id, role, restaurantId }`:
  - `listActive(actor)`: el personal usa `actor.restaurantId`. Un `admin` debe indicar `restaurantId`.
  - `getById(id, actor)`: lo puede ver el cliente dueño, el personal del mismo restaurante o un `admin`. Si no, `ForbiddenError`.
  - `updateItemStatus(orderId, itemId, status, actor)`: solo el personal del restaurante del pedido.
  - `create`: valida `items` y `quantity` y que cada `dishId` pertenezca a `restaurantId`.
- **Aislamiento entre restaurantes:** el middleware `requireSameRestaurant` compara `req.params.restaurantId` con `req.user.restaurantId` (exento el `admin`) y responde 403. Además, los repositorios filtran por `restaurant_id` (defensa en profundidad). Si el recurso es de otro restaurante, se responde 404.
- **Endpoints:** no cambian las rutas. Cambian los códigos: 403 por falta de permiso, 429 por exceso de peticiones y 400 por validación.
- **Errores:** `ForbiddenError` (403, "No tienes permiso para realizar esta acción"), `InvalidOrderItemsError` (400) y `WeakPasswordError` (400, "La contraseña debe tener entre 12 y 72 caracteres").
- **Dependencias nuevas:** `helmet` y `express-rate-limit`.
- **Base de datos:** sin cambios de esquema.
- **Alternativa descartada:** comprobar la autorización solo en el frontend, o solo con middlewares de ruta. No cubre `GET /orders/:id`, donde hace falta cargar el pedido para saber a quién pertenece.

## 6. Tareas

> Cada tarea debe llevar entre 5 y 10 minutos. Orden: primero las críticas, luego las altas, después las medias y bajas, y al final el frontend.

### Bloque A — Secreto y validación JWT (Crítica)

- [ ] **T1 — Test de configuración** (~5 min)
  - Ficheros: `packages/api/src/config/env.test.ts`
  - Qué hacer: comprobar que `loadConfig({})` lanza un error si falta `JWT_SECRET` o si tiene menos de 32 caracteres, y que devuelve la configuración cuando es válida.
  - Hecho cuando: el test falla (rojo).
- [ ] **T2 — Implementar `config/env.ts`** (~10 min)
  - Ficheros: `packages/api/src/config/env.ts`, `packages/api/vitest.config.ts`, `packages/api/.env.example`
  - Qué hacer: `import 'dotenv/config'`, una función `loadConfig(env)` y `export const config = loadConfig(process.env)`. Definir `JWT_SECRET` de prueba en `vitest.config.ts`. Documentar las variables en `.env.example`.
  - Hecho cuando: T1 pasa (verde).
- [ ] **T3 — Test de `authenticate`** (~10 min)
  - Ficheros: `packages/api/src/contexts/shared/infrastructure/http/middlewares.test.ts`
  - Qué hacer: comprobar que da 401 con un token firmado con `'super-secret-resttek-key'`, con `alg: none` y sin `issuer`/`audience`, y que deja pasar un token válido.
  - Hecho cuando: el test falla (rojo).
- [ ] **T4 — Usar `config` en `authenticate`** (~5 min)
  - Ficheros: `middlewares.ts`
  - Qué hacer: quitar el valor por defecto. Usar `jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'], issuer, audience })`.
  - Hecho cuando: T3 pasa.
- [ ] **T5 — Usar `config` en `BcryptAuthService`** (~5 min)
  - Ficheros: `BcryptAuthService.ts`
  - Qué hacer: firmar con `config.jwtSecret`, `algorithm: 'HS256'`, `issuer`, `audience` y `expiresIn: '1h'`. Subir el coste de bcrypt a 12.
  - Hecho cuando: los tests de `EmployeeUseCases.test.ts` pasan y `grep -r "super-secret" packages/api/src` no encuentra nada.

### Bloque B — Control de acceso en pedidos (Crítica)

- [ ] **T6 — Añadir `ForbiddenError` y mapearlo a 403** (~5 min)
  - Ficheros: `DomainErrors.ts`, `errorHandler.ts`
  - Qué hacer: crear la clase y añadir el caso 403 en el errorHandler.
  - Hecho cuando: un test del errorHandler devuelve 403 para `ForbiddenError`.
- [ ] **T7 — Tests de `listActive` y `getById` con actor** (~10 min)
  - Ficheros: `packages/api/src/services/order.service.test.ts`
  - Qué hacer:
    - Un `cliente` en `listActive` recibe `ForbiddenError`.
    - Un `cocinero` de A recibe solo los pedidos de A, aunque pida B.
    - Un `cliente` que no es dueño recibe `ForbiddenError` en `getById`, y el dueño recibe el pedido.
  - Hecho cuando: los tests fallan (rojo).
- [ ] **T8 — Implementar la autorización en `listActive` y `getById`** (~10 min)
  - Ficheros: `order.service.ts`
  - Qué hacer: añadir el parámetro `actor` y aplicar las reglas de la sección 5.
  - Hecho cuando: T7 pasa.
- [ ] **T9 — Test de `updateItemStatus` con actor** (~5 min)
  - Ficheros: `order.service.test.ts`
  - Qué hacer: un `cliente` y un empleado de otro restaurante reciben `ForbiddenError`; el personal del mismo restaurante actualiza el estado.
  - Hecho cuando: el test falla (rojo).
- [ ] **T10 — Implementar la autorización en `updateItemStatus`** (~5 min)
  - Ficheros: `order.service.ts`
  - Hecho cuando: T9 pasa.
- [ ] **T11 — Controller y rutas de pedidos** (~10 min)
  - Ficheros: `order.controller.ts`, `order.routes.ts`
  - Qué hacer:
    - Pasar `req.user` como actor y sustituir los `try/catch` que devuelven `error.message` por `next(error)` (hallazgo 11).
    - Añadir `authorize(['admin','manager','camarero','cocinero'])` en `/active` y `PATCH status`.
  - Hecho cuando: `npm test` pasa.
- [ ] **T12 — Test de integración de pedidos** (~10 min)
  - Ficheros: `packages/api/src/routes/order.routes.test.ts` (supertest)
  - Qué hacer: reproducir el escenario de la sección 1 (un cliente registrado intenta leer y modificar comandas ajenas) y comprobar que recibe 403.
  - Hecho cuando: el test pasa.

### Bloque C — Aislamiento entre restaurantes en platos e ingredientes (Alta)

- [ ] **T13 — Test y middleware `requireSameRestaurant`** (~10 min)
  - Ficheros: `middlewares.test.ts`, `middlewares.ts`
  - Qué hacer: devolver 403 si `params.restaurantId !== user.restaurantId` y el usuario no es `admin`; en otro caso, `next()`.
  - Hecho cuando: el test pasa.
- [ ] **T14 — Aplicar el middleware en las rutas** (~5 min)
  - Ficheros: `dish.routes.ts`, `ingredient.routes.ts`, `restaurant-employee.routes.ts`
  - Qué hacer: añadirlo justo después de `authenticate` (los routers usan `mergeParams`; comprobarlo).
  - Hecho cuando: un `PUT /restaurants/B/dishes/x` con un token de manager de A da 403.
- [ ] **T15 — Filtrar el repositorio de platos por restaurante** (~10 min)
  - Ficheros: `dish.repository.ts`, `dish.service.ts`, `dish.controller.ts`
  - Qué hacer: añadir `findByIdAndRestaurant(id, restaurantId)` y usarlo en getById, update y delete. Si no existe, 404.
  - Hecho cuando: un test de `/restaurants/A/dishes/<idDeB>` da 404.
- [ ] **T16 — Lo mismo para ingredientes** (~10 min)
  - Ficheros: `ingredient.repository.ts` (y su test), `ingredient.service.ts`, `ingredient.controller.ts`, `MockIngredientRepository.ts`
  - Hecho cuando: `ingredient.repository.test.ts` cubre el caso y pasa.

### Bloque D — Autenticación: rate limiting y contraseñas (Alta)

- [ ] **T17 — Rate limiting en `/auth`** (~10 min)
  - Ficheros: `packages/api/package.json`, `auth.routes.ts`
  - Qué hacer:
    - `npm i express-rate-limit -w @resttek/api`.
    - Login: 5 intentos cada 15 min por IP y email. Registro: 10 por hora por IP.
    - Que se pueda desactivar en tests.
  - Hecho cuando: un test con supertest recibe 429 en el sexto intento.
- [ ] **T18 — Value object `Password` con tests** (~10 min)
  - Ficheros: `contexts/employee/domain/value-objects/Password.ts` y `Password.test.ts`, `DomainErrors.ts`
  - Qué hacer: la contraseña debe ser un string de 12 caracteres como mínimo y 72 bytes como máximo. Si no, `WeakPasswordError`.
  - Hecho cuando: los tests pasan.
- [ ] **T19 — Usar `Password` en los casos de uso** (~5 min)
  - Ficheros: `RegisterClientUseCase.ts`, `CreateEmployeeUseCase.ts` y sus tests
  - Qué hacer: validar antes de `hashPassword`. Una contraseña vacía o ausente pasa a dar 400 en lugar de 500.
  - Hecho cuando: los tests de ambos casos de uso cubren una contraseña débil y pasan.
- [ ] **T20 — Asegurar el seed** (~10 min)
  - Ficheros: `scripts/seed.ts`, `.env.example`
  - Qué hacer:
    - Abortar si `NODE_ENV === 'production'`.
    - Tomar las contraseñas de `SEED_PASSWORD` o generarlas con `crypto.randomBytes`.
    - No imprimir contraseñas.
  - Hecho cuando: `npm run seed` funciona y no muestra contraseñas.

### Bloque E — Configuración, validación y datos expuestos (Media/Baja)

- [ ] **T21 — Endurecer `app.ts`** (~10 min)
  - Ficheros: `app.ts`, `package.json`
  - Qué hacer:
    - `npm i helmet`.
    - `app.disable('x-powered-by')`, `app.use(helmet())`.
    - `cors({ origin: config.corsOrigins })`.
    - `express.json({ limit: '100kb' })`.
  - Hecho cuando: un test de `/health` comprueba que no hay cabecera `x-powered-by` y que sí hay `x-content-type-options`.
- [ ] **T22 — Logging mínimo** (~5 min)
  - Ficheros: `errorHandler.ts`, `middlewares.ts`, `LoginUseCase.ts`
  - Qué hacer:
    - `console.error` en los 500.
    - `console.warn` en los 401/403 y en los logins fallidos, con IP y email pero sin contraseña.
  - Hecho cuando: la revisión manual lo confirma.
- [ ] **T23 — Validar la creación de pedidos (DoS)** (~10 min)
  - Ficheros: `order.service.ts`, `order.service.test.ts`, `DomainErrors.ts`
  - Qué hacer:
    - `items` debe ser un array de 1 a 50 líneas.
    - `quantity` debe ser un entero entre 1 y 50.
    - Cada `dishId` debe ser del restaurante. Si no, `InvalidOrderItemsError`.
  - Hecho cuando: los tests con `quantity: 10000000` e `items: "x"` dan error 400.
- [ ] **T24 — DTO público de restaurante y comprobación en `getById`** (~10 min)
  - Ficheros: `restaurant.model.ts`, `restaurant.controller.ts`, `restaurant.public.routes.ts`, `restaurant.routes.ts`
  - Qué hacer:
    - `toPublicJSON()` sin datos del propietario.
    - `getById` privado: comprobar que el restaurante es el del usuario (salvo `admin`).
    - `logoUrl` solo acepta `https://` (hallazgo 14).
  - Hecho cuando: `restaurant.service.test.ts` cubre el caso y `GET /public/restaurants` no devuelve emails.
- [ ] **T25 — Lista blanca de roles en el alta de empleados y `.gitignore`** (~5 min)
  - Ficheros: `EmployeeController.ts` (o `CreateEmployeeUseCase.ts`), `.gitignore`
  - Qué hacer:
    - Validar `role` con `Role`.
    - Añadir `*.db` y `.env` a `.gitignore` y sacar `resttek.db` del control de versiones.
  - Hecho cuando: un rol inválido da 400.

### Bloque F — web-empleados / web-shared (Alta/Media)

- [ ] **T26 — Parseo seguro y comprobación de `exp` en `AuthStore`** (~10 min)
  - Ficheros: `web-shared/src/lib/auth/auth.store.ts` y `auth.store.spec.ts`
  - Qué hacer:
    - `try/catch` en `JSON.parse` y validar la forma de los datos; si no es válida, `clear()`.
    - `isAuthenticated` comprueba que el token tenga `exp` futuro (decodificando el payload).
    - Leer `role` y `restaurantId` del payload del token, no de `auth_user`.
  - Hecho cuando: los specs cubren un token caducado y un JSON corrupto.
- [ ] **T27 — `roleGuard`** (~10 min)
  - Ficheros: `web-shared/src/lib/auth/role.guard.ts` y `.spec.ts`, `web-shared` index
  - Qué hacer: leer `route.data.roles` y redirigir a `/` si el rol del store no está incluido.
  - Hecho cuando: el spec pasa.
- [ ] **T28 — Aplicar `roleGuard` en las rutas de empleados** (~5 min)
  - Ficheros: `web-empleados/src/app/app.routes.ts`
  - Qué hacer: dar a `cocina`, `barra` y `salon` `canActivate: [roleGuard]` y los `data.roles` que ya usa `shell.component.ts`.
  - Hecho cuando: un cocinero que navega a `/barra` acaba en `/`.
- [ ] **T29 — Quitar `restaurantId` de la petición de pedidos y parar el sondeo en el logout** (~10 min)
  - Ficheros: `web-empleados/src/app/features/orders/services/order.service.ts`, las páginas `cocina`, `barra` y `salon`, `order.store.ts`, `web-shared/src/lib/auth/auth.service.ts`
  - Qué hacer: llamar a `GET /orders/active` sin query. Al hacer logout, limpiar `OrderStore` y su `setInterval`.
  - Hecho cuando: en la pestaña de red no aparece `restaurantId` y no se hacen peticiones después del logout.
- [ ] **T30 — CSP en web-empleados** (~5 min)
  - Ficheros: `web-empleados/src/index.html` (o `angular.json` con `security.autoCsp`)
  - Qué hacer: `default-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'` (en `<meta>` no funciona `frame-ancestors`; documentar que va en el servidor).
  - Hecho cuando: `ng build` y la aplicación funciona sin errores de CSP en consola.

### Cierre

- [ ] **T31 — Verificación final** (~10 min)
  - Qué hacer:
    - Ejecutar `npm test` en `packages/api` y los specs de las webs.
    - Ejecutar `npm audit`.
    - Repetir a mano los pasos de reproducción de la sección 1.
    - Marcar los criterios de aceptación.
  - Hecho cuando: todos los tests pasan y los criterios están marcados.

## 7. Estrategia de pruebas

- **Unitarias (vitest, junto al código):**
  - `env.test.ts`, `middlewares.test.ts` (JWT y `requireSameRestaurant`).
  - `order.service.test.ts` (autorización por actor y validación de items).
  - `Password.test.ts`, casos de uso de registro y alta, repositorios de platos e ingredientes.
- **Integración (supertest):**
  - `order.routes.test.ts`: cliente contra comandas ajenas (403).
  - Platos de otro restaurante (403/404).
  - Rate limiting (429).
  - Cabeceras de seguridad.
- **Frontend (specs de Angular):** `auth.store` (caducidad y JSON corrupto) y `roleGuard`.

## 8. Riesgos y preguntas abiertas

- **Tokens ya emitidos:** al cambiar el secreto e incluir `issuer`/`audience`, dejan de valer y todos los usuarios tendrán que volver a iniciar sesión. Comunicarlo antes del despliegue.
- **Admin en `/orders/active`:** ¿debe ver todos los restaurantes o indicar `restaurantId`? Se propone que lo indique. Confirmarlo con negocio.
- **web-admin y web-clientes:** se apoyan en los mismos endpoints. Hay que comprobar que no dependían de enviar `restaurantId` ni del acceso abierto a pedidos.
- **Contraseñas del seed:** cambiar a un mínimo de 12 caracteres invalida las credenciales de prueba documentadas. Hay que actualizar el README.
- **Rate limiting en memoria:** no se comparte entre instancias. Si se escala horizontalmente, hará falta un store en Redis.
- **Pendiente W1/W5:** queda pendiente un plan propio para pasar el token a cookie `HttpOnly` y revocar sesiones en el servidor.
