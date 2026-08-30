import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml;

import '../domain/scan_state.dart';
import '../application/scan_coordinator.dart';
import 'input_image_converter.dart';

/// ML Kit implementation of [BarcodeRecognizerAdapter].
///
/// Processes camera frames through [ml.BarcodeScanner] and emits
/// [BarcodeCandidate]s on its [results] stream. Frames are throttled
/// to at most one ML inference every [throttleDuration].
///
/// The adapter owns its own [ml.BarcodeScanner] and handles disposal.
class MlBarcodeAdapter implements BarcodeRecognizerAdapter {
  MlBarcodeAdapter({this.throttleDuration = const Duration(milliseconds: 220)})
    : _scanner = ml.BarcodeScanner(
        formats: const [ml.BarcodeFormat.ean13, ml.BarcodeFormat.ean8],
      );

  final ml.BarcodeScanner _scanner;
  final StreamController<BarcodeCandidate> _controller =
      StreamController<BarcodeCandidate>.broadcast();

  bool _paused = false;
  bool _processing = false;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration throttleDuration;

  @override
  Stream<BarcodeCandidate> get results => _controller.stream;

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  /// Process a camera frame for barcodes.
  ///
  /// Converts [CameraImage] to [InputImage] via [InputImageConverter], runs
  /// ML Kit barcode detection, and emits the first valid [BarcodeCandidate].
  /// Silently skips if paused, already processing, or throttled.
  Future<void> processFrame(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_paused || _processing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessed) < throttleDuration) return;
    _lastProcessed = now;

    _processing = true;
    try {
      final inputImage = InputImageConverter.fromCameraImage(
        image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (inputImage == null) return;

      final barcodes = await _scanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final candidate = _toBarcodeCandidate(barcode);
        if (candidate != null && !_controller.isClosed) {
          _controller.add(candidate);
          break; // emit only the first valid barcode per frame
        }
      }
    } on Object catch (error, stackTrace) {
      debugPrint('MlBarcodeAdapter frame failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _processing = false;
    }
  }

  /// Convert an ML Kit [ml.Barcode] to a domain [BarcodeCandidate].
  ///
  /// Returns `null` for non-numeric values, unknown formats, or
  /// length mismatches (EAN-13 must be 13 digits, EAN-8 must be 8).
  static BarcodeCandidate? _toBarcodeCandidate(ml.Barcode barcode) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || !RegExp(r'^\d+$').hasMatch(raw)) return null;

    final format = switch (barcode.format) {
      ml.BarcodeFormat.ean13 => BarcodeFormat.ean13,
      ml.BarcodeFormat.ean8 => BarcodeFormat.ean8,
      _ => BarcodeFormat.unknown,
    };
    if (format == BarcodeFormat.unknown) return null;
    if ((format == BarcodeFormat.ean13 && raw.length != 13) ||
        (format == BarcodeFormat.ean8 && raw.length != 8)) {
      return null;
    }

    final box = barcode.boundingBox;
    return BarcodeCandidate(
      barcode: raw,
      format: format,
      confidence: 1.0,
      region: Rect(
        left: box.left,
        top: box.top,
        right: box.right,
        bottom: box.bottom,
      ),
    );
  }

  /// Release ML Kit scanner resources and close the results stream.
  void dispose() {
    unawaited(_scanner.close());
    unawaited(_controller.close());
  }
}
