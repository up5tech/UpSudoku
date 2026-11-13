# Asset Licenses

All third-party assets bundled with UpSudoku are listed here, with their source
and license. Everything is bundled at build time; the app never downloads
assets at runtime.

## Fonts

### Baloo 2

- Files: `up_sudoku/assets/fonts/Baloo2-Regular.ttf`, `up_sudoku/assets/fonts/Baloo2-Bold.ttf`
- Copyright 2019 The Baloo 2 Project Authors (https://github.com/EkType/Baloo2)
- License: SIL Open Font License, Version 1.1 (see `up_sudoku/assets/fonts/OFL.txt`)
- Source: Google Fonts (https://fonts.google.com/specimen/Baloo+2), static
  weights 400 and 700 served from `fonts.gstatic.com`.

## Audio

- Files: `up_sudoku/assets/audio/{tap,place,error,unit_complete,win,lose}.wav`
- Source: generated for this project by `up_sudoku/tool/generate_sounds.py`
  (Python standard library only — synthesised sine/harmonic tones, no samples).
- License: original work, released with the app; no third-party audio is bundled.
- Format: 16-bit mono PCM WAV at 44.1 kHz, 4–42 KB per effect. They are played
  from bundle assets with `AssetSource`; nothing is downloaded.

## Images

- Files: `up_sudoku/assets/images/icon.png`, `icon_foreground.png`, the Android
  splash art (`android/app/src/main/res/drawable-nodpi/launch_image.png`) and the
  iOS `LaunchImage` set.
- Source: generated for this project by `up_sudoku/tool/generate_icon.dart` (a
  pure-Dart 1024×1024 drawing encoded as PNG, no third-party artwork).
- License: original work, released with the app.
- Platform launcher icons are produced from `assets/images/icon.png` with
  `flutter_launcher_icons` (config in `up_sudoku/pubspec.yaml`).
