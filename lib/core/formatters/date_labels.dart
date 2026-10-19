/// Spanish, dependency-free date labels for feeds and lists.
///
/// The project does not depend on `intl` (see `pubspec.yaml`), so the labels
/// used by the history feed are built here and kept in one place. [now] is
/// injectable so the relative labels stay deterministic in tests.
class DateLabels {
  const DateLabels._();

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// `Hoy` / `Ayer` / `Mañana` / `22 sep`, appending the year when the value
  /// does not belong to [now]'s year.
  static String relativeDay(DateTime value, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toLocal();
    final date = value.toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final target = DateTime(date.year, date.month, date.day);
    switch (today.difference(target).inDays) {
      case 0:
        return 'Hoy';
      case 1:
        return 'Ayer';
      case -1:
        return 'Mañana';
    }
    final label = '${date.day} ${_months[date.month - 1]}';
    return date.year == today.year ? label : '$label ${date.year}';
  }

  static const List<String> _monthsLong = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// `septiembre` for the month that contains [value] (local time).
  static String monthName(DateTime value) =>
      _monthsLong[value.toLocal().month - 1];

  /// `12:03` on a 24-hour clock, in the device's local time.
  static String time(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Full Colombian Spanish calendar date without converting the date-only
  /// value through a timezone (which can move API dates to the prior day).
  static String calendarDate(DateTime value) {
    final month = _monthsLong[value.month - 1];
    return '${value.day} de $month de ${value.year}';
  }
}
