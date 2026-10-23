import 'package:flutter/material.dart';

import '../../data/app_database.dart';

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
