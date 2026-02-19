import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CameraFacingSetting { back, front }
enum FlashSetting { off, on }
enum ScanSpeedSetting { normal, noDuplicates, unrestricted }
enum AppThemeSetting { system, light, dark }
enum AppBarColorSetting { blue, green, orange, teal, red, purple, black }

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _keyCameraFacing = 'camera_facing';
  static const String _keyFlash = 'flash_mode';
  static const String _keyScanSpeed = 'scan_speed';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keySound = 'sound_enabled';
  static const String _keyAutoOpenUrl = 'auto_open_url';
  static const String _keyLanguage = 'language';
  static const String _keyTheme = 'theme';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyAppBarColor = 'app_bar_color';
  static const String _keyCustomLogicEnabled = 'custom_logic_enabled';
  static const String _keyCustomLogicJson = 'custom_logic_json';
  static const String _keyGatewayRulesEnabled = 'gateway_rules_enabled';
  static const String _keyGatewayRulesJson = 'gateway_rules_json';

  SharedPreferences? _prefs;

  CameraFacingSetting cameraFacing = CameraFacingSetting.back;
  FlashSetting flash = FlashSetting.off;
  ScanSpeedSetting scanSpeed = ScanSpeedSetting.normal;
  bool vibrationEnabled = true;
  bool soundEnabled = true;
  bool autoOpenUrl = true;
  String language = 'English';
  AppThemeSetting theme = AppThemeSetting.system;
  bool notificationsEnabled = true;
  AppBarColorSetting appBarColorSetting = AppBarColorSetting.blue;
  bool customLogicEnabled = false;
  String customLogicJson = '';
  bool gatewayRulesEnabled = true;
  String gatewayRulesJson = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    cameraFacing = _readEnum(_keyCameraFacing, CameraFacingSetting.values, CameraFacingSetting.back);
    flash = _readEnum(_keyFlash, FlashSetting.values, FlashSetting.off);
    scanSpeed = _readEnum(_keyScanSpeed, ScanSpeedSetting.values, ScanSpeedSetting.normal);
    vibrationEnabled = _prefs?.getBool(_keyVibration) ?? true;
    soundEnabled = _prefs?.getBool(_keySound) ?? true;
    autoOpenUrl = _prefs?.getBool(_keyAutoOpenUrl) ?? true;
    language = _prefs?.getString(_keyLanguage) ?? 'English';
    theme = _readEnum(_keyTheme, AppThemeSetting.values, AppThemeSetting.system);
    notificationsEnabled = _prefs?.getBool(_keyNotifications) ?? true;
    appBarColorSetting = _readEnum(_keyAppBarColor, AppBarColorSetting.values, AppBarColorSetting.blue);
    customLogicEnabled = _prefs?.getBool(_keyCustomLogicEnabled) ?? false;
    customLogicJson = _prefs?.getString(_keyCustomLogicJson) ?? '';
    gatewayRulesEnabled = _prefs?.getBool(_keyGatewayRulesEnabled) ?? true;
    gatewayRulesJson = _prefs?.getString(_keyGatewayRulesJson) ?? '';
    notifyListeners();
  }

  T _readEnum<T extends Enum>(String key, List<T> values, T fallback) {
    final raw = _prefs?.getString(key);
    if (raw == null) return fallback;
    for (final value in values) {
      if (describeEnum(value) == raw) return value;
    }
    return fallback;
  }

  Future<void> setCameraFacing(CameraFacingSetting value) async {
    cameraFacing = value;
    await _prefs?.setString(_keyCameraFacing, describeEnum(value));
    notifyListeners();
  }

  Future<void> setFlash(FlashSetting value) async {
    flash = value;
    await _prefs?.setString(_keyFlash, describeEnum(value));
    notifyListeners();
  }

  Future<void> setScanSpeed(ScanSpeedSetting value) async {
    scanSpeed = value;
    await _prefs?.setString(_keyScanSpeed, describeEnum(value));
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    vibrationEnabled = value;
    await _prefs?.setBool(_keyVibration, value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await _prefs?.setBool(_keySound, value);
    notifyListeners();
  }

  Future<void> setAutoOpenUrl(bool value) async {
    autoOpenUrl = value;
    await _prefs?.setBool(_keyAutoOpenUrl, value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await _prefs?.setString(_keyLanguage, value);
    notifyListeners();
  }

  Future<void> setTheme(AppThemeSetting value) async {
    theme = value;
    await _prefs?.setString(_keyTheme, describeEnum(value));
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await _prefs?.setBool(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setAppBarColor(AppBarColorSetting value) async {
    appBarColorSetting = value;
    await _prefs?.setString(_keyAppBarColor, describeEnum(value));
    notifyListeners();
  }

  Future<void> setCustomLogicEnabled(bool value) async {
    customLogicEnabled = value;
    await _prefs?.setBool(_keyCustomLogicEnabled, value);
    notifyListeners();
  }

  Future<void> setCustomLogicJson(String value) async {
    customLogicJson = value;
    await _prefs?.setString(_keyCustomLogicJson, value);
    notifyListeners();
  }

  Future<void> setGatewayRulesEnabled(bool value) async {
    gatewayRulesEnabled = value;
    await _prefs?.setBool(_keyGatewayRulesEnabled, value);
    notifyListeners();
  }

  Future<void> setGatewayRulesJson(String value) async {
    gatewayRulesJson = value;
    await _prefs?.setString(_keyGatewayRulesJson, value);
    notifyListeners();
  }

  CameraFacing get scannerFacing {
    return cameraFacing == CameraFacingSetting.front ? CameraFacing.front : CameraFacing.back;
  }

  DetectionSpeed get detectionSpeed {
    switch (scanSpeed) {
      case ScanSpeedSetting.noDuplicates:
        return DetectionSpeed.noDuplicates;
      case ScanSpeedSetting.unrestricted:
        return DetectionSpeed.unrestricted;
      case ScanSpeedSetting.normal:
      default:
        return DetectionSpeed.normal;
    }
  }

  bool get torchEnabled => flash == FlashSetting.on;

  ThemeMode get themeMode {
    switch (theme) {
      case AppThemeSetting.dark:
        return ThemeMode.dark;
      case AppThemeSetting.light:
        return ThemeMode.light;
      case AppThemeSetting.system:
      default:
        return ThemeMode.system;
    }
  }

  Color get appBarColor {
    switch (appBarColorSetting) {
      case AppBarColorSetting.green:
        return Colors.green.shade700;
      case AppBarColorSetting.orange:
        return Colors.orange.shade700;
      case AppBarColorSetting.teal:
        return Colors.teal.shade700;
      case AppBarColorSetting.red:
        return Colors.red.shade700;
      case AppBarColorSetting.purple:
        return Colors.purple.shade700;
      case AppBarColorSetting.black:
        return Colors.black;
      case AppBarColorSetting.blue:
      default:
        return Colors.blue.shade700;
    }
  }

  String get appBarColorLabel {
    switch (appBarColorSetting) {
      case AppBarColorSetting.green:
        return 'Green';
      case AppBarColorSetting.orange:
        return 'Orange';
      case AppBarColorSetting.teal:
        return 'Teal';
      case AppBarColorSetting.red:
        return 'Red';
      case AppBarColorSetting.purple:
        return 'Purple';
      case AppBarColorSetting.black:
        return 'Black';
      case AppBarColorSetting.blue:
      default:
        return 'Blue';
    }
  }
  String get cameraLabel {
    return cameraFacing == CameraFacingSetting.front ? 'Front Camera' : 'Back Camera';
  }

  String get flashLabel {
    return flash == FlashSetting.on ? 'On' : 'Off';
  }

  String get scanSpeedLabel {
    switch (scanSpeed) {
      case ScanSpeedSetting.noDuplicates:
        return 'No Duplicates';
      case ScanSpeedSetting.unrestricted:
        return 'Unrestricted';
      case ScanSpeedSetting.normal:
      default:
        return 'Normal';
    }
  }

  String get themeLabel {
    switch (theme) {
      case AppThemeSetting.light:
        return 'Light';
      case AppThemeSetting.dark:
        return 'Dark';
      case AppThemeSetting.system:
      default:
        return 'System';
    }
  }
}
