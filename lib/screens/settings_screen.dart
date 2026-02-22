import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import '../widgets/common_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTestSound() async {
    try {
      if (_settings.soundType == SoundTypeSetting.custom) {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(_settings.soundVolume);
        await _audioPlayer.play(AssetSource(_settings.soundAssetPath));
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) {
          return ListView(
            children: [
              _buildSettingsSection(
                'Scanner Settings',
                [
                  _buildSettingsTile(
                    Icons.camera_alt,
                    'Camera',
                    _settings.cameraLabel,
                    onTap: () => _showSelectionDialog<CameraFacingSetting>(
                      title: 'Camera',
                      options: const [
                        _SettingsOption(label: 'Back Camera', value: CameraFacingSetting.back),
                        _SettingsOption(label: 'Front Camera', value: CameraFacingSetting.front),
                      ],
                      current: _settings.cameraFacing,
                      onSelected: _settings.setCameraFacing,
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.speed,
                    'Scan Speed',
                    _settings.scanSpeedLabel,
                    onTap: () => _showSelectionDialog<ScanSpeedSetting>(
                      title: 'Scan Speed',
                      options: const [
                        _SettingsOption(label: 'Normal', value: ScanSpeedSetting.normal),
                        _SettingsOption(label: 'No Duplicates', value: ScanSpeedSetting.noDuplicates),
                        _SettingsOption(label: 'Unrestricted', value: ScanSpeedSetting.unrestricted),
                      ],
                      current: _settings.scanSpeed,
                      onSelected: _settings.setScanSpeed,
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.timer,
                    'Scan Cooldown',
                    _settings.scanCooldownLabel,
                    onTap: () => _showSelectionDialog<int>(
                      title: 'Scan Cooldown',
                      options: const [
                        _SettingsOption(label: 'Off', value: 0),
                        _SettingsOption(label: '1s', value: 1000),
                        _SettingsOption(label: '2s', value: 2000),
                        _SettingsOption(label: '3s', value: 3000),
                        _SettingsOption(label: '5s', value: 5000),
                      ],
                      current: _settings.scanCooldownMs,
                      onSelected: _settings.setScanCooldownMs,
                    ),
                  ),
                  _buildSwitchTile(
                    Icons.vibration,
                    'Vibration',
                    'Vibrate on scan',
                    value: _settings.vibrationEnabled,
                    onChanged: _settings.setVibrationEnabled,
                  ),
                  _buildSwitchTile(
                    Icons.volume_up,
                    'Sound',
                    'Play sound on scan',
                    value: _settings.soundEnabled,
                    onChanged: _settings.setSoundEnabled,
                  ),
                  _buildSettingsTile(
                    Icons.music_note,
                    'Sound Type',
                    _settings.soundTypeLabel,
                    onTap: () => _showSelectionDialog<SoundTypeSetting>(
                      title: 'Sound Type',
                      options: const [
                        _SettingsOption(label: 'System', value: SoundTypeSetting.system),
                        _SettingsOption(label: 'Custom', value: SoundTypeSetting.custom),
                      ],
                      current: _settings.soundType,
                      onSelected: _settings.setSoundType,
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.tune,
                    'Sound Tone',
                    _settings.soundAssetLabel,
                    onTap: () => _showSelectionDialog<SoundAssetSetting>(
                      title: 'Sound Tone',
                      options: const [
                        _SettingsOption(label: 'Beep', value: SoundAssetSetting.beep),
                        _SettingsOption(label: 'Chirp', value: SoundAssetSetting.chirp),
                        _SettingsOption(label: 'Tick', value: SoundAssetSetting.tick),
                      ],
                      current: _settings.soundAsset,
                      onSelected: _settings.setSoundAsset,
                    ),
                  ),
                  _buildSliderTile(
                    icon: Icons.volume_down,
                    title: 'Sound Volume',
                    subtitle: _settings.soundVolumeLabel,
                    value: _settings.soundVolume,
                    onChanged: _settings.setSoundVolume,
                  ),
                  _buildSettingsTile(
                    Icons.play_arrow,
                    'Test Sound',
                    'Play the selected sound',
                    onTap: _playTestSound,
                  ),
                  _buildSwitchTile(
                    Icons.link,
                    'Open URLs',
                    'Open URLs immediately after scan',
                    value: _settings.autoOpenUrl,
                    onChanged: _settings.setAutoOpenUrl,
                  ),
                ],
              ),
              _buildSettingsSection(
                'App Settings',
                [
                  _buildSettingsTile(
                    Icons.language,
                    'Language',
                    _settings.language,
                    onTap: () => _showSelectionDialog<String>(
                      title: 'Language',
                      options: const [
                        _SettingsOption(label: 'English', value: 'English'),
                        _SettingsOption(label: 'Spanish', value: 'Spanish'),
                        _SettingsOption(label: 'French', value: 'French'),
                      ],
                      current: _settings.language,
                      onSelected: _settings.setLanguage,
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.dark_mode,
                    'Theme',
                    _settings.themeLabel,
                    onTap: () => _showSelectionDialog<AppThemeSetting>(
                      title: 'Theme',
                      options: const [
                        _SettingsOption(label: 'System', value: AppThemeSetting.system),
                        _SettingsOption(label: 'Light', value: AppThemeSetting.light),
                        _SettingsOption(label: 'Dark', value: AppThemeSetting.dark),
                      ],
                      current: _settings.theme,
                      onSelected: _settings.setTheme,
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.palette,
                    'App Bar Color',
                    _settings.appBarColorLabel,
                    onTap: () => _showSelectionDialog<AppBarColorSetting>(
                      title: 'App Bar Color',
                      options: const [
                        _SettingsOption(label: 'Blue', value: AppBarColorSetting.blue),
                        _SettingsOption(label: 'Green', value: AppBarColorSetting.green),
                        _SettingsOption(label: 'Orange', value: AppBarColorSetting.orange),
                        _SettingsOption(label: 'Teal', value: AppBarColorSetting.teal),
                        _SettingsOption(label: 'Red', value: AppBarColorSetting.red),
                        _SettingsOption(label: 'Purple', value: AppBarColorSetting.purple),
                        _SettingsOption(label: 'Black', value: AppBarColorSetting.black),
                      ],
                      current: _settings.appBarColorSetting,
                      onSelected: _settings.setAppBarColor,
                    ),
                  ),
                  _buildSwitchTile(
                    Icons.notifications,
                    'Notifications',
                    'Enable notifications',
                    value: _settings.notificationsEnabled,
                    onChanged: _settings.setNotificationsEnabled,
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
                    onTap: () => _showInfoDialog(
                      title: 'Version',
                      message: '${AppConstants.appName} version 1.0.0',
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.privacy_tip,
                    'Privacy Policy',
                    '',
                    onTap: () => _showInfoDialog(
                      title: 'Privacy Policy',
                      message:
                          'Your data stays on your device.\n'
                          'We do not collect or sell personal information.\n'
                          'QR contents are processed locally.\n'
                          'If you choose to open links, they are opened in your browser.\n'
                          'Scan history is stored locally and can be cleared by you.',
                    ),
                  ),
                  _buildSettingsTile(
                    Icons.terminal_sharp,
                    'Terms of Service',
                    '',
                    onTap: () => _showInfoDialog(
                      title: 'Terms of Service',
                      message:
                          'This app is provided as-is without warranties.\n'
                          'You are responsible for how you use scanned data.\n'
                          'Do not scan or open links you do not trust.\n'
                          'The app may change or be updated at any time.',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: subtitle,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectionDialog<T>({
    required String title,
    required List<_SettingsOption<T>> options,
    required T current,
    required Future<void> Function(T value) onSelected,
  }) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.8;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: options
                            .map(
                              (option) => ListTile(
                                title: Text(option.label),
                                trailing: option.value == current ? const Icon(Icons.check, color: Colors.blue) : null,
                                onTap: () => Navigator.pop(context, option.value),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (selected != null && selected != current) {
      await onSelected(selected);
    }
  }

  Future<void> _showInfoDialog({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SettingsOption<T> {
  const _SettingsOption({required this.label, required this.value});

  final String label;
  final T value;
}
