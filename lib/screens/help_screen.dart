import 'package:flutter/material.dart';

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
          _buildHelpCard(
            'FAQ',
            'Frequently asked questions about the app.',
            Icons.help_outline,
          ),
          _buildHelpCard(
            'Report Issue',
            'Found a problem? Report it to our team.',
            Icons.bug_report,
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
        onTap: () {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Opening $title')),
          // );
        },
      ),
    );
  }
}