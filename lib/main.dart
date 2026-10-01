import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/database_helper.dart';
import 'features/recurring/data/services/recurring_transaction_service.dart';
import 'features/transactions/presentation/screens/main_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RecurringTransactionService(
      databaseHelper: DatabaseHelper.instance,
    ).executeDueTransactions();
  } catch (error, stackTrace) {
    debugPrint('Recurring transaction check failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(const ProviderScope(child: KyatFlowApp()));
}

class KyatFlowApp extends StatelessWidget {
  const KyatFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KyatFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6755),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6F1),
        fontFamily: 'sans-serif',
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFDCEAE4),
          height: 72,
          elevation: 0,
        ),
      ),
      home: const MainShellScreen(),
    );
  }
}
