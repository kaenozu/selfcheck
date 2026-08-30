/// 価格観測を表すドメインモデル。
///
/// Infrastructure層（Drift生成型）に依存しない純粋な値オブジェクト。
/// 価格コンテキスト（セール/会員/クーポン/まとめ割）のブール値を持つ。
class PriceObservationDomain {
  final String id;
  final String productId;
  final int priceYen;
  final DateTime observedAt;
  final double priceConfidence;
  final bool isValid;

  /// 価格コンテキスト（将来の拡張用）
  final bool? isSaleVisible;
  final bool? isMemberPriceVisible;
  final bool? isCouponPriceVisible;
  final bool? isBulkDiscount;

  const PriceObservationDomain({
    required this.id,
    required this.productId,
    required this.priceYen,
    required this.observedAt,
    required this.priceConfidence,
    this.isValid = true,
    this.isSaleVisible,
    this.isMemberPriceVisible,
    this.isCouponPriceVisible,
    this.isBulkDiscount,
  });

  /// 価格コンテキストが少なくとも1つ有効かどうか
  bool get hasPriceContext =>
      isSaleVisible == true ||
      isMemberPriceVisible == true ||
      isCouponPriceVisible == true ||
      isBulkDiscount == true;

  PriceObservationDomain copyWith({
    String? id,
    String? productId,
    int? priceYen,
    DateTime? observedAt,
    double? priceConfidence,
    bool? isValid,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) {
    return PriceObservationDomain(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      priceYen: priceYen ?? this.priceYen,
      observedAt: observedAt ?? this.observedAt,
      priceConfidence: priceConfidence ?? this.priceConfidence,
      isValid: isValid ?? this.isValid,
      isSaleVisible: isSaleVisible ?? this.isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible ?? this.isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible ?? this.isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount ?? this.isBulkDiscount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceObservationDomain &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          priceYen == other.priceYen;

  @override
  int get hashCode => Object.hash(id, productId, priceYen);

  @override
  String toString() =>
      'PriceObservationDomain(id: $id, productId: $productId, '
      'price: ¥$priceYen, context: ${hasPriceContext ? "yes" : "no"})';
}
