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

  // Sample menu items
  final List<Map<String, dynamic>> menuItems = [
    {'icon': Icons.home, 'title': 'Home', 'page': 'home'},
    {'icon': Icons.qr_code_scanner, 'title': 'Scanner', 'page': 'scanner'},
    {'icon': Icons.history, 'title': 'History', 'page': 'history'},
    {'icon': Icons.bookmark, 'title': 'Saved', 'page': 'saved'},
    {'icon': Icons.settings, 'title': 'Settings', 'page': 'settings'},
    {'icon': Icons.help, 'title': 'Help', 'page': 'help'},
    {'icon': Icons.share, 'title': 'Share App', 'page': 'share'},
  ];

  // Sample history data
  final List<Map<String, dynamic>> scanHistory = [
    {'code': '9780201379624', 'type': 'ISBN', 'date': '2024-01-15 10:30 AM', 'product': 'Design Patterns Book'},
    {'code': '5901234123457', 'type': 'EAN-13', 'date': '2024-01-15 09:15 AM', 'product': 'Milk Chocolate'},
    {'code': '123456789012', 'type': 'CODE128', 'date': '2024-01-14 04:45 PM', 'product': 'Shipping Label'},
    {'code': 'ABC-123-XYZ', 'type': 'QR Code', 'date': '2024-01-14 02:30 PM', 'product': 'Product QR'},
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
    toggleSidebar(); // Close sidebar

    if (page == 'history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryScreen(
            scanHistory: scanHistory,
            onItemTap: (item) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanResultScreen(
                    barcodeData: item['code'],
                    format: item['type'],
                    productName: item['product'],
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (page == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(),
        ),
      );
    } else if (page == 'share') {
      _shareApp();
    } else if (page == 'saved') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedScreen(),
        ),
      );
    } else if (page == 'help') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HelpScreen(),
        ),
      );
    } else {
      // Handle other navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigating to $page')),
      );
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image for barcode...')),
        );
        // Simulate scanning from image
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanResultScreen(
                barcodeData: '5901234123457',
                format: 'EAN-13',
                imagePath: image.path,
              ),
            ),
          ).then((_) {
            controller.start();
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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
                      // Stop scanning
                      controller.stop();

                      // Add to history
                      scanHistory.insert(0, {
                        'code': code,
                        'type': barcodes.first.format.name,
                        'date': _getCurrentDateTime(),
                        'product': 'Product ${scanHistory.length + 1}',
                      });

                      // Navigate to result screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScanResultScreen(
                            barcodeData: code,
                            format: barcodes.first.format.name,
                          ),
                        ),
                      ).then((_) {
                        // Resume scanning when returning from result screen
                        controller.start();
                      });
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
                      onTap: () => navigateTo('settings'),
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
                      onTap: () => navigateTo('history'),
                    ),
                    _buildActionButton(
                      icon: Icons.share,
                      label: "Share App",
                      onTap: _shareApp,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sidebar Overlay
          if (isSidebarOpen)
            GestureDetector(
              onTap: toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Animated Sidebar Menu
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
                  // Sidebar Header with User Info
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                            Icons.person,
                            size: 35,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'John Doe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'john.doe@email.com',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        return ListTile(
                          leading: Icon(
                            item['icon'],
                            color: index == 1 ? Colors.blue.shade700 : Colors.grey.shade600,
                          ),
                          title: Text(
                            item['title'],
                            style: TextStyle(
                              color: index == 1 ? Colors.blue.shade700 : Colors.black87,
                              fontWeight: index == 1 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: item['page'] == 'share'
                              ? const Icon(Icons.open_in_new, size: 16, color: Colors.grey)
                              : null,
                          onTap: () => navigateTo(item['page']),
                        );
                      },
                    ),
                  ),

                  // Sidebar Footer
                  Container(
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

// History Screen
class HistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> scanHistory;
  final Function(Map<String, dynamic>) onItemTap;

  const HistoryScreen({
    Key? key,
    required this.scanHistory,
    required this.onItemTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              // Clear all history
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Are you sure you want to clear all scan history?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Clear history logic
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('History cleared')),
                        );
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: scanHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No scan history yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan barcodes to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: scanHistory.length,
        itemBuilder: (context, index) {
          final item = scanHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getTypeColor(item['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTypeIcon(item['type']),
                  color: _getTypeColor(item['type']),
                  size: 30,
                ),
              ),
              title: Text(
                item['code'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    item['product'] ?? 'Unknown Product',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(item['type']).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['type'],
                          style: TextStyle(
                            color: _getTypeColor(item['type']),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item['date'],
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () {
                  // Delete single item
                },
              ),
              onTap: () => onItemTap(item),
            ),
          );
        },
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    if (type.contains('QR')) {
      return Icons.qr_code;
    }
    return Icons.qr_code_scanner;
  }

  Color _getTypeColor(String type) {
    if (type.contains('QR')) {
      return Colors.purple;
    } else if (type.contains('ISBN')) {
      return Colors.green;
    } else if (type.contains('EAN')) {
      return Colors.orange;
    }
    return Colors.blue;
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildSettingsSection(
            'Scanner Settings',
            [
              _buildSettingsTile(
                Icons.camera_alt,
                'Camera',
                'Back Camera',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.flash_on,
                'Flash',
                'Auto',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.speed,
                'Scan Speed',
                'Normal',
                onTap: () {},
              ),
              _buildSwitchTile(
                Icons.vibration,
                'Vibration',
                'Vibrate on scan',
                value: true,
                onChanged: (value) {},
              ),
              _buildSwitchTile(
                Icons.volume_up,
                'Sound',
                'Play sound on scan',
                value: true,
                onChanged: (value) {},
              ),
            ],
          ),
          _buildSettingsSection(
            'App Settings',
            [
              _buildSettingsTile(
                Icons.language,
                'Language',
                'English',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.dark_mode,
                'Theme',
                'Light',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.notifications,
                'Notifications',
                'Enabled',
                onTap: () {},
              ),
            ],
          ),
          _buildSettingsSection(
            'About',
            [
              _buildSettingsTile(
                Icons.info,
                'Version',
                '1.0.0',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.privacy_tip,
                'Privacy Policy',
                '',
                onTap: () {},
              ),
              _buildSettingsTile(
                Icons.terminal_sharp,
                'Terms of Service',
                '',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, {required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.blue.shade700),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

// Saved Screen
class SavedScreen extends StatelessWidget {
  const SavedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Items'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved items',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save your favorite scans here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Help Screen
class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpCard(
            'How to Scan',
            'Point your camera at a barcode or QR code to scan automatically.',
            Icons.qr_code_scanner,
          ),
          _buildHelpCard(
            'Upload Image',
            'You can also upload images from your gallery to scan barcodes.',
            Icons.photo_library,
          ),
          _buildHelpCard(
            'History',
            'View your past scans in the history section.',
            Icons.history,
          ),
          _buildHelpCard(
            'Contact Us',
            'Need help? Contact our support team.',
            Icons.support_agent,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {},
      ),
    );
  }
}

// Scan Result Screen (Improved UI)
class ScanResultScreen extends StatefulWidget {
  final String barcodeData;
  final String format;
  final String? imagePath;
  final String? productName;

  const ScanResultScreen({
    Key? key,
    required this.barcodeData,
    required this.format,
    this.imagePath,
    this.productName,
  }) : super(key: key);

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isFavorite = false;
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: Colors.blue.shade700,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blue.shade700, Colors.purple.shade700],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        // Icon based on format
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.format.contains('QR') ? Icons.qr_code : Icons.qr_code_scanner,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Barcode Data
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            widget.barcodeData,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Format and timestamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.format,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getCurrentTime(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionChip(
                                icon: Icons.copy,
                                label: 'Copy',
                                onTap: _copyToClipboard,
                              ),
                              const SizedBox(width: 12),
                              _buildActionChip(
                                icon: Icons.share,
                                label: 'Share',
                                onTap: _shareResult,
                              ),
                              const SizedBox(width: 12),
                              _buildActionChip(
                                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                                label: 'Save',
                                onTap: () {
                                  setState(() {
                                    isFavorite = !isFavorite;
                                    isSaved = !isSaved;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isSaved ? 'Saved to collection' : 'Removed from collection'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue.shade700,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Details'),
                    Tab(text: 'Info'),
                    Tab(text: 'Actions'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDetailsTab(),
            _buildInfoTab(),
            _buildActionsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
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
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          icon: Icons.qr_code,
          title: 'Barcode Type',
          value: widget.format,
        ),
        _buildInfoCard(
          icon: Icons.numbers,
          title: 'Barcode Value',
          value: widget.barcodeData,
        ),
        _buildInfoCard(
          icon: Icons.access_time,
          title: 'Scan Time',
          value: _getCurrentDateTime(),
        ),
        _buildInfoCard(
          icon: Icons.shopping_bag,
          title: 'Product Name',
          value: widget.productName ?? 'Unknown Product',
        ),
        _buildInfoCard(
          icon: Icons.category,
          title: 'Category',
          value: 'General',
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          icon: Icons.description,
          title: 'Description',
          value: 'This is a sample product description. In a real app, this would be fetched from a database or API based on the barcode.',
          multiline: true,
        ),
        _buildInfoCard(
          icon: Icons.branding_watermark,
          title: 'Brand',
          value: 'Sample Brand',
        ),
        _buildInfoCard(
          icon: Icons.attach_money,
          title: 'Price',
          value: '\$29.99',
        ),
        _buildInfoCard(
          icon: Icons.star,
          title: 'Rating',
          value: '4.5 (128 reviews)',
        ),
        _buildInfoCard(
          icon: Icons.inventory,
          title: 'Availability',
          value: 'In Stock',
          valueColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildActionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.search,
          label: 'Search Online',
          color: Colors.blue,
          onTap: _searchOnline,
        ),
        _buildActionButton(
          icon: Icons.shopping_cart,
          label: 'Add to Cart',
          color: Colors.green,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to cart')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.compare_arrows,
          label: 'Compare Prices',
          color: Colors.orange,
          onTap: _comparePrices,
        ),
        _buildActionButton(
          icon: Icons.bookmark_border,
          label: 'Save to Collection',
          color: Colors.purple,
          onTap: () {
            setState(() {
              isSaved = !isSaved;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSaved ? 'Saved to collection' : 'Removed from collection'),
              ),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.share,
          label: 'Share Code',
          color: Colors.teal,
          onTap: _shareResult,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    bool multiline = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${widget.barcodeData}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareResult() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share dialog would open here')),
    );
  }

  void _searchOnline() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching online for: ${widget.barcodeData}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _comparePrices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Price comparison would open here')),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
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
          top: MediaQuery.of(context).size.height * _animation.value - 200,
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

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final double scannerSize = size.width * 0.7;
    final double left = (size.width - scannerSize) / 2;
    final double top = (size.height - scannerSize) / 2;

    final cutoutPath = Path()
      ..addRect(Rect.fromLTWH(left, top, scannerSize, scannerSize));

    final overlayPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, paint);

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