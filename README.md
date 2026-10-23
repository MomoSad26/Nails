# ManiGest — Gestión de negocio de uñas

Aplicación Flutter móvil, offline-first y en español para gestionar clientas, citas, servicios, agenda y mensajes preelaborados de WhatsApp. Este proyecto incorpora las reglas funcionales v1.0, las aclaraciones v1.1 y el modelo de navegación v1.2.

## Lo principal que incluye

- Pantalla raíz con seis monedas circulares para Inicio, Agenda, Citas, Clientes, Catálogo y Ajustes; sin barra lateral fija.
- Ventanas apiladas y animadas, con **Volver** sincronizado con el retroceso del sistema; las ventanas anteriores conservan su estado.
- Tema azul marino con textos claros y controles de alto contraste.
- SQLite local con persistencia de clientas, citas, servicios y configuración.
- Citas programadas, pendientes de cerrar e historial; revisión automática de citas vencidas al abrir la app y cada 30 segundos en primer plano.
- Agenda mensual con conteos por día, desplazamiento entre meses y acceso al detalle del día.
- Ficha editable de clienta, selector de código de país editable con **+53** por defecto y últimas diez citas.
- Eliminaciones confirmadas y posibilidad de **Deshacer durante cinco segundos**; los servicios se eliminan lógicamente.
- Precio por servicio guardado como snapshot en cada cita y total de cita editable.
- Mensajes de WhatsApp preelaborados, editables y enviados manualmente desde WhatsApp; sin envío automático.
- Ajustes para el nombre del negocio, nombre de la dueña, color de acento y símbolo de moneda.
- GitHub Actions para analizar el proyecto, correr pruebas y generar un APK de lanzamiento firmado.

## Requisitos

- Flutter estable 3.47.7 o compatible, con Dart 3.12 o superior.
- Android Studio/Android SDK para compilar Android. Xcode es necesario para compilar iOS en macOS.
- Git para trabajar con el repositorio.

Las dependencias de persistencia, fechas y apertura de WhatsApp están declaradas en `pubspec.yaml`; la configuración se almacena en SQLite junto con los datos locales.

## Primer uso local

1. Descomprime el proyecto o clónalo desde GitHub.
2. Abre una terminal en la carpeta raíz `manigest-app`.
3. Si aún no existen las carpetas de plataforma, genera el esqueleto nativo una sola vez:

   ```bash
   flutter create --platforms=android,ios --project-name=manigest .
   ```

4. Descarga dependencias y ejecuta la app:

   ```bash
   flutter pub get
   flutter run
   ```

5. Para compilar un APK de depuración manualmente:

   ```bash
   flutter build apk --debug
   ```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

## Usarlo en GitHub

1. Crea un repositorio vacío en GitHub.
2. Sube el contenido de esta carpeta manteniendo la estructura de carpetas, incluidos `.github/workflows/` y `docs/`.
3. En la pestaña **Actions**, abre la ejecución `Flutter checks`. Se ejecutará automáticamente al hacer push o abrir un pull request.
4. Cuando termine con éxito, descarga el artefacto **manigest-release-apk** desde esa ejecución e instala el APK en Android. Si no hay una clave válida configurada en Secrets, el workflow genera una clave nueva y también publica el artefacto privado **manigest-signing-backup**. Descárgalo y guárdalo de forma segura antes de futuras actualizaciones.

El workflow genera el esqueleto Android solo en el runner porque esta entrega se centra en la fuente Dart. Para desarrollar directamente en tu ordenador, ejecuta el paso `flutter create` anterior.

### Firma del APK

Si el repositorio no tiene una clave válida configurada, la primera ejecución crea una firma nueva. Descarga y conserva el artefacto `manigest-signing-backup`; contiene el almacén de clave y los datos de firma. Para mantener esa misma firma en las siguientes compilaciones, configura estos GitHub Actions Secrets:

- `ANDROID_KEYSTORE_BASE64`: archivo JKS codificado en base64.
- `ANDROID_KEYSTORE_PASSWORD`: contraseña del almacén.
- `ANDROID_KEY_ALIAS`: alias de la clave.
- `ANDROID_KEY_PASSWORD`: contraseña de la clave.

No subas el JKS ni las contraseñas al código del repositorio.

## Estructura

```text
manigest-app/
├── .github/workflows/flutter.yml
├── docs/
│   ├── DECISIONES_TECNICAS.md
│   ├── ENMIENDA_V1_1.md
│   ├── ENMIENDA_V1_2.md
│   ├── ESPECIFICACION_FUNCIONAL_V1_0.md
│   └── PRUEBAS_MANUALES.md
├── lib/
│   ├── data/app_database.dart
│   ├── services/whatsapp_service.dart
│   ├── utils/date_utils_es.dart
│   ├── utils/text_normalizer.dart
│   └── main.dart
├── test/text_normalizer_test.dart
├── analysis_options.yaml
└── pubspec.yaml
```

## Decisiones deliberadas

- Una clienta que tenga citas no se elimina físicamente: al confirmar y dejar vencer Deshacer se conserva como inactiva para no romper las relaciones ni el historial.
- Las acciones pendientes de Deshacer son temporales y viven en memoria; si la app se cierra durante esos cinco segundos, la operación se consolida.
- WhatsApp se abre con el texto para revisión manual. No se afirma ni registra que el mensaje se haya enviado.
- No incluye notificaciones recordatorias, PIN, backups, sincronización en la nube, login, multicuenta ni envío automático de WhatsApp.

## Verificación

El entorno donde se generó esta entrega no tenía Flutter/Dart instalado. Por eso no sería correcto afirmar que el APK ya fue compilado aquí. El workflow de GitHub realiza el análisis, las pruebas y la compilación al subir los archivos; revisa esa ejecución antes de considerar estable el APK.
