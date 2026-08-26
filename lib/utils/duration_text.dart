/// Formats a whole number of days for display.
///
/// Dart has no built-in pluralisation and the app renders day counts in four
/// separate places — the forecast headline, the alert threshold slider and its
/// description, the notification body, and the scoring reason — every one of
/// which read "1 days" before this existed.
String dayCount(int days) => days == 1 ? '1 day' : '$days days';
