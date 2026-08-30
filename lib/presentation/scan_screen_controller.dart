import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/scan_coordinator.dart';
import '../domain/comparison_result.dart';
import '../domain/scan_state.dart';

/// UI-facing state for the scan screen
class ScanScreenUiState {
  final ScanState scanState;
  final String? janCode;
  final int? currentPriceYen;
  final ComparisonResult? comparisonResult;
  final bool isSaving;
  final String? errorMessage;

  const ScanScreenUiState({
    this.scanState = ScanState.idle,
    this.janCode,
    this.currentPriceYen,
    this.comparisonResult,
    this.isSaving = false,
    this.errorMessage,
  });

  ScanScreenUiState copyWith({
    ScanState? scanState,
    String? janCode,
    int? currentPriceYen,
    ComparisonResult? comparisonResult,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ScanScreenUiState(
      scanState: scanState ?? this.scanState,
      janCode: janCode ?? this.janCode,
      currentPriceYen: currentPriceYen ?? this.currentPriceYen,
      comparisonResult: comparisonResult ?? this.comparisonResult,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Whether the scan button should be enabled
  bool get canStartScan =>
      scanState == ScanState.idle || scanState == ScanState.error;
  bool get isScanning =>
      scanState == ScanState.scanning || scanState == ScanState.waitingPrice;
  bool get isShowingResult => scanState == ScanState.result;
  bool get isError => scanState == ScanState.error;
}

/// ChangeNotifier that exposes scan screen state to widgets.
///
/// Scan state transitions are sourced from [ScanCoordinator]. The controller
/// does not optimistically invent a scanning state before the coordinator has
/// actually accepted a new session.
class ScanScreenController extends ChangeNotifier {
  final ScanCoordinator _coordinator;

  StreamSubscription<ScanState>? _stateSubscription;
  StreamSubscription<ComparisonResult>? _resultSubscription;
  StreamSubscription<String?>? _errorSubscription;

  ScanScreenUiState _uiState = const ScanScreenUiState();
  ScanScreenUiState get uiState => _uiState;

  ScanScreenController({required this._coordinator});

  /// Initialize and start listening to coordinator state/result/error streams
  void init() {
    _stateSubscription = _coordinator.stateStream.listen((scanState) {
      _onScanStateChanged(scanState);
    });

    _resultSubscription = _coordinator.resultStream.listen((result) {
      _uiState = _uiState.copyWith(
        comparisonResult: result,
        janCode: _coordinator.resultJanCode,
        currentPriceYen: result.currentPrice,
      );
      notifyListeners();
    });

    _errorSubscription = _coordinator.errorStream.listen((message) {
      if (message != null) {
        _uiState = _uiState.copyWith(errorMessage: message);
        notifyListeners();
      }
    });
  }

  void _onScanStateChanged(ScanState state) {
    _uiState = _uiState.copyWith(scanState: state, errorMessage: null);

    if (state == ScanState.result) {
      _uiState = _uiState.copyWith(isSaving: false);
    }

    notifyListeners();
  }

  /// Start a new scan session.
  void startScan() {
    if (!_uiState.canStartScan) return;
    _coordinator.startScan();
  }

  /// Cancel the current scan.
  void cancelScan() {
    _coordinator.cancelScan();
    _uiState = const ScanScreenUiState();
    notifyListeners();
  }

  /// Dismiss the result and return both UI and coordinator to idle.
  void dismissResult() {
    _coordinator.resetToIdle();
    _uiState = const ScanScreenUiState();
    notifyListeners();
  }

  /// Manually enter a price (for when OCR fails)
  void manualPriceEntry(int priceYen) {
    _uiState = _uiState.copyWith(currentPriceYen: priceYen);
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}
