import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final List<Widget>? actions;

  const CustomAppBar({
    Key? key,
    this.height = kToolbarHeight,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: height,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      backgroundColor: const Color(0xffc780ff),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
