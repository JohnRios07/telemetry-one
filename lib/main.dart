import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/storage/session_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for session storage
  await SessionRepository.initialize();

  runApp(
    const ProviderScope(
      child: TelemetryOneApp(),
    ),
  );
}
