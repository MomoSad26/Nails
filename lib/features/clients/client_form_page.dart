import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../utils/date_utils_es.dart';

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
  bool _notifyWhatsappManuallySet = false;
  bool _phoneWasPresent = false;
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
      _phoneWasPresent = hasSavedPhone;
      _notifyWhatsappManuallySet = (client['notificar_whatsapp_manual'] as int? ?? 0) == 1;
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
      _notifyWhatsapp = hasSavedPhone
          ? (_notifyWhatsappManuallySet ? (client['notificar_whatsapp'] as int? ?? 0) == 1 : true)
          : false;
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
        notificarWhatsappManual: _notifyWhatsappManuallySet,
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
            SizedBox(width: 124, child: TextFormField(
              controller: _countryCode,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]'))],
              decoration: InputDecoration(
                labelText: 'Código',
                hintText: '+53',
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Seleccionar código de país',
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  onSelected: (value) => setState(() => _countryCode.text = value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: '+53', child: Text('+53 · Cuba')),
                    PopupMenuItem(value: '+1', child: Text('+1 · EE. UU. / Canadá')),
                    PopupMenuItem(value: '+34', child: Text('+34 · España')),
                    PopupMenuItem(value: '+52', child: Text('+52 · México')),
                    PopupMenuItem(value: '+57', child: Text('+57 · Colombia')),
                    PopupMenuItem(value: '+58', child: Text('+58 · Venezuela')),
                    PopupMenuItem(value: '+54', child: Text('+54 · Argentina')),
                    PopupMenuItem(value: '+55', child: Text('+55 · Brasil')),
                    PopupMenuItem(value: '+56', child: Text('+56 · Chile')),
                    PopupMenuItem(value: '+51', child: Text('+51 · Perú')),
                    PopupMenuItem(value: '+593', child: Text('+593 · Ecuador')),
                    PopupMenuItem(value: '+44', child: Text('+44 · Reino Unido')),
                  ],
                ),
              ),
              validator: (value) => _phone.text.trim().isNotEmpty &&
                  (value == null || !RegExp(r'^\+[0-9]{1,4}
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Número de teléfono', hintText: '5 1234567'), onChanged: (value) => setState(() {
              final hasPhone = value.trim().isNotEmpty;
              if (!hasPhone) {
                _notifyWhatsapp = false;
                _notifyWhatsappManuallySet = false;
              } else if (!_phoneWasPresent) {
                _notifyWhatsapp = true;
                _notifyWhatsappManuallySet = false;
              }
              _phoneWasPresent = hasPhone;
            }))),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _note, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Nota', alignLabelWithHint: true, hintText: 'Preferencias, alergias a productos, observaciones…')),
          const SizedBox(height: 12),
          if (_client != null) _detailLineLocal(Icons.event_available_rounded, 'Fecha de registro', formatDateLong(DateTime.parse(_client!['fecha_registro'] as String))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Clienta activa'), subtitle: const Text('Las clientas inactivas se conservan en el historial.'), value: _active, onChanged: (value) => setState(() => _active = value)),
          if (_phone.text.trim().isNotEmpty) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Notificar por WhatsApp'), subtitle: const Text('La app prepara el mensaje; el envío se confirma en WhatsApp.'), value: _notifyWhatsapp, onChanged: (value) => setState(() {
                _notifyWhatsapp = value;
                _notifyWhatsappManuallySet = true;
              })),
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
).hasMatch(value.trim()))
                  ? 'Ej. +53'
                  : null,
            )),
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
