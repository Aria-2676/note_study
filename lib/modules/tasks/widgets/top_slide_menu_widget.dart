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
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: animation,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  color: Colors.transparent,
                  child: MenuPanelWidget(
                    onClose: onClose,
                    scrollCalendarToDate: scrollCalendarToDate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
