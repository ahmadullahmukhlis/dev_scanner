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
import '../utils/db_helper.dart';
import '../models/scan_history_model.dart';
import 'dart:io';

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
  final DBHelper _dbHelper = DBHelper();

  final List<Map<String, dynamic>> menuItems = [
    {'icon': Icons.qr_code_scanner, 'title': 'Scanner', 'page': 'scanner'},
    {'icon': Icons.history, 'title': 'History', 'page': 'history'},
    {'icon': Icons.bookmark, 'title': 'Saved', 'page': 'saved'},
    {'icon': Icons.settings, 'title': 'Settings', 'page': 'settings'},
    {'icon': Icons.help, 'title': 'Help', 'page': 'help'},
    {'icon': Icons.share, 'title': 'Share App', 'page': 'share'},
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

  void navigateTo(String page) {
    toggleSidebar();

    if (page == 'history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HistoryScreen(),
        ),
      ).then((_) {
        // Refresh when returning from history
        setState(() {});
      });
    } else if (page == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
        ),
      );
    } else if (page == 'saved') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SavedScreen(),
        ),
      );
    } else if (page == 'help') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HelpScreen(),
        ),
      );
    } else if (page == 'share') {
      _shareApp();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigating to $page')),
      );
    }
  }

  Future<void> _saveScanToHistory(String code, String type) async {
    final scan = ScanHistoryModel(
      code: code,
      type: type,
      date: _getCurrentDateTime(),
      product: 'Product ${await _dbHelper.getScanCount() + 1}',
    );
    await _dbHelper.insertScan(scan);
  }

  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image for barcode...')),
        );

        Future.delayed(const Duration(seconds: 1), () async {
          final mockCode = '';
          final mockType = 'EAN-13';

          // Save to database
          await _saveScanToHistory(mockCode, mockType);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScanResultScreen(
                  barcodeData: mockCode,
                  format: mockType,
                  imagePath: image.path,
                ),
              ),
            ).then((_) {
              controller.start();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _shareApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share app dialog would open here')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildScanner(),
          _buildTopBar(),
          _buildZoomControl(),
          _buildBottomButtons(),
          if (isSidebarOpen) _buildSidebarOverlay(),
          _buildSidebar(),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                controller.stop();

                // Save to database
                await _saveScanToHistory(code, barcodes.first.format.name);

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanResultScreen(
                        barcodeData: code,
                        format: barcodes.first.format.name,
                      ),
                    ),
                  ).then((_) {
                    controller.start();
                  });
                }
              }
            }
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

  Widget _buildTopBar() {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: toggleSidebar,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 24),
            ),
          ),
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
          GestureDetector(
            onTap: () => navigateTo('settings'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 24),
            ),
          ),
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
            GestureDetector(
              onTap: () {
                setState(() {
                  zoomLevel = (zoomLevel + 0.5).clamp(1.0, 3.0);
                  controller.setZoomScale(zoomLevel);
                });
              },
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
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
              child: const Icon(Icons.zoom_out, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Positioned(
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
            onTap: () => navigateTo('history'),
          ),
          _buildActionButton(
            icon: Icons.share,
            label: "Share App",
            onTap: _shareApp,
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
            child: Icon(icon, color: Colors.white, size: 24),
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

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: toggleSidebar,
      child: Container(
        color: Colors.black.withOpacity(0.5),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedBuilder(
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
        width: MediaQuery.of(context).size.width * 0.75,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildSidebarMenu(),
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarMenu() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return ListTile(
            leading: Icon(
              item['icon'],
              color: index == 0 ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            title: Text(
              item['title'],
              style: TextStyle(
                color: index == 0 ? Colors.blue.shade700 : Colors.black87,
                fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: item['page'] == 'share'
                ? const Icon(Icons.open_in_new, size: 16, color: Colors.grey)
                : null,
            onTap: () => navigateTo(item['page']),
          );
        },
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSidebarFooterItem(
            icon: Icons.logout,
            label: 'Logout',
            color: Colors.red,
          ),
          _buildSidebarFooterItem(
            icon: Icons.info,
            label: 'About',
            color: Colors.blue,
          ),
          _buildSidebarFooterItem(
            icon: Icons.privacy_tip,
            label: 'Privacy',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooterItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label tapped')),
        );
      },
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}