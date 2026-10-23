import 'package:intl/intl.dart';

String formatDateLong(DateTime date) => DateFormat("d 'de' MMMM 'de' y", 'es').format(date);
String formatDateCompact(DateTime date) => DateFormat('dd/MM/yyyy', 'es').format(date);
String formatDateWithWeekday(DateTime date) => DateFormat("EEEE, d 'de' MMMM", 'es').format(date);
String formatTime(DateTime date) => DateFormat('HH:mm', 'es').format(date);
String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String relativeAppointmentDate(DateTime appointment, DateTime messageDate) {
  final a = DateTime(appointment.year, appointment.month, appointment.day);
  final m = DateTime(messageDate.year, messageDate.month, messageDate.day);
  if (a.difference(m).inDays == 1) return 'mañana';
  if (appointment.year != messageDate.year) return formatDateLong(appointment);
  return DateFormat("d 'de' MMMM", 'es').format(appointment);
}
