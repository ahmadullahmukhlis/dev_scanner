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
    {'code': '9780201379624', 'type': 'ISBN', 'date': '2024-01-15 10:30 AM', 'product': 'Design Patterns Book'},
    {'code': '5901234123457', 'type': 'EAN-13', 'date': '2024-01-15 09:15 AM', 'product': 'Milk Chocolate'},
    {'code': '123456789012', 'type': 'CODE128', 'date': '2024-01-14 04:45 PM', 'product': 'Shipping Label'},
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
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void shareApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share app dialog would open here')),
    );
  }

  void openSettings() {
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
                      // Stop scanning
                      controller.stop();

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
                      onTap: toggleSidebar,
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
                              toggleSidebar();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScanResultScreen(
                                    barcodeData: item['code'],
                                    format: item['type'],
                                    productName: item['product'],
                                  ),
                                ),
                              ).then((_) {
                                controller.start();
                              });
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

// Scan Result Screen
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

  // Sample product data (in real app, fetch from API)
  Map<String, dynamic> get productInfo {
    return {
      'name': widget.productName ?? 'Premium Product',
      'brand': 'Sample Brand',
      'price': '\$29.99',
      'description': 'This is a high-quality product with excellent features. Perfect for daily use.',
      'rating': 4.5,
      'reviews': 128,
      'inStock': true,
      'category': 'Electronics',
      'manufacturer': 'Sample Manufacturing Co.',
      'country': 'USA',
    };
  }

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.blue),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Scan Result',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.blue,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              isFavorite = !isFavorite;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isFavorite ? 'Added to favorites' : 'Removed from favorites'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.share, color: Colors.blue),
                          ),
                          onPressed: _shareResult,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Barcode Display Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Icon based on format
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.format.contains('QR') ? Icons.qr_code : Icons.qr_code_scanner,
                        size: 40,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Barcode Data
                    Text(
                      widget.barcodeData,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
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
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.format,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getCurrentTime(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Barcode visualization (simulated)
                    if (!widget.format.contains('QR')) ...[
                      const SizedBox(height: 20),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CustomPaint(
                          painter: BarcodePainter(data: widget.barcodeData),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.blue.shade50,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Details'),
                    Tab(text: 'Info'),
                    Tab(text: 'Actions'),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(),
                    _buildInfoTab(),
                    _buildActionsTab(),
                  ],
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
          icon: Icons.shopping_bag,
          title: 'Product Name',
          value: productInfo['name'],
        ),
        _buildInfoCard(
          icon: Icons.branding_watermark,
          title: 'Brand',
          value: productInfo['brand'],
        ),
        _buildInfoCard(
          icon: Icons.attach_money,
          title: 'Price',
          value: productInfo['price'],
        ),
        _buildInfoCard(
          icon: Icons.star,
          title: 'Rating',
          value: '${productInfo['rating']} (${productInfo['reviews']} reviews)',
        ),
        _buildInfoCard(
          icon: Icons.inventory,
          title: 'Availability',
          value: productInfo['inStock'] ? 'In Stock' : 'Out of Stock',
          valueColor: productInfo['inStock'] ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.description,
          title: 'Description',
          value: productInfo['description'],
          multiline: true,
        ),
        _buildInfoCard(
          icon: Icons.category,
          title: 'Category',
          value: productInfo['category'],
        ),
        _buildInfoCard(
          icon: Icons.factory,
          title: 'Manufacturer',
          value: productInfo['manufacturer'],
        ),
        _buildInfoCard(
          icon: Icons.public,
          title: 'Country of Origin',
          value: productInfo['country'],
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
          icon: Icons.shopping_cart,
          label: 'Add to Cart',
          color: Colors.blue,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to cart')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.search,
          label: 'Search Online',
          color: Colors.green,
          onTap: _searchOnline,
        ),
        _buildActionButton(
          icon: Icons.copy,
          label: 'Copy Code',
          color: Colors.orange,
          onTap: _copyToClipboard,
        ),
        _buildActionButton(
          icon: Icons.share,
          label: 'Share Code',
          color: Colors.purple,
          onTap: _shareResult,
        ),
        _buildActionButton(
          icon: Icons.compare_arrows,
          label: 'Compare Prices',
          color: Colors.teal,
          onTap: _comparePrices,
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

  void _copyToClipboard() {
    // In real app, use Clipboard.setData
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

// Custom painter for barcode visualization
class BarcodePainter extends CustomPainter {
  final String data;

  BarcodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    final double barWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final int digit = int.tryParse(data[i]) ?? 0;
      final double x = i * barWidth;

      // Draw bars based on digit (simplified)
      for (int j = 0; j <= digit % 4; j++) {
        final double barX = x + (j * 3);
        if (barX < size.width) {
          canvas.drawLine(
            Offset(barX, 0),
            Offset(barX, size.height),
            paint..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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