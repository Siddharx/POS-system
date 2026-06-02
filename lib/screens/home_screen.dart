import 'package:flutter/material.dart';
import '../main.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/supabase_service.dart';
import '../services/sound_service.dart';
import '../widgets/category_bar.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/product_search_bar.dart';
import 'checkout_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin;

  const HomeScreen({super.key, this.isAdmin = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Data from Supabase
  List<Category> _categories = [];
  List<Product> _allProducts = [];

  // UI state
  String? _selectedCategoryId;
  String _searchQuery = '';
  final List<CartItem> _cartItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await SupabaseService.getCategories();
      final products = await SupabaseService.getProducts();
      setState(() {
        _categories = categories;
        _allProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Filtered products based on category and search
  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory = _selectedCategoryId == null ||
          p.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // Cart total
  double get _cartTotal {
    return _cartItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  // Add product to cart
  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(product: product));
      }
    });
    SoundService.playAddToCart();
    // Low stock warning sound
    if (product.stockQuantity <= 5) {
      SoundService.playLowStockWarning();
    }
  }

  // Increment quantity
  void _incrementItem(CartItem item) {
    setState(() => item.quantity++);
  }

  // Decrement quantity (remove if 0)
  void _decrementItem(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cartItems.remove(item);
      }
    });
  }

  // Set exact quantity
  void _setItemQuantity(CartItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cartItems.remove(item);
      } else {
        item.quantity = quantity;
      }
    });
  }

  // Remove item from cart
  void _removeItem(CartItem item) {
    setState(() => _cartItems.remove(item));
  }

  // Clear entire cart
  void _clearCart() {
    setState(() => _cartItems.clear());
  }

  // Pay button pressed
  void _onPay() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: List.from(_cartItems),
          total: _cartTotal,
          isAdmin: widget.isAdmin,
        ),
      ),
    );

    // If sale was completed, clear the cart and refresh products
    if (result == true) {
      setState(() => _cartItems.clear());
      _loadData();
    }
  }

  // Show cart as bottom sheet on narrow screens
  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: CartPanel(
          cartItems: _cartItems,
          total: _cartTotal,
          onIncrement: (item) {
            _incrementItem(item);
            // ignore: invalid_use_of_protected_member
            (ctx as Element).markNeedsBuild();
          },
          onDecrement: (item) {
            _decrementItem(item);
            (ctx as Element).markNeedsBuild();
          },
          onRemove: (item) {
            _removeItem(item);
            (ctx as Element).markNeedsBuild();
          },
          onSetQuantity: (item, qty) {
            _setItemQuantity(item, qty);
            (ctx as Element).markNeedsBuild();
          },
          onClearCart: () {
            _clearCart();
            Navigator.pop(ctx);
          },
          onPay: () {
            Navigator.pop(ctx);
            _onPay();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS System'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Dark mode toggle
          IconButton(
            icon: Icon(
              themeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              setState(() {});
            },
            tooltip: 'Toggle dark mode',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh products',
          ),
          // Cart badge (only on narrow screens)
          if (!isWide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Badge(
                  label: Text('${_cartItems.length}'),
                  isLabelVisible: _cartItems.isNotEmpty,
                  child: const Icon(Icons.shopping_cart),
                ),
                onPressed: _showCartBottomSheet,
                tooltip: 'View cart',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isWide
              ? _buildWideLayout()
              : _buildNarrowLayout(),
    );
  }

  // Desktop/Tablet: product grid on left, cart on right
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left side: categories + search + products
        Expanded(
          flex: 3,
          child: Column(
            children: [
              CategoryBar(
                categories: _categories,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: (id) {
                  setState(() => _selectedCategoryId = id);
                },
              ),
              ProductSearchBar(
                onChanged: (query) {
                  setState(() => _searchQuery = query);
                },
              ),
              Expanded(
                child: ProductGrid(
                  products: _filteredProducts,
                  onProductTapped: _addToCart,
                ),
              ),
            ],
          ),
        ),
        // Right side: cart
        SizedBox(
          width: 350,
          child: CartPanel(
            cartItems: _cartItems,
            total: _cartTotal,
            onIncrement: _incrementItem,
            onDecrement: _decrementItem,
            onRemove: _removeItem,
            onSetQuantity: _setItemQuantity,
            onClearCart: _clearCart,
            onPay: _onPay,
          ),
        ),
      ],
    );
  }

  // Phone: full-width products, cart as bottom sheet
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        CategoryBar(
          categories: _categories,
          selectedCategoryId: _selectedCategoryId,
          onCategorySelected: (id) {
            setState(() => _selectedCategoryId = id);
          },
        ),
        ProductSearchBar(
          onChanged: (query) {
            setState(() => _searchQuery = query);
          },
        ),
        Expanded(
          child: ProductGrid(
            products: _filteredProducts,
            onProductTapped: _addToCart,
          ),
        ),
      ],
    );
  }
}
