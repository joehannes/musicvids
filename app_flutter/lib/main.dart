import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MusicVidStudioApp());
}

class MusicVidStudioApp extends StatelessWidget {
  const MusicVidStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (_, state, __) => MaterialApp(
          title: 'MusicVid Studio',
          theme: state.activeTheme,
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
