import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/photo_metadata.dart';
import '../models/photo_item.dart';

const int kMaxPhotos = 30;

class PhotoSelection {
  const PhotoSelection({this.photos = const [], this.importing = false});

  final List<PhotoItem> photos;
  final bool importing;

  bool get isFull => photos.length >= kMaxPhotos;
}

class ImportResult {
  const ImportResult({
    this.added = 0,
    this.unsupported = 0,
    this.overLimit = 0,
  });

  final int added;
  final int unsupported;
  final int overLimit;
}

final photosProvider = NotifierProvider<PhotosNotifier, PhotoSelection>(
  PhotosNotifier.new,
);

/// Index of the photo shown in the preview.
final currentIndexProvider = NotifierProvider<CurrentIndexNotifier, int>(
  CurrentIndexNotifier.new,
);

class CurrentIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

class PhotosNotifier extends Notifier<PhotoSelection> {
  final _picker = ImagePicker();
  var _nextId = 0;

  @override
  PhotoSelection build() => const PhotoSelection();

  /// Opens the system Photo Picker and appends the chosen photos.
  Future<ImportResult> pickAndAdd() async {
    final remaining = kMaxPhotos - state.photos.length;
    if (remaining <= 0 || state.importing) return const ImportResult();

    final files = await _picker.pickMultiImage(limit: remaining);
    if (files.isEmpty) return const ImportResult();

    state = PhotoSelection(photos: state.photos, importing: true);
    try {
      final accepted = files.take(remaining).map((f) => f.path).toList();
      for (final extra in files.skip(remaining)) {
        await _deletePickerCopy(extra.path);
      }
      final metadata = await Isolate.run(() => _readAll(accepted));

      final added = <PhotoItem>[];
      var unsupported = 0;
      for (var i = 0; i < accepted.length; i++) {
        final meta = metadata[i];
        if (meta == null) {
          unsupported++;
          await _deletePickerCopy(accepted[i]);
          continue;
        }
        added.add(
          PhotoItem(
            id: 'p${_nextId++}',
            path: accepted[i],
            width: meta.width,
            height: meta.height,
            exif: meta.exif,
          ),
        );
      }
      state = PhotoSelection(photos: [...state.photos, ...added]);
      return ImportResult(
        added: added.length,
        unsupported: unsupported,
        overLimit: files.length - accepted.length,
      );
    } finally {
      if (state.importing) {
        state = PhotoSelection(photos: state.photos);
      }
    }
  }

  void remove(String id) {
    final target = state.photos.where((photo) => photo.id == id).firstOrNull;
    if (target == null) return;
    state = PhotoSelection(
      photos: [
        for (final photo in state.photos)
          if (photo.id != id) photo,
      ],
      importing: state.importing,
    );
    final index = ref.read(currentIndexProvider);
    if (index >= state.photos.length && index > 0) {
      ref.read(currentIndexProvider.notifier).select(state.photos.length - 1);
    }
    _deletePickerCopy(target.path);
  }

  /// Moves the photo at [oldIndex] so that it ends up at [newIndex].
  void reorder(int oldIndex, int newIndex) {
    final photos = [...state.photos];
    photos.insert(newIndex, photos.removeAt(oldIndex));
    state = PhotoSelection(photos: photos, importing: state.importing);
    // Keep previewing the photo that was moved.
    ref.read(currentIndexProvider.notifier).select(newIndex);
  }

  void setCaptionOverride(String id, String? text) {
    state = PhotoSelection(
      photos: [
        for (final photo in state.photos)
          photo.id == id ? photo.withCaptionOverride(text) : photo,
      ],
      importing: state.importing,
    );
  }

  /// The picker hands us private copies in the cache directory; remove them
  /// once they are no longer needed. Anything outside the cache is left alone.
  Future<void> _deletePickerCopy(String path) async {
    try {
      final cache = (await getTemporaryDirectory()).path;
      if (!p.isWithin(cache, path)) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort: the OS clears the cache eventually anyway.
    }
  }
}

List<PhotoMetadata?> _readAll(List<String> paths) => [
  for (final path in paths) _tryRead(path),
];

PhotoMetadata? _tryRead(String path) {
  try {
    return readPhotoMetadata(path);
  } on Object {
    return null;
  }
}
