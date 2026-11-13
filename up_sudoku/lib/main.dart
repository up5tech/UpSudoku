import 'package:flutter/material.dart';

import 'app.dart';
import 'data/puzzle_repository.dart';
import 'data/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The puzzle pools are bundled assets — no network is involved.
  final repository = PuzzleRepository();
  await repository.load();

  final storage = await StorageService.create();

  runApp(UpSudokuApp(repository: repository, storage: storage));
}
