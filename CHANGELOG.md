# Cambios

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
