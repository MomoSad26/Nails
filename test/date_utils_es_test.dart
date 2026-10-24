import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:manigest/utils/date_utils_es.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('formatDateLongWithWeekday', () {
    test('includes weekday and full date in Spanish', () {
      expect(formatDateLongWithWeekday(DateTime(2026, 10, 17)), 'sábado, 17 de octubre de 2026');
    });
  });

  group('formatTime', () {
    test('uses 12-hour time with explicit AM/PM', () {
      expect(formatTime(DateTime(2026, 10, 23, 0, 5)), '12:05 AM');
      expect(formatTime(DateTime(2026, 10, 23, 9, 7)), '9:07 AM');
      expect(formatTime(DateTime(2026, 10, 23, 12, 0)), '12:00 PM');
      expect(formatTime(DateTime(2026, 10, 23, 15, 45)), '3:45 PM');
    });
  });

  group('relativeAppointmentDate', () {
    test('uses mañana only when the appointment is the next calendar day', () {
      expect(
        relativeAppointmentDate(DateTime(2026, 10, 23, 9), DateTime(2026, 10, 22, 20)),
        'mañana',
      );
    });

    test('uses a full day and month for same-day appointments', () {
      expect(
        relativeAppointmentDate(DateTime(2026, 10, 22, 9), DateTime(2026, 10, 22, 8)),
        '22 de octubre',
      );
    });

    test('includes the year when it differs from the message year', () {
      expect(
        relativeAppointmentDate(DateTime(2027, 1, 4, 9), DateTime(2026, 12, 31, 8)),
        '4 de enero de 2027',
      );
    });
  });
}
