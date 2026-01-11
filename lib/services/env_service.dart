/// 環境變數服務
/// 
/// 從外部路徑讀取共用的環境變數配置檔
/// 配置檔位置: D:\Dropbox\FlutterProjects\.env
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

class EnvService {
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  final Map<String, String> _env = {};
  bool _isLoaded = false;

  /// 環境變數檔案路徑
  /// 根據平台調整路徑
  static String get _envFilePath {
    if (Platform.isWindows) {
      // Windows: 使用 Dropbox 路徑
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return '$userProfile\\Dropbox\\FlutterProjects\\.env';
    } else if (Platform.isMacOS || Platform.isLinux) {
      // macOS/Linux
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Dropbox/FlutterProjects/.env';
    } else {
      // Android/iOS: 使用內建的 assets（需另外處理）
      return '';
    }
  }

  /// 載入環境變數
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      // 桌面平台：從外部檔案讀取
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final file = File(_envFilePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          _parseEnvContent(content);
          debugPrint('EnvService: Loaded from $_envFilePath');
        } else {
          debugPrint('EnvService: File not found at $_envFilePath');
        }
      }
      // Android/iOS: 從系統環境變數讀取（需在原生層設定）
      else {
        // 嘗試從系統環境變數讀取
        _env['FINNHUB_API_KEY'] = Platform.environment['FINNHUB_API_KEY'] ?? '';
        _env['ANTHROPIC_API_KEY'] = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
      }
    } catch (e) {
      debugPrint('EnvService: Error loading env file: $e');
    }

    _isLoaded = true;
  }

  /// 解析 .env 檔案內容
  void _parseEnvContent(String content) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      
      // 跳過註解和空行
      if (line.isEmpty || line.startsWith('#')) continue;
      
      // 解析 KEY=VALUE
      final index = line.indexOf('=');
      if (index > 0) {
        final key = line.substring(0, index).trim();
        var value = line.substring(index + 1).trim();
        
        // 移除引號
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        
        _env[key] = value;
      }
    }
  }

  /// 取得環境變數
  String? get(String key) => _env[key];

  /// 取得環境變數，若不存在則回傳預設值
  String getOrDefault(String key, String defaultValue) {
    return _env[key] ?? defaultValue;
  }

  /// 檢查是否有該環境變數
  bool has(String key) => _env.containsKey(key) && _env[key]!.isNotEmpty;

  /// 所有環境變數（除錯用，隱藏敏感值）
  Map<String, String> get debugInfo {
    return _env.map((key, value) {
      if (key.toLowerCase().contains('key') || 
          key.toLowerCase().contains('secret') ||
          key.toLowerCase().contains('password')) {
        return MapEntry(key, '***${value.substring(value.length - 4)}');
      }
      return MapEntry(key, value);
    });
  }
}

/// 環境變數 Key 常數
class EnvKeys {
  static const String finnhubApiKey = 'FINNHUB_API_KEY';
  static const String anthropicApiKey = 'ANTHROPIC_API_KEY';
  static const String googlePlayLicenseKey = 'GOOGLE_PLAY_LICENSE_KEY';
  static const String admobAppId = 'ADMOB_APP_ID';
  static const String admobBannerId = 'ADMOB_BANNER_ID';
}
