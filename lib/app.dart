import 'package:material_ui/material_ui.dart';

import 'screens/home_shell.dart';

class GantabyaApp extends StatelessWidget {
  const GantabyaApp({super.key});

  static const seed = Color(0xFF0E7C66); // Himalayan green

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gantabya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeShell(key: HomeShell.globalKey),
    );
  }
}
