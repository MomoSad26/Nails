import 'package:flutter/material.dart';

class NavigationSidebar extends StatelessWidget {
  const NavigationSidebar({
    super.key,
    required this.activeSection,
    required this.accentColor,
    required this.onSelected,
  });

  final String? activeSection;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  static const sections = <(String, IconData)>[
    ('Inicio', Icons.home_rounded),
    ('Agenda', Icons.calendar_month_rounded),
    ('Citas', Icons.event_note_rounded),
    ('Clientes', Icons.people_alt_rounded),
    ('Catálogo', Icons.spa_rounded),
    ('Ajustes', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Colors.pink.shade50)),
        ),
        child: Column(children: [
          const SizedBox(height: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.spa_rounded, color: accentColor),
          ),
          const SizedBox(height: 20),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = sections[index];
              final active = activeSection == item.$1;
              return Tooltip(
                message: item.$1,
                child: InkWell(
                  onTap: () => onSelected(item.$1),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 48,
                    width: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: active ? accentColor.withValues(alpha: 0.16) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.$2,
                      color: activeColor(active),
                      size: 23,
                    ),
                  ),
                ),
              );
            },
          )),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'v1.1',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ]),
      );

  Color activeColor(bool active) => active ? accentColor : Colors.grey.shade600;
}
