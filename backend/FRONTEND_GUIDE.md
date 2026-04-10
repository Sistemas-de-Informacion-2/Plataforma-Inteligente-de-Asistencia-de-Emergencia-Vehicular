# Guía de Integración Frontend - Plataforma Inteligente de Emergencias Vehiculares 🚗🔧

Bienvenido al lado Frontend del proyecto. El Backend está construido con **FastAPI**, **PostgreSQL + PostGIS** (para geolocalización esférica de alta precisión), **SQLAlchemy 2.0 Async** y una Arquitectura manejada por **Eventos (WebSockets)** para la comunicación en tiempo real.

En esta guía encontrarás todo lo necesario para entender cómo interactuar fluidamente con nuestra API y cómo está estructurado el backend corporativo.

---

## 1. Estructura y Arquitectura del Backend

Para que el equipo de frontend comprenda la separación de responsabilidades y el flujo de los datos, esta es la anatomía microscópica de nuestra arquitectura:

- 📂 **`app/api/` (Routers y Endpoints):** Aquí viven los controladores. Reciben las peticiones HTTP/WS del frontend, inyectan dependencias (como la BD o el usuario autenticado) y delegan la lógica pesada a los *Services*.
- 📂 **`app/core/` (El Motor Central):** Contiene la configuración dura. Aquí se instancian las variables de entorno, la conexión a bases de datos asíncronas y habita `security.py` (hasheo de contraseñas y emisión de JWT).
- 📂 **`app/models/` (Modelos SQLAlchemy):** Representación en clases Python de las tablas de PostgreSQL. Aquí habilitamos columnas PostGIS (geometría) y todos heredan de un motor de rastreo lógico llamado `AuditableMixin`.
- 📂 **`app/schemas/` (Esquemas Pydantic):** Clases estrictas. Validan que los JSON que nos envíes en el Body tengan el tipo de dato correcto y dictan la forma del JSON que el backend te responderá (filtran contraseñas, formatean fechas).
- 📂 **`app/repositories/` (Capa de Acceso a Datos):** El único lugar que ejecuta código SQL (mediante SQLAlchemy 2.0). Aquí residen las lógicas de Soft Delete y los filtros de cercanía satelital.
- 📂 **`app/services/` (Reglas de Negocio):** El cerebro abstracto del proyecto. Orquestan el cruce de repositorios, disparan integraciones de IA para leer las fotos/audios de los accidentes, miden los polígonos de PostGIS e inician la cacería de técnicos.
- 📂 **`app/websocket/` (Tiempo Real):** Controladores tácticos de túnel abierto. Gestionan en memoria (RAM) a qué técnico y cliente disparar una notificación reactiva basándose en su ID.
- 📂 **`app/scripts/` (Semilleros):** Scripts de inicialización y Mocking. Nutren la base de datos con usuarios prueba, talleres en Santa Cruz, y geometrías precalculadas.

---

## 2. Autenticación y Autorización (JWT)

Todos nuestros endpoints de negocio están cerrados bajo protocolo **OAuth2 (Password Flow)**. 

### A. Iniciar Sesión (Obtener el Token)
Debes hacer un `POST` al endpoint de login para canjear un usuario y clave por un Access Token.
- **Ruta:** `POST /api/v1/auth/login`
- **Content-Type:** `application/x-www-form-urlencoded`
- **Payload:**
  - `username`: El email del usuario (ej. `luis.tec@test.com`)
  - `password`: Su contraseña
- **Respuesta:** Devuelve un `{ "access_token": "...", "token_type": "bearer" }`.

### B. Enviar el Token en las Peticiones REST
Manda el token en las cabeceras HTTP de Angular (idealmente en un HttpInterceptor):
```http
Authorization: Bearer eyJhbGci...
```

---

## 3. WebSockets (Comunicación en Tiempo Real)

Para actualizaciones tácticas instantáneas (ej. notificar a un mecánico sobre una emergencia cerca):

- **[WS] Conexión al Canal:** `ws://localhost:8000/api/v1/ws/notificaciones/?token=TU_TOKEN`
  *(Nota: Se inyecta el token en la URL, ya que los WS nativos en navegadores no toleran Auth Headers).*
- **[Evento] Recepción de Emergencia:** El WebSocket vibrará con este Payload JSON automático cuando la IA y PostGIS coordinen la asistencia:
  ```json
  {
    "type": "NUEVA_ASIGNACION",
    "solicitud_id": 14,
    "distancia": 4.25,
    "eta": 12
  }
  ```

---

## 4. Diccionario de Endpoints REST

Aquí tienes el catálogo exhaustivo para integrar tus llamadas `HttpClient` (con el Header `Bearer`).

### Módulo: Auth
| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | Recibe credenciales y emite el JWT Access Token. |

### Módulo: Usuarios
| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/api/v1/usuarios/` | Crea un usuario nuevo (y automáticamente su perfil). *(No requiere token)* |
| `GET` | `/api/v1/usuarios/` | Lista usuarios (paginado). |
| `GET` | `/api/v1/usuarios/{id}` | Retorna un usuario explícito con su Perfil anidado. |

### Módulo: Talleres y Sucursales 🔧
| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/api/v1/talleres/` | Crea un taller matriz. |
| `GET` | `/api/v1/talleres/` | Lista talleres y devuelve la sucursal matriz incrustada. |
| `POST` | `/api/v1/talleres/sucursales` | Crea una sucursal inyectando Coordenadas al modelo PostGIS. |
| `GET` | `/api/v1/talleres/sucursales/cercanas` | **[CRÍTICO]** Pide `latitud`, `longitud` y `radio_km`. Retorna las sucursales en ese radio usando `ST_DWithin`. |

### Módulo: Solicitudes (Emergencias)
| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/api/v1/solicitudes/` | Crea la emergencia. Soporta queryParams `?auto_diagnostico=true&auto_asignar=true`. Dispara IA y lanza el WS. |
| `GET` | `/api/v1/solicitudes/cliente/{id}` | Lista las emergencias solicitadas históricas de un cliente particular. |
| `GET` | `/api/v1/solicitudes/pendientes` | Lista las alertas abiertas listas para que los mecánicos las tomen. |
| `GET` | `/api/v1/solicitudes/{id}` | Obtiene vista 360 de la emergencia: *Evidencias de falla incrustadas y el Diagnóstico Mock IA*. |
| `PATCH` | `/api/v1/solicitudes/{id}/estado` | Cambia el estado de la alerta (ej. `?estado=ATENDIDO` o `CANCELADO`). |

**JSON Base para el POST - Solicitar Emergencia:**
```json
{
  "solicitud_in": {
    "descripcion": "Mi vehículo no enciende y sale humo negro.",
    "latitud": -17.7770,
    "longitud": -63.1945,
    "cliente_id": 1,
    "vehiculo_id": 3
  },
  "evidencias": [
    { "tipo": "IMAGEN", "url": "https://bucket.com/foto_motor.jpg" },
    { "tipo": "AUDIO", "url": "https://bucket.com/sonido.mp3" }
  ]
}
```

### Módulo: Órdenes y Pagos
| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/api/v1/ordenes/` | Genera una orden de trabajo (presupuesto formal) arraigada a una solicitud. |
| `POST` | `/api/v1/ordenes/{orden_id}/detalles` | Añade cobros singulares al presupuesto (ej. "Bujía - 25.00"). |
| `POST` | `/api/v1/ordenes/{orden_id}/pagar` | Ejecuta la transferencia marcando el status de deuda. |

---

## 5. Auditoría y Eliminación (⚠️ Consideración de BD)
Ningún registro de Negocio Principal se elimina fácticamente mediante destrucción atómica. En su lugar, el ORM emplea un **Soft Delete** administrado por `AuditableMixin`:
```json
{
  "es_eliminado": true,
  "fecha_eliminacion": "2026-04-09T03:15:00.000Z"
}
```
> **¿Qué significa esto para ti?**
> No debes preocuparte porque te lleguen registros de emergencias pasadas apuntando a Talleres "borrados" dando un Error 500 por Foreign Keys rotas. El backend se encarga de proteger la historicidad lógica y ocultar los registros fantasma en las consultas estándar.
