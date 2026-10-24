# Cambios

## 1.3.2 — Nombre NailStudio e icono de aplicación

- Se cambia el nombre visible de la aplicación a **NailStudio**, incluido el título Flutter y la etiqueta del icono Android.
- Se incorpora el nuevo icono cuadrado a sangre, sin bordes blancos, y se generan los iconos adaptativos/legacy de Android durante la compilación.
- Se conserva el nombre interno del paquete Flutter y el identificador Android para no introducir cambios innecesarios en la identidad técnica de la aplicación.
- El APK de esta versión se publica como `NailStudio.apk`; el artefacto de Actions se llama `NailStudio-APK`.

## 1.3.1 — Detalle de cita y acciones reversibles

- El detalle se abre desde Citas, Agenda, Inicio y las últimas 10 citas de la ficha de clienta; las acciones se determinan por el estado actual de la cita.
- Programadas muestra Editar cita, Notificar por WhatsApp, Llamar (si hay teléfono), Reprogramar, Cancelar, Eliminar y Terminar, en ese orden; no muestra No asistió.
- Pendientes por cerrar muestra Llamar (si hay teléfono), Reprogramar, Cancelar, Eliminar, No asistió y Terminar; no aparecen Editar cita ni Notificar por WhatsApp.
- Historial y cualquier cita cerrada solo muestran Eliminar.
- Cancelar, No asistió y Terminar requieren confirmación y permiten Deshacer durante 5 segundos; el temporizador continúa al navegar, retira cada aviso al vencer y restaura el estado previo si se usa Deshacer.
- Reprogramar usa la fecha y hora actuales como valores iniciales y conserva clienta, servicios, total y nota; si la nueva fecha/hora ya pasó, pasa a Pendientes por cerrar.
- Notificar por WhatsApp prepara el texto para la cita seleccionada, permite editarlo antes de abrir WhatsApp y reanuda el flujo después de agregar un teléfono.
- El código de país permite elegir códigos habituales (con +53 por defecto) o escribir otro; al agregar teléfono se activa WhatsApp por defecto, mientras la elección manual del toggle se conserva.
- La fecha del detalle incluye el día de la semana; las horas siguen en formato de 12 horas con AM/PM.

## 1.3.0 — Inicio final, Citas y formato horario

- Inicio queda con saludo, fecha, número de citas de hoy, lista compacta ordenada por hora, cuatro accesos rápidos verticales, contadores semanales y aviso de catálogo vacío condicional.
- Se eliminan de Inicio la próxima cita destacada y el aviso de citas pendientes por cerrar.
- Citas usa solo el selector exclusivo Programadas / Pendientes por cerrar, ambos con contador; Historial se abre en una ventana aparte.
- Historial muestra las citas cerradas más recientes primero y su detalle solo permite eliminar.
- Las citas vencidas pasan a Pendientes por cerrar; las listas de Programadas y Pendientes se ordenan por hora, y el menú rápido usa Terminar / Cancelar / Reprogramar / Eliminar / No asistió.
- Agenda ya no duplica Agregar cita cuando un día está vacío.
- El selector de clienta se integra en un solo campo de búsqueda/selección, con filtrado tolerante y opción Crear nueva clienta en el mismo panel.
- Todas las horas visibles pasan a 12 horas con AM/PM. Los selectores se abren con la hora actual y las fechas con la fecha actual, excepto el día seleccionado desde Agenda.
- Actions se organiza como un único job de compilación por push a main o ejecución manual; el build produce un APK y publica el artefacto y el enlace de Releases.


## 1.2.0 — Pantalla de monedas y ventanas apiladas

- Se elimina la barra lateral fija y se añade una pantalla raíz con seis monedas circulares, icono y nombre.
- Los menús y subflujos se abren en ventanas de pantalla completa con animación y una pila compartida.
- El botón **Volver**, el retroceso del sistema y el gesto de borde recorren la misma pila.
- Las ventanas anteriores permanecen montadas para conservar el desplazamiento, filtros y formularios.
- Tema azul marino predeterminado, textos claros, campos oscuros y bordes de alto contraste.
- La versión Android pasa a 2; GitHub Actions analiza, prueba y genera un APK de lanzamiento firmado. Si no existe una clave válida en Secrets, genera una clave nueva y publica un respaldo privado del material de firma.

## 1.1.0 — Enmienda v1.1 incorporada

- Pila de navegación interna; botón **Volver** y manejo del retroceso del sistema sincronizados.
- Flujo común de confirmación de eliminación con **Cancelar** a la izquierda y **Aceptar** a la derecha.
- Deshacer durante 5 segundos para citas, clientas y desactivación lógica de servicios.
- La ficha de clienta muestra datos editables, acciones y últimas 10 citas con fecha, hora, servicio, precio y estado.
- Código de país **+53** predeterminado para nuevas clientas o fichas sin teléfono; el código se puede editar y se conserva al editar un teléfono guardado.
- SQLite local, transiciones automáticas de citas vencidas, catálogo inactivo/reactivable y mensajes de WhatsApp con vista previa editable.
- CI de GitHub para formato, análisis, pruebas y compilación de APK de depuración.
