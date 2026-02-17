import 'package:flutter/material.dart';

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