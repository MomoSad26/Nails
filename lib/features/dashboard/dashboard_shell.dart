import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../services/whatsapp_service.dart';
import '../appointments/appointment_form_page.dart';
import '../../core/widgets/status_chip.dart';
import '../catalog/service_form_page.dart';
import '../clients/client_form_page.dart';
import '../messages/message_preview_page.dart';
import 'navigation_sidebar.dart';
import '../settings/settings_page.dart';
import '../../utils/date_utils_es.dart';
import '../../utils/text_normalizer.dart';

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
            NavigationSidebar(
              activeSection: _route.kind == 'section' ? _route.section : null,
              accentColor: _accent,
              onSelected: _changeSection,
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
          StatusChip(
            status: appointment['estado'] as String? ?? 'Programada',
            accentColor: _accent,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      ),
    );
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
              Row(children: [CircleAvatar(radius: 25, backgroundColor: _accent.withValues(alpha: 0.14), foregroundColor: _accent, child: Text((client['nombre'] as String).substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), const SizedBox(width: 12), Expanded(child: Text(client['nombre'] as String, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), StatusChip(status: active ? 'Activa' : 'Inactiva', accentColor: _accent)]),
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
              Row(children: [Expanded(child: Text(appointment['clienta_nombre'] as String, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))), StatusChip(status: status, accentColor: _accent)]),
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
