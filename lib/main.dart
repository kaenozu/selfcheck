import 'dart:async';

import 'package:flutter/material.dart';

import 'application/compare_use_case.dart';
import 'application/scan_coordinator.dart';
import 'infrastructure/camera_recognition_pipeline.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/price_repository.dart';
import 'infrastructure/price_repository_impl.dart';
import 'presentation/scan_screen.dart';
import 'presentation/scan_screen_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SelfCheckApp());
}

class SelfCheckApp extends StatelessWidget {
  const SelfCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自分値',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const ScanScreenEntry(),
    );
  }
}

/// Entry point that wires the device-local camera/recognition pipeline.
class ScanScreenEntry extends StatefulWidget {
  const ScanScreenEntry({super.key});

  @override
  State<ScanScreenEntry> createState() => _ScanScreenEntryState();
}

class _ScanScreenEntryState extends State<ScanScreenEntry> {
  late final AppDatabase _database;
  late final PriceRepository _repository;
  late final CompareUseCase _compareUseCase;
  late final CameraRecognitionPipeline _cameraPipeline;
  late final ScanCoordinator _coordinator;
  late final ScanScreenController _controller;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _repository = PriceRepositoryImpl(_database);
    _compareUseCase = CompareUseCase(_repository);
    _cameraPipeline = CameraRecognitionPipeline();
    _coordinator = ScanCoordinator(
      repository: _repository,
      compareUseCase: _compareUseCase,
      barcodeAdapter: CameraBarcodeAdapter(_cameraPipeline),
      priceAdapter: CameraPriceOcrAdapter(_cameraPipeline),
    );
    _controller = ScanScreenController(coordinator: _coordinator);
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraPipeline.initialize();
    } on Object {
      // The preview exposes the unavailable/permission-denied state. Starting a
      // scan remains harmless because no recognition events are produced.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _coordinator.dispose();
    _cameraPipeline.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScanScreen(
      controller: _controller,
      cameraPreview: CameraPreviewSurface(pipeline: _cameraPipeline),
    );
  }
}
