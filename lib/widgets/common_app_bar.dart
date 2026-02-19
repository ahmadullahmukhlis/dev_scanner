import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.leading,
  }) : super(key: key);

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final Widget? leading;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return AppBar(
          title: Text(title),
          backgroundColor: AppSettings.instance.appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: centerTitle,
          leading: leading,
          actions: actions,
          bottom: bottom,
        );
      },
    );
  }
}
