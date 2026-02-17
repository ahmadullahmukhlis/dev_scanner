import 'package:flutter/material.dart';

class CornerMarker extends StatelessWidget {
  final Alignment alignment;
  final double rotation;

  const CornerMarker({
    Key? key,
    required this.alignment,
    required this.rotation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.8),
                width: 4,
              ),
              left: BorderSide(
                color: Colors.white.withOpacity(0.8),
                width: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}