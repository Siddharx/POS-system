import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryBar extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  const CategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "All" button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onCategorySelected(null),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              showCheckmark: false,
            ),
          ),
          // Category buttons
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat.name),
              selected: selectedCategoryId == cat.id,
              onSelected: (_) => onCategorySelected(cat.id),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              showCheckmark: false,
            ),
          )),
        ],
      ),
    );
  }
}
