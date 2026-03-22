import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/meridian_colors.dart';

/// A large FAB that represents the beacon transmit action.
///
/// - Idle: primary blue background, broadcasting icon.
/// - Active ([isBeaconing] == true): danger red background, pulsing scale
///   animation to indicate TX is live.
///
/// The hero tag is fixed to `'beacon_fab'` to avoid conflicts in scaffolds
/// that show multiple FABs.
class BeaconFAB extends StatefulWidget {
  const BeaconFAB({super.key, required this.isBeaconing, required this.onTap});

  final bool isBeaconing;
  final VoidCallback onTap;

  @override
  State<BeaconFAB> createState() => _BeaconFABState();
}

class _BeaconFABState extends State<BeaconFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(BeaconFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBeaconing != widget.isBeaconing) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isBeaconing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = widget.isBeaconing
        ? MeridianColors.danger
        : colorScheme.primary;
    final fgColor = widget.isBeaconing
        ? colorScheme.surface
        : colorScheme.onPrimary;

    return ScaleTransition(
      scale: widget.isBeaconing
          ? _scaleAnim
          : const AlwaysStoppedAnimation(1.0),
      child: Semantics(
        label: widget.isBeaconing ? 'Stop beaconing' : 'Start beacon',
        button: true,
        child: FloatingActionButton.extended(
          heroTag: 'beacon_fab',
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onTap();
          },
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          tooltip: widget.isBeaconing ? 'Stop beaconing' : 'Send beacon',
          icon: Icon(
            widget.isBeaconing ? Symbols.wifi_tethering : Symbols.podcasts,
          ),
          label: Text(widget.isBeaconing ? 'Beaconing' : 'Beacon'),
        ),
      ),
    );
  }
}
