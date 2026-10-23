import 'package:flutter/material.dart';

import '../../services/whatsapp_service.dart';

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
    Text(widget.phone == null ? 'Elige el contacto o grupo dentro de WhatsApp.' : 'Destinatario: ${widget.phone}', style: TextStyle(color: const Color(0xFFC0D0E0))),
    const SizedBox(height: 12),
    Expanded(child: TextField(controller: _message, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'Mensaje editable', alignLabelWithHint: true, hintText: 'Edita el texto antes de abrir WhatsApp.'))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _opening ? null : _send, icon: _opening ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_opening ? 'Abriendo WhatsApp…' : 'Abrir WhatsApp'))),
    const SizedBox(height: 8),
    Text('La app no puede confirmar si el mensaje se envió o fue leído.', style: TextStyle(fontSize: 11, color: const Color(0xFFA9BED2))),
  ]);
}
