import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'scan_result_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'saved_screen.dart';
import 'help_screen.dart';
import 'custom_logic_screen.dart';
import '../widgets/corner_marker.dart';
import '../widgets/animated_scan_line.dart';
import '../widgets/scanner_overlay_painter.dart';
import '../utils/db_helper.dart';
import '../models/scan_history_model.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import '../utils/custom_logic.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common_app_bar.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with SingleTickerProviderStateMixin {
  late MobileScannerController controller;
  final AppSettings _settings = AppSettings.instance;
  CameraFacingSetting? _lastCameraFacing;
  FlashSetting? _lastFlash;
  ScanSpeedSetting? _lastScanSpeed;

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
    {'icon': Icons.code, 'title': 'Custom Logic', 'page': 'custom_logic'},
    {'icon': Icons.help, 'title': 'Help', 'page': 'help'},
    {'icon': Icons.share, 'title': 'Share App', 'page': 'share'},
  ];

  @override
  void initState() {
    super.initState();
    _initControllerFromSettings();
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
    );
    _settings.addListener(_handleSettingsChanged);
  }

  @override
  void dispose() {
    controller.dispose();
    _sidebarController.dispose();
    _settings.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _initControllerFromSettings() {
    _lastCameraFacing = _settings.cameraFacing;
    _lastFlash = _settings.flash;
    _lastScanSpeed = _settings.scanSpeed;
    controller = MobileScannerController(
      detectionSpeed: _settings.detectionSpeed,
      facing: _settings.scannerFacing,
      torchEnabled: _settings.torchEnabled,
    );
  }

  void _handleSettingsChanged() {
    final needsControllerRebuild = _lastCameraFacing != _settings.cameraFacing ||
        _lastFlash != _settings.flash ||
        _lastScanSpeed != _settings.scanSpeed;

    if (needsControllerRebuild) {
      final oldController = controller;
      _initControllerFromSettings();
      oldController.dispose();
      if (mounted) {
        setState(() {});
      }
    } else if (mounted) {
      setState(() {});
    }
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
    } else if (page == 'custom_logic') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomLogicScreen(),
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

  void _playScanFeedback() {
    if (_settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (_settings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.hasScheme && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.parse(value.trim());
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the URL')),
      );
    }
  }

  Future<bool> _runCustomLogic(String code, String format) async {
    if (!_settings.customLogicEnabled) return false;
    final rules = CustomLogicEngine.parseRules(_settings.customLogicJson);
    if (rules.isEmpty) return false;
    final engine = CustomLogicEngine(rules);
    final rule = engine.matchRule(code);
    if (rule == null) return false;

    final json = CustomLogicEngine.tryParseJson(code);

    for (final action in rule.actions) {
      switch (action.type) {
        case 'open_url':
          final urlValue = CustomLogicEngine.resolveValue(code, json, action.value);
          if (urlValue != null && _isValidUrl(urlValue)) {
            await _openUrl(urlValue);
          }
          break;
        case 'show_message':
          final message = CustomLogicEngine.resolveValue(code, json, action.value) ?? 'Matched rule: ${rule.name}';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
          break;
        case 'show_json_fields':
          if (mounted) {
            final fields = action.fields ?? [];
            final content = _buildJsonFieldsDisplay(json, fields);
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(rule.name),
                content: content,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          break;
        case 'show_result':
          if (mounted) {
            final mapping = action.mapping ?? {};
            final resolved = CustomLogicEngine.resolveMapping(code, json, mapping);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScanResultScreen(
                  barcodeData: code,
                  format: format,
                  customFields: resolved,
                  customTitle: rule.name,
                ),
              ),
            );
          }
          break;
        case 'sound':
          if (_settings.soundEnabled) {
            SystemSound.play(SystemSoundType.click);
          }
          break;
        case 'vibrate':
          if (_settings.vibrationEnabled) {
            HapticFeedback.mediumImpact();
          }
          break;
      }
    }

    if (rule.saveToHistory) {
      await _saveScanToHistory(code, format);
    }
    return true;
  }

  Widget _buildJsonFieldsDisplay(Map<String, dynamic>? json, List<String> fields) {
    if (json == null) {
      return const Text('No JSON data found in this QR code.');
    }
    if (fields.isEmpty) {
      return Text(json.toString());
    }
    final buffer = StringBuffer();
    for (final field in fields) {
      final value = CustomLogicEngine.resolveValue('', json, 'field:$field');
      buffer.writeln('$field: ${value ?? '-'}');
    }
    return Text(buffer.toString().trim());
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
          _playScanFeedback();

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
      appBar: CommonAppBar(
        title: AppConstants.appName,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: toggleSidebar,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => navigateTo('settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildScanner(),
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
                _playScanFeedback();

                if (mounted) {
                  final handled = await _runCustomLogic(code, barcodes.first.format.name);
                  if (handled) {
                    if (mounted) {
                      await Future.delayed(const Duration(milliseconds: 600));
                      controller.start();
                    }
                  } else {
                    // Default behavior
                    await _saveScanToHistory(code, barcodes.first.format.name);
                    if (_settings.autoOpenUrl && _isValidUrl(code)) {
                      await _openUrl(code);
                      if (mounted) {
                        await Future.delayed(const Duration(milliseconds: 600));
                        controller.start();
                      }
                    } else {
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
