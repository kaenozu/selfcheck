import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

/// Integration tests for PriceRepositoryImpl against real in-memory SQLite.
/// This eliminates test/production drift by testing the same SQL that runs on device.
void main() {
  group('PriceRepositoryImpl (real Drift DB)', () {
    late PriceRepository repository;

    setUp(() async {
      repository = await createTestRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    group('createProvisionalProduct', () {
      test('should create product with generated id', () async {
        final product = await repository.createProvisionalProduct('4901234567890');

        expect(product.id, startsWith('prod-'));
        expect(product.jan, '4901234567890');
      });

      test('should assign unique ids', () async {
        final p1 = await repository.createProvisionalProduct('4901234567890');
        final p2 = await repository.createProvisionalProduct('4901234567891');

        expect(p1.id, isNot(p2.id));
      });
    });

    group('insertObservation', () {
      test('should insert observation and return it with generated id', () async {
        final observation = await repository.insertObservation(
          productId: 'prod-123',
          priceYen: 500,
          priceConfidence: 0.95,
        );

        expect(observation.id, startsWith('obs-'));
        expect(observation.productId, 'prod-123');
        expect(observation.priceYen, 500);
        expect(observation.priceConfidence, 0.95);
        expect(observation.isValid, true);
      });

      test('should set price context booleans when provided', () async {
        final observation = await repository.insertObservation(
          productId: 'prod-123',
          priceYen: 500,
          priceConfidence: 0.95,
          isSaleVisible: true,
          isMemberPriceVisible: false,
          isCouponPriceVisible: null,
          isBulkDiscount: true,
        );

        expect(observation.isSaleVisible, true);
        expect(observation.isMemberPriceVisible, false);
        expect(observation.isCouponPriceVisible, null);
        expect(observation.isBulkDiscount, true);
      });

      test('should default price context booleans to null', () async {
        final observation = await repository.insertObservation(
          productId: 'prod-123',
          priceYen: 500,
          priceConfidence: 0.95,
        );

        expect(observation.isSaleVisible, null);
        expect(observation.isMemberPriceVisible, null);
        expect(observation.isCouponPriceVisible, null);
        expect(observation.isBulkDiscount, null);
      });
    });

    group('getValidObservations', () {
      test('should return observations for specified product', () async {
        await repository.insertObservation(
          productId: 'prod-A',
          priceYen: 100,
          priceConfidence: 0.9,
        );
        await repository.insertObservation(
          productId: 'prod-B',
          priceYen: 200,
          priceConfidence: 0.9,
        );
        await repository.insertObservation(
          productId: 'prod-A',
          priceYen: 150,
          priceConfidence: 0.9,
        );

        final observations = await repository.getValidObservations(
          productId: 'prod-A',
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 10,
        );

        expect(observations.length, 2);
        expect(observations.every((o) => o.productId == 'prod-A'), true);
      });

      test('should respect time window filter', () async {
        final now = DateTime.now();

        // Insert observation 200 days in the past
        await repository.insertObservationWithDate(
          productId: 'prod-1',
          priceYen: 100,
          priceConfidence: 0.9,
          observedAt: now.subtract(const Duration(days: 200)),
        );

        // Insert observation 10 days in the past
        await repository.insertObservationWithDate(
          productId: 'prod-1',
          priceYen: 200,
          priceConfidence: 0.9,
          observedAt: now.subtract(const Duration(days: 10)),
        );

        final observations = await repository.getValidObservations(
          productId: 'prod-1',
          since: now.subtract(const Duration(days: 180)),
          limit: 10,
        );

        expect(observations.length, 1);
        expect(observations.first.priceYen, 200);
      });

      test('should respect limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repository.insertObservation(
            productId: 'prod-1',
            priceYen: 100 + i,
            priceConfidence: 0.9,
          );
        }

        final observations = await repository.getValidObservations(
          productId: 'prod-1',
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 3,
        );

        expect(observations.length, 3);
      });
    });

    group('findProductByJan', () {
      test('should return product when found', () async {
        await repository.createProvisionalProduct('4901234567890');

        final found = await repository.findProductByJan('4901234567890');

        expect(found, isNotNull);
        expect(found!.jan, '4901234567890');
      });

      test('should return null when not found', () async {
        final found = await repository.findProductByJan('9999999999999');

        expect(found, isNull);
      });
    });

    group('insertObservationWithDate', () {
      test('should insert observation with specified date', () async {
        final pastDate = DateTime(2024, 1, 15, 10, 30);

        final obs = await repository.insertObservationWithDate(
          productId: 'prod-1',
          priceYen: 450,
          priceConfidence: 0.85,
          observedAt: pastDate,
        );

        expect(obs.observedAt, pastDate);
        expect(obs.priceYen, 450);
      });

      test('should be queryable via getValidObservations', () async {
        final now = DateTime.now();

        await repository.insertObservationWithDate(
          productId: 'prod-1',
          priceYen: 300,
          priceConfidence: 0.9,
          observedAt: now.subtract(const Duration(days: 90)),
        );

        final observations = await repository.getValidObservations(
          productId: 'prod-1',
          since: now.subtract(const Duration(days: 180)),
          limit: 10,
        );

        expect(observations.length, 1);
        expect(observations.first.priceYen, 300);
      });
    });

    group('dispose', () {
      test('should close the database without error', () async {
        await repository.createProvisionalProduct('4901234567890');
        await repository.insertObservation(
          productId: 'prod-1',
          priceYen: 500,
          priceConfidence: 0.9,
        );

        // Should not throw
        repository.dispose();
      });
    });
  });
}
