import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // --- Categories ---

  static Future<List<Category>> getCategories() async {
    final data = await _client
        .from('categories')
        .select()
        .order('name');
    return data.map((json) => Category.fromJson(json)).toList();
  }

  static Future<Category> addCategory(String name) async {
    final data = await _client
        .from('categories')
        .insert({'name': name})
        .select()
        .single();
    return Category.fromJson(data);
  }

  // --- Products ---

  static Future<List<Product>> getProducts({String? categoryId}) async {
    var query = _client
        .from('products')
        .select()
        .eq('is_active', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query.order('name', ascending: true);
    return data.map((json) => Product.fromJson(json)).toList();
  }

  static Future<Product> addProduct(Product product) async {
    final data = await _client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();
    return Product.fromJson(data);
  }

  static Future<Product> updateProduct(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('products')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Product.fromJson(data);
  }

  static Future<void> deleteProduct(String id) async {
    await _client
        .from('products')
        .update({'is_active': false})
        .eq('id', id);
  }

  // --- Sales (checkout) ---

  // Get the next order number (resets daily, starts at 101)
  static Future<int> _getNextOrderNumber() async {
    final now = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day).toIso8601String();

    final data = await _client
        .from('sales')
        .select('order_number')
        .gte('created_at', todayStart)
        .order('order_number', ascending: false)
        .limit(1);

    if (data.isEmpty || data[0]['order_number'] == null) {
      return 101;
    }
    return (data[0]['order_number'] as int) + 1;
  }

  static Future<Sale> createSale({
    required List<Map<String, dynamic>> cartItems,
    required double totalAmount,
    String paymentMethod = 'cash',
    bool isAdmin = false,
    double cashAmount = 0,
    double cardAmount = 0,
  }) async {
    // Get next order number
    final orderNumber = await _getNextOrderNumber();

    // Insert the sale record
    final saleData = await _client
        .from('sales')
        .insert({
          'total_amount': totalAmount,
          'payment_method': paymentMethod,
          'is_admin': isAdmin,
          'order_number': orderNumber,
          'cash_amount': cashAmount,
          'card_amount': cardAmount,
        })
        .select()
        .single();

    final sale = Sale.fromJson(saleData);

    // Insert sale items and decrement stock
    for (final item in cartItems) {
      await _client.from('sale_items').insert({
        'sale_id': sale.id,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'subtotal': (item['quantity'] as int) * (item['unit_price'] as double),
      });

      // Decrement stock
      final product = await _client
          .from('products')
          .select('stock_quantity')
          .eq('id', item['product_id'])
          .single();

      final currentStock = product['stock_quantity'] as int;
      final newStock = currentStock - (item['quantity'] as int);

      await _client
          .from('products')
          .update({'stock_quantity': newStock < 0 ? 0 : newStock})
          .eq('id', item['product_id']);
    }

    return sale;
  }

  // --- Sales history ---

  static Future<List<Sale>> getSales() async {
    final data = await _client
        .from('sales')
        .select()
        .order('created_at', ascending: false);
    return data.map((json) => Sale.fromJson(json)).toList();
  }

  static Future<List<SaleItem>> getSaleItems(String saleId) async {
    final data = await _client
        .from('sale_items')
        .select()
        .eq('sale_id', saleId);
    return data.map((json) => SaleItem.fromJson(json)).toList();
  }

  // Refund a sale (restore stock and mark as refunded)
  static Future<void> refundSale(String saleId) async {
    // Get sale items to restore stock
    final items = await _client
        .from('sale_items')
        .select()
        .eq('sale_id', saleId);

    // Restore stock for each item
    for (final item in items) {
      final product = await _client
          .from('products')
          .select('stock_quantity')
          .eq('id', item['product_id'])
          .single();

      final currentStock = product['stock_quantity'] as int;
      final restoredStock = currentStock + (item['quantity'] as int);

      await _client
          .from('products')
          .update({'stock_quantity': restoredStock})
          .eq('id', item['product_id']);
    }

    // Mark sale as refunded
    await _client
        .from('sales')
        .update({'is_refunded': true})
        .eq('id', saleId);
  }

  // Get sale items with product names joined
  static Future<List<Map<String, dynamic>>> getSaleItemsWithNames(String saleId) async {
    final data = await _client
        .from('sale_items')
        .select('*, products(name)')
        .eq('sale_id', saleId);
    return List<Map<String, dynamic>>.from(data);
  }

  // Get all sale items (for product sold counts)
  static Future<List<Map<String, dynamic>>> getAllSaleItems() async {
    final data = await _client
        .from('sale_items')
        .select('*, products(name)');
    return List<Map<String, dynamic>>.from(data);
  }
}
