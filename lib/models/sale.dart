class Sale {
  final String id;
  final double totalAmount;
  final String paymentMethod;
  final bool isAdmin;
  final bool isRefunded;
  final int? orderNumber;
  final double cashAmount;
  final double cardAmount;
  final DateTime? createdAt;

  Sale({
    required this.id,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.isAdmin = false,
    this.isRefunded = false,
    this.orderNumber,
    this.cashAmount = 0,
    this.cardAmount = 0,
    this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      isAdmin: json['is_admin'] as bool? ?? false,
      isRefunded: json['is_refunded'] as bool? ?? false,
      orderNumber: json['order_number'] as int?,
      cashAmount: (json['cash_amount'] as num?)?.toDouble() ?? 0,
      cardAmount: (json['card_amount'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'is_admin': isAdmin,
      'is_refunded': isRefunded,
      'order_number': orderNumber,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
    };
  }
}
