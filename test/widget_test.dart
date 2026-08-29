import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/price_context_badges.dart';

void main() {
  testWidgets('PriceContextBadges smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PriceContextBadges(isSaleVisible: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SALE'), findsOneWidget);
  });
}
