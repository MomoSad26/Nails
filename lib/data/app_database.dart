import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/text_normalizer.dart';

String _sqlDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    final file = p.join(root, 'manigest.db');
    _database = await openDatabase(
      file,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE clientas ADD COLUMN notificar_whatsapp_manual INTEGER NOT NULL DEFAULT 0');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clientas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            nombre_normalizado TEXT NOT NULL,
            telefono TEXT,
            codigo_pais TEXT NOT NULL DEFAULT '+53',
            telefono_local TEXT,
            nota TEXT,
            fecha_registro TEXT NOT NULL,
            activa INTEGER NOT NULL DEFAULT 1,
            notificar_whatsapp INTEGER NOT NULL DEFAULT 0,
            notificar_whatsapp_manual INTEGER NOT NULL DEFAULT 0,
            eliminada INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE servicios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            nombre_normalizado TEXT NOT NULL,
            precio REAL NOT NULL CHECK(precio >= 0),
            activo INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE citas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            clienta_id INTEGER NOT NULL,
            fecha_hora TEXT NOT NULL,
            precio_total REAL NOT NULL DEFAULT 0,
            estado TEXT NOT NULL DEFAULT 'Programada',
            nota TEXT,
            creada_en TEXT NOT NULL,
            cerrada_en TEXT,
            oculto INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(clienta_id) REFERENCES clientas(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE cita_servicios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cita_id INTEGER NOT NULL,
            servicio_id INTEGER,
            nombre_snapshot TEXT NOT NULL,
            precio_snapshot REAL NOT NULL,
            FOREIGN KEY(cita_id) REFERENCES citas(id) ON DELETE CASCADE,
            FOREIGN KEY(servicio_id) REFERENCES servicios(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('CREATE TABLE configuracion (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
        await db.execute('CREATE INDEX idx_citas_fecha ON citas(fecha_hora)');
        await db.execute('CREATE INDEX idx_citas_estado ON citas(estado)');
        await db.execute('CREATE INDEX idx_clientas_nombre ON clientas(nombre_normalizado)');
        await db.execute('CREATE INDEX idx_citas_clienta ON citas(clienta_id)');
        final defaults = <String, String>{
          'nombre_negocio': 'Mi negocio de uñas',
          'nombre_duena': 'Dueña',
          'color_acento': '0xFF62DCEB',
          'simbolo_moneda': r'$',
        };
        for (final entry in defaults.entries) {
          await db.insert('configuracion', {'clave': entry.key, 'valor': entry.value});
        }
      },
    );
    return _database!;
  }

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('configuracion');
    return {for (final row in rows) row['clave'] as String: row['valor'] as String};
  }

  Future<void> saveSettings(Map<String, String> values) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.insert('configuracion', {'clave': entry.key, 'valor': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> getClients({bool includeInactive = true}) async {
    final db = await database;
    return db.query(
      'clientas',
      where: 'eliminada = 0${includeInactive ? '' : ' AND activa = 1'}',
      orderBy: 'nombre_normalizado COLLATE NOCASE ASC, nombre COLLATE NOCASE ASC',
    );
  }

  Future<Map<String, Object?>?> getClient(int id) async {
    final db = await database;
    final rows = await db.query('clientas', where: 'id = ? AND eliminada = 0', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> saveClient({int? id, required String nombre, String? telefono, String codigoPais = '+53', String? telefonoLocal, String? nota,
      bool activa = true, bool notificarWhatsapp = false, bool notificarWhatsappManual = false}) async {
    final db = await database;
    final data = <String, Object?>{
      'nombre': nombre.trim(),
      'nombre_normalizado': normalizeSearch(nombre),
      'telefono': (telefono == null || telefono.trim().isEmpty) ? null : telefono.trim(),
      'codigo_pais': codigoPais.trim().isEmpty ? '+53' : codigoPais.trim(),
      'telefono_local': (telefonoLocal == null || telefonoLocal.trim().isEmpty) ? null : telefonoLocal.trim(),
      'nota': (nota == null || nota.trim().isEmpty) ? null : nota.trim(),
      'activa': activa ? 1 : 0,
      'notificar_whatsapp': (telefono == null || telefono.trim().isEmpty || !notificarWhatsapp) ? 0 : 1,
      'notificar_whatsapp_manual': (telefono == null || telefono.trim().isEmpty || !notificarWhatsappManual) ? 0 : 1,
    };
    if (id == null) {
      data['fecha_registro'] = _sqlDate(DateTime.now());
      return db.insert('clientas', data);
    }
    await db.update('clientas', data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<bool> isPhoneDuplicate(String? phone, {int? excludingId}) async {
    if (phone == null || phone.trim().isEmpty) return false;
    String digits(String value) => value.replaceAll(RegExp(r'\D'), '');
    final target = digits(phone);
    if (target.isEmpty) return false;
    final db = await database;
    final rows = await db.query('clientas', where: 'eliminada = 0');
    return rows.any((row) => row['id'] != excludingId && (row['telefono'] as String?) != null && digits(row['telefono'] as String) == target);
  }

  Future<bool> clientHasAppointments(int id) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM citas WHERE clienta_id = ?', [id]);
    return (result.first['total'] as int? ?? 0) > 0;
  }

  Future<void> setClientWhatsAppEnabled(int id, bool enabled) async {
    final db = await database;
    await db.update(
      'clientas',
      {
        'notificar_whatsapp': enabled ? 1 : 0,
        'notificar_whatsapp_manual': 1,
      },
      where: enabled
          ? 'id = ? AND telefono IS NOT NULL AND telefono != ? AND eliminada = 0'
          : 'id = ? AND eliminada = 0',
      whereArgs: enabled ? [id, ''] : [id],
    );
  }

  Future<void> hideClient(int id) async {
    final db = await database;
    await db.update('clientas', {'eliminada': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreClient(int id) async {
    final db = await database;
    await db.update('clientas', {'eliminada': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> finalizeClientDelete(int id) async {
    final db = await database;
    // Preserve the client row whenever a historical appointment still references it.
    final hasHistory = await clientHasAppointments(id);
    if (hasHistory) {
      await db.update('clientas', {'eliminada': 0, 'activa': 0, 'notificar_whatsapp': 0}, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete('clientas', where: 'id = ? AND eliminada = 1', whereArgs: [id]);
    }
  }

  Future<List<Map<String, Object?>>> getServices({bool activeOnly = false}) async {
    final db = await database;
    return db.query('servicios',
        where: activeOnly ? 'activo = 1' : null,
        orderBy: 'nombre_normalizado COLLATE NOCASE ASC, nombre COLLATE NOCASE ASC');
  }

  Future<Map<String, Object?>?> getService(int id) async {
    final db = await database;
    final rows = await db.query('servicios', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> saveService({int? id, required String nombre, required double precio}) async {
    final db = await database;
    final data = <String, Object?>{
      'nombre': nombre.trim(),
      'nombre_normalizado': normalizeSearch(nombre),
      'precio': precio,
    };
    if (id == null) return db.insert('servicios', data);
    await db.update('servicios', data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<bool> isServiceNameDuplicate(String nombre, {int? excludingId}) async {
    final db = await database;
    final rows = await db.query('servicios',
      where: 'nombre_normalizado = ?${excludingId == null ? '' : ' AND id != ?'}',
      whereArgs: excludingId == null ? [normalizeSearch(nombre)] : [normalizeSearch(nombre), excludingId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> setServiceActive(int id, bool active) async {
    final db = await database;
    await db.update('servicios', {'activo': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> _appointmentRows({
    String where = 'a.oculto = 0',
    List<Object?> args = const [],
    String orderBy = 'a.fecha_hora ASC',
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.*, c.nombre AS clienta_nombre, c.telefono AS clienta_telefono,
        c.notificar_whatsapp AS clienta_notificar_whatsapp,
        GROUP_CONCAT(cs.nombre_snapshot, ' · ') AS servicios_text
      FROM citas a
      JOIN clientas c ON c.id = a.clienta_id
      LEFT JOIN cita_servicios cs ON cs.cita_id = a.id
      WHERE $where
      GROUP BY a.id
      ORDER BY $orderBy
    ''', args);
  }

  Future<List<Map<String, Object?>>> getAllAppointments() => _appointmentRows();

  Future<List<Map<String, Object?>>> getAppointmentsByClient(int clientId, {int limit = 10}) =>
      _appointmentRows(where: 'a.oculto = 0 AND a.clienta_id = ?', args: [clientId],
          orderBy: 'a.fecha_hora DESC, a.id DESC').then((rows) => rows.take(limit).toList());

  Future<Map<String, Object?>?> getAppointment(int id) async {
    final rows = await _appointmentRows(where: 'a.oculto = 0 AND a.id = ?', args: [id], orderBy: 'a.fecha_hora ASC');
    if (rows.isEmpty) return null;
    final services = await getAppointmentServices(id);
    return {...rows.first, 'servicios': services};
  }

  Future<List<Map<String, Object?>>> getAppointmentServices(int appointmentId) async {
    final db = await database;
    return db.query('cita_servicios', where: 'cita_id = ?', whereArgs: [appointmentId], orderBy: 'id ASC');
  }

  Future<int> saveAppointment({int? id, required int clientId, required DateTime dateTime,
      required List<int> serviceIds, required double total, String? nota, bool resetStatus = false}) async {
    if (serviceIds.isEmpty) throw ArgumentError('Selecciona al menos un servicio.');
    final db = await database;
    final now = _sqlDate(DateTime.now());
    return db.transaction((txn) async {
      final data = <String, Object?>{
        'clienta_id': clientId,
        'fecha_hora': _sqlDate(dateTime),
        'precio_total': total,
        'nota': (nota == null || nota.trim().isEmpty) ? null : nota.trim(),
      };
      late final int appointmentId;
      if (id == null) {
        data['estado'] = 'Programada';
        data['creada_en'] = now;
        appointmentId = await txn.insert('citas', data);
      } else {
        if (resetStatus) {
          data['estado'] = 'Programada';
          data['cerrada_en'] = null;
        }
        appointmentId = id;
        final previousServices = await txn.query('cita_servicios', where: 'cita_id = ?', whereArgs: [id]);
        await txn.update('citas', data, where: 'id = ?', whereArgs: [id]);
        await txn.delete('cita_servicios', where: 'cita_id = ?', whereArgs: [id]);
        for (final serviceId in serviceIds) {
          final serviceRows = await txn.query('servicios', where: 'id = ?', whereArgs: [serviceId], limit: 1);
          if (serviceRows.isNotEmpty && (serviceRows.first['activo'] as int? ?? 0) == 1) {
            final service = serviceRows.first;
            await txn.insert('cita_servicios', {'cita_id': appointmentId, 'servicio_id': serviceId, 'nombre_snapshot': service['nombre'], 'precio_snapshot': service['precio']});
          } else {
            final previous = previousServices.where((row) => row['servicio_id'] == serviceId).toList();
            if (previous.isNotEmpty) {
              await txn.insert('cita_servicios', {'cita_id': appointmentId, 'servicio_id': serviceId, 'nombre_snapshot': previous.first['nombre_snapshot'], 'precio_snapshot': previous.first['precio_snapshot']});
            }
          }
        }
      }
      if (id == null) {
        for (final serviceId in serviceIds) {
          final rows = await txn.query('servicios', where: 'id = ? AND activo = 1', whereArgs: [serviceId], limit: 1);
          if (rows.isEmpty) continue;
          final service = rows.first;
          await txn.insert('cita_servicios', {'cita_id': appointmentId, 'servicio_id': serviceId, 'nombre_snapshot': service['nombre'], 'precio_snapshot': service['precio']});
        }
      }
      final count = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM cita_servicios WHERE cita_id = ?', [appointmentId])) ?? 0;
      if (count == 0) throw StateError('No se pudo guardar la cita: no hay servicios activos seleccionados.');
      return appointmentId;
    });
  }

  Future<void> consolidateStaleDeletes() async {
    final db = await database;
    // Deletions pending when the process was closed become committed on next launch.
    await db.delete('citas', where: 'oculto = 1');
    final hiddenClients = await db.query('clientas', where: 'eliminada = 1');
    for (final client in hiddenClients) {
      await finalizeClientDelete(client['id'] as int);
    }
  }

  Future<void> transitionOverdueAppointments() async {
    final db = await database;
    await db.update('citas', {'estado': 'Pendiente_de_cerrar'},
      where: "oculto = 0 AND estado = 'Programada' AND fecha_hora <= ?", whereArgs: [_sqlDate(DateTime.now())]);
  }

  Future<void> changeAppointmentStatus(int id, String status) async {
    final db = await database;
    final finalStatus = {'Terminada', 'Cancelada', 'No_asistio'}.contains(status);
    await db.update('citas', {
      'estado': status,
      'cerrada_en': finalStatus ? _sqlDate(DateTime.now()) : null,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreAppointmentStatus(int id, {required String status, String? closedAt}) async {
    final db = await database;
    await db.update('citas', {'estado': status, 'cerrada_en': closedAt},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> hideAppointment(int id) async {
    final db = await database;
    await db.update('citas', {'oculto': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreAppointment(int id) async {
    final db = await database;
    await db.update('citas', {'oculto': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> finalizeAppointmentDelete(int id) async {
    final db = await database;
    await db.delete('citas', where: 'id = ? AND oculto = 1', whereArgs: [id]);
  }

  Future<Map<String, int>> getMonthAppointmentCounts(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.rawQuery('''
      SELECT substr(fecha_hora, 1, 10) AS dia, COUNT(*) AS total
      FROM citas
      WHERE oculto = 0 AND estado IN ('Programada', 'Pendiente_de_cerrar')
        AND fecha_hora >= ? AND fecha_hora < ?
      GROUP BY substr(fecha_hora, 1, 10)
    ''', [_sqlDate(start), _sqlDate(end)]);
    return {for (final row in rows) row['dia'] as String: row['total'] as int};
  }

  Future<List<Map<String, Object?>>> getAppointmentsBetween(DateTime start, DateTime end) =>
      _appointmentRows(where: 'a.oculto = 0 AND a.fecha_hora >= ? AND a.fecha_hora < ?',
          args: [_sqlDate(start), _sqlDate(end)], orderBy: 'a.fecha_hora ASC');

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
