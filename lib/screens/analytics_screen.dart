import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../utils/format.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'today';
  bool _isLoading = true;

  Map<String, dynamic> _pulse = {};
  List<Map<String, dynamic>> _hourlySales = [];
  List<Map<String, dynamic>> _productPerformance = [];
  Map<String, List<Map<String, dynamic>>> _itemSalesByHour = {};
  Map<String, dynamic> _paymentSplit = {};
  List<Map<String, dynamic>> _categoryBreakdown = [];
  String? _selectedItem; // For per-item hourly chart

  final _periods = {
    'today': 'Today',
    'week': 'This Week',
    'month': 'This Month',
    'quarter': 'This Quarter',
    'year': 'This Year',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final (start, end) = AnalyticsService.getDateRange(_selectedPeriod);
      final sales = await AnalyticsService.getSalesInRange(start, end);
      final saleItems = await AnalyticsService.getSaleItemsInRange(start, end);

      final pulse = AnalyticsService.calculateDailyPulse(sales, saleItems);
      final hourly = AnalyticsService.calculateHourlySales(sales);
      final products = AnalyticsService.calculateProductPerformance(saleItems);
      final itemsByHour = AnalyticsService.calculateItemSalesByHour(saleItems);
      final payment = AnalyticsService.calculatePaymentSplit(sales);
      final categories =
          await AnalyticsService.calculateCategoryBreakdown(saleItems);

      setState(() {
        _pulse = pulse;
        _hourlySales = hourly;
        _productPerformance = products;
        _itemSalesByHour = itemsByHour;
        _paymentSplit = payment;
        _categoryBreakdown = categories;
        _selectedItem =
            itemsByHour.isNotEmpty ? itemsByHour.keys.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading analytics: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period filter
                  _buildPeriodFilter(),
                  const SizedBox(height: 16),

                  // 1. Daily Pulse
                  _buildDailyPulse(),
                  const SizedBox(height: 20),

                  // 2. Hourly Sales Chart
                  _buildSectionTitle('Sales by Hour'),
                  const SizedBox(height: 8),
                  _buildHourlySalesChart(),
                  const SizedBox(height: 20),

                  // 3. Top 5 & Bottom 5
                  _buildSectionTitle('Top 5 Sellers'),
                  const SizedBox(height: 8),
                  _buildProductList(_productPerformance.take(5).toList(), true),
                  const SizedBox(height: 16),
                  if (_productPerformance.length > 5) ...[
                    _buildSectionTitle('Bottom 5 (Kill List)'),
                    const SizedBox(height: 8),
                    _buildProductList(
                        _productPerformance.reversed.take(5).toList().reversed.toList(),
                        false),
                    const SizedBox(height: 20),
                  ],

                  // 4. Per-Item Sales by Hour
                  _buildSectionTitle('Item Sales by Hour'),
                  const SizedBox(height: 8),
                  _buildItemSelector(),
                  const SizedBox(height: 8),
                  _buildItemHourlyChart(),
                  const SizedBox(height: 20),

                  // 5. Refund Rate
                  _buildSectionTitle('Refund Rate'),
                  const SizedBox(height: 8),
                  _buildRefundRate(),
                  const SizedBox(height: 20),

                  // 6. Payment Split
                  _buildSectionTitle('Payment Split'),
                  const SizedBox(height: 8),
                  _buildPaymentSplit(),
                  const SizedBox(height: 20),

                  // 7. Category Breakdown
                  _buildSectionTitle('Category Breakdown'),
                  const SizedBox(height: 8),
                  _buildCategoryBreakdown(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _periods.entries.map((e) {
          final isSelected = _selectedPeriod == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedPeriod = e.key);
                _loadData();
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDailyPulse() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Pulse',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildPulseCard('Gross Sales',
                    formatPrice(_pulse['gross_sales'] ?? 0), Colors.blue),
                const SizedBox(width: 8),
                _buildPulseCard('Refunds',
                    formatPrice(_pulse['refunded_amount'] ?? 0), Colors.red),
                const SizedBox(width: 8),
                _buildPulseCard('Net Sales',
                    formatPrice(_pulse['net_sales'] ?? 0), Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPulseCard(
                    'AOV',
                    formatPrice(_pulse['aov'] ?? 0),
                    Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                _buildPulseCard(
                    'Transactions',
                    '${_pulse['transaction_count'] ?? 0}',
                    Colors.orange),
                const SizedBox(width: 8),
                _buildPulseCard(
                    'Items/Order',
                    (_pulse['items_per_transaction'] as double?)
                            ?.toStringAsFixed(1) ??
                        '0',
                    Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlySalesChart() {
    final maxY = _hourlySales
        .map((e) => (e['total'] as double))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY * 1.2 : 100,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final hour = group.x;
                    final label = hour < 12
                        ? '${hour == 0 ? 12 : hour}AM'
                        : '${hour == 12 ? 12 : hour - 12}PM';
                    return BarTooltipItem(
                      '$label\n${formatPrice(rod.toY)}',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour % 3 != 0) return const SizedBox.shrink();
                      final label = hour < 12
                          ? '${hour == 0 ? 12 : hour}a'
                          : '${hour == 12 ? 12 : hour - 12}p';
                      return Text(label,
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: _hourlySales.map((e) {
                final hour = e['hour'] as int;
                final total = e['total'] as double;
                return BarChartGroupData(
                  x: hour,
                  barRods: [
                    BarChartRodData(
                      toY: total,
                      color: Theme.of(context).colorScheme.primary,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(
      List<Map<String, dynamic>> products, bool isTop) {
    if (products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data yet'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: products.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            final name = product['name'] as String;
            final qty = product['quantity_sold'] as int;
            final revenue = product['revenue'] as double;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isTop
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isTop ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text('$qty sold',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Text(formatPrice(revenue),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItemSelector() {
    if (_itemSalesByHour.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _itemSalesByHour.keys.map((name) {
          final isSelected = _selectedItem == name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(name, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedItem = name),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemHourlyChart() {
    if (_selectedItem == null || !_itemSalesByHour.containsKey(_selectedItem)) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data yet'),
        ),
      );
    }

    final data = _itemSalesByHour[_selectedItem]!;
    final maxY = data
        .map((e) => (e['quantity'] as int).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_selectedItem — Sales by Hour',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY > 0 ? maxY * 1.2 : 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final hour = group.x;
                        final label = hour < 12
                            ? '${hour == 0 ? 12 : hour}AM'
                            : '${hour == 12 ? 12 : hour - 12}PM';
                        return BarTooltipItem(
                          '$label\n${rod.toY.toInt()} sold',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 3 != 0) return const SizedBox.shrink();
                          final label = hour < 12
                              ? '${hour == 0 ? 12 : hour}a'
                              : '${hour == 12 ? 12 : hour - 12}p';
                          return Text(label,
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: data.map((e) {
                    final hour = e['hour'] as int;
                    final qty = (e['quantity'] as int).toDouble();
                    return BarChartGroupData(
                      x: hour,
                      barRods: [
                        BarChartRodData(
                          toY: qty,
                          color: Colors.orange,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundRate() {
    final rate = (_pulse['refund_rate'] as double?) ?? 0;
    final count = (_pulse['refund_count'] as int?) ?? 0;
    final amount = (_pulse['refunded_amount'] as double?) ?? 0;
    final isHigh = rate > 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isHigh ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isHigh ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHigh ? 'High Refund Rate ⚠️' : 'Refund Rate Normal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isHigh ? Colors.red : Colors.green,
                    ),
                  ),
                  Text('$count refunds — ${formatPrice(amount)} total',
                      style: TextStyle(color: Colors.grey.shade600)),
                  if (isHigh)
                    const Text('Above 2% — investigate possible issues',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSplit() {
    final cashPercent = (_paymentSplit['cash_percent'] as double?) ?? 0;
    final cardPercent = (_paymentSplit['card_percent'] as double?) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (cashPercent > 0)
                      Expanded(
                        flex: cashPercent.round(),
                        child: Container(color: Colors.green),
                      ),
                    if (cardPercent > 0)
                      Expanded(
                        flex: cardPercent.round(),
                        child: Container(color: Colors.blue),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 12, height: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('Cash'),
                      ],
                    ),
                    Text(
                      '${cashPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(formatPrice(_paymentSplit['cash_total'] ?? 0),
                        style: TextStyle(color: Colors.grey.shade600)),
                    Text('${_paymentSplit['cash_count'] ?? 0} orders',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 12, height: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text('Card'),
                      ],
                    ),
                    Text(
                      '${cardPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(formatPrice(_paymentSplit['card_total'] ?? 0),
                        style: TextStyle(color: Colors.grey.shade600)),
                    Text('${_paymentSplit['card_count'] ?? 0} orders',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryBreakdown.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data yet'),
        ),
      );
    }

    final colors = [Colors.teal, Colors.orange, Colors.purple, Colors.pink,
        Colors.indigo, Colors.amber];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _categoryBreakdown.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final color = colors[index % colors.length];
            final percent = (cat['percent'] as double);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          )),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Text('${cat['quantity']} items',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(width: 12),
                      Text(formatPrice(cat['revenue'] as double),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 45,
                        child: Text('${percent.toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
