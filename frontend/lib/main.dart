import 'package:flutter/material.dart';
import 'models/system_info.dart';
import 'services/api_service.dart';
import 'services/backend_process_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/summary_hero_bar.dart';
import 'widgets/loading_view.dart';
import 'widgets/error_view.dart';
import 'widgets/cards/cpu_card.dart';
import 'widgets/cards/motherboard_card.dart';
import 'widgets/cards/ram_card.dart';
import 'widgets/cards/gpu_card.dart';
import 'widgets/cards/storage_card.dart';
import 'widgets/cards/windows_card.dart';
import 'widgets/cards/bios_card.dart';
import 'widgets/cards/network_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PcSystemInspectorApp());
}

class PcSystemInspectorApp extends StatefulWidget {
  const PcSystemInspectorApp({super.key});

  @override
  State<PcSystemInspectorApp> createState() => _PcSystemInspectorAppState();
}

class _PcSystemInspectorAppState extends State<PcSystemInspectorApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PC System Inspector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DashboardScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
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

    return Scaffold(
      body: SafeArea(
        child: _buildBody(context, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const LoadingView(
        message: 'Detecting hardware & Windows specifications...',
      );
    }

    if (_errorMessage != null && _systemInfo == null) {
      return ErrorView(
        errorMessage: _errorMessage!,
        onRetry: () => _loadSystemInfo(forceRefresh: true),
      );
    }

    if (_systemInfo == null) {
      return const LoadingView(
        message: 'Initializing inspector...',
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
            lastUpdated: info.timestamp,
          ),
        ),

        // Main Scrollable Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Overview Bar
                SummaryHeroBar(info: info),
                const SizedBox(height: 20),

                // Responsive Grid of Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 950;

                    if (isWide) {
                      // 2-Column Desktop Grid
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column
                          Expanded(
                            child: Column(
                              children: [
                                CpuCard(cpu: info.cpu),
                                const SizedBox(height: 16),
                                GpuCard(gpus: info.gpu),
                                const SizedBox(height: 16),
                                StorageCard(storage: info.storage),
                                const SizedBox(height: 16),
                                BiosCard(bios: info.bios),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right Column
                          Expanded(
                            child: Column(
                              children: [
                                RamCard(ram: info.ram),
                                const SizedBox(height: 16),
                                MotherboardCard(motherboard: info.motherboard),
                                const SizedBox(height: 16),
                                WindowsCard(
                                  windows: info.windows,
                                  system: info.system,
                                ),
                                const SizedBox(height: 16),
                                NetworkCard(network: info.network),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Single Column Layout for narrow windows
                      return Column(
                        children: [
                          CpuCard(cpu: info.cpu),
                          const SizedBox(height: 16),
                          RamCard(ram: info.ram),
                          const SizedBox(height: 16),
                          GpuCard(gpus: info.gpu),
                          const SizedBox(height: 16),
                          MotherboardCard(motherboard: info.motherboard),
                          const SizedBox(height: 16),
                          StorageCard(storage: info.storage),
                          const SizedBox(height: 16),
                          WindowsCard(
                            windows: info.windows,
                            system: info.system,
                          ),
                          const SizedBox(height: 16),
                          BiosCard(bios: info.bios),
                          const SizedBox(height: 16),
                          NetworkCard(network: info.network),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Footer Status
                Center(
                  child: Text(
                    'Inspection scan completed in ${info.scanDurationMs.toStringAsFixed(0)} ms • Local Windows Host (${info.system.computerName})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
