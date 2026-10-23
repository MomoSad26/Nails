import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:manigest/data/app_database.dart';
import 'package:manigest/main.dart';

void main() {
  final db = AppDatabase.instance;
  late String databasePath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('es');
    databasePath = p.join(await getDatabasesPath(), 'manigest.db');
  });

  setUp(() async {
    await db.close();
    await databaseFactory.deleteDatabase(databasePath);
    await db.database;
  });

  tearDown(() async {
    await db.close();
    await databaseFactory.deleteDatabase(databasePath);
  });

  test('clientas: guarda datos y elimina físicamente solo si no tienen historial', () async {
    final clientId = await db.saveClient(
      nombre: '  Ana Pérez  ',
      telefono: '+5355512345',
      codigoPais: '+53',
      telefonoLocal: '55512345',
      notificarWhatsapp: true,
    );

    final client = await db.getClient(clientId);
    expect(client?['nombre'], 'Ana Pérez');
    expect(client?['telefono'], '+5355512345');
    expect(client?['notificar_whatsapp'], 1);

    await db.hideClient(clientId);
    await db.finalizeClientDelete(clientId);
    expect(await db.getClient(clientId), isNull);
  });

  test('catálogo: normaliza nombres y conserva los servicios inactivos', () async {
    final serviceId = await db.saveService(nombre: 'Manicura clásica', precio: 25);

    expect(await db.isServiceNameDuplicate('MANICURA CLASICA'), isTrue);

    await db.setServiceActive(serviceId, false);
    expect(await db.getServices(activeOnly: true), isEmpty);
    expect((await db.getService(serviceId))?['activo'], 0);
    expect((await db.getServices()).single['nombre'], 'Manicura clásica');
  });

  test('citas: conserva snapshots de servicios y clientas con historial', () async {
    final clientId = await db.saveClient(nombre: 'Lucía');
    final serviceId = await db.saveService(nombre: 'Gel', precio: 20);
    final appointmentId = await db.saveAppointment(
      clientId: clientId,
      dateTime: DateTime(2030, 4, 5, 10, 30),
      serviceIds: [serviceId],
      total: 20,
      nota: 'Prueba de regresión',
    );

    expect((await db.getAppointment(appointmentId))?['estado'], 'Programada');
    var snapshots = await db.getAppointmentServices(appointmentId);
    expect(snapshots.single['nombre_snapshot'], 'Gel');
    expect((snapshots.single['precio_snapshot'] as num).toDouble(), 20);

    await db.saveService(id: serviceId, nombre: 'Gel premium', precio: 30);
    snapshots = await db.getAppointmentServices(appointmentId);
    expect(snapshots.single['nombre_snapshot'], 'Gel');
    expect((snapshots.single['precio_snapshot'] as num).toDouble(), 20);

    await db.hideClient(clientId);
    await db.finalizeClientDelete(clientId);
    final preservedClient = await db.getClient(clientId);
    expect(preservedClient, isNotNull);
    expect(preservedClient?['activa'], 0);

    await db.close();
    final restoredAppointment = await db.getAppointment(appointmentId);
    expect(restoredAppointment, isNotNull);
    expect((await db.getAppointmentServices(appointmentId)).single['nombre_snapshot'], 'Gel');
  });

  test('persistencia: ajustes y registros sobreviven al cierre de la base', () async {
    await db.saveSettings({'nombre_negocio': 'Estudio de uñas'});
    final clientId = await db.saveClient(nombre: 'María');

    await db.close();

    expect((await db.getSettings())['nombre_negocio'], 'Estudio de uñas');
    expect((await db.getClient(clientId))?['nombre'], 'María');
  });

  testWidgets('navegación: la pantalla de monedas abre un menú y Volver regresa a la raíz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ManiGestApp(enableOverdueTimer: false));

    // SQLite usa un isolate real; alternar tiempo real y frames sin pumpAndSettle.
    for (var attempt = 0;
        attempt < 20 && find.byKey(const ValueKey('menu-Inicio')).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }

    const sections = ['Inicio', 'Agenda', 'Citas', 'Clientes', 'Catálogo', 'Ajustes'];
    for (final section in sections) {
      expect(find.byKey(ValueKey('menu-$section')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('menu-Clientes')));
    for (var attempt = 0;
        attempt < 20 && find.text('Volver').evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Volver'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('menu-Clientes')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

}
