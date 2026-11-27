import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(VoiceRelayApp(state: state));
}

class VoiceRelayApp extends StatelessWidget {
  const VoiceRelayApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语音遥控',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) => RootScreen(state: state),
      ),
    );
  }
}
