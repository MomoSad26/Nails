import 'package:flutter/material.dart';

import '../../data/app_database.dart';

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
