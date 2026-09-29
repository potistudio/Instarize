import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/caption_settings.dart';
import '../models/frame_settings.dart';

/// Frame settings are shared by every photo.
final frameSettingsProvider =
    NotifierProvider<FrameSettingsNotifier, FrameSettings>(
      FrameSettingsNotifier.new,
    );

class FrameSettingsNotifier extends Notifier<FrameSettings> {
  @override
  FrameSettings build() => const FrameSettings();

  void update(FrameSettings Function(FrameSettings current) change) {
    state = change(state);
  }
}

/// Caption settings are shared too; per-photo text lives on the photo.
final captionSettingsProvider =
    NotifierProvider<CaptionSettingsNotifier, CaptionSettings>(
      CaptionSettingsNotifier.new,
    );

class CaptionSettingsNotifier extends Notifier<CaptionSettings> {
  @override
  CaptionSettings build() => const CaptionSettings();

  void update(CaptionSettings Function(CaptionSettings current) change) {
    state = change(state);
  }
}
