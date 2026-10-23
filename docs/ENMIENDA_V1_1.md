# Enmienda v1.1 — Aclaraciones incorporadas

Esta enmienda complementa la especificación funcional v1.0. En caso de contradicción, prevalecen estas reglas.

## 1. Navegación y retroceso

Todas las pantallas internas tienen un botón visible **Volver** que retrocede exactamente un nivel en la pila de navegación del panel. El retroceso Android vuelve por la misma pila; además se admite el gesto de borde izquierdo mientras exista una pantalla interna. En el nivel raíz, el botón no se muestra y la plataforma conserva su comportamiento normal.

## 2. Eliminación y deshacer

Toda acción de eliminación debe pedir confirmación con **Cancelar** a la izquierda y **Aceptar** a la derecha. Al aceptar, aparece un aviso con **Deshacer** durante cinco segundos. Deshacer restaura el estado previo. Si se navega a otro módulo antes de que venza el aviso, la operación pendiente se consolida de forma coherente.

- **Citas:** quedan ocultas temporalmente y se eliminan físicamente al consolidarse; Deshacer las restaura.
- **Servicios:** se aplica eliminación lógica (`activo = false`); Deshacer vuelve a activarlos. No se borran porque los snapshots sostienen el historial.
- **Clientas:** se ocultan durante la ventana de Deshacer. Si no tienen citas, se eliminan físicamente al consolidarse; si tienen historial, se conservan como inactivas y no notificables para preservar las relaciones y el historial.

Esta distinción protege las referencias de las citas y evita que una eliminación destruya datos históricos relacionados.

## 3. Ficha de clienta

Al seleccionar una clienta se abre una ficha con nombre, teléfono completo incluido código de país, nota, fecha de registro, estado activa/inactiva y estado de notificación por WhatsApp. La ficha permite editar todos los datos. Incluye acciones para agendar y preparar una notificación cuando corresponde; debajo aparecen las diez citas más recientes. Cada cita permite abrir su detalle.

## 4. Código de país

El código de país de un formulario nuevo comienza en **+53**. El campo es editable, por lo que no se limita a una lista fija de países. Si la clienta ya tiene teléfono, se recupera el código guardado. Si aún no tenía teléfono, al abrir el formulario para agregarlo se propone de nuevo +53.

## 5. Criterios de aceptación adicionales

- [ ] El botón Volver y el retroceso del sistema recorren la misma pila interna.
- [ ] Cada eliminación muestra confirmación Cancelar/Aceptar en ese orden visual.
- [ ] El aviso Deshacer permanece cinco segundos y restaura el estado original.
- [ ] La ficha permite editar todos los datos de una clienta.
- [ ] Se muestran las últimas diez citas de más reciente a más antigua.
- [ ] Un formulario nuevo de teléfono propone +53, con el código editable.
