import 'package:intl/intl.dart';
import '../core/i18n/i18n.dart';

NumberFormat get _net => NumberFormat('0.##', localeTag);
DateFormat get _shortDate => DateFormat('d MMM', localeTag);
DateFormat get _longDate => DateFormat('d MMMM yyyy', localeTag);

/// 85.25 → "85,25"
String formatNet(double value) => _net.format(value);

/// 3.5 → "+3,5", -2 → "−2"
String formatChange(double value) =>
    value >= 0 ? '+${_net.format(value)}' : '−${_net.format(value.abs())}';

String formatShortDate(DateTime d) => _shortDate.format(d);
String formatLongDate(DateTime d) => _longDate.format(d);
