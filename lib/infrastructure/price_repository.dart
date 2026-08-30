import '../domain/product.dart';
import '../domain/price_observation.dart';

/// PriceRepository interface for price observation storage.
///
/// Returns domain types ([Product], [PriceObservationDomain]) so that
/// Application and Domain layers never depend on Drift.
abstract class PriceRepository {
  Future<Product?> findProductByJan(String jan);
  Future<Product> createProvisionalProduct(String jan);
  Future<List<PriceObservationDomain>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  });
  Future<PriceObservationDomain> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  });
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  });

  /// Insert an observation with a specific observedAt date.
  /// Use for testing time-window filtering with past dates.
  Future<PriceObservationDomain> insertObservationWithDate({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  });

  void dispose();
}
