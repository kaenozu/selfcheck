import 'package:flutter/material.dart';
import 'domain/scan_state.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/price_repository_impl.dart';
import 'infrastructure/price_repository.dart';
import 'application/compare_use_case.dart';
import 'application/scan_coordinator.dart';
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

/// Entry point that wires up all dependencies
class ScanScreenEntry extends StatefulWidget {
  const ScanScreenEntry({super.key});

  @override
  State<ScanScreenEntry> createState() => _ScanScreenEntryState();
}

class _ScanScreenEntryState extends State<ScanScreenEntry> {
  late final AppDatabase _database;
  late final PriceRepository _repository;
  late final CompareUseCase _compareUseCase;
  late final ScanCoordinator _coordinator;
  late final ScanScreenController _controller;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _repository = PriceRepositoryImpl(_database);
    _compareUseCase = CompareUseCase(_repository);
    _coordinator = ScanCoordinator(
      repository: _repository,
      compareUseCase: _compareUseCase,
      barcodeAdapter: _StubBarcodeAdapter(),
      priceAdapter: _StubPriceOcrAdapter(),
    );
    _controller = ScanScreenController(coordinator: _coordinator);
  }

  @override
  void dispose() {
    _controller.dispose();
    _coordinator.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScanScreen(controller: _controller);
  }
}

/// Stub barcode adapter - will be replaced with real camera/ML Kit
class _StubBarcodeAdapter implements BarcodeRecognizerAdapter {
  @override
  Stream<BarcodeCandidate> get results => const Stream.empty();

  @override
  void pause() {}

  @override
  void resume() {}
}

/// Stub price OCR adapter - will be replaced with real OCR
class _StubPriceOcrAdapter implements PriceOcrAdapter {
  @override
  Stream<PriceCandidate> get results => const Stream.empty();

  @override
  void pause() {}

  @override
  void resume() {}
}
