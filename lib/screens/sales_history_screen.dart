import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../services/supabase_service.dart';
import '../utils/format.dart';
import 'sale_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  Map<String, int> _productSoldCounts = {};
  Map<String, String> _productNames = {};
  bool _isLoading = true;
  String _searchQuery = '';
  double _dailyTotal = 0;
  double _weeklyTotal = 0;
  double _allTimeTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await SupabaseService.getSales();
      final allItems = await SupabaseService.getAllSaleItems();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));

      double daily = 0;
      double weekly = 0;
      double allTime = 0;

      for (final s in sales) {
        if (s.isRefunded) continue; // Skip refunded sales from totals
        allTime += s.totalAmount;
        if (s.createdAt != null) {
          if (s.createdAt!.isAfter(today)) {
            daily += s.totalAmount;
          }
          if (s.createdAt!.isAfter(weekAgo)) {
            weekly += s.totalAmount;
          }
        }
      }

      // Count products sold
      final Map<String, int> counts = {};
      final Map<String, String> names = {};
      for (final item in allItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        final productData = item['products'];
        final productName = productData != null ? productData['name'] as String? ?? 'Unknown' : 'Unknown';

        counts[productId] = (counts[productId] ?? 0) + quantity;
        names[productId] = productName;
      }

      setState(() {
        _sales = sales;
        _filteredSales = sales;
        _dailyTotal = daily;
        _weeklyTotal = weekly;
        _allTimeTotal = allTime;
        _productSoldCounts = counts;
        _productNames = names;
        _searchQuery = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterSales(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSales = _sales;
      } else {
        _filteredSales = _sales.where((sale) {
          final orderMatch = sale.orderNumber != null &&
              '#${sale.orderNumber}'.contains(query);
          final amountMatch =
              sale.totalAmount.toStringAsFixed(2).contains(query);
          final methodMatch =
              sale.paymentMethod.toLowerCase().contains(query.toLowerCase());
          final dateMatch = sale.createdAt
                  ?.toLocal()
                  .toString()
                  .contains(query) ??
              false;
          return orderMatch || amountMatch || methodMatch || dateMatch;
        }).toList();
      }
    });
  }

  void _showSaleDetails(Sale sale) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaleDetailScreen(sale: sale, isAdmin: true),
      ),
    );
    // Refresh after returning (in case a refund was made)
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // Sort product counts descending
    final sortedProducts = _productSoldCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Totals banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        _TotalCard(label: "Today", amount: _dailyTotal),
                        const SizedBox(width: 12),
                        _TotalCard(label: "This Week", amount: _weeklyTotal),
                        const SizedBox(width: 12),
                        _TotalCard(label: "All Time", amount: _allTimeTotal),
                      ],
                    ),
                  ),

                  // Products sold count
                  if (sortedProducts.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        'Products Sold',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: sortedProducts.length,
                        itemBuilder: (context, index) {
                          final entry = sortedProducts[index];
                          final name = _productNames[entry.key] ?? 'Unknown';
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${entry.value} sold',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: TextField(
                      onChanged: _filterSales,
                      decoration: InputDecoration(
                        hintText: 'Search by order #, amount, date, or method...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),

                  // Sales list
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'All Sales'
                          : '${_filteredSales.length} results',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (_filteredSales.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No sales yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredSales.length,
                      itemBuilder: (context, index) {
                        final sale = _filteredSales[index];
                        final dateStr = sale.createdAt
                                ?.toLocal()
                                .toString()
                                .substring(0, 16) ??
                            'N/A';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            onTap: () => _showSaleDetails(sale),
                            leading: CircleAvatar(
                              backgroundColor: sale.isRefunded
                                  ? Colors.red.shade100
                                  : sale.paymentMethod == 'cash'
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100,
                              child: sale.isRefunded
                                  ? Icon(Icons.undo, color: Colors.red.shade700)
                                  : Icon(
                                      sale.paymentMethod == 'cash'
                                          ? Icons.money
                                          : Icons.credit_card,
                                      color: sale.paymentMethod == 'cash'
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                            ),
                            title: Row(
                              children: [
                                if (sale.orderNumber != null) ...[
                                  Text(
                                    '#${sale.orderNumber}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  formatPrice(sale.totalAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    decoration: sale.isRefunded ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (sale.isRefunded) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'REFUNDED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                                if (sale.isAdmin) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(dateStr),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sale.paymentMethod == 'split'
                                        ? Colors.orange.shade50
                                        : sale.paymentMethod == 'cash'
                                            ? Colors.green.shade50
                                            : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sale.paymentMethod.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: sale.paymentMethod == 'split'
                                          ? Colors.orange
                                          : sale.paymentMethod == 'cash'
                                              ? Colors.green
                                              : Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalCard({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              formatPrice(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
