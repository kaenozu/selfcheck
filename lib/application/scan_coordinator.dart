import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/scan_state.dart';
import '../domain/comparison_result.dart';
import '../infrastructure/price_repository.dart';
import '../infrastructure/price_stabilizer.dart';
import 'compare_use_case.dart';

/// ScanCoordinator manages the scanning session lifecycle
///
/// Emits state changes via [stateStream] and comparison results via [resultStream].
/// Uses [CompareUseCase] for the actual comparison logic to avoid duplication.
///
/// Error handling:
/// - DB failures in [_compare] emit [ScanState.error] and reset to idle on retry.
/// - Adapter stream errors are caught and surfaced through [errorStream].
/// - All throwables (Exception AND Error) are caught, never swallowed.
class ScanCoordinator {
  final PriceRepository _repository;
  final CompareUseCase _compareUseCase;
  final PriceStabilizer _stabilizer;
  final BarcodeRecognizerAdapter _barcodeAdapter;
  final PriceOcrAdapter _priceAdapter;

  ScanState _state = ScanState.idle;

  /// Last error message (cleared on next successful scan start)
  String? _lastError;
  String? get lastError => _lastError;

  /// Cached barcode candidate (set in waitingPrice, consumed in _compare)
  BarcodeCandidate? _pendingBarcode;

  final StreamController<ScanState> _stateController =
      StreamController<ScanState>.broadcast();

  final StreamController<ComparisonResult> _resultController =
      StreamController<ComparisonResult>.broadcast();

  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  /// State changes (idle, scanning, waitingPrice, comparing, result, error)
  Stream<ScanState> get stateStream => _stateController.stream;

  /// Comparison results (emitted once when compare completes)
  Stream<ComparisonResult> get resultStream => _resultController.stream;

  /// Error events (emitted on DB failure, adapter error, etc.)
  Stream<String?> get errorStream => _errorController.stream;

  ScanState get currentState => _state;

  StreamSubscription? _barcodeSubscription;
  StreamSubscription? _priceSubscription;

  ScanCoordinator({
    required this._repository,
    required this._compareUseCase,
    PriceStabilizer? stabilizer,
    required this._barcodeAdapter,
    required this._priceAdapter,
  }) : _stabilizer = stabilizer ?? PriceStabilizer();

  void startScan() {
    if (_state != ScanState.idle && _state != ScanState.error) return;

    _state = ScanState.scanning;
    _lastError = null;
    _stateController.add(_state);
    _stabilizer.reset();
    _pendingBarcode = null;

    _barcodeSubscription = _barcodeAdapter.results.listen(
      (barcode) {
        try {
          _onBarcodeDetected(barcode);
        } catch (e, st) {
          _handleAdapterError('バーコード処理エラー', e, st);
        }
      },
      onError: (Object error, StackTrace st) {
        _handleAdapterError('バーコード認識ストリームエラー', error, st);
      },
    );

    _priceSubscription = _priceAdapter.results.listen(
      (price) {
        try {
          _onPriceDetected(price);
        } catch (e, st) {
          _handleAdapterError('価格OCR処理エラー', e, st);
        }
      },
      onError: (Object error, StackTrace st) {
        _handleAdapterError('価格OCRストリームエラー', error, st);
      },
    );
  }

  void cancelScan() {
    _barcodeSubscription?.cancel();
    _priceSubscription?.cancel();
    _pendingBarcode = null;
    _state = ScanState.idle;
    _stateController.add(_state);
  }

  void _onBarcodeDetected(BarcodeCandidate barcode) {
    if (_state != ScanState.scanning) return;

    _barcodeAdapter.pause();
    _priceAdapter.pause();

    if (_stabilizer.currentPrice != null) {
      // Both barcode and price available — compare immediately
      _compare(barcode, _stabilizer.currentPrice!, _stabilizer.confidence);
    } else {
      // Barcode found first — wait for price to stabilize
      _pendingBarcode = barcode;
      _state = ScanState.waitingPrice;
      _stateController.add(_state);
      _priceAdapter.resume();
    }
  }

  void _onPriceDetected(PriceCandidate price) async {
    if (_state != ScanState.scanning && _state != ScanState.waitingPrice)
      return;

    final isStable = _stabilizer.submit(price);

    if (isStable) {
      _barcodeAdapter.pause();
      _priceAdapter.pause();

      if (_state == ScanState.waitingPrice && _pendingBarcode != null) {
        // Price stabilized while waiting — we have both, compare
        _compare(_pendingBarcode!, price.priceYen, price.confidence);
      } else {
        // Price only (no barcode) — inform user, resume scanning
        _state = ScanState.noProduct;
        _stateController.add(_state);
        await Future.delayed(const Duration(milliseconds: 500));
        _barcodeAdapter.resume();
        _priceAdapter.resume();
        _state = ScanState.scanning;
        _stateController.add(_state);
      }
    }
  }

  Future<void> _compare(
    BarcodeCandidate barcode,
    int priceYen,
    double confidence,
  ) async {
    _state = ScanState.comparing;
    _stateController.add(_state);

    try {
      // Find or create product
      var product = await _repository.findProductByJan(barcode.barcode);
      product ??= await _repository.createProvisionalProduct(barcode.barcode);

      // Check for duplicate — skip save if already recorded recently
      final isDup = await _repository.isDuplicate(
        productId: product.id,
        priceYen: priceYen,
        observedAt: DateTime.now(),
      );

      // If duplicate, show comparison without saving a new observation
      final result = await _compareUseCase.compare(
        currentPriceYen: priceYen,
        productId: product.id,
        currentConfidence: confidence,
        skipInsert: isDup,
      );
      _resultController.add(result);

      _pendingBarcode = null;
      _state = ScanState.result;
      _stateController.add(_state);
    } on Exception catch (e, st) {
      _handleCompareError(e, st);
    } on Error catch (e, st) {
      // Catch StackOverflowError, StateError, etc. that aren't Exceptions
      _handleCompareError(e, st);
    }
  }

  void _handleCompareError(Object error, StackTrace stackTrace) {
    debugPrint('ScanCoordinator._compare failed: $error');
    debugPrint('$stackTrace');

    final message = _friendlyErrorMessage(error);
    _lastError = message;
    _errorController.add(message);

    _pendingBarcode = null;
    _state = ScanState.error;
    _stateController.add(_state);
  }

  void _handleAdapterError(String context, Object error, StackTrace st) {
    debugPrint('ScanCoordinator adapter error ($context): $error');
    debugPrint('$st');

    final message = '$context: ${_friendlyErrorMessage(error)}';
    _lastError = message;
    _errorController.add(message);

    // Don't change state — adapter errors are usually transient.
    // The scan continues and the error is surfaced to the user.
  }

  /// Convert technical errors to user-friendly Japanese messages
  String _friendlyErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains('SqliteException') || text.contains('database')) {
      return 'データベースエラーが発生しました。もう一度お試しください。';
    }
    if (text.contains(' disk ') || text.contains(' SQLITE_FULL')) {
      return 'ストレージ容量が不足しています。';
    }
    if (text.contains('Permission denied')) {
      return 'カメラの権限が必要です。設定から許可してください。';
    }
    // Default: generic message (don't expose raw error to user)
    return '予期せぬエラーが発生しました。もう一度お試しください。';
  }

  void dispose() {
    _barcodeSubscription?.cancel();
    _priceSubscription?.cancel();
    _stateController.close();
    _resultController.close();
    _errorController.close();
  }
}

/// Adapter interfaces for barcode and price OCR
abstract class BarcodeRecognizerAdapter {
  Stream<BarcodeCandidate> get results;
  void pause();
  void resume();
}

abstract class PriceOcrAdapter {
  Stream<PriceCandidate> get results;
  void pause();
  void resume();
}
