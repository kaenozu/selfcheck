import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/comparison_result.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/result_card.dart';

void main() {
  testWidgets('main price keeps a dark foreground on the white result card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ResultCard(result: ComparisonResult.firstPrice(398)),
        ),
      ),
    );

    final priceText = tester.widget<Text>(find.text('¥398'));

    expect(priceText.style?.color, const Color(0xFF212121));
  });
}
