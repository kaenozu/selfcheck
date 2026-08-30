/// 商品を表すドメインモデル。
///
/// Infrastructure層（Drift）に依存しない純粋な値オブジェクト。
/// [PriceRepository] はこの型を返し、Application層はこの型のみ使う。
class Product {
  final String id;
  final String jan;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.jan,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    String? id,
    String? jan,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      jan: jan ?? this.jan,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          jan == other.jan;

  @override
  int get hashCode => Object.hash(id, jan);

  @override
  String toString() =>
      'Product(id: $id, jan: $jan, displayName: $displayName)';
}
