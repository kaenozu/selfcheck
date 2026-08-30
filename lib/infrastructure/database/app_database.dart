import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// ProductIdentity table - JAN/GTIN as primary identifier
///
/// Drift generates ProductIdentity data class from this table definition.
class ProductIdentitys extends Table {
  @override
  String get tableName => 'product_identity';

  TextColumn get id => text()();
  TextColumn get jan => text().unique()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// PriceObservation table - price records with context booleans
///
/// Drift generates PriceObservation data class from this table definition.
/// Includes v0.2 price context booleans for future extensibility.
class PriceObservations extends Table {
  @override
  String get tableName => 'price_observation';

  TextColumn get id => text()();
  TextColumn get productId => text().references(ProductIdentitys, #id)();
  IntColumn get priceYen => integer()();
  DateTimeColumn get observedAt => dateTime()();
  RealColumn get priceConfidence => real()();
  BoolColumn get isValid => boolean().withDefault(const Constant(true))();
  TextColumn get duplicateKey => text()();

  // v0.2 price context booleans (nullable for future extensibility)
  BoolColumn get isSaleVisible => boolean().nullable()();
  BoolColumn get isMemberPriceVisible => boolean().nullable()();
  BoolColumn get isCouponPriceVisible => boolean().nullable()();
  BoolColumn get isBulkDiscount => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{duplicateKey}];
}

@DriftDatabase(tables: [ProductIdentitys, PriceObservations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA user_version = 2;');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS product_stats;');

        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_sale_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_member_price_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_coupon_price_visible INTEGER DEFAULT NULL;',
        );
        await customStatement(
          'ALTER TABLE price_observation ADD COLUMN is_bulk_discount INTEGER DEFAULT NULL;',
        );

        await customStatement('PRAGMA user_version = 2;');
      }
    },
    beforeOpen: (details) async {
      // SQLite does not enforce declared foreign keys unless explicitly enabled
      // on every connection. Keep the existing schema/data intact and reject new
      // orphan observations from this point forward.
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  // ========== ProductIdentity CRUD ==========

  Future<ProductIdentity?> findProductByJan(String jan) async {
    return (select(productIdentitys)..where((t) => t.jan.equals(jan)))
        .getSingleOrNull();
  }

  Future<ProductIdentity> insertProvisionalProduct(String jan) async {
    final now = DateTime.now();
    final id = 'prod-$jan-${now.microsecondsSinceEpoch}';

    final entity = ProductIdentitysCompanion.insert(
      id: id,
      jan: jan,
      createdAt: now,
      updatedAt: now,
    );

    await into(productIdentitys).insert(entity);

    return ProductIdentity(
      id: id,
      jan: jan,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateProductDisplayName(String id, String name) async {
    await (update(productIdentitys)..where((t) => t.id.equals(id)))
      .write(ProductIdentitysCompanion(
        displayName: Value(name),
        updatedAt: Value(DateTime.now()),
      ));
  }

  // ========== PriceObservation CRUD ==========

  Future<List<PriceObservation>> getValidObservations({
    required String productId,
    required DateTime since,
    required int limit,
    bool excludeCurrent = false,
  }) async {
    final query = select(priceObservations)
      ..where((t) => t.productId.equals(productId))
      ..where((t) => t.isValid.equals(true))
      ..where((t) => t.observedAt.isBiggerThanValue(since))
      ..orderBy([(t) => OrderingTerm.desc(t.observedAt)])
      ..limit(limit);

    return await query.get();
  }

  Future<PriceObservation> insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    final now = DateTime.now();
    return _insertObservation(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      observedAt: now,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
    );
  }

  Future<bool> isDuplicate({
    required String productId,
    required int priceYen,
    required DateTime observedAt,
  }) async {
    final window = observedAt.millisecondsSinceEpoch ~/ (5 * 60 * 1000);
    final duplicateKey = '$productId:$priceYen:$window';

    final rows = await (select(priceObservations)
      ..where((t) => t.duplicateKey.equals(duplicateKey))
      ..where((t) => t.isValid.equals(true))
    ).get();

    return rows.isNotEmpty;
  }

  Future<void> invalidateObservation(String id) async {
    await (update(priceObservations)..where((t) => t.id.equals(id)))
      .write(const PriceObservationsCompanion(
        isValid: Value(false),
      ));
  }

  /// Insert an observation with a specific observedAt date (for testing).
  /// Allows creating observations in the past to test time-window filtering.
  Future<PriceObservation> insertObservationWithDate({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    return _insertObservation(
      productId: productId,
      priceYen: priceYen,
      priceConfidence: priceConfidence,
      observedAt: observedAt,
      isSaleVisible: isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount,
    );
  }

  Future<PriceObservation> _insertObservation({
    required String productId,
    required int priceYen,
    required double priceConfidence,
    required DateTime observedAt,
    bool? isSaleVisible,
    bool? isMemberPriceVisible,
    bool? isCouponPriceVisible,
    bool? isBulkDiscount,
  }) async {
    final id =
        'obs-$productId-${observedAt.microsecondsSinceEpoch}-$priceYen';
    final duplicateKey =
        '$productId:$priceYen:${observedAt.millisecondsSinceEpoch ~/ (5 * 60 * 1000)}';

    final entity = PriceObservationsCompanion.insert(
      id: id,
      productId: productId,
      priceYen: priceYen,
      observedAt: observedAt,
      priceConfidence: priceConfidence,
      duplicateKey: duplicateKey,
      isSaleVisible: Value(isSaleVisible),
      isMemberPriceVisible: Value(isMemberPriceVisible),
      isCouponPriceVisible: Value(isCouponPriceVisible),
      isBulkDiscount: Value(isBulkDiscount),
    );

    // duplicateKey defines intentional five-minute duplicate suppression.
    // Any other constraint failure must not be reported as a successful insert.
    await into(priceObservations).insert(
      entity,
      mode: InsertMode.insertOrIgnore,
    );

    final persisted = await (select(priceObservations)
          ..where((t) => t.duplicateKey.equals(duplicateKey)))
        .getSingleOrNull();
    if (persisted == null) {
      throw StateError('Price observation insert was not persisted');
    }
    return persisted;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'selfcheck.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
