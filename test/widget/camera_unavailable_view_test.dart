import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/presentation/camera_unavailable_view.dart';
import 'package:selfcheck_jibun_check/presentation/widgets/scan_overlay.dart';

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

  testWidgets('scan overlay does not block camera recovery controls', (
    tester,
  ) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              CameraUnavailableView(
                onRetry: () async {
                  retryCount++;
                },
              ),
              const ScanOverlay(scanState: ScanState.idle),
            ],
          ),
        ),
      ),
    );

    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('タップしてスキャン開始'), findsOneWidget);

    await tester.tap(find.text('再試行'));
    await tester.pump();

    expect(retryCount, 1);
  });
}
