import 'package:flutter/material.dart';

import 'app.dart';
import 'data/audio_service.dart';
import 'data/puzzle_repository.dart';
import 'data/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The puzzle pools are bundled assets — no network is involved.
  final repository = PuzzleRepository();
  await repository.load();

  final storage = await StorageService.create();

  // The sound effects are bundled assets, preloaded before the first frame.
  final audio = AudioService(enabled: storage.readSettings().sound);
  await audio.preload();

  runApp(
    UpSudokuApp(repository: repository, storage: storage, audio: audio),
  );
}
