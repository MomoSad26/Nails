import 'package:flutter/material.dart';

/// Small, self-contained presentation widget for an record state.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    required this.accentColor,
  });

  final String status;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
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
      _ => accentColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
