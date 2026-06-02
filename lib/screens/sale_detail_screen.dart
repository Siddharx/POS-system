import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../services/supabase_service.dart';
import '../utils/format.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  final bool isAdmin;

  const SaleDetailScreen({super.key, required this.sale, this.isAdmin = false});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isRefunded = false;
  bool _isRefunding = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await SupabaseService.getSaleItemsWithNames(widget.sale.id);
      setState(() {
        _items = items;
        _isRefunded = widget.sale.isRefunded;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _buildReceiptText() {
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('         POS RECEIPT');
    buffer.writeln('================================');
    buffer.writeln('Date: ${widget.sale.createdAt?.toLocal().toString().substring(0, 19) ?? 'N/A'}');
    buffer.writeln('Payment: ${widget.sale.paymentMethod.toUpperCase()}');
    if (widget.sale.isAdmin) buffer.writeln('Sold by: ADMIN');
    buffer.writeln('--------------------------------');

    for (final item in _items) {
      final name = item['products']?['name'] ?? 'Unknown';
      final quantity = item['quantity'] as int;
      final unitPrice = (item['unit_price'] as num).toDouble();
      final subtotal = (item['subtotal'] as num).toDouble();
      buffer.writeln(name);
      buffer.writeln('  $quantity x ${formatPrice(unitPrice)}    ${formatPrice(subtotal)}');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL:                ${formatPrice(widget.sale.totalAmount)}');
    buffer.writeln('================================');
    buffer.writeln('       Thank you!');
    buffer.writeln('================================');

    return buffer.toString();
  }

  void _shareReceipt() {
    SharePlus.instance.share(ShareParams(text: _buildReceiptText()));
  }

  Future<void> _refundSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Sale'),
        content: Text(
          'Are you sure you want to refund ${formatPrice(widget.sale.totalAmount)}?\n\n'
          'This will restore the stock for all items in this sale.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRefunding = true);
      try {
        await SupabaseService.refundSale(widget.sale.id);
        setState(() {
          _isRefunded = true;
          _isRefunding = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale refunded. Stock has been restored.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        setState(() => _isRefunding = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error refunding: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Receipt'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _items.isNotEmpty ? _shareReceipt : null,
            tooltip: 'Share receipt',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
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
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            if (widget.sale.orderNumber != null)
                              Text(
                                'Order #${widget.sale.orderNumber}',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                            if (_isRefunded)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'REFUNDED',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),

                      // Date & payment
                      Text(
                        'Date: ${widget.sale.createdAt?.toLocal().toString().substring(0, 19) ?? 'N/A'}',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment: ${widget.sale.paymentMethod.toUpperCase()}',
                                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                                ),
                                if (widget.sale.paymentMethod == 'split')
                                  Text(
                                    'Cash: ${formatPrice(widget.sale.cashAmount)} / Card: ${formatPrice(widget.sale.cardAmount)}',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.sale.isAdmin) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 24),

                      // Items
                      ...List.generate(_items.length, (index) {
                        final item = _items[index];
                        final name = item['products']?['name'] ?? 'Unknown';
                        final quantity = item['quantity'] as int;
                        final unitPrice = (item['unit_price'] as num).toDouble();
                        final subtotal = (item['subtotal'] as num).toDouble();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$quantity x ${formatPrice(unitPrice)}',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatPrice(subtotal),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatPrice(widget.sale.totalAmount),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                  // Refund button (admin only, not already refunded)
                  if (widget.isAdmin && !_isRefunded) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isRefunding ? null : _refundSale,
                        icon: _isRefunding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.undo),
                        label: Text(
                          _isRefunding ? 'Processing...' : 'Refund This Sale',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
