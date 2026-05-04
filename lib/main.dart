import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'domain/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LogiStock — Inventario',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(), // El login verifica sesión guardada antes de mostrar el form
      debugShowCheckedModeBanner: false,
    );
  }
}
