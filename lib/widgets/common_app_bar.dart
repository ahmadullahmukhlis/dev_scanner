import 'package:flutter/material.dart';
import '../utils/constants.dart';

PreferredSizeWidget buildCommonAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool centerTitle = false,
  Widget? leading,
}) {
  return AppBar(
    title: Text(title),
    backgroundColor: AppConstants.primaryBlue,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: centerTitle,
    leading: leading,
    actions: actions,
    bottom: bottom,
  );
}
