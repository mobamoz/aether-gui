import 'package:flutter/material.dart';
import 'controller.dart';
import 'home_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AetherController();
  await controller.init();
  runApp(AetherApp(controller));
}

class AetherApp extends StatelessWidget {
  const AetherApp(this.controller, {super.key});
  final AetherController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Aether',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Palette.zenith, surface: Palette.cloud),
          scaffoldBackgroundColor: Palette.cloud,
        ),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HomePage(controller),
      );
}
