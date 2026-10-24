# Detalle de cita — Consolidado v2

Esta enmienda reemplaza las reglas previas sobre el detalle de una cita.

## Acceso y datos
El detalle se abre al tocar una cita desde Programadas, Pendientes por cerrar, Historial, Agenda del día, Inicio o las últimas 10 citas de una clienta. La pantalla se apila sobre la anterior y el botón Volver, el gesto de borde y el retroceso del sistema desapilan un nivel. Muestra clienta, fecha completa con día de semana, hora AM/PM, cada servicio con su precio, total, estado y nota.

## Acciones por estado
- **Programada:** Editar cita; Notificar por WhatsApp; Llamar si tiene teléfono; Reprogramar; Cancelar; Eliminar; Terminar. No aparece No asistió.
- **Pendiente por cerrar:** Llamar si tiene teléfono; Reprogramar; Cancelar; Eliminar; No asistió; Terminar. No aparecen Editar cita ni Notificar por WhatsApp.
- **Terminada, Cancelada o No asistió:** solo Eliminar, sin importar desde qué pantalla se abrió el detalle.

Editar precarga clienta, fecha, hora, servicios, total y nota. Tras guardar, una cita con fecha/hora pasada se clasifica como Pendiente por cerrar. Reprogramar preserva los demás datos y arranca con la fecha y hora actuales del dispositivo; al guardar, la app clasifica según si la nueva fecha/hora está en el futuro o en el pasado. El término Posponer no se utiliza.

## WhatsApp y llamada
La acción Notificar por WhatsApp prepara un mensaje informativo sin servicio ni precio, con nombre de clienta, fecha relativa (mañana solo si la cita es el día siguiente; en otro caso la fecha), y hora AM/PM. El texto se puede editar antes de abrir WhatsApp, con destinatario y mensaje precargados. La app no declara que el mensaje se entregó o leyó.

Sin teléfono, se pregunta si se desea agregarlo. Al guardarlo se actualiza la clienta, el toggle queda activado por defecto y se prepara el mensaje de la cita concreta. Si el toggle estaba desactivado manualmente, se muestra «Notificaciones desactivadas para esta clienta» y se pregunta si se desea activarlo. Llamar solo se ofrece cuando hay teléfono y abre el marcador del sistema sin confirmación.

El código de país parte de +53, ofrece selección de códigos habituales y permite escribir un código distinto. Al añadir o volver a añadir teléfono, WhatsApp se activa por defecto. Si la dueña desactiva manualmente el toggle, la preferencia queda guardada.

## Confirmación y Deshacer
Cancelar, Eliminar, No asistió y Terminar piden confirmación con Cancelar a la izquierda y Aceptar a la derecha. Tras confirmar, aparece el aviso correspondiente con Deshacer durante 5 segundos exactos. Deshacer antes del vencimiento restaura estado y fecha de cierre anteriores (o restaura la cita eliminada); al vencer, se elimina el aviso y la acción queda consolidada. Navegar a otra pantalla no oculta el aviso ni reinicia/cancela el temporizador.

El menú rápido de pulsación larga (500 ms) desde Programadas y Pendientes por cerrar mantiene el orden Terminar, Cancelar, Reprogramar, Eliminar, No asistió; cerrar una cita desde ahí también requiere confirmación y ofrece Deshacer.
