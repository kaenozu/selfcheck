import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/presentation/camera_unavailable_view.dart';

void main() {
  testWidgets('camera unavailable view retries once while pending', (
    tester,
  ) async {
    final retryCompleter = Completer<void>();
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CameraUnavailableView(
          onRetry: () {
            retryCount++;
            return retryCompleter.future;
          },
        ),
      ),
    );

    expect(find.textContaining('カメラを利用できません'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);

    await tester.tap(find.text('再試行'));
    await tester.pump();
    expect(retryCount, 1);
    expect(find.text('再試行中…'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(retryCount, 1);

    retryCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('再試行'), findsOneWidget);
  });
}
