import 'package:drift/native.dart';

import '../domain/product.dart';
import '../domain/price_observation.dart';
import 'database/app_database.dart';
import 'price_repository.dart';

/// PriceRepository implementation using Drift database.
///
/// Maps between Drift-generated data classes and domain models at this
/// boundary, so the rest of the app never depends on Drift types.
class PriceRepositoryImpl implements PriceRepository {
  final AppDatabase _database;

  PriceRepositoryImpl(this._database);

  // ── Mapping helpers ──────────────────────────────────────────────────

  Product _mapProduct(ProductIdentity row) => Product(
        id: row.id,
        jan: row.jan,
        displayName: row.displayName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  PriceObservationDomain _mapObservation(PriceObservation row) =>
      PriceObservationDomain(
        id: row.id,
        productId: row.productId,
        priceYen: row.priceYen,
        observedAt: row.observedAt,
        priceConfidence: row.priceConfidence,
        isValid: row.isValid,
        isSaleVisible: row.isSaleVisible,
        isMemberPriceVisible: row.isMemberPriceVisible,
        isCouponPriceVisible: row.isCouponPriceVisible,
        isBulkDiscount: row.isBulkDiscount,
      );

  // ── PriceRepository interface ────────────────────────────────────────

  @override
  Future<Product?> findProductByJan(String jan) async {
    final row = await _database.findProductByJan(jan);
    return row == null ? null : _mapProduct(row);
  }

  @override
  Future<Product> createProvisionalProduct(String jan) async {
    final row = await _database.insertProvisionalProduct(jan);
    return _mapProduct(row);
  }

  @override
  Future<List<PriceObservationDomain>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
  }) async {
    final rows = await _database.getValidObservations(
      productId: productId,
      since: since,
      limit: limit,
    );
    return rows.map(_mapObservation).toList();
  }

  @override
  Future<PriceObservationDomain> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    final row = await _database.insertObservation(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
    );
    return _mapObservation(row);
  }

  @override
  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async {
    return await _database.isDuplicate(
      productId: productId,
      priceYen: priceYen,
      observedAt: observedAt,
    );
  }

  @override
  Future<PriceObservationDomain> insertObservationWithDate({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    final row = await _database.insertObservationWithDate(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      observedAt: observedAt,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
    );
    return _mapObservation(row);
  }

  @override
  void dispose() {
    _database.close();
  }
}

/// Create a PriceRepositoryImpl backed by an in-memory SQLite database.
/// Use this in tests to get the same SQL behavior as production.
Future<PriceRepositoryImpl> createTestRepository() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  return PriceRepositoryImpl(db);
}
