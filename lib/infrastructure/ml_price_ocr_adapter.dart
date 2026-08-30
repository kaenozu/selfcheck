import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../application/scan_coordinator.dart';
import '../domain/scan_state.dart';
import 'input_image_converter.dart';
import 'price_text_parser.dart';

/// ML Kit implementation of [PriceOcrAdapter].
///
/// Processes camera frames through [TextRecognizer] and emits
/// [PriceCandidate]s extracted by [parsePriceText]. Frames are throttled
/// to at most one ML inference every [throttleDuration].
///
/// The adapter owns its own [TextRecognizer] and handles disposal.
class MlPriceOcrAdapter implements PriceOcrAdapter {
  MlPriceOcrAdapter({this.throttleDuration = const Duration(milliseconds: 220)})
    : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _textRecognizer;
  final StreamController<PriceCandidate> _controller =
      StreamController<PriceCandidate>.broadcast();

  bool _paused = false;
  bool _processing = false;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration throttleDuration;

  @override
  Stream<PriceCandidate> get results => _controller.stream;

  @override
  void pause() => _paused = true;

  @override
  void resume() => _paused = false;

  /// Process a camera frame for price text.
  ///
  /// Converts [CameraImage] to [InputImage] via [InputImageConverter], runs
  /// ML Kit text recognition, and emits a [PriceCandidate] if a valid price
  /// is found. Silently skips if paused, already processing, or throttled.
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

      final recognized = await _textRecognizer.processImage(inputImage);
      final candidate = parsePriceText(
        recognized.blocks.expand(
          (block) => block.lines.map(
            (line) => (
              text: line.text,
              region: Rect(
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                right: line.boundingBox.right,
                bottom: line.boundingBox.bottom,
              ),
            ),
          ),
        ),
      );
      if (candidate != null && !_controller.isClosed) {
        _controller.add(candidate);
      }
    } on Object catch (error, stackTrace) {
      debugPrint('MlPriceOcrAdapter frame failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _processing = false;
    }
  }

  /// Release ML Kit text recognizer resources and close the results stream.
  void dispose() {
    unawaited(_textRecognizer.close());
    unawaited(_controller.close());
  }
}
