import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../models/cart_item.dart';
import '../utils/format.dart';

class ReceiptScreen extends StatelessWidget {
  final Sale sale;
  final List<CartItem> cartItems;
  final double? amountPaid;
  final double? changeDue;

  const ReceiptScreen({
    super.key,
    required this.sale,
    required this.cartItems,
    this.amountPaid,
    this.changeDue,
  });

  String _buildReceiptText() {
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('         POS RECEIPT');
    if (sale.orderNumber != null) {
      buffer.writeln('        Order #${sale.orderNumber}');
    }
    buffer.writeln('================================');
    buffer.writeln('Date: ${sale.createdAt?.toLocal().toString().substring(0, 19) ?? 'N/A'}');
    buffer.writeln('Payment: ${sale.paymentMethod.toUpperCase()}');
    buffer.writeln('--------------------------------');

    for (final item in cartItems) {
      buffer.writeln(item.product.name);
      buffer.writeln('  ${item.quantity} x ${formatPrice(item.product.price)}    ${formatPrice(item.subtotal)}');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL:                ${formatPrice(sale.totalAmount)}');

    if (amountPaid != null) {
      buffer.writeln('PAID:                 ${formatPrice(amountPaid!)}');
      buffer.writeln('CHANGE:               ${formatPrice(changeDue!)}');
    }

    buffer.writeln('================================');
    buffer.writeln('       Thank you!');
    buffer.writeln('================================');

    return buffer.toString();
  }

  void _shareReceipt() {
    SharePlus.instance.share(ShareParams(text: _buildReceiptText()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Success icon
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                sale.orderNumber != null
                    ? 'Order #${sale.orderNumber} Complete!'
                    : 'Sale Complete!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Receipt card
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'POS RECEIPT',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (sale.orderNumber != null)
                              Text(
                                'Order #${sale.orderNumber}',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),

                      // Date & payment
                      Text(
                        'Date: ${sale.createdAt?.toLocal().toString().substring(0, 19) ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        'Payment: ${sale.paymentMethod.toUpperCase()}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Divider(height: 24),

                      // Items
                      ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${item.quantity} x ${formatPrice(item.product.price)}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatPrice(item.subtotal),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )),
                      const Divider(height: 24),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatPrice(sale.totalAmount),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      // Paid & Change (cash only)
                      if (amountPaid != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PAID',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatPrice(amountPaid!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CHANGE',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatPrice(changeDue!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Thank you!',
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareReceipt,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Receipt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
