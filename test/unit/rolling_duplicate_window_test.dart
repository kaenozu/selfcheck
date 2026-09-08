import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';

void main() {
  group('rolling five-minute duplicate window', () {
    late PriceRepositoryImpl repository;

    setUp(() async {
      repository = await createTestRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    Future<String> createProduct(String jan) async {
      return (await repository.createProvisionalProduct(jan)).id;
    }

    test(
      'detects a duplicate across a fixed five-minute bucket boundary',
      () async {
        final productId = await createProduct('4901234567800');
        final firstAt = DateTime(2026, 8, 30, 10, 4, 59);

        await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.95,
          observedAt: firstAt,
        );

        final duplicate = await repository.isDuplicate(
          productId: productId,
          priceYen: 500,
          observedAt: DateTime(2026, 8, 30, 10, 5, 1),
        );

        expect(duplicate, isTrue);
      },
    );

    test(
      'treats exactly five minutes as inside the duplicate window',
      () async {
        final productId = await createProduct('4901234567801');
        final firstAt = DateTime(2026, 8, 30, 10, 0);

        await repository.insertObservationWithDate(
          productId: productId,
          priceYen: 500,
          priceConfidence: 0.95,
          observedAt: firstAt,
        );

        final duplicate = await repository.isDuplicate(
          productId: productId,
          priceYen: 500,
          observedAt: firstAt.add(const Duration(minutes: 5)),
        );

        expect(duplicate, isTrue);
      },
    );

    test('does not flag the same price after more than five minutes', () async {
      final productId = await createProduct('4901234567802');
      final firstAt = DateTime(2026, 8, 30, 10, 0);

      await repository.insertObservationWithDate(
        productId: productId,
        priceYen: 500,
        priceConfidence: 0.95,
        observedAt: firstAt,
      );

      final duplicate = await repository.isDuplicate(
        productId: productId,
        priceYen: 500,
        observedAt: firstAt.add(const Duration(minutes: 5, seconds: 1)),
      );

      expect(duplicate, isFalse);
    });

    test('does not flag a different price or a different product', () async {
      final productA = await createProduct('4901234567803');
      final productB = await createProduct('4901234567804');
      final observedAt = DateTime(2026, 8, 30, 10, 4, 59);

      await repository.insertObservationWithDate(
        productId: productA,
        priceYen: 500,
        priceConfidence: 0.95,
        observedAt: observedAt,
      );

      expect(
        await repository.isDuplicate(
          productId: productA,
          priceYen: 501,
          observedAt: observedAt.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
      expect(
        await repository.isDuplicate(
          productId: productB,
          priceYen: 500,
          observedAt: observedAt.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
    });
  });
}
