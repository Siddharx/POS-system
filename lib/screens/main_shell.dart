import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'inventory_screen.dart';
import 'sales_history_screen.dart';
import 'analytics_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  static const String _adminPin = '4362';

  void _toggleAdmin() {
    if (_isAdmin) {
      setState(() {
        _isAdmin = false;
        // If on admin-only tab, go back to storefront
        if (_currentIndex >= 2) _currentIndex = 0;
      });
    } else {
      _showPinDialog();
    }
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Admin PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '****',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (value) {
            if (value == _adminPin) {
              Navigator.pop(ctx);
              setState(() => _isAdmin = true);
            } else {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incorrect PIN'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == _adminPin) {
                Navigator.pop(ctx);
                setState(() => _isAdmin = true);
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect PIN'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(isAdmin: _isAdmin),
      InventoryScreen(isAdmin: _isAdmin),
      if (_isAdmin) const SalesHistoryScreen(),
      if (_isAdmin) const AnalyticsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // Handle ADMIN button tap (always the last one)
          final adminIndex = _isAdmin ? 4 : 2;
          if (index == adminIndex) {
            _toggleAdmin();
            return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Storefront',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Sales',
            ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
          NavigationDestination(
            icon: Icon(
              _isAdmin ? Icons.lock_open : Icons.admin_panel_settings_outlined,
              color: _isAdmin ? Colors.green : null,
            ),
            selectedIcon: Icon(
              _isAdmin ? Icons.lock_open : Icons.admin_panel_settings,
              color: _isAdmin ? Colors.green : null,
            ),
            label: _isAdmin ? 'ADMIN ✓' : 'ADMIN',
          ),
        ],
      ),
    );
  }
}
