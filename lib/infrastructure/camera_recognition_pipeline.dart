import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml_barcode;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../application/scan_coordinator.dart';
import '../domain/scan_state.dart';
import 'price_text_parser.dart';

/// Owns the live camera and on-device ML Kit recognizers.
///
/// Frames are processed in memory only. This class never calls takePicture,
/// never writes camera bytes to disk, and keeps at most one ML inference in
/// flight to avoid unbounded frame queues.
class CameraRecognitionPipeline extends ChangeNotifier {
  CameraRecognitionPipeline()
    : _barcodeScanner = ml_barcode.BarcodeScanner(
        formats: const [
          ml_barcode.BarcodeFormat.ean13,
          ml_barcode.BarcodeFormat.ean8,
        ],
      ),
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final ml_barcode.BarcodeScanner _barcodeScanner;
  final TextRecognizer _textRecognizer;
  final StreamController<BarcodeCandidate> _barcodeResults =
      StreamController<BarcodeCandidate>.broadcast();
  final StreamController<PriceCandidate> _priceResults =
      StreamController<PriceCandidate>.broadcast();

  CameraController? _cameraController;
  CameraDescription? _camera;
  bool _barcodeEnabled = false;
  bool _priceEnabled = false;
  bool _processing = false;
  bool _disposed = false;
  Object? _initializationError;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<BarcodeCandidate> get barcodeResults => _barcodeResults.stream;
  Stream<PriceCandidate> get priceResults => _priceResults.stream;
  CameraController? get cameraController => _cameraController;
  bool get isReady => _cameraController?.value.isInitialized ?? false;
  Object? get initializationError => _initializationError;

  Future<void> initialize() async {
    if (_disposed || isReady) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.startImageStream(_onCameraImage);
      if (!_disposed) notifyListeners();
    } on Object catch (error) {
      _initializationError = error;
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  void enableBarcode() => _barcodeEnabled = true;
  void disableBarcode() => _barcodeEnabled = false;
  void enablePrice() => _priceEnabled = true;
  void disablePrice() => _priceEnabled = false;

  Future<void> _onCameraImage(CameraImage image) async {
    if (_disposed || _processing || (!_barcodeEnabled && !_priceEnabled)) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastProcessed) < const Duration(milliseconds: 220)) {
      return;
    }
    _lastProcessed = now;
    _processing = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      if (_barcodeEnabled) {
        final barcodes = await _barcodeScanner.processImage(inputImage);
        for (final barcode in barcodes) {
          final candidate = _toBarcodeCandidate(barcode);
          if (candidate != null && !_barcodeResults.isClosed) {
            _barcodeResults.add(candidate);
            break;
          }
        }
      }

      if (_priceEnabled) {
        final text = await _textRecognizer.processImage(inputImage);
        final candidate = parsePriceText(
          text.blocks.expand(
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
        if (candidate != null && !_priceResults.isClosed) {
          _priceResults.add(candidate);
        }
      }
    } on Object catch (error, stackTrace) {
      debugPrint('CameraRecognitionPipeline frame failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _cameraController;
    if (camera == null || controller == null) return null;

    final rotation = _inputImageRotation(
      camera,
      controller.value.deviceOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final compensation = orientations[deviceOrientation];
    if (compensation == null) return null;

    final rotationCompensation =
        camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  BarcodeCandidate? _toBarcodeCandidate(ml_barcode.Barcode barcode) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || !RegExp(r'^\d+$').hasMatch(raw)) return null;

    final format = switch (barcode.format) {
      ml_barcode.BarcodeFormat.ean13 => BarcodeFormat.ean13,
      ml_barcode.BarcodeFormat.ean8 => BarcodeFormat.ean8,
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _barcodeEnabled = false;
    _priceEnabled = false;
    unawaited(_cameraController?.stopImageStream());
    unawaited(_cameraController?.dispose());
    unawaited(_barcodeScanner.close());
    unawaited(_textRecognizer.close());
    unawaited(_barcodeResults.close());
    unawaited(_priceResults.close());
    super.dispose();
  }
}

class CameraBarcodeAdapter implements BarcodeRecognizerAdapter {
  const CameraBarcodeAdapter(this.pipeline);
  final CameraRecognitionPipeline pipeline;

  @override
  Stream<BarcodeCandidate> get results => pipeline.barcodeResults;

  @override
  void pause() => pipeline.disableBarcode();

  @override
  void resume() => pipeline.enableBarcode();
}

class CameraPriceOcrAdapter implements PriceOcrAdapter {
  const CameraPriceOcrAdapter(this.pipeline);
  final CameraRecognitionPipeline pipeline;

  @override
  Stream<PriceCandidate> get results => pipeline.priceResults;

  @override
  void pause() => pipeline.disablePrice();

  @override
  void resume() => pipeline.enablePrice();
}

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
