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
      child: MaterialApp(
        title: 'MusicVid Studio',
        theme: ThemeData.dark(useMaterial3: true),
        home: const DashboardScreen(),
      ),
    );
  }
}
