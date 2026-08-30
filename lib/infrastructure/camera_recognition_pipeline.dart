import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../application/scan_coordinator.dart';
import '../domain/scan_state.dart';
import 'camera_lifecycle_manager.dart';
import 'input_image_converter.dart';
import 'ml_barcode_adapter.dart';
import 'ml_price_ocr_adapter.dart';

export 'camera_lifecycle_manager.dart' show CameraLifecycleManager;
export 'input_image_converter.dart' show InputImageConverter;
export 'ml_barcode_adapter.dart' show MlBarcodeAdapter;
export 'ml_price_ocr_adapter.dart' show MlPriceOcrAdapter;

/// Thin orchestrator that owns camera lifecycle, ML Kit recognizers, and
/// frame dispatching.
///
/// Delegates to:
/// - [CameraLifecycleManager] for camera hardware
/// - [MlBarcodeAdapter] for barcode recognition
/// - [MlPriceOcrAdapter] for price OCR
/// - [InputImageConverter] for frame format conversion
///
/// This class is the only one that knows about all four components.
/// Each component can be tested independently.
class CameraRecognitionPipeline extends ChangeNotifier {
  CameraRecognitionPipeline({
    CameraLifecycleManager? cameraManager,
    MlBarcodeAdapter? barcodeAdapter,
    MlPriceOcrAdapter? priceOcrAdapter,
  }) : _cameraManager = cameraManager ?? CameraLifecycleManager(),
       _barcodeAdapter = barcodeAdapter ?? MlBarcodeAdapter(),
       _priceOcrAdapter = priceOcrAdapter ?? MlPriceOcrAdapter();

  final CameraLifecycleManager _cameraManager;
  final MlBarcodeAdapter _barcodeAdapter;
  final MlPriceOcrAdapter _priceOcrAdapter;
  bool _disposed = false;

  // ── Public API (used by main.dart and CameraPreviewSurface) ──

  Stream<BarcodeCandidate> get barcodeResults => _barcodeAdapter.results;
  Stream<PriceCandidate> get priceResults => _priceOcrAdapter.results;
  CameraController? get cameraController => _cameraManager.controller;
  bool get isReady => _cameraManager.isReady;
  Object? get initializationError => _cameraManager.initializationError;

  /// Initialize camera and start frame processing.
  Future<void> initialize() async {
    if (_disposed || isReady) return;
    try {
      await _cameraManager.initialize(onImage: _onCameraImage);
      if (!_disposed) notifyListeners();
    } on Object {
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  void enableBarcode() => _barcodeAdapter.resume();
  void disableBarcode() => _barcodeAdapter.pause();
  void enablePrice() => _priceOcrAdapter.resume();
  void disablePrice() => _priceOcrAdapter.pause();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _barcodeAdapter.pause();
    _priceOcrAdapter.pause();
    _cameraManager.dispose();
    _barcodeAdapter.dispose();
    _priceOcrAdapter.dispose();
    super.dispose();
  }

  // ── Internal frame dispatching ──

  /// Dispatch a single camera frame to the active adapters.
  Future<void> _onCameraImage(CameraImage image) async {
    if (_disposed) return;

    final camera = _cameraManager.camera;
    final controller = _cameraManager.controller;
    if (camera == null || controller == null) return;

    // Dispatch to barcode adapter (respects its own pause/throttle state)
    _barcodeAdapter.processFrame(
      image,
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
    );

    // Dispatch to price OCR adapter (respects its own pause/throttle state)
    _priceOcrAdapter.processFrame(
      image,
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
    );
  }
}

/// Adapter that bridges [CameraRecognitionPipeline] to the
/// [BarcodeRecognizerAdapter] interface expected by [ScanCoordinator].
class CameraBarcodeAdapter implements BarcodeRecognizerAdapter {
  const CameraBarcodeAdapter(this._adapter);
  final MlBarcodeAdapter _adapter;

  @override
  Stream<BarcodeCandidate> get results => _adapter.results;

  @override
  void pause() => _adapter.pause();

  @override
  void resume() => _adapter.resume();
}

/// Adapter that bridges [CameraRecognitionPipeline] to the
/// [PriceOcrAdapter] interface expected by [ScanCoordinator].
class CameraPriceOcrAdapter implements PriceOcrAdapter {
  const CameraPriceOcrAdapter(this._adapter);
  final MlPriceOcrAdapter _adapter;

  @override
  Stream<PriceCandidate> get results => _adapter.results;

  @override
  void pause() => _adapter.pause();

  @override
  void resume() => _adapter.resume();
}

/// Widget that displays the live camera preview.
///
/// Listens to [CameraRecognitionPipeline] (a [ChangeNotifier]) to rebuild
/// when the camera state changes.
class CameraPreviewSurface extends StatelessWidget {
  const CameraPreviewSurface({super.key, required this.pipeline});

  final CameraRecognitionPipeline pipeline;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pipeline,
      builder: (context, _) {
        final controller = pipeline.cameraController;
        if (controller != null && controller.value.isInitialized) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          );
        }

        if (pipeline.initializationError != null) {
          return const ColoredBox(
            color: Color(0xFF1A1A2E),
            child: Center(
              child: Icon(
                Icons.no_photography,
                size: 72,
                color: Colors.white30,
              ),
            ),
          );
        }

        return const ColoredBox(
          color: Color(0xFF1A1A2E),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
