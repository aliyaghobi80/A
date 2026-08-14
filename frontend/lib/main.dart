import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'models/system_info.dart';
import 'services/api_service.dart';
import 'services/backend_process_manager.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/simple_mode_view.dart';
import 'widgets/advanced_mode_view.dart';
import 'widgets/loading_view.dart';
import 'widgets/error_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.loadSettings();
  runApp(CentralSystemCheckerApp(initialSettings: settings));
}

class CentralSystemCheckerApp extends StatefulWidget {
  final AppSettings initialSettings;

  const CentralSystemCheckerApp({
    super.key,
    required this.initialSettings,
  });

  @override
  State<CentralSystemCheckerApp> createState() => _CentralSystemCheckerAppState();
}

class _CentralSystemCheckerAppState extends State<CentralSystemCheckerApp> {
  late String _languageCode;
  late DisplayMode _displayMode;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.initialSettings.languageCode;
    _displayMode = widget.initialSettings.displayMode;
    _isDarkMode = widget.initialSettings.isDarkMode;
  }

  void _updateSettings({
    String? languageCode,
    DisplayMode? displayMode,
    bool? isDarkMode,
  }) {
    setState(() {
      if (languageCode != null) _languageCode = languageCode;
      if (displayMode != null) _displayMode = displayMode;
      if (isDarkMode != null) _isDarkMode = isDarkMode;
    });

    SettingsService.saveSettings(
      AppSettings(
        languageCode: _languageCode,
        displayMode: _displayMode,
        isDarkMode: _isDarkMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = _languageCode == 'fa';
    final textDirection = isPersian ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp(
      title: isPersian ? 'مرکزی سیستم چکر' : 'Central System Checker',
      debugShowCheckedModeBanner: false,
      locale: Locale(_languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.getLightTheme(languageCode: _languageCode),
      darkTheme: AppTheme.getDarkTheme(languageCode: _languageCode),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: DashboardScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: () => _updateSettings(isDarkMode: !_isDarkMode),
        displayMode: _displayMode,
        onModeChanged: (mode) => _updateSettings(displayMode: mode),
        currentLanguage: _languageCode,
        onLanguageChanged: (lang) => _updateSettings(languageCode: lang),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onModeChanged;
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const DashboardScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.displayMode,
    required this.onModeChanged,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  SystemInfo? _systemInfo;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
  }

  @override
  void dispose() {
    BackendProcessManager.dispose();
    super.dispose();
  }

  Future<void> _loadSystemInfo({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final info = await _apiService.fetchSystemInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _systemInfo = info;
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: _buildBody(context, isDark, l10n),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, AppLocalizations l10n) {
    if (_isLoading) {
      return LoadingView(
        message: l10n.loadingMessage,
      );
    }

    if (_errorMessage != null && _systemInfo == null) {
      return ErrorView(
        errorMessage: _errorMessage!,
        onRetry: () => _loadSystemInfo(forceRefresh: true),
      );
    }

    if (_systemInfo == null) {
      return LoadingView(
        message: l10n.initializingMessage,
      );
    }

    final info = _systemInfo!;

    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101728) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: AppHeader(
            isRefreshing: _isRefreshing,
            onRefresh: () => _loadSystemInfo(forceRefresh: true),
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
            displayMode: widget.displayMode,
            onModeChanged: widget.onModeChanged,
            currentLanguage: widget.currentLanguage,
            onLanguageChanged: widget.onLanguageChanged,
            lastUpdated: info.timestamp,
          ),
        ),

        // Main Scrollable Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render Simple Mode or Advanced Mode
                if (widget.displayMode == DisplayMode.simple)
                  SimpleModeView(info: info)
                else
                  AdvancedModeView(info: info),

                const SizedBox(height: 24),

                // Footer Status
                Center(
                  child: Directionality(
                    textDirection: widget.currentLanguage == 'fa'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      l10n.scanCompleted(info.scanDurationMs, info.system.computerName),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
