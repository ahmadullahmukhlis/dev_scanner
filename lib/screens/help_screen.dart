import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common_app_bar.dart';
import '../utils/constants.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Getting Started'),
          _buildItem(
            context,
            icon: Icons.qr_code_scanner,
            title: 'Scan QR / Barcode',
            subtitle: 'Point the camera at a code. The app scans once, gives sound/vibration, and shows result.',
          ),
          _buildItem(
            context,
            icon: Icons.photo_library,
            title: 'Scan From Image',
            subtitle: 'Use Upload to scan a QR/Barcode from gallery. If no code is found, nothing is saved.',
          ),
          _buildItem(
            context,
            icon: Icons.tune,
            title: 'Scan Controls',
            subtitle: 'Use flash and zoom for better detection. Zoom bar shows % level.',
          ),
          _buildItem(
            context,
            icon: Icons.history,
            title: 'Scan History',
            subtitle: 'All scans are saved in History for quick access.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Create QR'),
          _buildItem(
            context,
            icon: Icons.qr_code_2,
            title: 'Generate QR',
            subtitle: 'Create QR from raw text or key/value data.',
          ),
          _buildItem(
            context,
            icon: Icons.download,
            title: 'Export QR',
            subtitle: 'Save as PNG, JPG, SVG, or PDF from the Create QR screen.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Gateway Rules'),
          _buildItem(
            context,
            icon: Icons.rule,
            title: 'Rules Builder',
            subtitle: 'Create multi-condition rules with actions and field mapping.',
          ),
          _buildItem(
            context,
            icon: Icons.qr_code_scanner,
            title: 'Import From QR',
            subtitle: 'Scan a QR sample to generate a rule quickly.',
          ),
          _buildItem(
            context,
            icon: Icons.sync,
            title: 'Form + JSON Sync',
            subtitle: 'Edit rules in the form or JSON editor. Both stay synced.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('App Logic'),
          _buildItem(
            context,
            icon: Icons.play_arrow,
            title: 'Scan Flow',
            subtitle: 'Scan → feedback (sound/vibrate) → save history → show result.',
          ),
          _buildItem(
            context,
            icon: Icons.link,
            title: 'Auto Open URL',
            subtitle: 'If a scanned value is a URL and auto-open is enabled, it opens in browser.',
          ),
          _buildItem(
            context,
            icon: Icons.rule,
            title: 'Gateway Rules Execution',
            subtitle: 'If rules match JSON, actions run first (redirect, API call, message, save).',
          ),
          _buildItem(
            context,
            icon: Icons.save,
            title: 'History & Saved',
            subtitle: 'Every scan can be saved. You can view or manage them later.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Troubleshooting'),
          _buildItem(
            context,
            icon: Icons.flash_on,
            title: 'Flash Not Working',
            subtitle: 'Flash works only while the scanner is running.',
          ),
          _buildItem(
            context,
            icon: Icons.volume_up,
            title: 'Sound Not Working',
            subtitle: 'Enable sound in Settings and choose Sound Type.',
          ),
          _buildItem(
            context,
            icon: Icons.download_for_offline,
            title: 'Downloads Not Visible',
            subtitle: 'Check the Downloads folder and refresh your file manager.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Contact'),
          _buildContactCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItem(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
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
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ahmadullah Mukhlis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Kabul, Afghanistan'),
            const SizedBox(height: 6),
            const Text('Support: 24 hours'),
            const SizedBox(height: 12),
            _buildLinkRow(
              context,
              icon: Icons.phone,
              label: '+93 784 069 77',
              uri: Uri.parse('tel:+9378406977'),
            ),
            _buildLinkRow(
              context,
              icon: Icons.message,
              label: 'WhatsApp',
              uri: Uri.parse('https://wa.me/9378406977'),
            ),
            _buildLinkRow(
              context,
              icon: Icons.public,
              label: 'GitHub',
              uri: Uri.parse('https://github.com/ahmadullahmukhlis'),
            ),
            _buildLinkRow(
              context,
              icon: Icons.work,
              label: 'LinkedIn',
              uri: Uri.parse('https://www.linkedin.com/in/ahmadullahmukhlis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(BuildContext context, {required IconData icon, required String label, required Uri uri}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () => _launch(context, uri),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
  }
}
