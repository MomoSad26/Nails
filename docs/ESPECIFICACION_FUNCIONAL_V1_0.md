# Especificación funcional — App de gestión de negocio de uñas

**Versión 1.0 — Documento de entrega para desarrollo**
**Plataforma:** Flutter (móvil Android/iOS)
**Modo:** Offline-first, usuario único (la dueña)
**Idioma de la interfaz:** Español

---

## 0. Resumen ejecutivo

App para que una manicurista (dueña única) gestione su negocio sin necesidad de internet: clientas, citas, servicios, precios, mensajes de WhatsApp preelaborados y un calendario. La app no envía mensajes por sí sola: prepara el texto y abre WhatsApp para que la dueña lo envíe manualmente. Todo el funcionamiento central es local.

Fuera de esta versión: recordatorios (notificaciones locales), sincronización en nube, multiusuario, envío automático por API de WhatsApp, estadísticas financieras avanzadas.

---

## 1. Stack técnico y arquitectura (recomendación)

| Aspecto | Recomendación |
|---|---|
| Framework | Flutter (última versión estable) |
| Base de datos local | SQLite (sqflite o Drift). Persistencia total offline. |
| Estado | Riverpod o Bloc (a elección del desarrollador) |
| Formato de fechas | `intl` con locale `es` |
| Apertura de WhatsApp | `url_launcher` con esquema `whatsapp://` y fallback `https://wa.me/` |
| Notificaciones (futuro) | `flutter_local_notifications` — **no implementar en v1** |
| Arquitectura | Capas: datos (DB) → dominio (reglas) → presentación (UI) |
| Persistencia de configuración | Preferencias locales (shared_preferences) o tabla `settings` en DB |

**Requisitos:**
- La app **debe funcionar sin conexión a internet** para todas las funciones excepto el envío real de WhatsApp (que ocurre fuera de la app, en la app de WhatsApp).
- **No** se requiere login ni cuenta.
- **No** se requiere PIN en v1 (queda pendiente).

---

## 2. Navegación y layout

### 2.1 Estructura general
- **Una sola página** (single-page).
- **Barra lateral fija a la izquierda** con iconos circulares (metáfora “monedas”), de arriba a abajo, **siempre visible**.
- **No es un drawer**: no se abre/cierra, no se desliza, no se superpone al contenido.
- **Panel de contenido único** a la derecha que cambia según el icono activo.
- **No hay ventanas superpuestas ni apiladas**. Los subflujos (detalle de cita, formulario, ficha de clienta, edición de servicio) se abren como **páginas internas dentro del panel de contenido**, con botón **“Volver”**.
- Los **diálogos modales** se permiten **solo** para: confirmaciones (eliminar, cerrar cita, etc.) y menú rápido de long press.

### 2.2 Orden de iconos en la barra lateral (arriba → abajo)
1. **Inicio**
2. **Agenda**
3. **Citas**
4. **Clientes**
5. **Catálogo**
6. **Ajustes**

### 2.3 Indicador de menú activo
- El icono del menú activo se pinta con el **color de acento** del negocio (configurable en Ajustes) y se resalta con un **fondo circular suave** del mismo color.
- Los iconos inactivos van en **gris neutro**.

### 2.4 Comportamiento en pantallas estrechas
- La barra lateral **no desaparece** ni se convierte en drawer.
- La barra mantiene un **ancho mínimo** (56–64 px) suficiente para mostrar los iconos; los textos/etiquetas se ocultan si no caben (opcional: tooltip al long press sobre el icono).
- El contenido se adapta al ancho restante: listas y tarjetas se reorganizan **verticalmente**.
- Si el contenido no cabe: **scroll vertical dentro del panel**. Nunca scroll horizontal de la página completa.
- La barra **nunca** se superpone al contenido.
- Se respetan **safe areas** (notch, bordes).

---

## 3. Modelo de datos

### 3.1 Entidad `Clienta`
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| id | entero autoincremental | sí | PK |
| nombre | texto | **sí** | libre |
| telefono | texto | no | incluye **código de país** |
| nota | texto libre | no | sin límite práctico |
| fecha_registro | fecha/hora | sí | auto al crear |
| activa | booleano | no | default `true`; estado opcional |
| notificar_whatsapp | booleano | no | **solo válido si hay teléfono**; default `false` |

Relaciones: una clienta tiene muchas citas (`historial`).

### 3.2 Entidad `Servicio` (Catálogo)
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| id | entero autoincremental | sí | PK |
| nombre | texto | **sí** | único (advertir duplicado) |
| precio | decimal | **sí** | ≥ 0 |
| activo | booleano | sí | default `true`; ver §7.4 |

### 3.3 Entidad `Cita`
| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| id | entero autoincremental | sí | PK |
| clienta_id | entero (FK Clienta) | **sí** | no se puede eliminar clienta con citas sin decidir antes |
| fecha_hora | datetime | **sí** | inicio de la cita |
| servicios | lista de `{servicio_id, nombre_snapshot, precio_snapshot}` | **sí, al menos uno** | seleccionados del Catálogo |
| precio_total | decimal | **sí** | auto-calculado desde el catálogo, **editable** |
| estado | enum | sí | ver §8 |
| nota | texto libre | no | — |
| creada_en | datetime | sí | auto |
| cerrada_en | datetime | no | cuando se marca Terminada/Cancelada/No asistió |

**Nota sobre snapshot:** aunque el precio se “toma siempre del catálogo”, se guarda un `nombre_snapshot` y `precio_snapshot` por cada servicio en la cita para no romper el historial si el servicio se edita o se inactiva. El total de la cita es un campo independiente y editable.

### 3.4 Entidad `Configuracion` (tabla clave-valor)
- `nombre_negocio`
- `nombre_duena`
- `color_acento`
- `simbolo_moneda` (pendiente de definir; default sugerido “$”)
- (reservado para recordatorios, backups, PIN → v2)

### 3.5 Entidad `Plantilla_mensaje` (opcional en v1, recomendado)
- `tipo`: `notificacion_cita` | `catalogo`
- `texto`: string con variables (ej. `{{nombre}}`, `{{fecha_relativa}}`, `{{hora}}`)
- Editable en Ajustes.
- En v1 se puede incluir como **constante editable** en Ajustes; si no, hardcoded.

---

## 4. Módulos (uno por cada menú)

---

### 4.1 Menú Inicio

**Contenido en este orden (confirmado):**

1. **Saludo y fecha**
   - “Hola [nombre de la dueña]” + fecha de hoy (formato largo, ej. “viernes, 17 de octubre”).
   - Si hay citas hoy: “Hoy tienes X citas.”

2. **Próxima cita (destacada)**
   - Tarjeta grande con la **próxima cita** (la primera cita futura ordenada por fecha/hora ascendente).
   - Muestra: hora, nombre de la clienta, servicios (lista), precio total.
   - Botones: **Ver detalle**, **Notificar por WhatsApp**, **Llamar**.
   - Si no hay próxima cita: mensaje “No tienes citas próximas” + botón **“Agregar cita”**.

3. **Citas de hoy (lista compacta)**
   - Lista de citas de hoy ordenadas por hora ascendente.
   - Cada fila: **hora, nombre de la clienta, estado**.
   - Al tocar → detalle de la cita.
   - Si no hay citas hoy: mensaje “No tienes citas hoy” + botón **“Agregar cita”**.

4. **Pendientes de cerrar (aviso)**
   - Si hay citas en estado “Pendiente de cerrar”: mostrar “Tienes X citas pendientes de cerrar” + botón que lleva a **Citas → pestaña Pendientes de cerrar**.
   - Si no hay: ocultar este bloque.

5. **Accesos rápidos (botones)**
   - **Agregar cita** → abre el formulario de nueva cita **con fecha vacía** (mismo comportamiento que desde Citas).
   - **Agregar clienta** → abre el formulario de nueva clienta.
   - **Ver agenda de mañana** → abre Agenda posicionada en el día de mañana.
   - **Compartir catálogo por WhatsApp** → genera el mensaje del catálogo y abre el flujo de WhatsApp (§6.2).

6. **Resumen semanal (opcional)**
   - Mini contadores: “Citas esta semana: X” / “Citas próxima semana: Y”.
   - Sin gráficos.

7. **Aviso de catálogo vacío**
   - Si no hay servicios activos en el Catálogo: “Tu catálogo está vacío. Agrega servicios para poder agendar citas” + botón directo a **Catálogo**.

**Orden de bloques en pantalla:** 1 → 2 → 3 → 4 → 5 → 6 → 7. Los bloques 4, 6 y 7 se ocultan si no aplican.

---

### 4.2 Menú Agenda

**Al abrir:** calendario con el **mes actual** visible.

**Navegación de meses:** permitida hacia **meses pasados y futuros** (flechas ‹ › y, opcional, selector de mes/año).

**Indicador visual en el calendario:**
- Cada día con citas muestra un **numerito pequeño** en una esquina con la **cantidad de citas** de ese día.
- Días sin citas: sin indicador.
- El indicador **solo cuenta citas en estado Programada o Pendiente de cerrar** (no Historial cerrado). Definir según §8.

**Vista del día (al tocar un día):**
- Se abre como **página interna** dentro del panel (con “Volver”).
- Si **no hay citas**: mensaje “No hay citas para este día” + botón **“Agregar cita”**.
- Si **hay citas**: lista ordenada por **hora ascendente**. Cada fila muestra hora, nombre, servicio(s) y estado. Al tocar → detalle de la cita.
- **“Agregar cita”** desde un día → abre el formulario de nueva cita con la **fecha precargada** al día seleccionado (campo editable).

**Desde Inicio:** el acceso “Ver agenda de mañana” posiciona la Agenda en el día de mañana mostrando su vista del día.

---

### 4.3 Menú Citas

**Estructura en pestañas (internas al panel):**

1. **Programadas** — citas futuras. Orden: **más próximas arriba** (fecha/hora ascendente).
2. **Pendientes de cerrar** — citas cuya hora de inicio ya pasó y aún no tienen estado final. Orden: más antiguas arriba (para que no se olviden) — a criterio del desarrollador, recomendado ascendente.
3. **Historial** — citas cerradas (Terminada / Cancelada / No asistió). Orden: **más recientes primero**.

**Filtros desplegables (aplican al listado visible de la pestaña activa):**
- **Hoy**
- **Semana** (semana actual, lunes a domingo)
- **Mensual** (mes actual)
- Opción “Todos” implícita o por defecto.

**Botón “Agregar cita”:**
- Visible en las pestañas Programadas y Pendientes de cerrar (y opcionalmente en Historial).
- Abre el formulario de nueva cita **con fecha vacía** (la dueña debe configurarla manualmente).

**Filas de cita:** hora, nombre de la clienta, servicios, precio total, estado. Al tocar → detalle.

**Interacciones:**
- **Tap** → detalle de cita (§4.3.1).
- **Long press 500 ms** → menú rápido (§4.3.2).

#### 4.3.1 Detalle de cita
Pantalla interna (con “Volver”) que muestra:
- Clienta, fecha, hora, servicios, precio total, estado, nota.
- Acciones:
  - **Editar cita** → abre formulario precargado.
  - **Terminar cita** → estado `Terminada`, pasa a Historial, `cerrada_en = ahora`.
  - **Reprogramar cita** → abre selector de fecha/hora; al guardar, la cita vuelve a `Programada` con nueva fecha/hora.
  - **Eliminar cita** → confirmación → borrado real.
  - **Cancelar cita** → estado `Cancelada`, pasa a Historial, `cerrada_en = ahora`.
  - **No asistió** → estado `No_asistio`, pasa a Historial, `cerrada_en = ahora`.
  - **Notificar por WhatsApp** → ver §6.1.
  - **Recordatorio para esta cita** → **en pausa (v2)**, no implementar.
  - **Llamar** → si la clienta tiene teléfono, abre el marcador del teléfono del sistema.

#### 4.3.2 Menú rápido (long press 500 ms)
Diálogo modal pequeño con las opciones:
- **Terminada**
- **Posponer** (equivale a Reprogramar: abre selector de nueva fecha/hora)
- **Eliminar** (con confirmación)
- **Cancelar**
- **No asistió**

Cada acción cierra el diálogo y aplica el cambio.

---

### 4.4 Menú Clientes

**Listado:**
- Orden **alfabético** por nombre.
- Muestra nombre y (si tiene) teléfono.

**Buscador (parte superior del panel):**
- **Tolerante** (ver §7.1). Aplica al listado.
- Busca por **nombre** y por **teléfono**.

**Alta / edición de clienta:**
- **Nombre** (obligatorio).
- **Teléfono** (opcional) con **selector de código de país**.
- **Nota** (opcional, texto libre).
- **Fecha de registro** (auto, solo lectura).
- **Estado activa/inactiva** (opcional; default activa).
- **Notificar por WhatsApp Sí/No** (visible solo si hay teléfono; default No).

**Validaciones:**
- Nombre obligatorio.
- Teléfono: formato flexible; si existe, incluir código de país.
- Detección de teléfono duplicado: advertir, no bloquear.

**Ficha de clienta (al tocar su nombre):**
- Datos de la clienta.
- Botón **“Agendar cita”** → formulario de nueva cita con la clienta precargada.
- Botón **“Notificar por WhatsApp”** → solo si tiene teléfono y el toggle está en Sí; si no, mensaje + opción de agregar teléfono/activar.
- **Últimas 10 citas** ordenadas de más reciente a más antigua. Cada una muestra: **fecha, hora, servicio(s), precio**. Incluir estado resumido si aporta claridad.

---

### 4.5 Menú Catálogo

**Listado:**
- Muestra todos los servicios activos con **nombre y precio**.
- Orden **alfabético fijo**, independiente del orden de creación.
- Pestaña o sección **“Inactivos”** para servicios eliminados lógicamente (§7.4), con opción de **reactivar**.

**Acciones:**
- **Agregar servicio** (nombre + precio).
- **Editar servicio** (nombre y precio).
- **Eliminar servicio** → **eliminación lógica** (pasa a `activo = false`). Confirmación previa.
- **Reactivar servicio** desde la sección Inactivos.

**Validaciones:**
- Nombre obligatorio y único (advertir duplicado).
- Precio numérico ≥ 0.

**Compartir catálogo por WhatsApp:**
- Botón **“Compartir catálogo por WhatsApp”**.
- Toma **todos los servicios activos** y arma **un solo mensaje** con cada servicio y su precio al lado (§6.2).
- Abre WhatsApp en la pantalla de **selección de destinatario** (contacto o grupo). La dueña elige libremente.
- El mensaje va preelaborado y **editable antes de enviar**.

---

### 4.6 Menú Ajustes

**Definido hasta ahora:**
- **Nombre del negocio**.
- **Nombre de la dueña** (para el saludo en Inicio).
- **Color de acento** (paleta predefinida o selector).
- **Símbolo de moneda** (pendiente de definir formalmente; default “$”).
- (Reservado v2) Hora de recordatorio diario, PIN, backups.

**Pendiente de desglose:** backup/import, PIN, plantillas de mensajes editables. **No implementar en v1** salvo nombre de negocio, nombre de dueña, color de acento y símbolo de moneda.

---

## 5. Formulario de cita (transversal)

Se usa desde: Inicio (Agregar cita), Agenda (día seleccionado), Citas (Agregar cita), Ficha de clienta (Agendar cita), Detalle de cita (Editar / Reprogramar).

| Campo | Comportamiento |
|---|---|
| **Clienta** | Selector con buscador tolerante (§7.1). Opción **“Crear nueva clienta”** dentro del mismo formulario (nombre, teléfono opcional con código de país, nota opcional). |
| **Fecha** | **Precargada** si viene desde Agenda (día seleccionado) o desde Ficha de clienta con día; **vacía** si viene desde Inicio “Agregar cita” o desde Citas “Agregar cita”. Siempre **editable**. |
| **Hora** | Selector de hora. Obligatoria. |
| **Servicios** | Selector múltiple desde el Catálogo (solo activos). Al menos uno obligatorio. |
| **Precio total** | **Auto-calculado** como la suma de `precio` de los servicios seleccionados (siempre desde el Catálogo). **Editable** por la dueña (override manual). |
| **Estado** | Default `Programada`. No editable en el formulario de creación; se cambia desde el detalle o menú rápido. |
| **Nota** | Opcional, texto libre. |

**Reglas:**
- Si el Catálogo está vacío: al abrir el formulario, mostrar aviso con enlace directo a Catálogo y **bloquear el guardado** hasta que haya al menos un servicio.
- Al cambiar la selección de servicios, recalcular el precio total **solo si la dueña no lo ha editado manualmente**; si ya lo editó, no sobreescribir.
- Validar fecha/hora no vacías.
- Al guardar: la cita aparece en **Agenda** (día correspondiente) y en **Citas → Programadas**.
- Editar: formulario precargado; mismas reglas.

---

## 6. WhatsApp (transversal)

### 6.1 Notificación de cita a una clienta
- Disponible desde: **detalle de cita** y **ficha de clienta** (si hay cita seleccionada).
- **Comprobación previa:**
  - Si la clienta **no tiene teléfono**: mensaje “Esta clienta no tiene número de WhatsApp” + opción **“¿Deseas agregar número de contacto? Sí / No”**.
    - **No** → cerrar el aviso.
    - **Sí** → abrir formulario de teléfono con selector de código de país; al guardar, habilitar el toggle **“Notificar por WhatsApp Sí/No”**.
  - Si la clienta **tiene teléfono pero el toggle está en No**: mostrar aviso “Notificaciones desactivadas para esta clienta” + opción de activar el toggle.
- **Generación del mensaje:** preelaborado según plantilla, con regla de **fecha relativa** (§7.2). Estructura base:
  > Hola {{nombre}}, recuerde que {{fecha_relativa}} tiene cita conmigo a las {{hora}}. Por favor, si se le presenta algún problema me avisa con antelación. Gracias.
- **Sin servicio ni precio** en este mensaje.
- **Vista previa editable** del mensaje antes de enviar.
- Botón **“Enviar”** → abre WhatsApp con el texto y destinatario precargados (§10.2).
- El envío real lo hace la dueña manualmente en WhatsApp. La app no confirma entrega ni lectura.
- Opcional (recomendado): registrar `ultimo_mensaje_preparado_en` en la cita para trazabilidad interna.

### 6.2 Compartir catálogo
- Disponible desde: **Catálogo** y desde **Inicio → Compartir catálogo por WhatsApp**.
- Toma **todos los servicios activos** del Catálogo.
- Genera **un solo mensaje** con cada servicio y su precio al lado. Estructura base (el formato final se pule en diseño, pero debe ser un único mensaje):
  > Catálogo de servicios – {{nombre_negocio}}
  > • {{servicio_1}} – {{precio_1}}
  > • {{servicio_2}} – {{precio_2}}
  > • ...
- **No** se dirige a una clienta específica: abre WhatsApp en la pantalla de **selección de destinatario**; la dueña elige contacto o grupo.
- **Vista previa editable** del mensaje antes de enviar.
- Botón **“Enviar”** → abre WhatsApp con el texto precargado.

### 6.3 Reglas comunes de mensajes
- Todos los mensajes van **preelaborados** por la app.
- La dueña **puede editar** el texto antes de enviar.
- El envío es **manual**: pulsar “Enviar” abre WhatsApp; la confirmación de envío ocurre fuera de la app.
- La app **no** requiere internet para preparar mensajes; solo WhatsApp lo requiere para enviarlos.

---

## 7. Reglas transversales

### 7.1 Buscador tolerante
Aplica a **todos los buscadores de la app** (hoy solo en Clientes; futuros buscadores deben heredar esta regla).

**Normalización del texto (entrada y campo de búsqueda):**
1. Convertir a minúsculas.
2. Eliminar **diacríticos/acentos** (NFD + remover marcas combinantes): “Sofía” → “sofia”.
3. Colapsar espacios múltiples en uno.
4. Recortar espacios al inicio y al final.
5. (Opcional recomendado) Ignorar signos de puntuación para búsquedas por nombre.

**Comportamiento:**
- Devuelve **todos los resultados** que contengan la subcadena normalizada en cualquier posición.
- No requiere coincidencia exacta ni al inicio.
- Ejemplos: “Sofia”, “Sofía”, “ sofia ”, “SOFIA”, “sofia ” → todos devuelven las mismas clientas.

### 7.2 Fechas relativas en mensajes de WhatsApp
Regla única para el texto “mañana” vs fecha completa:
- Si la **fecha de la cita** es el **día siguiente** a la fecha del mensaje → usar **“mañana”**.
- En **cualquier otro caso** → usar **fecha completa** (día + mes, y año si difiere).
- Ejemplo: cita el día 20, mensaje el día 19 → “mañana”. Mensaje el día 18 → “20 de [mes]”.

### 7.3 Precio
- El **precio de cada servicio** se toma **siempre del Catálogo**.
- El **precio total** de la cita se **auto-calcula** como suma de los servicios seleccionados.
- El total es **editable** por la dueña.
- Si la dueña edita el total y luego cambia la selección de servicios: **no sobreescribir** el total editado (mostrar aviso opcional: “El total fue modificado manualmente”).
- Se guarda `nombre_snapshot` y `precio_snapshot` por servicio en la cita para proteger el historial ante ediciones/inactivaciones del Catálogo.

### 7.4 Servicios eliminados (Opción B — eliminación lógica)
- Al “eliminar” un servicio del Catálogo, este pasa a `activo = false`.
- **Deja de aparecer** en el selector de nuevas citas.
- **No se borra** de la base de datos.
- Las citas existentes **conservan su referencia** al servicio (por snapshot + id).
- Se puede **reactivar** desde la sección “Inactivos” del Catálogo.
- El precio del servicio inactivo sigue disponible para el historial.

### 7.5 Ciclo de vida de la cita (modelo híbrido)

**Estados:**
- `Programada` — estado inicial.
- `Pendiente_de_cerrar` — estado transitorio automático.
- `Terminada` — final.
- `Cancelada` — final.
- `No_asistio` — final.

**Transiciones:**
- Al crear → `Programada`.
- Al llegar la **hora de inicio** de la cita → **automáticamente** pasa a `Pendiente_de_cerrar`.
  - Deja de mostrarse en **Programadas**.
  - Aparece en **Pendientes de cerrar**.
  - No cuenta como Historial consolidado.
  - Si la app está abierta, la actualización debe reflejarse sin recargar manualmente.
- Desde `Pendiente_de_cerrar` la dueña decide:
  - **Terminar** → `Terminada` (Historial).
  - **Cancelar** → `Cancelada` (Historial).
  - **No asistió** → `No_asistio` (Historial).
  - **Reprogramar/Posponer** → abre selector de nueva fecha/hora; vuelve a `Programada` con nueva fecha.
  - **Eliminar** → borrado real (con confirmación).
- Desde `Programada` la dueña también puede Terminar/Cancelar/No asistió/Eliminar/Reprogramar.
- `Historial` contiene únicamente `Terminada`, `Cancelada`, `No_asistio`, ordenadas por `cerrada_en` descendente.
- **No existe estado “Pospuesta” persistente**: posponer = reprogramar (vuelve a Programada).

### 7.6 Menú rápido (long press)
- Al mantener presionada una cita **500 ms** → diálogo modal con: **Terminada / Posponer / Eliminar / Cancelar / No asistió**.
- Cada opción se comporta según §7.5.
- “Posponer” abre selector de fecha/hora y reprograma.

---

## 8. Estados y transiciones (resumen visual)

```
[Crear cita]
     │
     ▼
  Programada ──(hora llega)──▶ Pendiente_de_cerrar
     │                              │
     │                              ├─ Terminar ──▶ Terminada (Historial)
     │                              ├─ Cancelar ──▶ Cancelada (Historial)
     │                              ├─ No asistió ─▶ No_asistio (Historial)
     │                              ├─ Reprogramar ─▶ Programada (nueva fecha)
     │                              └─ Eliminar ──▶ (borrado)
     │
     ├─ Terminar ──▶ Terminada (Historial)
     ├─ Cancelar ──▶ Cancelada (Historial)
     ├─ No asistió ─▶ No_asistio (Historial)
     ├─ Reprogramar ─▶ Programada (nueva fecha)
     └─ Eliminar ──▶ (borrado)
```

---

## 9. Consideraciones técnicas

### 9.1 Base de datos local
- SQLite con migraciones versionadas.
- Índices en: `citas(fecha_hora)`, `citas(estado)`, `clientas(nombre_normalizado)`.
- Recomendado: guardar el `nombre_normalizado` de la clienta (según §7.1) para búsquedas eficientes.

### 9.2 Job de transición automática
- Al abrir la app y periódicamente mientras está en primer plano (p. ej. cada minuto o al cambiar de pantalla), ejecutar un chequeo que pase a `Pendiente_de_cerrar` las citas en `Programada` cuya `fecha_hora <= ahora`.
- No requiere servicio en segundo plano en v1.

### 9.3 Apertura de WhatsApp
- Notificación a clienta específica: `whatsapp://send?phone={{telefono_e164}}&text={{mensaje_urlencoded}}` con fallback a `https://wa.me/{{telefono_e164}}?text={{mensaje_urlencoded}}`.
- Compartir catálogo (sin destinatario): `https://wa.me/?text={{mensaje_urlencoded}}` (abre selección de destinatario) o `whatsapp://send?text={{mensaje_urlencoded}}`.
- URL-encode del texto completo.
- Si WhatsApp no está instalado: mostrar aviso.

### 9.4 Permisos
- v1: no requiere permisos especiales adicionales más allá de los estándar para lanzar WhatsApp.
- Permisos de notificaciones → solo v2 (recordatorios).

### 9.5 Formato de fecha y hora
- Locale `es`.
- Mostrar fechas como “17 de octubre de 2026” en contextos de lectura; “17/10/2026” o similar en listas compactas.
- Hora en formato 24 h por defecto (configurable en v2 si se requiere).

### 9.6 Accesibilidad
- Contraste suficiente en iconos activos vs inactivos.
- Tamaños táctiles mínimos de 44×44.
- Textos legibles con escalado del sistema.

### 9.7 Rendimiento
- La app debe abrir en < 2 s con hasta 5.000 citas y 2.000 clientas en almacenamiento.
- Listados con scroll virtualizado.

---

## 10. Fuera de alcance v1 (pendientes explícitos)

No implementar en esta versión (serán fases siguientes):
- **Recordatorios** (notificación diaria general para la dueña + recordatorio por cita). Toda la lógica está diseñada pero **no se implementa ahora**.
- **Backup / exportación / importación** de datos.
- **PIN** de acceso.
- **Plantillas de mensajes editables** en Ajustes (en v1 pueden ser constantes internas).
- **Duplicar cita**, **Copiar datos de la cita** al portapapeles.
- **Estadísticas financieras** o reportes.
- **Multiusuario**, **multiempleadas**.
- **Sincronización en nube**.
- **Envío automático** por WhatsApp Business API.
- **Fotos de trabajos**.
- **Navegación a meses pasados en Agenda** (sí está dentro de alcance, confirmado; solo lo listo aquí para evitar confusión: **Agenda sí navega a meses pasados y futuros**).
- **Precio con snapshot** ya está incluido arriba; no es pendiente.

---

## 11. Criterios de aceptación (por módulo)

### 11.1 Navegación
- [ ] Barra lateral fija con 6 iconos visibles en todo momento.
- [ ] Cambiar de menú cambia solo el panel de contenido; la barra no se mueve.
- [ ] No existe drawer ni gesto de apertura/cierre.
- [ ] En pantalla de 320 px de ancho, la barra se mantiene y el contenido se adapta sin scroll horizontal.
- [ ] Icono activo se distingue por color de acento + fondo circular.
- [ ] Subflujos tienen botón “Volver” y reemplazan el contenido del panel.

### 11.2 Inicio
- [ ] Muestra saludo, fecha y contador de citas de hoy.
- [ ] Próxima cita destacada con botones Ver detalle / Notificar por WhatsApp / Llamar.
- [ ] Lista de citas de hoy o mensaje vacío con “Agregar cita”.
- [ ] Aviso de pendientes de cerrar con contador y enlace.
- [ ] Accesos rápidos funcionan: Agregar cita (fecha vacía), Agregar clienta, Agenda de mañana, Compartir catálogo.
- [ ] Resumen semanal con contadores.
- [ ] Aviso de catálogo vacío con enlace.

### 11.3 Agenda
- [ ] Abre en el mes actual.
- [ ] Permite ir a meses pasados y futuros.
- [ ] Cada día con citas muestra numerito con cantidad.
- [ ] Tocar un día abre vista del día.
- [ ] Día sin citas: mensaje + “Agregar cita” con fecha precargada.
- [ ] Día con citas: lista por hora; tocar → detalle.
- [ ] Cita creada desde aquí aparece en Citas y en el calendario.

### 11.4 Citas
- [ ] Tres pestañas: Programadas / Pendientes de cerrar / Historial.
- [ ] Filtros Hoy / Semana / Mensual.
- [ ] Botón “Agregar cita” con fecha vacía.
- [ ] Al pasar la hora, la cita se mueve automáticamente a Pendientes de cerrar.
- [ ] Long press 500 ms abre menú rápido con 5 opciones.
- [ ] Detalle con las 7 acciones confirmadas.
- [ ] Historial ordenado de más reciente a más antiguo.
- [ ] Cita reprogramada vuelve a Programadas con nueva fecha.

### 11.5 Clientes
- [ ] Listado alfabético.
- [ ] Buscador tolerante (tildes, espacios, mayúsculas/minúsculas).
- [ ] Ficha con datos + últimas 10 citas (fecha, hora, servicio, precio).
- [ ] Alta/edición con nombre obligatorio, teléfono con código de país opcional, nota opcional.
- [ ] Toggle “Notificar por WhatsApp” visible solo con teléfono.

### 11.6 Catálogo
- [ ] Listado alfabético con nombre y precio.
- [ ] Agregar, editar, eliminar (lógico) y reactivar.
- [ ] Validaciones de nombre único y precio ≥ 0.
- [ ] Compartir por WhatsApp: un solo mensaje con todos los servicios y precios, editable, abre WhatsApp a selección de destinatario.

### 11.7 Formulario de cita
- [ ] Clienta con buscador tolerante y opción de crear nueva.
- [ ] Fecha precargada desde Agenda; vacía desde Citas/Inicio.
- [ ] Hora obligatoria.
- [ ] Servicios múltiples desde Catálogo; al menos uno.
- [ ] Precio total auto-calculado y editable; respeta edición manual.
- [ ] Guardar crea la cita y aparece en Agenda y Citas.

### 11.8 WhatsApp
- [ ] Notificación: mensaje sin servicio ni precio, con “mañana” solo si es el día siguiente, fecha completa en otro caso.
- [ ] Vista previa **editable** antes de enviar.
- [ ] Pulsar “Enviar” abre WhatsApp con texto y destinatario precargados.
- [ ] Sin teléfono: mensaje “No tiene número” + flujo de agregar.
- [ ] Catálogo: un solo mensaje con todos los servicios y precios; abre selección de destinatario.

### 11.9 Datos y persistencia
- [ ] La app funciona completamente sin internet.
- [ ] Al cerrar y reabrir la app, todos los datos persisten.
- [ ] Las transiciones automáticas a Pendientes de cerrar se aplican al abrir la app.

---

## 12. Puntos abiertos a confirmar antes o durante el desarrollo

Estos puntos **no bloquean** el inicio del desarrollo, pero deben resolverse antes de la entrega final:
1. **Símbolo de moneda** por defecto y si es configurable.
2. **Formato visual exacto** del mensaje de catálogo (encabezado, viñetas, saltos de línea, emojis opcionales).
3. **Plantillas de mensajes** hardcodeadas en v1 o editables en Ajustes (recomendado: hardcodeadas ahora, editables en v2).
4. **Color de acento por defecto** y paleta de opciones.
5. **Comportamiento del aviso de pendientes de cerrar** en Inicio: umbral de antigüedad para considerarlo urgente (a definir v2).
6. **Nombre de la app** y branding visual.
7. **¿Mostrar confirmación** al preparar un mensaje de WhatsApp en la cita (“¿Marcar como preparado?”)? Recomendado: sí, opcional.

---

**Fin del documento v1.0.**  
Cualquier decisión nueva se documenta como enmienda a esta versión.