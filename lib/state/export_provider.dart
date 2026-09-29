import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/cancellable_isolate.dart';
import '../core/caption_renderer.dart';
import '../core/compositor.dart';
import '../core/frame_layout.dart';
import 'photos_provider.dart';
import 'settings_providers.dart';

/// Output goes to `Pictures/<kAlbumName>`.
const String kAlbumName = 'Instarize';

enum ExportStatus { idle, running, finished, cancelled, failed }

class ExportState {
  const ExportState({
    this.status = ExportStatus.idle,
    this.done = 0,
    this.total = 0,
    this.saved = 0,
    this.failed = 0,
    this.message,
  });

  final ExportStatus status;

  /// Photos processed so far (saved or failed).
  final int done;
  final int total;
  final int saved;
  final int failed;
  final String? message;

  ExportState copyWith({
    ExportStatus? status,
    int? done,
    int? saved,
    int? failed,
    String? message,
  }) {
    return ExportState(
      status: status ?? this.status,
      done: done ?? this.done,
      total: total,
      saved: saved ?? this.saved,
      failed: failed ?? this.failed,
      message: message ?? this.message,
    );
  }
}

final exportProvider = NotifierProvider<ExportNotifier, ExportState>(
  ExportNotifier.new,
);

class ExportNotifier extends Notifier<ExportState> {
  CancelToken? _token;

  @override
  ExportState build() => const ExportState();

  /// Renders every photo at full resolution, one at a time, and saves it to
  /// the gallery. Only one full-size image is in memory at any moment.
  Future<void> start() async {
    if (state.status == ExportStatus.running) return;
    final photos = ref.read(photosProvider).photos;
    final frame = ref.read(frameSettingsProvider);
    final caption = ref.read(captionSettingsProvider);
    if (photos.isEmpty) return;

    final token = _token = CancelToken();
    state = ExportState(status: ExportStatus.running, total: photos.length);

    try {
      final granted =
          await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        state = state.copyWith(
          status: ExportStatus.failed,
          message: '写真を保存する権限がありません',
        );
        return;
      }

      final dir = Directory(
        p.join((await getTemporaryDirectory()).path, 'export'),
      );
      await dir.create(recursive: true);
      final stamp = _timestamp(DateTime.now());

      for (var i = 0; i < photos.length; i++) {
        if (token.isCancelled) break;
        final photo = photos[i];
        final output = File(
          p.join(dir.path, '${kAlbumName}_${stamp}_${_pad(i + 1)}.jpg'),
        );
        try {
          final layout = computeFrameLayout(
            photoWidth: photo.width,
            photoHeight: photo.height,
            frame: frame,
            caption: caption,
          );
          final prepared = PreparedCaption.create(
            layout: layout,
            text: captionTextFor(photo, caption),
            settings: caption,
          );
          final List<TextTile> tiles;
          try {
            tiles = prepared == null
                ? const []
                : await rasterizeCaption(prepared, layout);
          } finally {
            prepared?.dispose();
          }

          await runCancellable(
            runComposeJob,
            ComposeJob(
              sourcePath: photo.path,
              outputPath: output.path,
              layout: layout,
              frameColor: frame.color.toARGB32(),
              tiles: tiles,
            ),
            token,
          );
          await Gal.putImage(output.path, album: kAlbumName);
          state = state.copyWith(saved: state.saved + 1);
        } on CancelledException {
          break;
        } on GalException catch (e) {
          // Storage problems affect every remaining photo as well.
          state = state.copyWith(
            status: ExportStatus.failed,
            message: _galMessage(e.type),
          );
          return;
        } catch (e, stack) {
          debugPrint('Export failed for ${photo.path}: $e\n$stack');
          state = state.copyWith(failed: state.failed + 1);
        } finally {
          if (await output.exists()) await output.delete();
        }
        state = state.copyWith(done: i + 1);
      }

      state = state.copyWith(
        status: token.isCancelled
            ? ExportStatus.cancelled
            : ExportStatus.finished,
      );
    } catch (e) {
      state = state.copyWith(status: ExportStatus.failed, message: '$e');
    } finally {
      if (identical(_token, token)) _token = null;
    }
  }

  void cancel() => _token?.cancel();

  static String _galMessage(GalExceptionType type) => switch (type) {
    GalExceptionType.accessDenied => '写真を保存する権限がありません',
    GalExceptionType.notEnoughSpace => '端末の空き容量が不足しています',
    GalExceptionType.notSupportedFormat => '保存できない形式です',
    GalExceptionType.unexpected => '保存中に予期しないエラーが発生しました',
  };

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _timestamp(DateTime t) =>
      '${t.year}${_pad(t.month)}${_pad(t.day)}_'
      '${_pad(t.hour)}${_pad(t.minute)}${_pad(t.second)}';
}
