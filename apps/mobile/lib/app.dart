import 'package:flutter/material.dart';

import 'features/foundation/presentation/home_screen.dart';
import 'shared/api/api_client.dart';
import 'shared/theme/app_theme.dart';

class FinancialShockApp extends StatefulWidget {
  const FinancialShockApp({super.key});

  @override
  State<FinancialShockApp> createState() => _FinancialShockAppState();
}

class _FinancialShockAppState extends State<FinancialShockApp> {
  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(apiClient: _apiClient),
      theme: AppTheme.light,
      title: '금융 충격 미리보기',
    );
  }
}
