# Instarize

複数枚の写真に同じフレームとキャプションをまとめて適用し、元解像度の JPEG（品質 95）として `Pictures/Instarize` に保存する Android アプリ。完全オフラインで動作する。

## ビルドと実行

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
flutter run                    # 接続中の Android 端末 / エミュレータで起動
```

対象は Android 7.0（minSdk 24）以上。写真の選択は Photo Picker を使うため、ストレージ権限は要求しない（Android 10 以下での保存時だけ書き込み権限を求める）。

## 構成

| パス | 役割 |
| --- | --- |
| `lib/core/frame_layout.dart` | 余白・写真・キャプション位置を元解像度のピクセルで計算。プレビューと書き出しで共通 |
| `lib/core/caption_template.dart` | EXIF の整形と `{camera}` などのテンプレート展開。欠けた変数の区切り文字を除去 |
| `lib/core/caption_renderer.dart` | キャプション描画（プレビューは縮小キャンバス、書き出しは等倍でタイル状にラスタライズ） |
| `lib/core/compositor.dart` | 別 isolate でデコード → Orientation 反映 → 合成 → JPEG エンコード |
| `lib/state/` | Riverpod の状態（写真リスト、設定、プレビュー画像、書き出し） |

書き出しは1枚ずつ、キャンセルするとすぐ kill できる isolate で処理する。プレビューはエンジン側で長辺 1600px に縮小デコードする。

## 使用パッケージ

- `flutter_riverpod`: 指定された状態管理。コード生成なしで使える
- `image_picker`（+ `image_picker_android` / `image_picker_platform_interface`）: Flutter 公式。Photo Picker を明示的に有効化するために直接依存している
- `image`: 純 Dart のため isolate で動く。JPEG デコード時に EXIF Orientation を適用し、ICC プロファイルと EXIF も読み書きできる
- `gal`: MediaStore 経由で `Pictures/<アルバム>` に保存。Android 10 以降は権限不要
- `path_provider` / `path`: Dart・Flutter チームのパッケージ。一時ファイルのパス処理に使う

## 既知の制約

- HEIC / AVIF は読み込めない（選択時に「非対応」と表示してスキップ）。対応形式は JPEG・PNG・WebP・GIF・BMP・TIFF
- フォントは Android のシステムフォント（sans-serif / serif / monospace など）なので、見た目はメーカーや OS バージョンで少し変わる
- 出力の EXIF に残すのは撮影情報（機種・レンズ・露出・日時）だけ。GPS・メーカーノート・サムネイルは含めない
- 設定はアプリを終了すると初期値に戻る
