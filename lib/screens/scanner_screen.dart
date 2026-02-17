import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool isSidebarOpen = false;
  double zoomLevel = 1.0;
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  final ImagePicker _imagePicker = ImagePicker();

  // Sample history data
  final List<Map<String, dynamic>> scanHistory = [
    {'code': '9780201379624', 'type': 'ISBN', 'date': '2024-01-15 10:30 AM'},
    {'code': '5901234123457', 'type': 'EAN-13', 'date': '2024-01-15 09:15 AM'},
    {'code': '123456789012', 'type': 'CODE128', 'date': '2024-01-14 04:45 PM'},
  ];

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
      if (isSidebarOpen) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Process the image for barcode scanning
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image for barcode...')),
        );
        // Here you would implement barcode detection from image
        // For now, we'll just show a message
        Navigator.pop(context, 'Scanned from image: ${image.path}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void shareApp() {
    // Implement app sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share app dialog would open here')),
    );
  }

  void openSettings() {
    // Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings screen would open here')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Scanner Content
          Stack(
            children: [
              // Scanner with custom overlay
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null) {
                      // Add to history
                      setState(() {
                        scanHistory.insert(0, {
                          'code': code,
                          'type': barcodes.first.format.name,
                          'date': DateTime.now().toString().substring(0, 19),
                        });
                      });
                      Navigator.pop(context, code);
                    }
                  }
                },
              ),

              // Scanner overlay with scan area
              CustomPaint(
                painter: ScannerOverlayPainter(),
                child: Container(),
              ),

              // Animated scan line
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        children: [
                          _CornerMarker(
                            alignment: Alignment.topLeft,
                            rotation: 0,
                          ),
                          _CornerMarker(
                            alignment: Alignment.topRight,
                            rotation: 90,
                          ),
                          _CornerMarker(
                            alignment: Alignment.bottomLeft,
                            rotation: 270,
                          ),
                          _CornerMarker(
                            alignment: Alignment.bottomRight,
                            rotation: 180,
                          ),
                          _AnimatedScanLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top Bar with Sidebar Toggle
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sidebar Toggle Button
                    GestureDetector(
                      onTap: toggleSidebar,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Title
                    Column(
                      children: [
                        const Text(
                          'AfPay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Scan Barcode',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    // Settings Button
                    GestureDetector(
                      onTap: openSettings,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Zoom Control
              Positioned(
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
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            zoomLevel = (zoomLevel + 0.5).clamp(1.0, 3.0);
                            controller.setZoomScale(zoomLevel);
                          });
                        },
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${zoomLevel.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            zoomLevel = (zoomLevel - 0.5).clamp(1.0, 3.0);
                            controller.setZoomScale(zoomLevel);
                          });
                        },
                        child: const Icon(
                          Icons.zoom_out,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.photo_library,
                      label: "Upload",
                      onTap: pickImageFromGallery,
                    ),
                    _buildActionButton(
                      icon: Icons.history,
                      label: "History",
                      onTap: () {
                        // Show history in sidebar or navigate
                        toggleSidebar();
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.share,
                      label: "Share App",
                      onTap: shareApp,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sidebar (History Panel)
          if (isSidebarOpen)
            GestureDetector(
              onTap: toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Animated Sidebar
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -MediaQuery.of(context).size.width * (1 - _sidebarAnimation.value),
                  0,
                ),
                child: child,
              );
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Sidebar Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.purple.shade700],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.qr_code_scanner,
                            size: 30,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Your recent scans',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // History List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: scanHistory.length,
                      itemBuilder: (context, index) {
                        final item = scanHistory[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.qr_code,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            title: Text(
                              item['code'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item['type']} • ${item['date']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  scanHistory.removeAt(index);
                                });
                              },
                            ),
                            onTap: () {
                              // Show scan details
                              Navigator.pop(context, item['code']);
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Sidebar Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSidebarAction(
                          icon: Icons.share,
                          label: 'Share',
                          onTap: shareApp,
                        ),
                        _buildSidebarAction(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: openSettings,
                        ),
                        _buildSidebarAction(
                          icon: Icons.clear_all,
                          label: 'Clear',
                          onTap: () {
                            setState(() {
                              scanHistory.clear();
                            });
                            toggleSidebar();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  final Alignment alignment;
  final double rotation;

  const _CornerMarker({
    required this.alignment,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.8),
                width: 4,
              ),
              left: BorderSide(
                color: Colors.white.withOpacity(0.8),
                width: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedScanLine extends StatefulWidget {
  const _AnimatedScanLine();

  @override
  State<_AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<_AnimatedScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _animation.value,
          left: 25,
          right: 25,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.8),
                  Colors.white,
                  Colors.white.withOpacity(0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Create a dark overlay with a cutout for the scanner area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate scanner area (centered square)
    final double scannerSize = size.width * 0.7;
    final double left = (size.width - scannerSize) / 2;
    final double top = (size.height - scannerSize) / 2;

    // Create cutout path
    final cutoutPath = Path()
      ..addRect(Rect.fromLTWH(left, top, scannerSize, scannerSize));

    // Subtract cutout from overlay
    final overlayPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, paint);

    // Draw rounded rectangle outline around scanner area
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scannerSize, scannerSize),
        const Radius.circular(16),
      ),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}