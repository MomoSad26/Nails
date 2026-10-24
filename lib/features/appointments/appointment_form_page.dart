import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../utils/date_utils_es.dart';
import '../../utils/text_normalizer.dart';

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
  bool _clientSelectorOpen = false;

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
    DateTime? date = widget.initialDate ?? DateTime.now();
    TimeOfDay? time = TimeOfDay.now();
    final selected = <int>{};
    var note = '';
    var total = 0.0;
    var manual = false;
    if (widget.initialDraft != null) {
      final draft = widget.initialDraft!;
      clientId = draft['clientId'] as int? ?? clientId;
      date = draft['date'] as DateTime? ?? date;
      time = draft['time'] as TimeOfDay? ?? time;
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
      _clientQuery = '';
      _clientSelectorOpen = false;
      _searchClient.text = _labelForSelectedClient(clients, clientId);
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
    final launchedFromAgenda = widget.initialDate != null && widget.initialId == null;
    final initialDate = launchedFromAgenda ? (_selectedDate ?? now) : now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
      initialTime: TimeOfDay.now(),
      helpText: 'Selecciona la hora (AM/PM)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (selected != null) setState(() => _selectedTime = selected);
  }

  String _labelForSelectedClient(List<Map<String, Object?>> clients, int? id) {
    if (id == null) return '';
    for (final client in clients) {
      if (client['id'] == id) {
        final inactive = (client['activa'] as int? ?? 1) == 0;
        return '${client['nombre']}${inactive ? ' · Inactiva' : ''}';
      }
    }
    return '';
  }

  void _openClientSelector() {
    if (_clientSelectorOpen) return;
    setState(() {
      _clientSelectorOpen = true;
      _clientQuery = '';
      _searchClient.clear();
    });
  }

  void _closeClientSelector() {
    setState(() {
      _clientSelectorOpen = false;
      _clientQuery = '';
      _searchClient.text = _labelForSelectedClient(_clients, _clientId);
    });
  }

  void _selectClient(Map<String, Object?> client) {
    setState(() {
      _clientId = client['id'] as int;
      _searchClient.text = _labelForSelectedClient(_clients, _clientId);
      _clientQuery = '';
      _clientSelectorOpen = false;
    });
  }

  Widget _clientSelector() {
    final query = normalizeSearch(_clientQuery);
    final filtered = _clients.where((client) {
      final searchable = normalizeSearch('${client['nombre']} ${client['telefono'] ?? ''}');
      return query.isEmpty || searchable.contains(query);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF36516B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchClient,
            readOnly: !_clientSelectorOpen,
            onTap: _openClientSelector,
            onChanged: (value) => setState(() {
              _clientSelectorOpen = true;
              _clientQuery = value;
            }),
            decoration: InputDecoration(
              labelText: 'Clienta *',
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: IconButton(
                tooltip: _clientSelectorOpen ? 'Cerrar lista' : 'Mostrar clientas',
                onPressed: _clientSelectorOpen ? _closeClientSelector : _openClientSelector,
                icon: Icon(_clientSelectorOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
          if (_clientSelectorOpen) ...[
            const Divider(height: 1, color: Color(0xFF36516B)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (_clients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No hay clientas'),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No se encontraron clientas'),
                    )
                  else
                    ...filtered.map((client) {
                      final inactive = (client['activa'] as int? ?? 1) == 0;
                      final name = '${client['nombre']}${inactive ? ' · Inactiva' : ''}';
                      final phone = (client['telefono'] as String?)?.trim() ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: phone.isEmpty ? null : Text(phone),
                        onTap: () => _selectClient(client),
                      );
                    }),
                  const Divider(height: 1, color: Color(0xFF36516B)),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: const Text('Crear nueva clienta'),
                    onTap: () => widget.onCreateClient(_draft()),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
      if (_services.isEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF3B3219), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Expanded(child: Text('El catálogo está vacío. Agrega un servicio antes de guardar una cita.')), TextButton(onPressed: () => widget.onOpenCatalog(_draft()), child: const Text('Abrir Catálogo'))])),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          _clientSelector(),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final dateButton = OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_rounded), label: Text(_selectedDate == null ? 'Elegir fecha *' : formatDateCompact(_selectedDate!)));
            final timeButton = OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule_rounded), label: Text(_selectedTime == null ? 'Elegir hora *' : formatTimeParts(_selectedTime!.hour, _selectedTime!.minute)));
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
