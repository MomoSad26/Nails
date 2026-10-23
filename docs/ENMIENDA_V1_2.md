# Enmienda v1.2 — Pantalla de monedas y ventanas apiladas

Esta enmienda reemplaza por completo la sección §2 (Navegación y layout) de la especificación funcional v1.0. El resto de las reglas de v1.0 y v1.1 sigue vigente, salvo incompatibilidad explícita con este documento.

## 1. Modelo general

- No existe una barra lateral fija.
- La única pantalla raíz es la pantalla de monedas.
- Cada moneda abre una ventana de pantalla completa encima de la actual.
- Cada acción de navegación apila una ventana; **Volver** desapila exactamente una.
- El botón o gesto de retroceso de Android ejecuta la misma acción que **Volver**.
- En la raíz no aparece **Volver** y el retroceso del sistema conserva el comportamiento habitual de la plataforma.
- Las ventanas anteriores permanecen montadas y ocultas para conservar desplazamiento, filtros y datos de formularios.

## 2. Pantalla de monedas

### 2.1 Contenido

En la parte superior aparece un marcador provisional de logo, centrado, con el nombre del negocio. Debajo se muestran solo los seis menús, cada uno con un icono y su nombre:

- Inicio — casa.
- Agenda — calendario.
- Citas — lista de citas.
- Clientes — personas.
- Catálogo — servicios.
- Ajustes — engranaje.

No se muestran resúmenes ni contadores en la pantalla raíz.

### 2.2 Disposición adaptable

- Móvil en vertical: cuadrícula de dos columnas y tres filas.
- Pantallas anchas: tres columnas y dos filas.
- Monedas circulares con tamaño táctil aproximado de 82 px, separación uniforme y scroll vertical si falta espacio.
- El grupo se centra vertical y horizontalmente cuando la altura disponible lo permite.

### 2.3 Animación y respuesta táctil

- La moneda da una animación breve de escala/rebote al pulsarla.
- La ventana entra con una transición de fade y desplazamiento.
- Al volver, la ventana superior sale con una transición inversa.
- Las transiciones duran aproximadamente 200–300 ms.

## 3. Ventanas apiladas

- Cada menú o subflujo ocupa toda la pantalla y oculta la ventana anterior.
- Todas las ventanas internas muestran **Volver** arriba a la izquierda.
- **Volver** y el retroceso del sistema desapilan una ventana, sin saltarse niveles.
- Una secuencia típica es: Pantalla de monedas → Clientes → Ficha de clienta → Editar clienta. Cada retroceso muestra la ventana anterior.
- Los formularios y detalles, incluido el catálogo abierto desde una cita, se apilan como ventanas independientes.
- La raíz se mantiene al fondo de la pila. Las acciones de acceso rápido también se apilan; no reinician ni mezclan los subflujos.
- En la raíz, un retroceso adicional sale o minimiza la aplicación conforme a Android.

## 4. Reglas que permanecen vigentes

La gestión de clientas, citas, servicios, agenda, historial, mensajes de WhatsApp, moneda y código de país no cambia. Se mantienen las confirmaciones de eliminación, el orden visual **Cancelar** / **Aceptar**, el plazo de **Deshacer de cinco segundos**, el buscador tolerante y el código de país **+53** editable.

Los diálogos modales se reservan para confirmaciones y menús rápidos. WhatsApp sigue abriéndose con el mensaje preparado para revisión y envío manual.

## 5. Estilo visual

- Fondo predeterminado azul marino.
- Textos principales claros y secundarios en azul grisáceo claro.
- Tarjetas y campos en tonos de azul más claros que el fondo, con bordes visibles.
- Botones, estados e iconos mantienen contraste legible.
- El logo definitivo podrá incorporarse posteriormente sin cambiar la navegación.

## 6. Criterios de aceptación

- [ ] No aparece una barra lateral fija.
- [ ] La pantalla raíz presenta un marcador de logo y las seis monedas con icono y nombre.
- [ ] La cuadrícula usa 2×3 en móvil vertical y puede adaptarse a 3×2 en pantallas anchas.
- [ ] Pulsar una moneda da feedback y abre una ventana animada.
- [ ] Las ventanas internas muestran **Volver** arriba a la izquierda.
- [ ] **Volver**, el botón del sistema y el gesto de borde recorren la misma pila.
- [ ] Cada retroceso desapila un único nivel y conserva el estado anterior.
- [ ] El fondo predeterminado es azul marino y el texto, las tarjetas, los campos y los controles mantienen contraste.
- [ ] En la raíz no aparece **Volver** y el retroceso del sistema conserva el comportamiento normal.
