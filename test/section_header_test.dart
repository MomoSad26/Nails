import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manigest/core/widgets/section_header.dart';

void main() {
  testWidgets('muestra título, subtítulo y acción opcional', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            'Agenda',
            subtitle: 'Consulta las citas por día',
            trailing: Text('Acción'),
          ),
        ),
      ),
    );

    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Consulta las citas por día'), findsOneWidget);
    expect(find.text('Acción'), findsOneWidget);
  });

  testWidgets('coloca la acción debajo del título en espacios estrechos', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            'Catálogo',
            subtitle: 'Servicios',
            trailing: Text('Añadir'),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(find.text('Catálogo'));
    final actionRect = tester.getRect(find.text('Añadir'));
    expect(actionRect.top, greaterThan(titleRect.bottom));
  });
}
