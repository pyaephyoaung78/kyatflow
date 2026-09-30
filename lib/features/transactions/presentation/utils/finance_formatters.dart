const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatMoney(double value, {String currencyCode = 'MMK'}) {
  final negative = value < 0;
  final absolute = value.abs();
  final fixed = absolute.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final fraction = parts[1] == '00' ? '' : '.${parts[1]}';
  return '$currencyCode ${negative ? '-' : ''}$grouped$fraction';
}

String formatMonth(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

String formatLedgerDate(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

String formatTransactionTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

String formatShortDate(DateTime date) {
  final month = _monthNames[date.month - 1].substring(0, 3);
  return '$month ${date.day}';
}
