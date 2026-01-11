import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/calculator_screen.dart';
import 'services/subscription_service.dart';
import 'services/finnhub_service.dart';
import 'services/env_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  
  // 載入環境變數 (從 D:\Dropbox\FlutterProjects\.env)
  await EnvService().load();
  
  // 設定 Finnhub API Key
  final finnhubKey = EnvService().get(EnvKeys.finnhubApiKey);
  if (finnhubKey != null && finnhubKey.isNotEmpty) {
    FinnhubService.setApiKey(finnhubKey);
  }
  
  // 初始化訂閱服務
  await SubscriptionService().initialize();
  
  runApp(const TXFLeverageApp());
}

class TXFLeverageApp extends StatefulWidget {
  const TXFLeverageApp({super.key});

  @override
  State<TXFLeverageApp> createState() => _TXFLeverageAppState();
}

class _TXFLeverageAppState extends State<TXFLeverageApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '台指期槓桿計算器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: CalculatorScreen(
        currentThemeMode: _themeMode,
        onThemeChanged: _updateThemeMode,
      ),
    );
  }
}
