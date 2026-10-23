import 'package:flutter/material.dart';

import '../../data/app_database.dart';

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
