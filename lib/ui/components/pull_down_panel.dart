import 'dart:ui';
import 'package:flutter/material.dart';

class PullDownPanel extends StatefulWidget {
  final Widget child;
  final Widget Function(
    BuildContext context,
    TextEditingController searchController,
  )
  panelContent;
  final double panelHeight;
  final double dragThreshold;

  const PullDownPanel({
    super.key,
    required this.child,
    required this.panelContent,
    this.panelHeight = 280,
    this.dragThreshold = 80,
  });

  @override
  State<PullDownPanel> createState() => _PullDownPanelState();
}

class _PullDownPanelState extends State<PullDownPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();
  double _dragExtent = 0;
  bool _isPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openPanel() {
    if (!_isPanelOpen) {
      _animationController.forward();
      setState(() => _isPanelOpen = true);
    }
  }

  void _closePanel() {
    if (_isPanelOpen) {
      _animationController.reverse();
      setState(() => _isPanelOpen = false);
    }
  }

  void _togglePanel() {
    if (_isPanelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPanelOpen || _animationController.value > 0)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closePanel,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8 * _animationController.value,
                      sigmaY: 8 * _animationController.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.3 * _animationController.value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  -widget.panelHeight * (1 - _animationController.value),
                ),
                child: child,
              );
            },
            child: Container(
              height: widget.panelHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.panelContent(context, _searchController),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 40,
          child: GestureDetector(
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (details) {
              if (!_isPanelOpen) {
                setState(() {
                  _dragExtent += details.delta.dy;
                  _animationController.value =
                      (-_dragExtent / widget.dragThreshold).clamp(0.0, 1.0);
                });
              }
            },
            onVerticalDragEnd: (details) {
              if (_dragExtent < -widget.dragThreshold / 2) {
                _openPanel();
              } else {
                _closePanel();
              }
              setState(() => _dragExtent = 0);
            },
            onTap: _togglePanel,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isPanelOpen
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PullDownMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isToggle;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggleChanged;

  const PullDownMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isToggle = false,
    this.toggleValue,
    this.onToggleChanged,
  });
}

class PullDownMenuGrid extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final List<PullDownMenuItem> menuItems;
  final int crossAxisCount;

  const PullDownMenuGrid({
    super.key,
    required this.searchController,
    this.onSearchChanged,
    this.searchHint,
    required this.menuItems,
    this.crossAxisCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: searchHint ?? '搜索任务...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return _buildMenuItem(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, PullDownMenuItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToggled = item.toggleValue ?? false;

    return InkWell(
      onTap: item.isToggle ? null : item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isToggled
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: isToggled
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: item.isToggle
                ? IconButton(
                    icon: Icon(
                      item.icon,
                      color: isToggled
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      item.onToggleChanged?.call(!isToggled);
                    },
                  )
                : Icon(
                    item.icon,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              color: isToggled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
