class Product {
  final String id;
  final String name;
  final double price;
  final int stockQuantity;
  final String? categoryId;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    this.categoryId,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stockQuantity: json['stock_quantity'] as int,
      categoryId: json['category_id'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'stock_quantity': stockQuantity,
      'category_id': categoryId,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }
}
