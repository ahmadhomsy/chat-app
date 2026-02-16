import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DividerWidget extends StatelessWidget {
  const DividerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'OR',
            style: TextStyle(fontSize: 14.sp, color: Colors.white54),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}
