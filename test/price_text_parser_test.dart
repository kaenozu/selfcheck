import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_text_parser.dart';

void main() {
  const region = Rect(left: 1, top: 2, right: 3, bottom: 4);

  test('prefers currency-marked price over bare numbers', () {
    final result = parsePriceText([
      (text: '在庫 12', region: region),
      (text: '税込 ￥1,980円', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 1980);
    expect(result.confidence, 0.90);
  });

  test('accepts a plausible bare price', () {
    final result = parsePriceText([(text: '398', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
    expect(result.confidence, 0.70);
  });

  test('rejects bare numbers embedded in non-price text', () {
    expect(parsePriceText([(text: '在庫 12', region: region)]), isNull);
    expect(parsePriceText([(text: '商品 398', region: region)]), isNull);
  });

  test('prefers the larger OCR region for equally ranked bare prices', () {
    const smallRegion = Rect(left: 0, top: 0, right: 20, bottom: 10);
    const largeRegion = Rect(left: 0, top: 0, right: 80, bottom: 40);

    final result = parsePriceText([
      (text: '398', region: smallRegion),
      (text: '980', region: largeRegion),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 980);
    expect(result.region, largeRegion);
  });

  test('does not reinterpret JAN/EAN-length text as a price', () {
    final result = parsePriceText([(text: '4901234567894', region: region)]);

    expect(result, isNull);
  });

  test('rejects zero and values above 99,999 yen', () {
    expect(parsePriceText([(text: '￥0円', region: region)]), isNull);
    expect(parsePriceText([(text: '￥100,000円', region: region)]), isNull);
  });

  test('prefers product price over a marked per-weight unit price', () {
    final result = parsePriceText([
      (text: '398', region: region),
      (text: '100g当たり ¥198', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('rejects slash-form unit price without a product price', () {
    expect(parsePriceText([(text: '¥198/100g', region: region)]), isNull);
    expect(parsePriceText([(text: '￥198／100ml', region: region)]), isNull);
  });

  test('rejects per-item unit price without a product price', () {
    expect(parsePriceText([(text: '1個当たり 50円', region: region)]), isNull);
    expect(parsePriceText([(text: '1本あたり ￥80', region: region)]), isNull);
  });

  test('keeps a normal price followed by package weight', () {
    final result = parsePriceText([(text: '税込 ¥398 100g', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });
}
