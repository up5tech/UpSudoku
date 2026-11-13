import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';

/// Root widget of the app.
///
/// Phase 0 only boots an empty shell; navigation (Splash → Home → Game) and the
/// controllers/screens arrive in later phases (see PLAN.md §14 and §24).
class UpSudokuApp extends StatelessWidget {
  const UpSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const Scaffold(
        body: Center(
          child: Text(
            kAppName,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
