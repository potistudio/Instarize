import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'panels/caption_panel.dart';
import 'panels/frame_panel.dart';
import 'panels/photos_panel.dart';
import 'theme.dart';

/// Bottom sheet holding every control. Tapping the handle collapses it to
/// give the preview the whole screen.
class ControlSheet extends StatefulWidget {
  const ControlSheet({super.key});

  @override
  State<ControlSheet> createState() => _ControlSheetState();
}

class _ControlSheetState extends State<ControlSheet> {
  var _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = media.size.height - media.viewInsets.bottom;
    final panelHeight = (available * 0.36).clamp(120.0, 320.0);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Material(
        color: kSheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: _collapsed ? '操作パネルを開く' : '操作パネルを閉じる',
                child: InkWell(
                  onTap: () => setState(() => _collapsed = !_collapsed),
                  child: SizedBox(
                    height: 20,
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TabBar(
                onTap: (_) {
                  if (_collapsed) setState(() => _collapsed = false);
                },
                dividerHeight: 0,
                tabs: const [
                  Tab(text: '写真', height: 40),
                  Tab(text: 'フレーム', height: 40),
                  Tab(text: 'キャプション', height: 40),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: _collapsed ? 0 : math.max(0, panelHeight),
                  child: const TabBarView(
                    children: [PhotosPanel(), FramePanel(), CaptionPanel()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
