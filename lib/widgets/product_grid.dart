import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/format.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductTapped;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 2 on phone, 3 on tablet, 4 on desktop
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final bool outOfStock = product.stockQuantity <= 0;
            final bool lowStock = product.stockQuantity > 0 && product.stockQuantity <= 5;

            return GestureDetector(
              onTap: outOfStock ? null : () => onProductTapped(product),
              child: Card(
                elevation: 2,
                color: outOfStock
                    ? Colors.grey.shade200
                    : Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fastfood,
                        size: 28,
                        color: outOfStock
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: outOfStock ? Colors.grey : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatPrice(product.price),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: outOfStock
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (outOfStock)
                        const Text(
                          'Out of Stock',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          '${product.stockQuantity} left',
                          style: TextStyle(
                            fontSize: 11,
                            color: lowStock ? Colors.orange.shade800 : Colors.grey,
                            fontWeight: lowStock ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
