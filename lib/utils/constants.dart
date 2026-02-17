import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'AfPay';
  static const String scanBarcode = 'Scan Barcode';

  // Colors
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color primaryPurple = Color(0xFF7B1FA2);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1976D2), Color(0xFF7B1FA2)],
  );
}

class MenuItem {
  final IconData icon;
  final String title;
  final String page;

  MenuItem({
    required this.icon,
    required this.title,
    required this.page,
  });
}

class HistoryItem {
  final String code;
  final String type;
  final String date;
  final String product;

  HistoryItem({
    required this.code,
    required this.type,
    required this.date,
    required this.product,
  });
}