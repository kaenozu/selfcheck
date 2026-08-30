import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

void main() {
  group('PriceRepositoryImpl (real Drift DB)', () {
    late PriceRepository repository;

    setUp(() async {
      repository = await createTestRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    Future<String> createProduct(String jan) async {
      return (await repository.createProvisionalProduct(jan)).id;
    }

    group('createProvisionalProduct', () {
      test('creates product with generated id', () async {
        final product = await repository.createProvisionalProduct('4901234567890');
        expect(product.id, startsWith('prod-'));
        expect(product.jan, '4901234567890');
      });

      test('assigns unique ids', () async {
        final p1 = await repository.createProvisionalProduct('4901234567890');
        final p2 = await repository.createProvisionalProduct('4901234567891');
        expect(p1.id, isNot(p2.id));
      });
    });

    group('insertObservation', () {
      test('inserts observation for an existing product', () async {
        final productId = await createProduct('4901234567890');
        final observation = await repository.insertObservation(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.95,
        );

        expect(observation.id, startsWith('obs-'));
        expect(observation.productId, productId);
        expect(observation.priceYen, 500);
        expect(observation.priceConfidence, 0.95);
        expect(observation.isValid, true);
      });

      test('rejects an observation for a nonexistent product', () async {
        expect(
          () => repository.insertObservation(
            productId: 'missing-product',
            priceYen: 500,
            priceConfidence: 0.95,
          ),
          throwsA(anything),
        );
      });

      test('persists price context booleans', () async {
        final productId = await createProduct('4901234567890');
        final observation = await repository.insertObservation(
          productId: productId,
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

      test('returns the actually persisted row when suppressing a duplicate', () async {
        final productId = await createProduct('4901234567890');
        final observedAt = DateTime(2026, 8, 30, 9, 0);
        final first = await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.95,
          observedAt: observedAt,
        );
        final duplicate = await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.50,
          observedAt: observedAt.add(const Duration(minutes: 1)),
        );

        expect(duplicate.id, first.id);
        expect(duplicate.observedAt, first.observedAt);
        expect(duplicate.priceConfidence, first.priceConfidence);
      });

      test('same timestamp and price for different products both persist', () async {
        final productA = await createProduct('4901234567890');
        final productB = await createProduct('4901234567891');
        final observedAt = DateTime(2026, 8, 30, 9, 0);

        final a = await repository.insertObservationWithDate(
          productId: productA,
          priceYen: 500,
          priceConfidence: 0.9,
          observedAt: observedAt,
        );
        final b = await repository.insertObservationWithDate(
          productId: productB,
          priceYen: 500,
          priceConfidence: 0.9,
          observedAt: observedAt,
        );

        expect(a.id, isNot(b.id));
        expect(a.productId, productA);
        expect(b.productId, productB);
      });
    });

    group('getValidObservations', () {
      test('returns observations for specified product only', () async {
        final productA = await createProduct('4901234567890');
        final productB = await createProduct('4901234567891');
        await repository.insertObservation(
          productId: productA,
          priceYen: 100,
          priceConfidence: 0.9,
        );
        await repository.insertObservation(
          productId: productB,
          priceYen: 200,
          priceConfidence: 0.9,
        );
        await repository.insertObservation(
          productId: productA,
          priceYen: 150,
          priceConfidence: 0.9,
        );

        final observations = await repository.getValidObservations(
          productId: productA,
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 10,
        );

        expect(observations.length, 2);
        expect(observations.every((o) => o.productId == productA), true);
      });

      test('respects time window filter', () async {
        final productId = await createProduct('4901234567890');
        final now = DateTime.now();
        await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 100,
          priceConfidence: 0.9,
          observedAt: now.subtract(const Duration(days: 200)),
        );
        await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 200,
          priceConfidence: 0.9,
          observedAt: now.subtract(const Duration(days: 10)),
        );

        final observations = await repository.getValidObservations(
          productId: productId,
          since: now.subtract(const Duration(days: 180)),
          limit: 10,
        );

        expect(observations.length, 1);
        expect(observations.first.priceYen, 200);
      });

      test('respects limit parameter', () async {
        final productId = await createProduct('4901234567890');
        for (var i = 0; i < 5; i++) {
          await repository.insertObservation(
            productId: productId,
            priceYen: 100 + i,
            priceConfidence: 0.9,
          );
        }

        final observations = await repository.getValidObservations(
          productId: productId,
          since: DateTime.now().subtract(const Duration(days: 30)),
          limit: 3,
        );
        expect(observations.length, 3);
      });
    });

    group('findProductByJan', () {
      test('returns product when found', () async {
        await repository.createProvisionalProduct('4901234567890');
        final found = await repository.findProductByJan('4901234567890');
        expect(found, isNotNull);
        expect(found!.jan, '4901234567890');
      });

      test('returns null when not found', () async {
        final found = await repository.findProductByJan('9999999999999');
        expect(found, isNull);
      });
    });
  });
}
