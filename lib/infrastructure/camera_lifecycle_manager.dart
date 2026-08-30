import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';

/// Manages camera lifecycle: initialization, image streaming, and disposal.
///
/// Decoupled from ML Kit recognizers so camera hardware concerns stay
/// independent of ML inference.
class CameraLifecycleManager {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _disposed = false;
  Object? _initializationError;

  CameraController? get controller => _controller;
  CameraDescription? get camera => _camera;
  bool get isReady => _controller?.value.isInitialized ?? false;
  Object? get initializationError => _initializationError;

  /// Initialize the back camera and start the image stream.
  ///
  /// [onImage] is called for every frame delivered by the camera.
  /// Throws if no camera is available or initialization fails.
  Future<void> initialize({
    required void Function(CameraImage image) onImage,
  }) async {
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
      _controller = controller;
      await controller.initialize();
      await controller.startImageStream(onImage);
    } on Object catch (error) {
      _initializationError = error;
      rethrow;
    }
  }

  /// Stop the image stream without disposing the camera controller.
  Future<void> stopImageStream() async {
    final c = _controller;
    if (c != null && c.value.isStreamingImages) {
      await c.stopImageStream();
    }
  }

  /// Release all camera resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final c = _controller;
    if (c != null) {
      unawaited(c.stopImageStream());
      unawaited(c.dispose());
    }
    _controller = null;
  }
}
