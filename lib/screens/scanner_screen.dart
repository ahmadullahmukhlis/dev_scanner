import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'scan_result_screen.dart';
import 'create_qr_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'saved_screen.dart';
import 'help_screen.dart';
import '../widgets/corner_marker.dart';
import '../widgets/animated_scan_line.dart';
import '../widgets/scanner_overlay_painter.dart';
import '../utils/db_helper.dart';
import '../models/scan_history_model.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/gateway_rules.dart';
import '../widgets/common_app_bar.dart';
import 'gateway_rules_screen.dart';
import 'dart:convert';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with SingleTickerProviderStateMixin {
  late MobileScannerController controller;
  final AppSettings _settings = AppSettings.instance;
  CameraFacingSetting? _lastCameraFacing;
  ScanSpeedSetting? _lastScanSpeed;

  bool isSidebarOpen = false;
  double zoomLevel = 0.0;
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  final ImagePicker _imagePicker = ImagePicker();
  final DBHelper _dbHelper = DBHelper();
  bool _isProcessingScan = false;
  String? _lastScannedValue;
  DateTime? _lastScanTime;

  final List<Map<String, dynamic>> menuItems = [
    {'icon': Icons.qr_code_scanner, 'title': 'Scanner', 'page': 'scanner'},
    {'icon': Icons.qr_code_2, 'title': 'Create QR', 'page': 'create_qr'},
    {'icon': Icons.history, 'title': 'History', 'page': 'history'},
    {'icon': Icons.bookmark, 'title': 'Saved', 'page': 'saved'},
    {'icon': Icons.settings, 'title': 'Settings', 'page': 'settings'},
    {'icon': Icons.rule, 'title': 'Custom Rules', 'page': 'custom_rules'},
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
    _lastScanSpeed = _settings.scanSpeed;
    controller = MobileScannerController(
      detectionSpeed: _settings.detectionSpeed,
      facing: _settings.scannerFacing,
      torchEnabled: false,
    );
  }

  void _handleSettingsChanged() {
    final needsControllerRebuild = _lastCameraFacing != _settings.cameraFacing ||
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
      SystemSound.play(SystemSoundType.alert);
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

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }


  Future<void> pickImageFromGallery() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image scan is not supported on web')),
        );
        return;
      }
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image for barcode...')),
        );

        final BarcodeCapture? capture = await controller.analyzeImage(image.path);
        final Barcode? firstBarcode = capture?.barcodes.isNotEmpty == true ? capture!.barcodes.first : null;
        final String? code = firstBarcode?.rawValue;

        if (code == null || code.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No barcode found in the image')),
            );
          }
          return;
        }

        await _saveScanToHistory(code, firstBarcode!.format.name);
        _playScanFeedback();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanResultScreen(
                barcodeData: code,
                format: firstBarcode.format.name,
                imagePath: image.path,
              ),
            ),
          ).then((_) {
            _lastScannedValue = null;
            _lastScanTime = null;
            controller.start();
          });
        }
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
      ),
      body: Stack(
        children: [
          _buildScanner(),
          _buildTopActions(),
          _buildZoomBar(),
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
                if (_shouldIgnoreScan(code)) return;
                if (_isProcessingScan) return;
                _isProcessingScan = true;
                controller.stop();
                _playScanFeedback();

                if (mounted) {
                  try {
                    if (_settings.gatewayRulesEnabled) {
                      final decoded = _tryParseJson(code);
                      if (decoded != null) {
                        final rulesJson = _settings.gatewayRulesJson.trim();
                        if (rulesJson.isNotEmpty) {
                          try {
                            final rulesDecoded = json.decode(rulesJson);
                            if (rulesDecoded is Map<String, dynamic>) {
                              final ruleSet = GatewayRuleSet.fromJson(rulesDecoded);
                              final evaluation = GatewayRuleEngine.evaluate(decoded, ruleSet);
                              if (evaluation.matched && evaluation.actions != null) {
                                final data = evaluation.mappedData ?? decoded;
                                for (final action in evaluation.actions!) {
                                  if (action.type == 'redirect' && action.url != null) {
                                    final params = action.params ?? {};
                                    final resolvedParams = GatewayRuleEngine.applyTemplateToMap(params, data);
                                    final uri = Uri.parse(action.url!);
                                    final merged = Map<String, String>.from(uri.queryParameters)
                                      ..addAll(resolvedParams.map((k, v) => MapEntry(k, v.toString())));
                                    await _openUrl(uri.replace(queryParameters: merged).toString());
                                    await Future.delayed(const Duration(milliseconds: 600));
                                    _lastScannedValue = null;
                                    _lastScanTime = null;
                                    controller.start();
                                    _isProcessingScan = false;
                                    return;
                                  }
                                  if ((action.type == 'api_call' || action.type == 'backend_hook') && action.url != null) {
                                    final body = action.body ?? {};
                                    final resolvedBody = GatewayRuleEngine.applyTemplateToMap(body, data);
                                    await GatewayRuleEngine.callApi(action.url!, resolvedBody);
                                  }
                                  if (action.type == 'route' && action.route != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Route: ${action.route}')),
                                    );
                                  }
                                  if (action.type == 'show_message' && action.message != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(GatewayRuleEngine.applyTemplate(action.message!, data))),
                                    );
                                  }
                                  if (action.type == 'save_history') {
                                    await _saveScanToHistory(code, barcodes.first.format.name);
                                  }
                                }
                              }
                            }
                          } catch (_) {
                            // Ignore rules parse errors; fall back to default result
                          }
                        }
                      }
                    }

                    await _saveScanToHistory(code, barcodes.first.format.name);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanResultScreen(
                          barcodeData: code,
                          format: barcodes.first.format.name,
                        ),
                      ),
                    ).then((_) {
                      _lastScannedValue = null;
                      _lastScanTime = null;
                      controller.start();
                    });
                  } finally {
                    _isProcessingScan = false;
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

  Widget _buildTorchButton() {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final torchState = state.torchState;
        if (torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final isOn = torchState == TorchState.on;
        return IconButton(
          icon: Icon(isOn ? Icons.flash_on : Icons.flash_off),
          onPressed: () => controller.toggleTorch(),
        );
      },
    );
  }

  Widget _buildTopActions() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildOverlayButton(
            icon: Icons.flash_on,
            onTap: () => controller.toggleTorch(),
            valueListenable: controller,
            builder: (state) {
              final torchState = state.torchState;
              if (torchState == TorchState.unavailable) return null;
              final isOn = torchState == TorchState.on;
              return isOn ? Icons.flash_on : Icons.flash_off;
            },
          ),
          _buildOverlayButton(
            icon: Icons.photo_library,
            onTap: pickImageFromGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onTap,
    ValueListenable<MobileScannerState>? valueListenable,
    IconData? Function(MobileScannerState state)? builder,
  }) {
    if (valueListenable != null && builder != null) {
      return ValueListenableBuilder<MobileScannerState>(
        valueListenable: valueListenable,
        builder: (context, state, _) {
          final iconData = builder(state);
          if (iconData == null) return const SizedBox.shrink();
          return _buildOverlayButton(
            icon: iconData,
            onTap: onTap,
          );
        },
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    );
  }

  Widget _buildZoomBar() {
    final size = MediaQuery.of(context).size;
    final scannerSize = size.width * 0.7;
    final top = (size.height - scannerSize) / 2;
    final barTop = top + scannerSize + 12;
    return Positioned(
      top: barTop,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  zoomLevel = (zoomLevel - 0.1).clamp(0.0, 1.0);
                  controller.setZoomScale(zoomLevel);
                });
              },
              child: const Icon(Icons.remove, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: zoomLevel,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(zoomLevel * 100).round()}%',
                activeColor: Colors.white,
                inactiveColor: Colors.white.withOpacity(0.4),
                onChanged: (value) {
                  setState(() {
                    zoomLevel = value;
                    controller.setZoomScale(zoomLevel);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(zoomLevel * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  zoomLevel = (zoomLevel + 0.1).clamp(0.0, 1.0);
                  controller.setZoomScale(zoomLevel);
                });
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
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

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  bool _shouldIgnoreScan(String code) {
    final now = DateTime.now();
    final cooldownMs = _settings.scanCooldownMs;
    if (cooldownMs <= 0) {
      _lastScannedValue = code;
      _lastScanTime = now;
      return false;
    }
    if (_lastScannedValue == code && _lastScanTime != null) {
      final delta = now.difference(_lastScanTime!);
      if (delta < Duration(milliseconds: cooldownMs)) {
        return true;
      }
    }
    _lastScannedValue = code;
    _lastScanTime = now;
    return false;
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
    } else if (page == 'create_qr') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateQrScreen(),
        ),
      );
    } else if (page == 'help') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HelpScreen(),
        ),
      );
    } else if (page == 'custom_rules') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GatewayRulesScreen(),
        ),
      );
    } else if (page == 'share') {
      _shareApp();
    }
  }
}
