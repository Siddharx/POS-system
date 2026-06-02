import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Get sales within a date range
  static Future<List<Map<String, dynamic>>> getSalesInRange(
      DateTime start, DateTime end) async {
    final data = await _client
        .from('sales')
        .select()
        .gte('created_at', start.toUtc().toIso8601String())
        .lte('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get all sale items with product names within a date range
  static Future<List<Map<String, dynamic>>> getSaleItemsInRange(
      DateTime start, DateTime end) async {
    // Get sale IDs in range first
    final sales = await getSalesInRange(start, end);
    if (sales.isEmpty) return [];

    final saleIds = sales.map((s) => s['id'] as String).toList();

    final data = await _client
        .from('sale_items')
        .select('*, products(name, category_id), sales(created_at, is_refunded)')
        .inFilter('sale_id', saleIds);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Daily pulse: gross, refunds, net, AOV, transaction count, items per transaction
  static Map<String, dynamic> calculateDailyPulse(
      List<Map<String, dynamic>> sales, List<Map<String, dynamic>> saleItems) {
    double grossSales = 0;
    double refundedAmount = 0;
    int transactionCount = 0;
    int refundCount = 0;

    for (final sale in sales) {
      final amount = (sale['total_amount'] as num).toDouble();
      final isRefunded = sale['is_refunded'] as bool? ?? false;

      if (isRefunded) {
        refundedAmount += amount;
        refundCount++;
      } else {
        grossSales += amount;
        transactionCount++;
      }
    }

    final netSales = grossSales;
    final aov = transactionCount > 0 ? netSales / transactionCount : 0.0;
    final refundRate = sales.isNotEmpty
        ? (refundCount / sales.length) * 100
        : 0.0;

    // Items per transaction (exclude refunded)
    int totalItems = 0;
    for (final item in saleItems) {
      final saleData = item['sales'];
      final isRefunded = saleData?['is_refunded'] as bool? ?? false;
      if (!isRefunded) {
        totalItems += item['quantity'] as int;
      }
    }
    final itemsPerTransaction =
        transactionCount > 0 ? totalItems / transactionCount : 0.0;

    return {
      'gross_sales': grossSales + refundedAmount,
      'refunded_amount': refundedAmount,
      'net_sales': netSales,
      'aov': aov,
      'transaction_count': transactionCount,
      'refund_count': refundCount,
      'refund_rate': refundRate,
      'items_per_transaction': itemsPerTransaction,
    };
  }

  /// Hourly sales breakdown
  static List<Map<String, dynamic>> calculateHourlySales(
      List<Map<String, dynamic>> sales) {
    final hourlyMap = <int, double>{};
    for (int i = 0; i < 24; i++) {
      hourlyMap[i] = 0;
    }

    for (final sale in sales) {
      final isRefunded = sale['is_refunded'] as bool? ?? false;
      if (isRefunded) continue;

      final createdAt = sale['created_at'] != null
          ? DateTime.parse(sale['created_at'] as String).toLocal()
          : null;
      if (createdAt != null) {
        final hour = createdAt.hour;
        hourlyMap[hour] =
            hourlyMap[hour]! + (sale['total_amount'] as num).toDouble();
      }
    }

    return hourlyMap.entries
        .map((e) => {'hour': e.key, 'total': e.value})
        .toList();
  }

  /// Product performance: quantity sold and revenue per product
  static List<Map<String, dynamic>> calculateProductPerformance(
      List<Map<String, dynamic>> saleItems) {
    final productMap = <String, Map<String, dynamic>>{};

    for (final item in saleItems) {
      final saleData = item['sales'];
      final isRefunded = saleData?['is_refunded'] as bool? ?? false;
      if (isRefunded) continue;

      final productId = item['product_id'] as String;
      final productData = item['products'];
      final name = productData?['name'] as String? ?? 'Unknown';
      final quantity = item['quantity'] as int;
      final subtotal = (item['subtotal'] as num).toDouble();

      if (!productMap.containsKey(productId)) {
        productMap[productId] = {
          'name': name,
          'quantity_sold': 0,
          'revenue': 0.0,
        };
      }
      productMap[productId]!['quantity_sold'] =
          (productMap[productId]!['quantity_sold'] as int) + quantity;
      productMap[productId]!['revenue'] =
          (productMap[productId]!['revenue'] as double) + subtotal;
    }

    final list = productMap.values.toList();
    list.sort((a, b) =>
        (b['quantity_sold'] as int).compareTo(a['quantity_sold'] as int));
    return list;
  }

  /// Per-item sales by hour (which items sell when)
  static Map<String, List<Map<String, dynamic>>> calculateItemSalesByHour(
      List<Map<String, dynamic>> saleItems) {
    final itemHourMap = <String, Map<int, int>>{};

    for (final item in saleItems) {
      final saleData = item['sales'];
      final isRefunded = saleData?['is_refunded'] as bool? ?? false;
      if (isRefunded) continue;

      final productData = item['products'];
      final name = productData?['name'] as String? ?? 'Unknown';
      final quantity = item['quantity'] as int;
      final createdAt = saleData?['created_at'] != null
          ? DateTime.parse(saleData['created_at'] as String).toLocal()
          : null;

      if (createdAt != null) {
        if (!itemHourMap.containsKey(name)) {
          itemHourMap[name] = {};
        }
        final hour = createdAt.hour;
        itemHourMap[name]![hour] =
            (itemHourMap[name]![hour] ?? 0) + quantity;
      }
    }

    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in itemHourMap.entries) {
      result[entry.key] = List.generate(24, (h) => {
            'hour': h,
            'quantity': entry.value[h] ?? 0,
          });
    }
    return result;
  }

  /// Payment method split
  static Map<String, dynamic> calculatePaymentSplit(
      List<Map<String, dynamic>> sales) {
    double cashTotal = 0;
    double cardTotal = 0;
    int cashCount = 0;
    int cardCount = 0;

    for (final sale in sales) {
      final isRefunded = sale['is_refunded'] as bool? ?? false;
      if (isRefunded) continue;

      final amount = (sale['total_amount'] as num).toDouble();
      final method = sale['payment_method'] as String? ?? 'cash';

      if (method == 'cash') {
        cashTotal += amount;
        cashCount++;
      } else {
        cardTotal += amount;
        cardCount++;
      }
    }

    final total = cashTotal + cardTotal;
    return {
      'cash_total': cashTotal,
      'card_total': cardTotal,
      'cash_count': cashCount,
      'card_count': cardCount,
      'cash_percent': total > 0 ? (cashTotal / total) * 100 : 0.0,
      'card_percent': total > 0 ? (cardTotal / total) * 100 : 0.0,
    };
  }

  /// Category breakdown
  static Future<List<Map<String, dynamic>>> calculateCategoryBreakdown(
      List<Map<String, dynamic>> saleItems) async {
    // Get categories
    final categories = await _client
        .from('categories')
        .select();

    final catMap = <String, String>{};
    for (final cat in categories) {
      catMap[cat['id'] as String] = cat['name'] as String;
    }

    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final item in saleItems) {
      final saleData = item['sales'];
      final isRefunded = saleData?['is_refunded'] as bool? ?? false;
      if (isRefunded) continue;

      final productData = item['products'];
      final categoryId = productData?['category_id'] as String?;
      final categoryName = categoryId != null
          ? (catMap[categoryId] ?? 'Uncategorized')
          : 'Uncategorized';
      final subtotal = (item['subtotal'] as num).toDouble();
      final quantity = item['quantity'] as int;

      categoryTotals[categoryName] =
          (categoryTotals[categoryName] ?? 0) + subtotal;
      categoryCounts[categoryName] =
          (categoryCounts[categoryName] ?? 0) + quantity;
    }

    final totalRevenue =
        categoryTotals.values.fold<double>(0, (a, b) => a + b);

    return categoryTotals.entries.map((e) {
      return {
        'name': e.key,
        'revenue': e.value,
        'quantity': categoryCounts[e.key] ?? 0,
        'percent': totalRevenue > 0 ? (e.value / totalRevenue) * 100 : 0.0,
      };
    }).toList()
      ..sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));
  }

  /// Get date range for a period
  static (DateTime, DateTime) getDateRange(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'today':
        return (today, now);
      case 'week':
        final weekAgo = today.subtract(const Duration(days: 7));
        return (weekAgo, now);
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return (monthAgo, now);
      case 'quarter':
        final quarterAgo = DateTime(now.year, now.month - 3, now.day);
        return (quarterAgo, now);
      case 'year':
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        return (yearAgo, now);
      default:
        return (today, now);
    }
  }
}
