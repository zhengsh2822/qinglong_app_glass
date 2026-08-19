import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';



class StatusWidget extends ConsumerWidget {
  final String title;
  final Color color;

  const StatusWidget({
    super.key,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context, ref) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
