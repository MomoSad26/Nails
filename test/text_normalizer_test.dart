import 'package:flutter_test/flutter_test.dart';
import 'package:manigest/utils/text_normalizer.dart';

void main() {
  group('normalizeSearch', () {
    test('ignora mayúsculas, tildes y espacios repetidos', () {
      expect(normalizeSearch('  SOFÍA   Pérez '), 'sofia perez');
      expect(normalizeSearch('Sofia Perez'), 'sofia perez');
    });

    test('normaliza caracteres frecuentes en español', () {
      expect(normalizeSearch('Muñoz Çelik'), 'munoz celik');
    });

    test('no cambia números ni texto sin acentos', () {
      expect(normalizeSearch('  Ana 123 '), 'ana 123');
    });
  });
}
