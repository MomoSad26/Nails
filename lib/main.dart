import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/app_database.dart';
import 'services/whatsapp_service.dart';
import 'utils/date_utils_es.dart';
import 'utils/text_normalizer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const ManiGestApp());
}

class ManiGestApp extends StatelessWidget {
  const ManiGestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ManiGest',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB76E79)),
          scaffoldBackgroundColor: const Color(0xFFFFFAFA),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF0E3E5))),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const DashboardShell(),
      );
}

class _PanelRoute {
  _PanelRoute(this.kind, {this.section, this.title = '', Map<String, dynamic>? data}) : data = data ?? {};
  final String kind;
  final String? section;
  final String title;
  final Map<String, dynamic> data;
}

class _PendingUndo {
  _PendingUndo({required this.label, required this.restore, required this.finalize});
  final String label;
  final Future<void> Function() restore;
  final Future<void> Function() finalize;
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final AppDatabase _db = AppDatabase.instance;
  final List<_PanelRoute> _stack = [];
  _PanelRoute _route = _PanelRoute('section', section: 'Inicio');
  Map<String, String> _settings = {};
  bool _loading = true;
  Timer? _transitionTimer;
  Timer? _undoTimer;
  _PendingUndo? _pendingUndo;
  String _clientSearch = '';
  int _appointmentsTab = 0;
  String _appointmentFilter = 'Todos';
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _performingUndo = false;
  bool _edgeSwipeActive = false;
  double _edgeSwipeDistance = 0;

  static const _sections = <(String, IconData)>[
    ('Inicio', Icons.home_rounded),
    ('Agenda', Icons.calendar_month_rounded),
    ('Citas', Icons.event_note_rounded),
    ('Clientes', Icons.people_alt_rounded),
    ('Catálogo', Icons.spa_rounded),
    ('Ajustes', Icons.settings_rounded),
  ];

  Color get _accent {
    final raw = _settings['color_acento'] ?? '0xFFB76E79';
    final parsed = int.tryParse(raw.replaceFirst('0x', ''), radix: 16);
    return Color(parsed ?? 0xFFB76E79);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    _transitionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _db.transitionOverdueAppointments();
      if (mounted) setState(() {});
    });
  }

  Future<void> _initialize() async {
    await _db.consolidateStaleDeletes();
    await _db.transitionOverdueAppointments();
    final settings = await _db.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await _db.transitionOverdueAppointments();
    final settings = await _db.getSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _commitPendingUndo() async {
    _undoTimer?.cancel();
    final pending = _pendingUndo;
    _pendingUndo = null;
    if (pending != null) {
      await pending.finalize();
      if (mounted) await _refresh();
    }
  }

  Future<void> _scheduleUndo({required String label, required Future<void> Function() restore,
      required Future<void> Function() finalize}) async {
    await _commitPendingUndo();
    _pendingUndo = _PendingUndo(label: label, restore: restore, finalize: finalize);
    _undoTimer = Timer(const Duration(seconds: 5), () async {
      final pending = _pendingUndo;
      _pendingUndo = null;
      if (pending != null) {
        await pending.finalize();
        if (mounted) await _refresh();
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      content: Text(label),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Deshacer', onPressed: () async {
        if (_performingUndo) return;
        _performingUndo = true;
        _undoTimer?.cancel();
        final pending = _pendingUndo;
        _pendingUndo = null;
        if (pending != null) await pending.restore();
        _performingUndo = false;
        await _refresh();
      }),
    ));
  }

  void _push(String kind, String title, {Map<String, dynamic>? data}) {
    if (_pendingUndo != null) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    unawaited(_commitPendingUndo());
    setState(() {
      _stack.add(_route);
      _route = _PanelRoute(kind, title: title, data: data);
    });
  }

  void _goBack() {
    if (_stack.isEmpty) return;
    setState(() => _route = _stack.removeLast());
  }

  void _changeSection(String section) {
    unawaited(_commitPendingUndo());
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _stack.clear();
      _route = _PanelRoute('section', section: section);
      if (section == 'Agenda') _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    });
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Aceptar')),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _askYesNo({required String title, required String message, String yesText = 'Sí', String noText = 'No'}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(noText)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(yesText)),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteAppointment(int id) async {
    final yes = await _confirm(title: 'Eliminar cita', message: '¿Deseas eliminar esta cita? Podrás deshacerlo durante 5 segundos.');
    if (!yes) return;
    await _db.hideAppointment(id);
    await _scheduleUndo(
      label: 'Cita eliminada',
      restore: () => _db.restoreAppointment(id),
      finalize: () => _db.finalizeAppointmentDelete(id),
    );
    await _refresh();
    if (_route.kind == 'appointment_detail') _goBack();
  }

  Future<void> _deleteClient(int id) async {
    final client = await _db.getClient(id);
    if (client == null) return;
    final yes = await _confirm(title: 'Eliminar clienta', message: '¿Deseas eliminar a ${client['nombre']}? Si tiene citas, se conservará internamente su ficha para proteger el historial.');
    if (!yes) return;
    final hasHistory = await _db.clientHasAppointments(id);
    await _db.hideClient(id);
    await _scheduleUndo(
      label: hasHistory ? 'Clienta archivada como inactiva' : 'Clienta eliminada',
      restore: () => _db.restoreClient(id),
      finalize: () => _db.finalizeClientDelete(id),
    );
    await _refresh();
    if (_route.kind == 'client_detail') _goBack();
  }

  Future<void> _deleteService(Map<String, Object?> service) async {
    final id = service['id'] as int;
    final wasActive = (service['activo'] as int? ?? 0) == 1;
    final yes = await _confirm(title: 'Eliminar servicio', message: '¿Deseas desactivar “${service['nombre']}”? No aparecerá en citas nuevas; el historial se conservará.');
    if (!yes) return;
    await _db.setServiceActive(id, false);
    await _scheduleUndo(
      label: 'Servicio desactivado',
      restore: () => _db.setServiceActive(id, wasActive),
      finalize: () async {},
    );
    await _refresh();
  }

  void _openCatalogPreservingForm(Map<String, dynamic> draft) {
    _route.data['draft'] = draft;
    if (_pendingUndo != null) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    unawaited(_commitPendingUndo());
    setState(() {
      _stack.add(_route);
      _route = _PanelRoute('section', section: 'Catálogo', data: {'internal': true});
    });
  }

  Future<void> _openAppointmentForm({int? id, int? clientId, DateTime? date, bool reprogram = false, Map<String, dynamic>? draft}) async {
    _push('appointment_form', id == null ? 'Agregar cita' : reprogram ? 'Reprogramar cita' : 'Editar cita', data: {
      if (id != null) 'id': id,
      if (reprogram) 'reprogram': true,
      if (clientId != null) 'clientId': clientId,
      if (date != null) 'date': date,
      if (draft != null) 'draft': draft,
    });
  }

  String _currency(num amount) {
    final symbol = _settings['simbolo_moneda'] ?? r'$';
    return '$symbol${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  Widget _pageHeader(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            OutlinedButton.icon(onPressed: _goBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Volver')),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          ]),
          if (trailing != null) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: trailing)],
        ]),
      );

  Widget _sectionHeader(String title, {String? subtitle, Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LayoutBuilder(builder: (context, constraints) {
          final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Colors.grey.shade700))],
          ]);
          if (trailing == null) return titleBlock;
          if (constraints.maxWidth < 360) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: trailing)]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: titleBlock), trailing]);
        }),
      );

  Widget _bodyCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Card(
        child: Padding(padding: padding, child: child),
      );

  Widget _empty(String message, {Widget? action, IconData icon = Icons.inbox_rounded}) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            if (action != null) ...[const SizedBox(height: 14), action],
          ]),
        ),
      );

  Widget _primaryButton(String label, VoidCallback onPressed, {IconData icon = Icons.add_rounded}) => FilledButton.icon(
        onPressed: onPressed, icon: Icon(icon), label: Text(label),
      );

  Widget _renderCurrentPanel() {
    if (_route.kind == 'section') {
      switch (_route.section) {
        case 'Inicio': return _homeSection();
        case 'Agenda': return _agendaSection();
        case 'Citas': return _appointmentsSection();
        case 'Clientes': return _clientsSection();
        case 'Catálogo': return _catalogSection(internal: _route.data['internal'] == true);
        case 'Ajustes': return _settingsSection();
      }
    }
    switch (_route.kind) {
      case 'client_detail': return _clientDetailPage(_route.data['id'] as int);
      case 'client_form': return ClientFormPage(
        db: _db,
        key: ValueKey('client-form-${_route.data['id'] ?? 'new'}-${_route.data['returnToAppointment'] == true}'),
        initial: _route.data['id'] == null ? null : _route.data['client'] as Map<String, Object?>?,
        clientId: _route.data['id'] as int?,
        onCreateClient: _route.data['returnToAppointment'] == true,
        onBack: _goBack,
        onSave: (id) async {
          await _refresh();
          if (_route.data['returnToAppointment'] == true && _stack.isNotEmpty && _stack.last.kind == 'appointment_form') {
            final previous = _stack.last;
            previous.data['clientId'] = id;
            final draft = Map<String, dynamic>.from(previous.data['draft'] as Map<String, dynamic>? ?? {});
            draft['clientId'] = id;
            previous.data['draft'] = draft;
          }
          _goBack();
        },
      );
      case 'appointment_detail': return _appointmentDetailPage(_route.data['id'] as int);
      case 'appointment_form': return AppointmentFormPage(
        key: ValueKey('appointment-form-${_route.data['id'] ?? 'new'}-${_route.data['date'] ?? ''}-${_route.data['clientId'] ?? ''}'),
        db: _db,
        initialId: _route.data['id'] as int?,
        initialClientId: _route.data['clientId'] as int?,
        initialDate: _route.data['date'] as DateTime?,
        initialDraft: _route.data['draft'] as Map<String, dynamic>?,
        resetStatusOnSave: _route.data['reprogram'] == true,
        onBack: _goBack,
        currency: _currency,
        onOpenCatalog: (draft) => _openCatalogPreservingForm(draft),
        onCreateClient: (draft) {
          _route.data['draft'] = draft;
          _push('client_form', 'Agregar clienta', data: {'returnToAppointment': true});
        },
        onSaved: () async { await _refresh(); _goBack(); },
      );
      case 'service_form': return ServiceFormPage(
        key: ValueKey('service-form-${_route.data['id'] ?? 'new'}'),
        db: _db,
        service: _route.data['service'] as Map<String, Object?>?,
        onBack: _goBack,
        currency: _currency,
        onSaved: () async { await _refresh(); _goBack(); },
      );
      case 'agenda_day': return _agendaDayPage(_route.data['date'] as DateTime);
      case 'whatsapp_preview': return MessagePreviewPage(
        initialText: _route.data['message'] as String,
        phone: _route.data['phone'] as String?,
        title: _route.data['title'] as String? ?? 'Mensaje de WhatsApp',
        onBack: _goBack,
      );
    }
    return const Center(child: Text('Pantalla no encontrada'));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PopScope<Object?>(
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _stack.isNotEmpty) _goBack();
      },
      child: Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _accent)),
        child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) { _edgeSwipeActive = details.localPosition.dx <= 24 && _stack.isNotEmpty; _edgeSwipeDistance = 0; },
            onHorizontalDragUpdate: (details) { if (_edgeSwipeActive) _edgeSwipeDistance += details.primaryDelta ?? 0; },
            onHorizontalDragEnd: (details) { if (_edgeSwipeActive && _edgeSwipeDistance > 80) _goBack(); _edgeSwipeActive = false; _edgeSwipeDistance = 0; },
            child: Row(children: [
            Container(
              width: 64,
              decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.pink.shade50))),
              child: Column(children: [
                const SizedBox(height: 16),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(Icons.spa_rounded, color: _accent),
                ),
                const SizedBox(height: 20),
                Expanded(child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _sections[index];
                    final active = _route.kind == 'section' && _route.section == item.$1;
                    return Tooltip(
                      message: item.$1,
                      child: InkWell(
                        onTap: () => _changeSection(item.$1),
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          height: 48, width: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: active ? _accent.withValues(alpha: 0.16) : Colors.transparent, shape: BoxShape.circle),
                          child: Icon(item.$2, color: active ? _accent : Colors.grey.shade600, size: 23),
                        ),
                      ),
                    );
                  },
                )),
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('v1.1', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
              ]),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFFFFAFA),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: _renderCurrentPanel(),
                ),
              ),
            ),
          ]),
          ),
        ),
        ),
        ),
    );
  }

  Widget _homeSection() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_db.getAllAppointments(), _db.getServices(activeOnly: true)]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final appointments = (snapshot.data![0] as List<Map<String, Object?>>);
        final services = (snapshot.data![1] as List<Map<String, Object?>>);
        final now = DateTime.now();
        final todays = appointments.where((a) {
          final date = DateTime.parse(a['fecha_hora'] as String);
          return date.year == now.year && date.month == now.month && date.day == now.day;
        }).toList()..sort((a, b) => (a['fecha_hora'] as String).compareTo(b['fecha_hora'] as String));
        final upcoming = appointments.where((a) => a['estado'] == 'Programada' && DateTime.parse(a['fecha_hora'] as String).isAfter(now)).toList()
          ..sort((a, b) => (a['fecha_hora'] as String).compareTo(b['fecha_hora'] as String));
        final pending = appointments.where((a) => a['estado'] == 'Pendiente_de_cerrar').length;
        final todayCount = todays.length;
        final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final nextWeekStart = weekStart.add(const Duration(days: 7));
        final endNextWeek = nextWeekStart.add(const Duration(days: 7));
        final thisWeek = appointments.where((a) {
          final d = DateTime.parse(a['fecha_hora'] as String);
          return !d.isBefore(weekStart) && d.isBefore(nextWeekStart) && a['estado'] != 'Cancelada' && a['estado'] != 'No_asistio';
        }).length;
        final nextWeek = appointments.where((a) {
          final d = DateTime.parse(a['fecha_hora'] as String);
          return !d.isBefore(nextWeekStart) && d.isBefore(endNextWeek) && a['estado'] != 'Cancelada' && a['estado'] != 'No_asistio';
        }).length;
        final greeting = _settings['nombre_duena'] ?? 'Dueña';
        return ListView(children: [
          _sectionHeader('Hola, $greeting', subtitle: formatDateWithWeekday(now)),
          Text('Hoy tienes $todayCount ${todayCount == 1 ? 'cita' : 'citas'}.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 18),
          if (upcoming.isNotEmpty) _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.star_rounded, color: _accent), const SizedBox(width: 8), const Text('Próxima cita', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17))]),
            const SizedBox(height: 12),
            Text(formatTime(DateTime.parse(upcoming.first['fecha_hora'] as String)), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _accent)),
            const SizedBox(height: 3),
            Text('${upcoming.first['clienta_nombre']} · ${upcoming.first['servicios_text'] ?? 'Sin servicios'}'),
            const SizedBox(height: 4),
            Text(_currency(upcoming.first['precio_total'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _push('appointment_detail', 'Detalle de cita', data: {'id': upcoming.first['id']}), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Ver detalle')),
              OutlinedButton.icon(onPressed: () => _prepareAppointmentMessage(upcoming.first), icon: const Icon(Icons.chat_rounded), label: const Text('Notificar por WhatsApp')),
              if ((upcoming.first['clienta_telefono'] as String?)?.isNotEmpty == true)
                OutlinedButton.icon(onPressed: () => WhatsAppService.callPhone(upcoming.first['clienta_telefono'] as String), icon: const Icon(Icons.call_rounded), label: const Text('Llamar')),
            ]),
          ])) else _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('No tienes citas próximas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 10), _primaryButton('Agregar cita', () => _openAppointmentForm()),
          ])),
          const SizedBox(height: 14),
          _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Citas de hoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (todays.isEmpty) _empty('No tienes citas hoy', action: _primaryButton('Agregar cita', () => _openAppointmentForm()))
            else ...todays.map((a) => _appointmentListTile(a)),
          ])),
          if (pending > 0) ...[
            const SizedBox(height: 14),
            _bodyCard(child: Row(children: [Icon(Icons.pending_actions_rounded, color: _accent), const SizedBox(width: 12), Expanded(child: Text('Tienes $pending ${pending == 1 ? 'cita pendiente' : 'citas pendientes'} de cerrar.')), TextButton(onPressed: () { _changeSection('Citas'); setState(() => _appointmentsTab = 1); }, child: const Text('Revisar'))])),
          ],
          const SizedBox(height: 14),
          _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Accesos rápidos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _primaryButton('Agregar cita', () => _openAppointmentForm()),
              OutlinedButton.icon(onPressed: () => _push('client_form', 'Agregar clienta'), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Agregar clienta')),
              OutlinedButton.icon(onPressed: () { final tomorrow = DateTime.now().add(const Duration(days: 1)); _changeSection('Agenda'); setState(() => _calendarMonth = DateTime(tomorrow.year, tomorrow.month)); _push('agenda_day', 'Agenda de mañana', data: {'date': DateTime(tomorrow.year, tomorrow.month, tomorrow.day)}); }, icon: const Icon(Icons.calendar_today_rounded), label: const Text('Ver agenda de mañana')),
              OutlinedButton.icon(onPressed: _prepareCatalogMessage, icon: const Icon(Icons.share_rounded), label: const Text('Compartir catálogo por WhatsApp')),
            ]),
          ])),
          const SizedBox(height: 14),
          _bodyCard(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Resumen semanal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Text('Citas esta semana: $thisWeek'), Text('Citas próxima semana: $nextWeek')])),
            Icon(Icons.date_range_rounded, color: _accent, size: 34),
          ])),
          if (services.isEmpty) ...[
            const SizedBox(height: 14),
            _bodyCard(child: Row(children: [Icon(Icons.info_outline_rounded, color: _accent), const SizedBox(width: 12), const Expanded(child: Text('Tu catálogo está vacío. Agrega servicios para poder agendar citas.')), TextButton(onPressed: () => _changeSection('Catálogo'), child: const Text('Catálogo'))])),
          ],
          const SizedBox(height: 16),
        ]);
      },
    );
  }

  Widget _appointmentListTile(Map<String, Object?> appointment, {bool compact = false}) {
    final date = DateTime.parse(appointment['fecha_hora'] as String);
    return InkWell(
      onTap: () => _push('appointment_detail', 'Detalle de cita', data: {'id': appointment['id']}),
      onLongPress: () => _showQuickAppointmentMenu(appointment),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(width: 54, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(formatTime(date), textAlign: TextAlign.center, style: TextStyle(color: _accent, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${appointment['clienta_nombre'] ?? 'Clienta'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (!compact) Text('${appointment['servicios_text'] ?? 'Sin servicios'} · ${_currency(appointment['precio_total'] as num)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ])),
          const SizedBox(width: 8),
          _statusChip(appointment['estado'] as String? ?? 'Programada'),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _statusChip(String status) {
    final display = switch (status) {
      'Pendiente_de_cerrar' => 'Pendiente',
      'No_asistio' => 'No asistió',
      _ => status,
    };
    final color = switch (status) {
      'Terminada' => Colors.green,
      'Cancelada' => Colors.red,
      'No_asistio' => Colors.deepOrange,
      'Pendiente_de_cerrar' => Colors.amber.shade800,
      _ => _accent,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)), child: Text(display, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)));
  }

  Widget _agendaSection() {
    return FutureBuilder<Map<String, int>>(
      future: _db.getMonthAppointmentCounts(_calendarMonth),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final counts = snapshot.data!;
        final firstWeekday = DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday; // Monday = 1
        final days = DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
        final cellCount = ((firstWeekday - 1 + days) / 7).ceil() * 7;
        final monthTitle = DateFormat('MMMM y', 'es').format(_calendarMonth);
        return ListView(children: [
          _sectionHeader('Agenda', subtitle: 'Consulta las citas por día'),
          _bodyCard(child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'Mes anterior', onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text(toBeginningOfSentenceCase(monthTitle) ?? monthTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Mes siguiente', onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
              IconButton(tooltip: 'Volver al mes actual', onPressed: () => setState(() => _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month)), icon: const Icon(Icons.today_rounded)),
            ]),
            const SizedBox(height: 10),
            const Row(children: [
              _WeekdayLabel('L'), _WeekdayLabel('M'), _WeekdayLabel('X'), _WeekdayLabel('J'), _WeekdayLabel('V'), _WeekdayLabel('S'), _WeekdayLabel('D'),
            ]),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 4, childAspectRatio: 0.83),
              itemBuilder: (context, index) {
                final dayNumber = index - (firstWeekday - 1) + 1;
                if (dayNumber < 1 || dayNumber > days) return const SizedBox.shrink();
                final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNumber);
                final count = counts[dateKey(date)] ?? 0;
                final today = DateUtils.isSameDay(date, DateTime.now());
                return InkWell(
                  onTap: () => _push('agenda_day', 'Agenda del día', data: {'date': date}),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: today ? _accent.withValues(alpha: 0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: today ? _accent : const Color(0xFFF0E3E5), width: today ? 1.5 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$dayNumber', style: TextStyle(fontWeight: today ? FontWeight.w800 : FontWeight.w500, color: today ? _accent : Colors.black87)),
                      const SizedBox(height: 3),
                      if (count > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(12)), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))
                      else const SizedBox(height: 14),
                    ]),
                  ),
                );
              },
            ),
          ])),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => _push('agenda_day', 'Agenda del día', data: {'date': DateTime.now()}), icon: const Icon(Icons.today_rounded), label: const Text('Ver hoy'))),
        ]);
      },
    );
  }

  Widget _agendaDayPage(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _db.getAppointmentsBetween(start, end),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final appointments = snapshot.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pageHeader(formatDateLong(day), trailing: _primaryButton('Agregar cita', () => _openAppointmentForm(date: start))),
          Expanded(child: appointments.isEmpty
              ? _empty('No hay citas para este día', action: _primaryButton('Agregar cita', () => _openAppointmentForm(date: start)))
              : ListView.separated(itemCount: appointments.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) => _appointmentListTile(appointments[index]))),
        ]);
      },
    );
  }

  Widget _appointmentsSection() {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _db.getAllAppointments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final now = DateTime.now();
        List<Map<String, Object?>> selected;
        if (_appointmentsTab == 0) {
          selected = all.where((a) => a['estado'] == 'Programada').toList()
            ..sort((a, b) => (a['fecha_hora'] as String).compareTo(b['fecha_hora'] as String));
        } else if (_appointmentsTab == 1) {
          selected = all.where((a) => a['estado'] == 'Pendiente_de_cerrar').toList()
            ..sort((a, b) => (a['fecha_hora'] as String).compareTo(b['fecha_hora'] as String));
        } else {
          selected = all.where((a) => ['Terminada', 'Cancelada', 'No_asistio'].contains(a['estado'])).toList()
            ..sort((a, b) => ((b['cerrada_en'] ?? b['fecha_hora']) as String).compareTo((a['cerrada_en'] ?? a['fecha_hora']) as String));
        }
        selected = selected.where((a) {
          final d = DateTime.parse(a['fecha_hora'] as String);
          switch (_appointmentFilter) {
            case 'Hoy': return d.year == now.year && d.month == now.month && d.day == now.day;
            case 'Semana':
              final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
              final end = start.add(const Duration(days: 7));
              return !d.isBefore(start) && d.isBefore(end);
            case 'Mensual': return d.year == now.year && d.month == now.month;
            default: return true;
          }
        }).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader('Citas', subtitle: 'Organiza, actualiza y consulta el historial', trailing: _primaryButton('Agregar cita', () => _openAppointmentForm())),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return DropdownButtonFormField<int>(
                value: _appointmentsTab,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sección de citas'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Programadas')),
                  DropdownMenuItem(value: 1, child: Text('Pendientes de cerrar')),
                  DropdownMenuItem(value: 2, child: Text('Historial')),
                ],
                onChanged: (value) => setState(() => _appointmentsTab = value ?? 0),
              );
            }
            return SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Programadas')),
                ButtonSegment(value: 1, label: Text('Pendientes')),
                ButtonSegment(value: 2, label: Text('Historial')),
              ],
              selected: {_appointmentsTab},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => _appointmentsTab = value.first),
            );
          }),
          const SizedBox(height: 12),
          Row(children: [const Text('Filtrar:', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(width: 10), DropdownButton<String>(value: _appointmentFilter, items: const [
            DropdownMenuItem(value: 'Todos', child: Text('Todos')),
            DropdownMenuItem(value: 'Hoy', child: Text('Hoy')),
            DropdownMenuItem(value: 'Semana', child: Text('Semana')),
            DropdownMenuItem(value: 'Mensual', child: Text('Mensual')),
          ], onChanged: (value) => setState(() => _appointmentFilter = value ?? 'Todos'))]),
          Expanded(child: selected.isEmpty
              ? _empty(_appointmentsTab == 1 ? 'No tienes citas pendientes de cerrar' : _appointmentsTab == 2 ? 'Todavía no hay citas en el historial' : 'No hay citas programadas', action: _appointmentsTab == 2 ? null : _primaryButton('Agregar cita', () => _openAppointmentForm()))
              : ListView.separated(itemCount: selected.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) => _appointmentListTile(selected[index]))),
          const SizedBox(height: 4),
          Text('Mantén pulsada una cita para abrir el menú rápido.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]);
      },
    );
  }

  Future<void> _showQuickAppointmentMenu(Map<String, Object?> appointment) async {
    final action = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Acciones rápidas'),
      content: Text('${appointment['clienta_nombre']} · ${formatDateCompact(DateTime.parse(appointment['fecha_hora'] as String))}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'Terminada'), child: const Text('Terminada')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'Posponer'), child: const Text('Posponer')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'Eliminar'), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'Cancelar'), child: const Text('Cancelar cita')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'No_asistio'), child: const Text('No asistió')),
      ],
    ));
    if (action == null) return;
    final id = appointment['id'] as int;
    if (action == 'Eliminar') {
      await _deleteAppointment(id);
    } else if (action == 'Posponer') {
      _openAppointmentForm(id: id, reprogram: true);
    } else {
      await _db.changeAppointmentStatus(id, action == 'Cancelar' ? 'Cancelada' : action);
      await _refresh();
    }
  }

  Widget _clientsSection() {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _db.getClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final query = normalizeSearch(_clientSearch);
        final clients = snapshot.data!.where((client) => query.isEmpty || normalizeSearch('${client['nombre']} ${client['telefono'] ?? ''}').contains(query)).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader('Clientes', subtitle: 'Ficha, contacto e historial de citas', trailing: _primaryButton('Agregar clienta', () => _push('client_form', 'Agregar clienta'))),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Buscar por nombre o teléfono', hintText: 'Admite tildes y mayúsculas diferentes'),
            onChanged: (value) => setState(() => _clientSearch = value),
          ),
          const SizedBox(height: 12),
          Expanded(child: clients.isEmpty ? _empty(query.isEmpty ? 'Todavía no hay clientas' : 'No se encontraron coincidencias', action: query.isEmpty ? _primaryButton('Agregar clienta', () => _push('client_form', 'Agregar clienta')) : null)
              : ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: 0.12), foregroundColor: _accent, child: Text((client['nombre'] as String).trim().isEmpty ? '?' : (client['nombre'] as String).trim().substring(0, 1).toUpperCase())),
                      title: Text(client['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text((client['telefono'] as String?)?.isNotEmpty == true ? client['telefono'] as String : 'Sin teléfono'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [if ((client['activa'] as int? ?? 1) == 0) const Chip(label: Text('Inactiva')), const Icon(Icons.chevron_right_rounded)]),
                      onTap: () => _push('client_detail', 'Ficha de clienta', data: {'id': client['id']}),
                    );
                  },
                )),
        ]);
      },
    );
  }

  Widget _catalogSection({bool internal = false}) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _db.getServices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final services = snapshot.data!;
        final active = services.where((s) => (s['activo'] as int? ?? 0) == 1).toList();
        final inactive = services.where((s) => (s['activo'] as int? ?? 0) == 0).toList();
        Widget serviceList(List<Map<String, Object?>> list, {required bool inactiveList}) {
          if (list.isEmpty) return _empty(inactiveList ? 'No hay servicios inactivos' : 'Tu catálogo está vacío', action: inactiveList ? null : _primaryButton('Agregar servicio', () => _push('service_form', 'Agregar servicio')));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final service = list[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: 0.12), foregroundColor: _accent, child: const Icon(Icons.spa_rounded)),
                title: Text(service['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_currency(service['precio'] as num)),
                trailing: Wrap(spacing: 0, children: [
                  IconButton(tooltip: 'Editar', onPressed: () => _push('service_form', 'Editar servicio', data: {'id': service['id'], 'service': service}), icon: const Icon(Icons.edit_outlined)),
                  if (inactiveList)
                    IconButton(tooltip: 'Reactivar', onPressed: () async { await _db.setServiceActive(service['id'] as int, true); await _refresh(); }, icon: Icon(Icons.restore_rounded, color: _accent))
                  else
                    IconButton(tooltip: 'Eliminar', onPressed: () => _deleteService(service), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                ]),
              );
            },
          );
        }
        final catalogActions = Wrap(spacing: 6, children: [
          IconButton(tooltip: 'Compartir catálogo por WhatsApp', onPressed: _prepareCatalogMessage, icon: const Icon(Icons.share_rounded)),
          _primaryButton('Agregar', () => _push('service_form', 'Agregar servicio')),
        ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (internal) ...[_pageHeader('Catálogo'), Align(alignment: Alignment.centerLeft, child: catalogActions)]
          else _sectionHeader('Catálogo', subtitle: 'Servicios, precios y lista para compartir', trailing: catalogActions),
          Expanded(child: DefaultTabController(length: 2, child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Activos'), Tab(text: 'Inactivos')]),
            Expanded(child: TabBarView(children: [serviceList(active, inactiveList: false), serviceList(inactive, inactiveList: true)])),
          ]))),
        ]);
      },
    );
  }

  Widget _settingsSection() {
    return SettingsPage(
      key: const ValueKey('settings-page'),
      db: _db,
      initialSettings: _settings,
      onSaved: () async { await _refresh(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados'))); },
    );
  }

  Widget _clientDetailPage(int id) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_db.getClient(id), _db.getAppointmentsByClient(id, limit: 10)]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final client = snapshot.data![0] as Map<String, Object?>?;
        if (client == null) return Column(children: [_pageHeader('Ficha de clienta'), const Expanded(child: Center(child: Text('Esta ficha ya no está disponible.')))]);
        final history = snapshot.data![1] as List<Map<String, Object?>>;
        final phone = client['telefono'] as String?;
        final active = (client['activa'] as int? ?? 1) == 1;
        final notify = (client['notificar_whatsapp'] as int? ?? 0) == 1;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pageHeader('Ficha de clienta', trailing: PopupMenuButton<String>(onSelected: (value) {
            if (value == 'edit') _push('client_form', 'Editar clienta', data: {'id': id, 'client': client});
            if (value == 'delete') _deleteClient(id);
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Eliminar'))])),
          Expanded(child: ListView(children: [
            _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [CircleAvatar(radius: 25, backgroundColor: _accent.withValues(alpha: 0.14), foregroundColor: _accent, child: Text((client['nombre'] as String).substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), const SizedBox(width: 12), Expanded(child: Text(client['nombre'] as String, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), _statusChip(active ? 'Activa' : 'Inactiva')]),
              const SizedBox(height: 18),
              _detailLine(Icons.phone_rounded, 'Teléfono', (phone?.isNotEmpty == true) ? phone! : 'Sin teléfono'),
              _detailLine(Icons.notes_rounded, 'Nota', (client['nota'] as String?)?.isNotEmpty == true ? client['nota'] as String : 'Sin notas'),
              _detailLine(Icons.event_available_rounded, 'Fecha de registro', formatDateLong(DateTime.parse(client['fecha_registro'] as String))),
              _detailLine(Icons.notifications_active_outlined, 'Notificar por WhatsApp', notify && phone?.isNotEmpty == true ? 'Sí' : 'No'),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => _push('client_form', 'Editar clienta', data: {'id': id, 'client': client}), icon: const Icon(Icons.edit_rounded), label: const Text('Editar datos'))),
            ])),
            const SizedBox(height: 12),
            _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Acciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _primaryButton('Agendar cita', () => _openAppointmentForm(clientId: id)),
                OutlinedButton.icon(onPressed: () => _prepareClientMessage(client, history), icon: const Icon(Icons.chat_rounded), label: const Text('Notificar por WhatsApp')),
                OutlinedButton.icon(onPressed: () => _push('client_form', 'Editar clienta', data: {'id': id, 'client': client}), icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
              ]),
              if (phone?.isNotEmpty != true || !notify) ...[
                const SizedBox(height: 8),
                Text(phone?.isNotEmpty != true ? 'Agrega un teléfono para preparar mensajes.' : 'Las notificaciones están desactivadas para esta clienta.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ])),
            const SizedBox(height: 12),
            _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Últimas 10 citas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (history.isEmpty) _empty('Esta clienta todavía no tiene citas')
              else ...history.map((appointment) => InkWell(
                onTap: () => _push('appointment_detail', 'Detalle de cita', data: {'id': appointment['id']}),
                borderRadius: BorderRadius.circular(10),
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.event_note_rounded, color: _accent)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${formatDateCompact(DateTime.parse(appointment['fecha_hora'] as String))} · ${formatTime(DateTime.parse(appointment['fecha_hora'] as String))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${appointment['servicios_text'] ?? 'Sin servicios'}${appointment['estado'] == 'Programada' || appointment['estado'] == 'Pendiente_de_cerrar' ? '' : ' · ${_statusText(appointment['estado'] as String)}'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ])),
                  const SizedBox(width: 6),
                  Text(_currency(appointment['precio_total'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ])),
              )),
            ])),
            const SizedBox(height: 20),
          ])),
        ]);
      },
    );
  }

  String _statusText(String status) => switch (status) {
    'No_asistio' => 'No asistió',
    'Pendiente_de_cerrar' => 'Pendiente de cerrar',
    _ => status,
  };

  Widget _detailLine(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: _accent), const SizedBox(width: 10), SizedBox(width: 125, child: Text(label, style: TextStyle(color: Colors.grey.shade700))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))) ]),
      );

  Widget _appointmentDetailPage(int id) {
    return FutureBuilder<Map<String, Object?>?>(
      future: _db.getAppointment(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final appointment = snapshot.data;
        if (appointment == null) return Column(children: [_pageHeader('Detalle de cita'), const Expanded(child: Center(child: Text('La cita ya no está disponible.')))]);
        final date = DateTime.parse(appointment['fecha_hora'] as String);
        final services = (appointment['servicios'] as List<Map<String, Object?>>?) ?? [];
        final phone = appointment['clienta_telefono'] as String?;
        final status = appointment['estado'] as String;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pageHeader('Detalle de cita', trailing: PopupMenuButton<String>(onSelected: (value) {
            if (value == 'edit') _openAppointmentForm(id: id);
            if (value == 'delete') _deleteAppointment(id);
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar cita')), PopupMenuItem(value: 'delete', child: Text('Eliminar cita'))])),
          Expanded(child: ListView(children: [
            _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(appointment['clienta_nombre'] as String, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))), _statusChip(status)]),
              const SizedBox(height: 14),
              _detailLine(Icons.calendar_today_rounded, 'Fecha', formatDateLong(date)),
              _detailLine(Icons.schedule_rounded, 'Hora', formatTime(date)),
              _detailLine(Icons.payments_outlined, 'Precio total', _currency(appointment['precio_total'] as num)),
              _detailLine(Icons.notes_rounded, 'Nota', (appointment['nota'] as String?)?.isNotEmpty == true ? appointment['nota'] as String : 'Sin notas'),
              const Divider(height: 24),
              const Text('Servicios', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (services.isEmpty) const Text('No hay servicios registrados')
              else ...services.map((service) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(service['nombre_snapshot'] as String)), Text(_currency(service['precio_snapshot'] as num), style: const TextStyle(fontWeight: FontWeight.w600))]))),
            ])),
            const SizedBox(height: 12),
            _bodyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Acciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: () => _openAppointmentForm(id: id), icon: const Icon(Icons.edit_rounded), label: const Text('Editar cita')),
                OutlinedButton.icon(onPressed: () => _openAppointmentForm(id: id, reprogram: true), icon: const Icon(Icons.event_repeat_rounded), label: const Text('Reprogramar')),
                if (status != 'Terminada') _primaryButton('Terminar cita', () async { await _db.changeAppointmentStatus(id, 'Terminada'); await _refresh(); }),
                if (status != 'Cancelada') OutlinedButton.icon(onPressed: () async { await _db.changeAppointmentStatus(id, 'Cancelada'); await _refresh(); }, icon: const Icon(Icons.event_busy_rounded), label: const Text('Cancelar cita')),
                if (status != 'No_asistio') OutlinedButton.icon(onPressed: () async { await _db.changeAppointmentStatus(id, 'No_asistio'); await _refresh(); }, icon: const Icon(Icons.person_off_rounded), label: const Text('No asistió')),
                OutlinedButton.icon(onPressed: () => _deleteAppointment(id), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), label: const Text('Eliminar cita')),
                OutlinedButton.icon(onPressed: () => _prepareAppointmentMessage(appointment), icon: const Icon(Icons.chat_rounded), label: const Text('Notificar por WhatsApp')),
                if (phone?.isNotEmpty == true) OutlinedButton.icon(onPressed: () => WhatsAppService.callPhone(phone!), icon: const Icon(Icons.call_rounded), label: const Text('Llamar')),
              ]),
            ])),
            const SizedBox(height: 20),
          ])),
        ]);
      },
    );
  }

  Future<void> _prepareAppointmentMessage(Map<String, Object?> appointment) async {
    final phone = appointment['clienta_telefono'] as String?;
    final clientId = appointment['clienta_id'] as int;
    final name = appointment['clienta_nombre'] as String? ?? 'clienta';
    if (phone == null || phone.trim().isEmpty) {
      final addPhone = await _askYesNo(
        title: 'Falta el número de contacto',
        message: 'Esta clienta no tiene número de WhatsApp. ¿Deseas agregar un número de contacto?',
        yesText: 'Sí, agregar',
      );
      if (addPhone) {
        final client = await _db.getClient(clientId);
        if (client != null) _push('client_form', 'Editar clienta', data: {'id': clientId, 'client': client});
      }
      return;
    }
    if ((appointment['clienta_notificar_whatsapp'] as int? ?? 0) != 1) {
      final enableNotifications = await _confirm(
        title: 'Notificaciones desactivadas',
        message: 'Las notificaciones están desactivadas para esta clienta. ¿Deseas activarlas para preparar el mensaje?',
      );
      if (!enableNotifications) return;
      await _db.setClientWhatsAppEnabled(clientId, true);
      await _refresh();
    }
    final date = DateTime.parse(appointment['fecha_hora'] as String);
    final relative = relativeAppointmentDate(date, DateTime.now());
    final message = 'Hola $name, recuerde que $relative tiene cita conmigo a las ${formatTime(date)}. Por favor, si se le presenta algún problema me avisa con antelación. Gracias.';
    _push('whatsapp_preview', 'Vista previa de WhatsApp', data: {'message': message, 'phone': phone, 'title': 'Notificación de cita'});
  }

  Future<void> _prepareClientMessage(Map<String, Object?> client, List<Map<String, Object?>> history) async {
    final phone = client['telefono'] as String?;
    final clientId = client['id'] as int;
    if (phone == null || phone.trim().isEmpty) {
      final addPhone = await _askYesNo(
        title: 'Falta el número de contacto',
        message: 'Esta clienta no tiene número de WhatsApp. ¿Deseas agregar un número de contacto?',
        yesText: 'Sí, agregar',
      );
      if (addPhone) _push('client_form', 'Editar clienta', data: {'id': clientId, 'client': client});
      return;
    }
    if ((client['notificar_whatsapp'] as int? ?? 0) != 1) {
      final enableNotifications = await _confirm(
        title: 'Notificaciones desactivadas',
        message: 'Las notificaciones están desactivadas para esta clienta. ¿Deseas activarlas para preparar el mensaje?',
      );
      if (!enableNotifications) return;
      await _db.setClientWhatsAppEnabled(clientId, true);
      await _refresh();
    }
    final now = DateTime.now();
    final upcoming = history.where((a) => a['estado'] == 'Programada' && DateTime.parse(a['fecha_hora'] as String).isAfter(now)).toList()
      ..sort((a, b) => (a['fecha_hora'] as String).compareTo(b['fecha_hora'] as String));
    final appointment = upcoming.isNotEmpty ? upcoming.first : null;
    if (appointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta clienta no tiene una cita futura programada. Agenda una cita primero.')));
      return;
    }
    final date = DateTime.parse(appointment['fecha_hora'] as String);
    final message = 'Hola ${client['nombre']}, recuerde que ${relativeAppointmentDate(date, now)} tiene cita conmigo a las ${formatTime(date)}. Por favor, si se le presenta algún problema me avisa con antelación. Gracias.';
    _push('whatsapp_preview', 'Vista previa de WhatsApp', data: {'message': message, 'phone': phone, 'title': 'Notificación de cita'});
  }

  Future<void> _prepareCatalogMessage() async {
    final services = await _db.getServices(activeOnly: true);
    if (services.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un servicio activo para compartir el catálogo.')));
      return;
    }
    final lines = services.map((service) => '• ${service['nombre']} – ${_currency(service['precio'] as num)}').join('\n');
    final businessName = _settings['nombre_negocio'] ?? 'Mi negocio de uñas';
    _push('whatsapp_preview', 'Compartir catálogo', data: {
      'message': 'Catálogo de servicios – $businessName\n\n$lines',
      'phone': null,
      'title': 'Catálogo de servicios',
    });
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(child: Center(child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade600))));
}

class ClientFormPage extends StatefulWidget {
  const ClientFormPage({super.key, required this.db, required this.onSave, required this.onBack, this.initial, this.clientId, this.onCreateClient = false});
  final AppDatabase db;
  final Map<String, Object?>? initial;
  final int? clientId;
  final bool onCreateClient;
  final VoidCallback onBack;
  final Future<void> Function(int id) onSave;

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _countryCode = TextEditingController(text: '+53');
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _active = true;
  bool _notifyWhatsapp = false;
  bool _loading = true;
  bool _saving = false;
  Map<String, Object?>? _client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var client = widget.initial;
    if (widget.clientId != null) client = await widget.db.getClient(widget.clientId!);
    if (!mounted) return;
    if (client != null) {
      _client = client;
      _name.text = client['nombre'] as String? ?? '';
      final hasSavedPhone = (client['telefono'] as String?)?.isNotEmpty == true;
      _countryCode.text = hasSavedPhone ? (client['codigo_pais'] as String? ?? '+53') : '+53';
      _phone.text = client['telefono_local'] as String? ?? '';
      // Compatibility fallback in case a database created by an earlier build lacks split fields.
      if (_phone.text.isEmpty && (client['telefono'] as String?)?.isNotEmpty == true) {
        final full = client['telefono'] as String;
        final match = RegExp(r'^(\+\d{1,4})\s*(.*)$').firstMatch(full);
        if (match != null) {
          _countryCode.text = match.group(1)!;
          _phone.text = match.group(2)!;
        } else {
          _phone.text = full;
        }
      }
      _note.text = client['nota'] as String? ?? '';
      _active = (client['activa'] as int? ?? 1) == 1;
      _notifyWhatsapp = (client['notificar_whatsapp'] as int? ?? 0) == 1;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _countryCode.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final local = _phone.text.trim();
    final code = _countryCode.text.trim().isEmpty ? '+53' : _countryCode.text.trim();
    if (local.isNotEmpty && !RegExp(r'^\+[0-9]{1,4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe el código de país con + y entre 1 y 4 dígitos.')));
      return;
    }
    final fullPhone = local.isEmpty ? null : '$code${local.replaceAll(RegExp(r'\s+'), '')}';
    final duplicate = await widget.db.isPhoneDuplicate(fullPhone, excludingId: widget.clientId);
    if (duplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso: otra clienta tiene guardado ese número. Puedes continuar si es correcto.')));
    }
    setState(() => _saving = true);
    try {
      final id = await widget.db.saveClient(
        id: widget.clientId,
        nombre: _name.text,
        telefono: fullPhone,
        codigoPais: code,
        telefonoLocal: local,
        nota: _note.text,
        activa: _active,
        notificarWhatsapp: _notifyWhatsapp,
      );
      await widget.onSave(id);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar la clienta: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        OutlinedButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Volver')),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.clientId == null ? 'Agregar clienta' : 'Editar clienta', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 12),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.only(bottom: 20), children: [
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre *', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (value) => (value == null || value.trim().isEmpty) ? 'Escribe el nombre de la clienta.' : null),
          const SizedBox(height: 12),
          const Text('Teléfono (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 104, child: TextFormField(controller: _countryCode, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]'))], decoration: const InputDecoration(labelText: 'Código', hintText: '+53'), validator: (value) => _phone.text.trim().isNotEmpty && (value == null || !RegExp(r'^\+[0-9]{1,4}$').hasMatch(value.trim())) ? 'Ej. +53' : null)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Número de teléfono', hintText: '5 1234567'), onChanged: (_) => setState(() { if (_phone.text.trim().isEmpty) _notifyWhatsapp = false; }))),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _note, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Nota', alignLabelWithHint: true, hintText: 'Preferencias, alergias a productos, observaciones…')),
          const SizedBox(height: 12),
          if (_client != null) _detailLineLocal(Icons.event_available_rounded, 'Fecha de registro', formatDateLong(DateTime.parse(_client!['fecha_registro'] as String))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Clienta activa'), subtitle: const Text('Las clientas inactivas se conservan en el historial.'), value: _active, onChanged: (value) => setState(() => _active = value)),
          if (_phone.text.trim().isNotEmpty) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Notificar por WhatsApp'), subtitle: const Text('La app prepara el mensaje; el envío se confirma en WhatsApp.'), value: _notifyWhatsapp, onChanged: (value) => setState(() => _notifyWhatsapp = value)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _saving ? null : _submit, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(_saving ? 'Guardando…' : 'Guardar clienta')),
        ]),
      )),
    ]);
  }

  Widget _detailLineLocal(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)), Expanded(child: Text(value))]),
      );
}

class ServiceFormPage extends StatefulWidget {
  const ServiceFormPage({super.key, required this.db, required this.onSaved, required this.currency, required this.onBack, this.service});
  final AppDatabase db;
  final Future<void> Function() onSaved;
  final String Function(num amount) currency;
  final VoidCallback onBack;
  final Map<String, Object?>? service;
  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.service?['nombre'] as String? ?? '');
    _price = TextEditingController(text: widget.service?['precio']?.toString() ?? '');
  }
  @override
  void dispose() { _name.dispose(); _price.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final price = double.parse(_price.text.trim().replaceAll(',', '.'));
    final duplicate = await widget.db.isServiceNameDuplicate(_name.text, excludingId: widget.service?['id'] as int?);
    if (duplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso: ya existe un servicio con ese nombre. Se permite continuar, pero revisa el catálogo.')));
    }
    setState(() => _saving = true);
    try {
      await widget.db.saveService(id: widget.service?['id'] as int?, nombre: _name.text, precio: price);
      await widget.onSaved();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el servicio: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [OutlinedButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Volver')), const SizedBox(width: 12), Expanded(child: Text(widget.service == null ? 'Agregar servicio' : 'Editar servicio', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))]),
    const SizedBox(height: 16),
    Expanded(child: Form(key: _key, child: ListView(children: [
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre del servicio *'), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe un nombre.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Precio *', prefixText: ''), validator: (v) { final n = double.tryParse((v ?? '').trim().replaceAll(',', '.')); return n == null || n.isNaN || n.isInfinite || n < 0 ? 'Introduce un precio numérico igual o mayor que cero.' : null; }),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(_saving ? 'Guardando…' : 'Guardar servicio')),
    ]))),
  ]);
}

class AppointmentFormPage extends StatefulWidget {
  const AppointmentFormPage({super.key, required this.db, required this.onSaved, required this.onCreateClient, required this.onOpenCatalog,
    required this.onBack, required this.currency, this.initialId, this.initialClientId, this.initialDate, this.initialDraft, this.resetStatusOnSave = false});
  final AppDatabase db;
  final Future<void> Function() onSaved;
  final void Function(Map<String, dynamic> draft) onCreateClient;
  final void Function(Map<String, dynamic> draft) onOpenCatalog;
  final VoidCallback onBack;
  final String Function(num amount) currency;
  final int? initialId;
  final int? initialClientId;
  final DateTime? initialDate;
  final Map<String, dynamic>? initialDraft;
  final bool resetStatusOnSave;

  @override
  State<AppointmentFormPage> createState() => _AppointmentFormPageState();
}

class _AppointmentFormPageState extends State<AppointmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchClient = TextEditingController();
  final _totalController = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, Object?>> _clients = [];
  List<Map<String, Object?>> _services = [];
  final Set<int> _selectedServices = {};
  int? _clientId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _manualTotal = false;
  bool _updatingTotal = false;
  bool _loading = true;
  bool _saving = false;
  String _clientQuery = '';

  @override
  void initState() {
    super.initState();
    _totalController.addListener(_onTotalChanged);
    _load();
  }

  void _onTotalChanged() {
    if (!_updatingTotal && !_manualTotal) {
      _manualTotal = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    final loaded = await Future.wait([widget.db.getClients(), widget.db.getServices(activeOnly: true)]);
    final clients = loaded[0] as List<Map<String, Object?>>;
    final services = loaded[1] as List<Map<String, Object?>>;
    var clientId = widget.initialClientId;
    DateTime? date = widget.initialDate;
    TimeOfDay? time;
    final selected = <int>{};
    var note = '';
    var total = 0.0;
    var manual = false;
    if (widget.initialDraft != null) {
      final draft = widget.initialDraft!;
      clientId = draft['clientId'] as int? ?? clientId;
      date = draft['date'] as DateTime? ?? date;
      time = draft['time'] as TimeOfDay?;
      selected.addAll((draft['services'] as List<dynamic>? ?? []).whereType<int>());
      note = draft['note'] as String? ?? '';
      total = (draft['total'] as num?)?.toDouble() ?? 0;
      manual = draft['manualTotal'] as bool? ?? false;
    } else if (widget.initialId != null) {
      final appointment = await widget.db.getAppointment(widget.initialId!);
      if (appointment != null) {
        clientId = appointment['clienta_id'] as int;
        final dateTime = DateTime.parse(appointment['fecha_hora'] as String);
        date = DateTime(dateTime.year, dateTime.month, dateTime.day);
        time = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
        note = appointment['nota'] as String? ?? '';
        total = (appointment['precio_total'] as num).toDouble();
        final currentServices = await widget.db.getAppointmentServices(widget.initialId!);
        for (final service in currentServices) {
          final serviceId = service['servicio_id'] as int?;
          if (serviceId != null) {
            selected.add(serviceId);
            if (!services.any((s) => s['id'] == serviceId)) {
              services.add({'id': serviceId, 'nombre': service['nombre_snapshot'], 'precio': service['precio_snapshot'], 'activo': 0});
            }
          }
        }
        final snapshotSum = currentServices.fold<double>(0, (sum, item) => sum + (item['precio_snapshot'] as num).toDouble());
        manual = (snapshotSum - total).abs() > 0.005;
      }
    }
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _services = services;
      _clientId = clientId;
      _selectedDate = date;
      _selectedTime = time;
      _selectedServices.addAll(selected);
      _noteController.text = note;
      _manualTotal = manual;
      _setTotal(total);
      _loading = false;
    });
    if (!_manualTotal) _recalculateTotal();
  }

  void _setTotal(double value) {
    _updatingTotal = true;
    _totalController.text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    _updatingTotal = false;
  }

  double get _selectedServicesSum => _services.where((s) => _selectedServices.contains(s['id'] as int)).fold<double>(0, (sum, s) => sum + (s['precio'] as num).toDouble());

  void _recalculateTotal() => _setTotal(_selectedServicesSum);

  Map<String, dynamic> _draft() => {
    'clientId': _clientId,
    'date': _selectedDate,
    'time': _selectedTime,
    'services': _selectedServices.toList(),
    'note': _noteController.text,
    'total': double.tryParse(_totalController.text.trim().replaceAll(',', '.')) ?? 0,
    'manualTotal': _manualTotal,
  };

  @override
  void dispose() {
    _searchClient.dispose();
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es'),
      helpText: 'Selecciona la fecha de la cita',
    );
    if (selected != null) setState(() => _selectedDate = DateTime(selected.year, selected.month, selected.day));
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: 'Selecciona la hora',
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (selected != null) setState(() => _selectedTime = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una clienta.')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fecha y la hora son obligatorias.')));
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un servicio activo.')));
      return;
    }
    final total = double.tryParse(_totalController.text.trim().replaceAll(',', '.'));
    if (total == null || total.isNaN || total.isInfinite || total < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El precio total debe ser un número mayor o igual que cero.')));
      return;
    }
    final dateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
    setState(() => _saving = true);
    try {
      await widget.db.saveAppointment(
        id: widget.initialId,
        clientId: _clientId!,
        dateTime: dateTime,
        serviceIds: _selectedServices.toList(),
        total: total,
        nota: _noteController.text,
        resetStatus: widget.resetStatusOnSave,
      );
      await widget.onSaved();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar la cita: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [OutlinedButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Volver')), const SizedBox(width: 12), Expanded(child: Text(widget.initialId == null ? 'Agregar cita' : widget.resetStatusOnSave ? 'Reprogramar cita' : 'Editar cita', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))]),
      const SizedBox(height: 10),
      if (_services.isEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Expanded(child: Text('El catálogo está vacío. Agrega un servicio antes de guardar una cita.')), TextButton(onPressed: () => widget.onOpenCatalog(_draft()), child: const Text('Abrir Catálogo'))])),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          TextField(controller: _searchClient, decoration: const InputDecoration(labelText: 'Buscar clienta', prefixIcon: Icon(Icons.search_rounded)), onChanged: (value) => setState(() => _clientQuery = value)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _clientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Clienta *'),
            items: _clients.where((client) => normalizeSearch('${client['nombre']} ${client['telefono'] ?? ''}').contains(normalizeSearch(_clientQuery))).map((client) => DropdownMenuItem<int>(value: client['id'] as int, child: Text('${client['nombre']}${(client['activa'] as int? ?? 1) == 0 ? ' · Inactiva' : ''}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => setState(() => _clientId = value),
            validator: (value) => value == null ? 'Selecciona una clienta.' : null,
          ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => widget.onCreateClient(_draft()), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Crear nueva clienta'))),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final dateButton = OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_rounded), label: Text(_selectedDate == null ? 'Elegir fecha *' : formatDateCompact(_selectedDate!)));
            final timeButton = OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule_rounded), label: Text(_selectedTime == null ? 'Elegir hora *' : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'));
            if (constraints.maxWidth < 360) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dateButton, const SizedBox(height: 8), timeButton]);
            return Row(children: [Expanded(child: dateButton), const SizedBox(width: 8), Expanded(child: timeButton)]);
          }),
          const SizedBox(height: 18),
          const Text('Servicios *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          if (_services.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No hay servicios activos. El guardado queda bloqueado hasta que agregues uno.'))
          else ..._services.map((service) {
            final id = service['id'] as int;
            final selected = _selectedServices.contains(id);
            final active = (service['activo'] as int? ?? 0) == 1;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${service['nombre']}${active ? '' : ' · Inactivo (histórico)'}'),
              subtitle: Text(widget.currency(service['precio'] as num)),
              value: selected,
              onChanged: (value) {
                setState(() {
                  if (value == true) _selectedServices.add(id); else _selectedServices.remove(id);
                  if (!_manualTotal) _recalculateTotal();
                });
              },
            );
          }),
          const SizedBox(height: 12),
          TextFormField(
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: const InputDecoration(labelText: 'Precio total *', helperText: 'Se calcula desde los servicios; puedes modificarlo manualmente.'),
            validator: (value) { final number = double.tryParse((value ?? '').trim().replaceAll(',', '.')); return number == null || number.isNaN || number.isInfinite || number < 0 ? 'Introduce un precio válido mayor o igual que cero.' : null; },
          ),
          if (_manualTotal) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () { setState(() { _manualTotal = false; _recalculateTotal(); }); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Volver a calcular desde los servicios'))),
          const SizedBox(height: 12),
          TextFormField(controller: _noteController, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Nota', hintText: 'Información adicional de la cita', alignLabelWithHint: true)),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _saving || _services.isEmpty ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(_saving ? 'Guardando…' : 'Guardar cita')),
        ]),
      )),
    ]);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.db, required this.initialSettings, required this.onSaved});
  final AppDatabase db;
  final Map<String, String> initialSettings;
  final Future<void> Function() onSaved;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _business;
  late final TextEditingController _owner;
  late final TextEditingController _currency;
  late int _selectedColor;
  bool _saving = false;
  static const _colors = <(String, int)>[
    ('Rosa empolvado', 0xFFB76E79),
    ('Malva', 0xFF8F6AA8),
    ('Coral', 0xFFE47C6E),
    ('Verde salvia', 0xFF638A79),
    ('Azul', 0xFF547CA5),
    ('Ciruela', 0xFF80516B),
    ('Dorado', 0xFFB38A3E),
  ];

  @override
  void initState() {
    super.initState();
    _business = TextEditingController(text: widget.initialSettings['nombre_negocio'] ?? 'Mi negocio de uñas');
    _owner = TextEditingController(text: widget.initialSettings['nombre_duena'] ?? 'Dueña');
    _currency = TextEditingController(text: widget.initialSettings['simbolo_moneda'] ?? r'$');
    _selectedColor = int.tryParse((widget.initialSettings['color_acento'] ?? '0xFFB76E79').replaceFirst('0x', ''), radix: 16) ?? 0xFFB76E79;
  }

  @override
  void dispose() { _business.dispose(); _owner.dispose(); _currency.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_business.text.trim().isEmpty || _owner.text.trim().isEmpty || _currency.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa el nombre del negocio, el nombre de la dueña y el símbolo de moneda.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.db.saveSettings({
        'nombre_negocio': _business.text.trim(),
        'nombre_duena': _owner.text.trim(),
        'simbolo_moneda': _currency.text.trim(),
        'color_acento': '0x${_selectedColor.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      });
      await widget.onSaved();
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(children: [
    const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('Ajustes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
    Text('Personaliza el nombre y la apariencia del negocio.', style: TextStyle(color: Colors.grey.shade700)),
    const SizedBox(height: 18),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _business, decoration: const InputDecoration(labelText: 'Nombre del negocio')),
      const SizedBox(height: 12),
      TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Nombre de la dueña')),
      const SizedBox(height: 12),
      TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Símbolo de moneda', hintText: r'$')),
      const SizedBox(height: 18),
      const Text('Color de acento', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: _colors.map((option) {
        final selected = _selectedColor == option.$2;
        return Tooltip(message: option.$1, child: InkWell(
          onTap: () => setState(() => _selectedColor = option.$2),
          borderRadius: BorderRadius.circular(22),
          child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Color(option.$2), shape: BoxShape.circle, border: selected ? Border.all(color: Colors.black87, width: 3) : Border.all(color: Colors.white, width: 2)), child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null),
        ));
      }).toList()),
      const SizedBox(height: 8),
      Text(_colors.firstWhere((o) => o.$2 == _selectedColor, orElse: () => ('Color personalizado', _selectedColor)).$1, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(_saving ? 'Guardando…' : 'Guardar ajustes')),
    ]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Sobre la app', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('ManiGest v1.1 · Datos guardados localmente en el dispositivo.'),
      const SizedBox(height: 4),
      Text('No se envían mensajes automáticamente. La app abre WhatsApp con el texto preparado para que tú lo revises y envíes.', style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 8),
      const Text('Las copias de seguridad y la sincronización en la nube no forman parte de esta versión.'),
    ]))),
    const SizedBox(height: 20),
  ]);
}

class MessagePreviewPage extends StatefulWidget {
  const MessagePreviewPage({super.key, required this.initialText, required this.title, required this.onBack, this.phone});
  final String initialText;
  final String title;
  final String? phone;
  final VoidCallback onBack;
  @override
  State<MessagePreviewPage> createState() => _MessagePreviewPageState();
}

class _MessagePreviewPageState extends State<MessagePreviewPage> {
  late final TextEditingController _message;
  bool _opening = false;
  @override
  void initState() { super.initState(); _message = TextEditingController(text: widget.initialText); }
  @override
  void dispose() { _message.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un mensaje antes de continuar.')));
      return;
    }
    setState(() => _opening = true);
    final opened = await WhatsAppService.openMessage(phone: widget.phone, message: _message.text.trim());
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp. Comprueba que esté instalado o usa WhatsApp Web.')));
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [OutlinedButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Volver')), const SizedBox(width: 12), Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))]),
    const SizedBox(height: 12),
    Text(widget.phone == null ? 'Elige el contacto o grupo dentro de WhatsApp.' : 'Destinatario: ${widget.phone}', style: TextStyle(color: Colors.grey.shade700)),
    const SizedBox(height: 12),
    Expanded(child: TextField(controller: _message, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'Mensaje editable', alignLabelWithHint: true, hintText: 'Edita el texto antes de abrir WhatsApp.'))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _opening ? null : _send, icon: _opening ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_opening ? 'Abriendo WhatsApp…' : 'Abrir WhatsApp'))),
    const SizedBox(height: 8),
    Text('La app no puede confirmar si el mensaje se envió o fue leído.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
  ]);
}
