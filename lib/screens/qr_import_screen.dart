import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/constants.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/scanner_overlay_painter.dart';
import '../widgets/corner_marker.dart';
import '../widgets/animated_scan_line.dart';

class QrImportScreen extends StatefulWidget {
  const QrImportScreen({Key? key}) : super(key: key);

  @override
  State<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends State<QrImportScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isDetected = false;
  double _zoomLevel = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: Stack(
        children: [
          _buildScanner(),
          _buildTopActions(),
          _buildZoomBar(),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan a QR code that contains JSON data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_isDetected) return;
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final code = barcodes.first.rawValue;
            if (code == null) return;
            _isDetected = true;
            Navigator.pop(context, code);
          },
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

  Widget _buildTopActions() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchState = state.torchState;
              if (torchState == TorchState.unavailable) return const SizedBox.shrink();
              final isOn = torchState == TorchState.on;
              return _buildOverlayButton(
                icon: isOn ? Icons.flash_on : Icons.flash_off,
                onTap: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildZoomBar() {
    final size = MediaQuery.of(context).size;
    final scannerSize = size.width * 0.7;
    final top = (size.height - scannerSize) / 2;
    final barTop = top + scannerSize + 12;
    return Positioned(
      top: barTop,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _zoomLevel = (_zoomLevel - 0.1).clamp(0.0, 1.0);
                  _controller.setZoomScale(_zoomLevel);
                });
              },
              child: const Icon(Icons.remove, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: _zoomLevel,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_zoomLevel * 100).round()}%',
                activeColor: Colors.white,
                inactiveColor: Colors.white.withOpacity(0.4),
                onChanged: (value) {
                  setState(() {
                    _zoomLevel = value;
                    _controller.setZoomScale(_zoomLevel);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_zoomLevel * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _zoomLevel = (_zoomLevel + 0.1).clamp(0.0, 1.0);
                  _controller.setZoomScale(_zoomLevel);
                });
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
