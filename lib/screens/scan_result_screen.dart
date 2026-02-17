import 'package:flutter/material.dart';

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

class _ScanResultScreenState extends State<ScanResultScreen>
    with SingleTickerProviderStateMixin {
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
              expandedHeight: 340, // Increased height to fit content
              floating: false,
              pinned: true,
              backgroundColor: Colors.blue.shade700,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1976D2), Color(0xFF7B1FA2)],
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView( // Prevent overflow
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.format.contains('QR')
                                  ? Icons.qr_code
                                  : Icons.qr_code_scanner,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
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
                                  icon: isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: 'Save',
                                  onTap: () {
                                    setState(() {
                                      isFavorite = !isFavorite;
                                      isSaved = !isSaved;
                                    });
                                    _showSnackBar(isSaved
                                        ? 'Saved to collection'
                                        : 'Removed from collection');
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
          value:
          'This is a sample product description. In a real app, this would be fetched from a database or API based on the barcode.',
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
          onTap: () => _showSnackBar('Added to cart'),
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
            _showSnackBar(
                isSaved ? 'Saved to collection' : 'Removed from collection');
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
        crossAxisAlignment:
        multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
    _showSnackBar('Copied: ${widget.barcodeData}');
  }

  void _shareResult() {
    _showSnackBar('Share dialog would open here');
  }

  void _searchOnline() {
    _showSnackBar('Searching online for: ${widget.barcodeData}');
  }

  void _comparePrices() {
    _showSnackBar('Price comparison would open here');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
