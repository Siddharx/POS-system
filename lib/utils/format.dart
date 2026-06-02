import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat('#,##0.00');

String formatPrice(double price) {
  return '\$${_currencyFormat.format(price)}';
}
