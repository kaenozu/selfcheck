import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/infrastructure/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('invalidation frees the duplicate slot for a corrected observation', () async {
    final product = await db.insertProvisionalProduct('4901234567890');
    final firstAt = DateTime(2026, 8, 31, 9, 1);
    final first = await db.insertObservationWithDate(
      productId: product.id,
      priceYen: 500,
      priceConfidence: 0.9,
      observedAt: firstAt,
    );

    await db.invalidateObservation(first.id);
    await db.invalidateObservation(first.id);

    expect(
      await db.isDuplicate(
        productId: product.id,
        priceYen: 500,
        observedAt: firstAt.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );

    final corrected = await db.insertObservationWithDate(
      productId: product.id,
      priceYen: 500,
      priceConfidence: 0.95,
      observedAt: firstAt.add(const Duration(minutes: 1)),
    );

    expect(corrected.id, isNot(first.id));
    expect(corrected.isValid, isTrue);

    final rows = await db.select(db.priceObservations).get();
    expect(rows, hasLength(2));

    final invalid = rows.singleWhere((row) => row.id == first.id);
    final valid = rows.singleWhere((row) => row.id == corrected.id);
    expect(invalid.isValid, isFalse);
    expect(valid.isValid, isTrue);
    expect(invalid.duplicateKey, isNot(valid.duplicateKey));
    expect(invalid.duplicateKey, contains(':invalid:${first.id}'));
  });
}
