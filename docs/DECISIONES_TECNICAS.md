# Decisiones técnicas y límites conocidos

## Arquitectura

- Flutter y Dart; interfaz en español.
- SQLite mediante `sqflite`; toda la gestión principal ocurre en el dispositivo y no depende de Internet.
- `lib/data/app_database.dart` centraliza esquema, índices, consultas y transacciones.
- `lib/services/whatsapp_service.dart` abre WhatsApp o su alternativa web con un mensaje ya codificado; no envía mensajes automáticamente.
- La navegación interna se controla con una pila en `DashboardShell`; el `PopScope` usa esa misma pila y el gesto de borde izquierdo llama al mismo retroceso.

## Datos e integridad

- Cada servicio de una cita guarda nombre y precio de snapshot. Los cambios futuros del catálogo no alteran el historial.
- Los servicios se desactivan, nunca se eliminan físicamente desde la interfaz.
- Una cita eliminada se marca temporalmente como oculta. Al vencer los cinco segundos, se elimina con sus filas de servicios por la relación `ON DELETE CASCADE`.
- Una clienta sin citas puede eliminarse físicamente al consolidar. Una clienta con citas pasa a inactiva para preservar las claves foráneas y el historial.
- Las operaciones pendientes de Deshacer viven en memoria; cerrar el proceso durante esos cinco segundos consolida la operación. No se pretende ofrecer una cola persistente de deshacer a través de reinicios.

## Fechas y cambios automáticos

- Se guarda la fecha y hora local del dispositivo.
- Al abrir la app y cada 30 segundos en primer plano, las citas cuya hora ya llegó pasan de `Programada` a `Pendiente_de_cerrar`.
- No se implementan trabajos en segundo plano, recordatorios ni notificaciones del sistema.

## WhatsApp

- Los mensajes se pueden editar antes de abrir WhatsApp.
- La notificación de cita no incluye servicios ni precio.
- Solo usa “mañana” cuando la cita cae exactamente al día calendario siguiente; en otro caso usa fecha completa. Desde la ficha de clienta solo propone citas futuras en estado Programada, para evitar preparar por error un recordatorio de una cita pasada.
- El número se normaliza a dígitos para crear el enlace. La aplicación no confirma envío, entrega o lectura.

## Plataforma y compilación

El repositorio guarda la fuente Flutter, no el esqueleto generado de Android/iOS. En una máquina con Flutter instalado, ejecutar una vez `flutter create --platforms=android,ios --project-name=manigest .` para generar esas carpetas si faltan. El workflow de GitHub crea temporalmente el esqueleto Android en el runner, analiza el código, ejecuta pruebas y publica un APK de depuración como artefacto.
