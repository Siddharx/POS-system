import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/supabase_service.dart';
import '../services/sound_service.dart';
import '../utils/format.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double total;
  final bool isAdmin;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.total,
    this.isAdmin = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'cash'; // 'cash', 'card', 'split'
  final _amountController = TextEditingController();
  final _splitCashController = TextEditingController();
  final _splitCardController = TextEditingController();
  bool _isProcessing = false;

  double get _amountReceived {
    return double.tryParse(_amountController.text) ?? 0;
  }

  double get _changeDue {
    return _amountReceived - widget.total;
  }

  double get _splitCash {
    return double.tryParse(_splitCashController.text) ?? 0;
  }

  double get _splitCard {
    return double.tryParse(_splitCardController.text) ?? 0;
  }

  double get _splitTotal {
    return _splitCash + _splitCard;
  }

  double get _splitRemaining {
    return widget.total - _splitTotal;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _splitCashController.dispose();
    _splitCardController.dispose();
    super.dispose();
  }

  Future<void> _confirmSale() async {
    // Validate
    if (_paymentMethod == 'cash' && _amountReceived < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount received is less than the total'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_paymentMethod == 'split') {
      if (_splitTotal < widget.total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Split total (${formatPrice(_splitTotal)}) is less than order total (${formatPrice(widget.total)})'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final cartData = widget.cartItems.map((item) => {
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': item.product.price,
          }).toList();

      double cashAmt = 0;
      double cardAmt = 0;
      String method = _paymentMethod;

      if (_paymentMethod == 'cash') {
        cashAmt = widget.total;
      } else if (_paymentMethod == 'card') {
        cardAmt = widget.total;
      } else {
        // split
        cashAmt = _splitCash;
        cardAmt = _splitCard;
      }

      final sale = await SupabaseService.createSale(
        cartItems: cartData,
        totalAmount: widget.total,
        paymentMethod: method,
        isAdmin: widget.isAdmin,
        cashAmount: cashAmt,
        cardAmount: cardAmt,
      );

      if (mounted) {
        SoundService.playSaleComplete();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(
              sale: sale,
              cartItems: widget.cartItems,
              amountPaid:
                  _paymentMethod == 'cash' ? _amountReceived : null,
              changeDue:
                  _paymentMethod == 'cash' ? _changeDue : null,
            ),
          ),
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing sale: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...widget.cartItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                    '${item.product.name} x${item.quantity}',
                                    style: const TextStyle(fontSize: 15)),
                              ),
                              Text(formatPrice(item.subtotal),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Text(formatPrice(widget.total),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Method',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMethodButton('cash', Icons.money, 'Cash'),
                        const SizedBox(width: 10),
                        _buildMethodButton(
                            'card', Icons.credit_card, 'Card'),
                        const SizedBox(width: 10),
                        _buildMethodButton(
                            'split', Icons.call_split, 'Split'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cash Calculator
            if (_paymentMethod == 'cash')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cash Payment',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount Received',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _changeDue >= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _changeDue >= 0
                                  ? 'Change Due'
                                  : 'Amount Short',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _changeDue >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text(
                              formatPrice(_changeDue.abs()),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _changeDue >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Split Payment
            if (_paymentMethod == 'split')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Split Payment',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _splitCashController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Cash Amount',
                          prefixIcon: const Icon(Icons.money),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _splitCardController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Card Amount',
                          prefixIcon: const Icon(Icons.credit_card),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _splitRemaining <= 0
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Order Total',
                                    style: TextStyle(fontSize: 15)),
                                Text(formatPrice(widget.total),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cash + Card',
                                    style: TextStyle(fontSize: 15)),
                                Text(formatPrice(_splitTotal),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _splitRemaining <= 0
                                      ? 'Fully Covered'
                                      : 'Remaining',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _splitRemaining <= 0
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                Text(
                                  _splitRemaining <= 0
                                      ? '✓'
                                      : formatPrice(_splitRemaining),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _splitRemaining <= 0
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Confirm Sale Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmSale,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Confirm Sale',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodButton(String method, IconData icon, String label) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 28,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
