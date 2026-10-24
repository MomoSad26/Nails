# Enmienda v1.3 — Inicio, Citas, selector de clienta y formato horario

Esta enmienda conserva las reglas de navegación v1.2 y define los siguientes cambios funcionales.

## 1. Menú Inicio — versión final

El contenido aparece en este orden:

1. Saludo «Hola [nombre de la dueña]», fecha actual y texto «Hoy tienes X citas».
2. Lista compacta de las citas del día, ordenadas por hora ascendente. Cada fila muestra hora, nombre de la clienta y estado. Al tocar, abre el detalle. Si no hay citas, muestra «No tienes citas hoy» sin un botón de Agregar cita en ese bloque.
3. Cuatro accesos rápidos en vertical: **Agregar cita**, **Agregar clienta**, **Citas** y **Compartir catálogo**. Agregar cita abre el formulario con fecha y hora actuales; Compartir catálogo prepara el mensaje y abre WhatsApp para elegir destinatario.
4. Resumen semanal con «Citas esta semana: X» y «Citas próxima semana: Y». No se muestran gráficos.
5. Aviso de catálogo vacío solo cuando no hay servicios activos: «Tu catálogo está vacío. Agrega servicios para poder agendar citas», con botón para abrir Catálogo.

Se eliminan de Inicio la próxima cita destacada y el aviso de citas pendientes por cerrar.

## 2. Formato global de fecha y hora

- Todas las horas visibles se presentan en formato de 12 horas con **AM/PM**, en la lista, el detalle, el formulario, Agenda, Inicio y los mensajes de WhatsApp.
- Todos los selectores de hora muestran el periodo AM/PM y se abren con la hora actual del dispositivo.
- Al abrir un selector de fecha, su fecha inicial es la fecha actual del dispositivo, excepto al crear una cita desde Agenda con un día seleccionado: en ese caso, se conserva ese día como fecha inicial.
- Al crear una cita desde Inicio o Citas, el formulario se precarga con la fecha y hora actuales. Fecha y hora siguen siendo editables.
- La fecha y hora guardadas se combinan en un único valor de fecha/hora para la cita.

## 3. Agenda — día sin citas

Al seleccionar un día vacío, la vista muestra «No hay citas para este día» y un solo botón «Agregar cita» arriba a la derecha. El botón abre el formulario con el día seleccionado. No se repite un segundo botón dentro del mensaje vacío.

## 4. Menú Citas

- Un selector exclusivo de dos opciones: **Programadas (contador)** y **Pendientes por cerrar (contador)**.
- No hay filtros Hoy, Semana ni Mensual.
- **Programadas** contiene las citas futuras, de la más cercana a la más lejana.
- Cuando una cita llega a su fecha/hora, pasa automáticamente a **Pendientes por cerrar**. Esta lista ordena primero las más antiguas.
- **Historial** es un acceso separado, fuera del selector de dos opciones. Solo muestra citas cerradas (Terminada, Cancelada o No asistió), de la más reciente a la más antigua, sin contador.
- Abrir un elemento del Historial muestra el detalle en modo de consulta y su única acción es **Eliminar**.
- El detalle de una cita pendiente expone en este orden: **Terminar**, **Cancelar**, **Reprogramar**, **Eliminar**, **No asistió**.
- Mantener pulsada una cita en Programadas o Pendientes por cerrar durante 500 ms abre el menú rápido con esas mismas cinco acciones y ese orden.
- Al reprogramar una cita pendiente, vuelve a Programadas con una nueva fecha/hora.
- Nunca se muestra el término «Posponer»; se utiliza «Reprogramar».

## 5. Formulario Agendar cita — selector de clienta

El nombre y la búsqueda se integran en un solo componente:

- Al tocar el campo se despliega una lista dentro del selector, inmediatamente debajo del campo.
- Escribir filtra por nombre o teléfono con búsqueda tolerante a tildes, mayúsculas/minúsculas y espacios.
- Al seleccionar una clienta, su nombre aparece en el campo y la lista se cierra.
- Al volver a tocar el campo, se puede cambiar la selección.
- «Crear nueva clienta» aparece dentro del mismo selector, aunque la lista esté vacía o no haya coincidencias.
- Sin clientas registradas, la lista muestra «No hay clientas» junto a la opción para crear una.
- Al crear una clienta desde el selector y guardarla, queda seleccionada en el formulario de cita.
- Se comprueba que abrir/cerrar el selector y borrar la búsqueda no deja listas duplicadas ni selección desincronizada.

## 6. Criterios de aceptación

- [ ] Inicio mantiene el orden final y no muestra la próxima cita destacada ni el aviso de pendientes.
- [ ] La lista compacta de hoy muestra hora AM/PM, clienta y estado; al tocar abre el detalle.
- [ ] Si hoy está vacío, Inicio muestra «No tienes citas hoy» sin botón dentro de ese bloque.
- [ ] Los cuatro accesos rápidos aparecen uno debajo del otro.
- [ ] El resumen semanal muestra dos contadores y no incluye gráficos.
- [ ] El aviso de catálogo vacío solo aparece cuando no hay servicios activos.
- [ ] Todas las horas visibles usan formato 12 h con AM/PM.
- [ ] Los selectores de fecha/hora se abren con los valores actuales, con la excepción del día seleccionado en Agenda.
- [ ] Un día vacío en Agenda solo muestra un botón Agregar cita arriba a la derecha.
- [ ] Citas tiene dos opciones mutuamente excluyentes con contadores y no incluye filtros de tiempo.
- [ ] Historial está fuera del selector, ordenado más reciente primero y su detalle solo permite eliminar.
- [ ] Acciones y menú rápido siguen el orden definido y utilizan «Reprogramar».
- [ ] El selector de clienta es un único componente, permite búsqueda tolerante y selecciona a la clienta sin duplicar listas.
- [ ] Una nueva clienta creada desde el selector queda seleccionada al volver al formulario.
- [ ] Un push de actualización a main genera una única ejecución de Actions con un solo job de compilación APK.
