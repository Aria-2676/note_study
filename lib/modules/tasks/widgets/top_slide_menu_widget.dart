import 'package:flutter/material.dart';
import './menu_panel_widget.dart';

class TopSlideMenuWidget extends StatelessWidget {
  final Animation<Offset> animation;
  final VoidCallback onClose;
  final void Function(DateTime) scrollCalendarToDate;

  const TopSlideMenuWidget({
    super.key,
    required this.animation,
    required this.onClose,
    required this.scrollCalendarToDate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // 遮罩层：独立 GestureDetector，只响应自身区域的点击
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          // 菜单层：使用 TapRegion 拦截属于菜单区域的点击事件，
          // 避免弹出对话框关闭时的 pointer-up 穿透到遮罩层
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: animation,
              child: Material(
                color: Colors.transparent,
                child: MenuPanelWidget(
                  onClose: onClose,
                  scrollCalendarToDate: scrollCalendarToDate,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
