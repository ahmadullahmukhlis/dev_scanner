import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'scan_result_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'saved_screen.dart';
import 'help_screen.dart';
import '../widgets/corner_marker.dart';
import '../widgets/animated_scan_line.dart';
import '../widgets/scanner_overlay_painter.dart';
import 'dart:io';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final ImagePicker _imagePicker = ImagePicker();

  bool isSidebarOpen = false;
  bool isProcessing = false; // 🔥 prevents duplicate navigation
  double zoomLevel = 1.0;

  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;

  final List<Map<String, dynamic>> scanHistory = [];

  @override
  void initState() {
    super.initState();

    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _sidebarController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    setState(() {
      isSidebarOpen = !isSidebarOpen;
      isSidebarOpen
          ? _sidebarController.forward()
          : _sidebarController.reverse();
    });
  }

  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image =
      await _imagePicker.pickImage(source: ImageSource.gallery);

      if (!mounted) return;

      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image...')),
        );

        await controller.stop();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              barcodeData: "Detected from image",
              format: "IMAGE",
              imagePath: image.path,
            ),
          ),
        ).then((_) async {
          if (mounted) {
            await controller.start();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    isProcessing = true;

    await controller.stop();

    scanHistory.insert(0, {
      'code': code,
      'type': barcodes.first.format.name,
      'date': _getCurrentDateTime(),
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          barcodeData: code,
          format: barcodes.first.format.name,
        ),
      ),
    ).then((_) async {
      isProcessing = false;
      if (mounted) {
        await controller.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildScanner(),
            _buildTopBar(),
            _buildZoomControl(),
            _buildBottomButtons(),
            if (isSidebarOpen) _buildSidebarOverlay(),
            _buildSidebar(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _handleDetection,
        ),

        CustomPaint(
          painter: ScannerOverlayPainter(),
          child: Container(),
        ),

        const Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  children: [
                    CornerMarker(alignment: Alignment.topLeft, rotation: 0),
                    CornerMarker(alignment: Alignment.topRight, rotation: 90),
                    CornerMarker(alignment: Alignment.bottomLeft, rotation: 270),
                    CornerMarker(alignment: Alignment.bottomRight, rotation: 180),
                    AnimatedScanLine(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.menu, toggleSidebar),
          const Column(
            children: [
              Text(
                'AfPay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Scan Barcode',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          _circleButton(Icons.settings, () {}),
        ],
      ),
    );
  }

  Widget _buildZoomControl() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).size.height / 2 - 100,
      child: Container(
        width: 40,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_in, color: Colors.white),
              onPressed: () {
                zoomLevel = (zoomLevel + 0.5).clamp(1.0, 3.0);
                controller.setZoomScale(zoomLevel);
                setState(() {});
              },
            ),
            Text(
              '${zoomLevel.toStringAsFixed(1)}x',
              style: const TextStyle(color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out, color: Colors.white),
              onPressed: () {
                zoomLevel = (zoomLevel - 0.5).clamp(1.0, 3.0);
                controller.setZoomScale(zoomLevel);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(Icons.photo_library, "Upload", pickImageFromGallery),
          _actionButton(Icons.history, "History", () {}),
          _actionButton(Icons.share, "Share", () {}),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _actionButton(
      IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: toggleSidebar,
      child: Container(color: Colors.black54),
    );
  }

  Widget _buildSidebar() {
    return AnimatedBuilder(
      animation: _sidebarAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            -MediaQuery.of(context).size.width *
                (1 - _sidebarAnimation.value),
            0,
          ),
          child: child,
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height: double.infinity,
        color: Colors.white,
      ),
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
  }
}
