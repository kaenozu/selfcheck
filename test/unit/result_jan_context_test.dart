import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/application/compare_use_case.dart';
import 'package:selfcheck_jibun_check/application/scan_coordinator.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_repository_impl.dart';
import 'package:selfcheck_jibun_check/presentation/scan_screen_controller.dart';

void main() {
  late PriceRepository repository;
  late ScanCoordinator coordinator;
  late ScanScreenController controller;
  late _PushBarcodeAdapter barcodeAdapter;
  late _PushPriceAdapter priceAdapter;

  setUp(() async {
    repository = await createTestRepository();
    barcodeAdapter = _PushBarcodeAdapter();
    priceAdapter = _PushPriceAdapter();
    coordinator = ScanCoordinator(
      repository: repository,
      compareUseCase: CompareUseCase(repository),
      barcodeAdapter: barcodeAdapter,
      priceAdapter: priceAdapter,
    );
    controller = ScanScreenController(coordinator: coordinator)..init();
  });

  tearDown(() async {
    controller.dispose();
    coordinator.dispose();
    await barcodeAdapter.dispose();
    await priceAdapter.dispose();
    repository.dispose();
  });

  test('propagates the recognized JAN to result UI and clears it on reset', () async {
    const jan = '4901234567890';
    const barcode = BarcodeCandidate(
      barcode: jan,
      format: BarcodeFormat.ean13,
      confidence: 0.95,
      region: Rect(left: 0, top: 0, right: 200, bottom: 100),
    );
    const price = PriceCandidate(
      priceYen: 398,
      confidence: 0.9,
      region: Rect(left: 0, top: 100, right: 200, bottom: 150),
      rawTexts: ['¥398'],
    );

    controller.startScan();
    barcodeAdapter.add(barcode);
    await _waitUntil(() => coordinator.currentState == ScanState.waitingPrice);

    priceAdapter.add(price);
    priceAdapter.add(price);
    priceAdapter.add(price);

    await _waitUntil(
      () =>
          controller.uiState.scanState == ScanState.result &&
          controller.uiState.janCode == jan,
    );

    expect(coordinator.lastCompletedJan, jan);
    expect(controller.uiState.janCode, jan);
    expect(controller.uiState.currentPriceYen, 398);

    controller.dismissResult();

    expect(coordinator.lastCompletedJan, isNull);
    expect(controller.uiState.janCode, isNull);
    expect(controller.uiState.scanState, ScanState.idle);
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Timed out waiting for the expected scan state.');
}

class _PushBarcodeAdapter implements BarcodeRecognizerAdapter {
  final StreamController<BarcodeCandidate> _controller =
      StreamController<BarcodeCandidate>.broadcast();
  bool _paused = true;

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  void add(BarcodeCandidate candidate) {
    if (!_paused) _controller.add(candidate);
  }

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> dispose() => _controller.close();
}

class _PushPriceAdapter implements PriceOcrAdapter {
  final StreamController<PriceCandidate> _controller =
      StreamController<PriceCandidate>.broadcast();
  bool _paused = true;

  @override
  Stream<PriceCandidate> get results => _controller.stream;

  void add(PriceCandidate candidate) {
    if (!_paused) _controller.add(candidate);
  }

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  Future<void> dispose() => _controller.close();
}
