import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../core/network/connection_manager.dart';
import '../../../core/network/udp_service.dart';
import '../../../features/dashboard/providers/telemetry_provider.dart';
import '../../../features/dashboard/screens/dashboard_screen.dart';

/// Futuristic connection screen for configuring the PS5 IP address.
///
/// Glowing neon accent, carbon dark theme, Orbitron typography.
/// Shown on first launch or when no saved IP exists.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _pulseController;

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _loadSavedIp() async {
    final savedIp = await ConnectionManager.loadSavedIp();
    if (savedIp != null && mounted) {
      _ipController.text = savedIp;
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    final ip = _ipController.text.trim();
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await ConnectionManager.saveIp(ip);
      final udpService = ref.read(udpServiceProvider);
      await udpService.start(ip);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const _DashboardRedirect(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'CONNECTION FAILED: $e';
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return Scaffold(
      backgroundColor: AppColors.carbonBlack,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Futuristic title with glow ─────────────
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = 0.4 + (_pulseController.value * 0.6);
                    return Text(
                      'TELEMETRY ONE',
                      style: AppTypography.orbitron(
                        size: 32,
                        weight: FontWeight.w900,
                        color: AppColors.telemetryOrange,
                        letterSpacing: 6,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: AppColors.telemetryOrange
                                .withValues(alpha: glow * 0.5),
                            blurRadius: 20 + (_pulseController.value * 15),
                          ),
                          Shadow(
                            color: AppColors.telemetryOrange
                                .withValues(alpha: glow * 0.3),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'GT7 TELEMETRY',
                  style: AppTypography.orbitron(
                    size: 11,
                    weight: FontWeight.w300,
                    color: AppColors.textDim,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 40),

                // ─── Panel card ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.darkSurface.withValues(alpha: 0.6),
                      width: 0.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkSurface.withValues(alpha: 0.15),
                        AppColors.carbonBlack,
                        AppColors.darkSurface.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // IP Input
                      TextFormField(
                        controller: _ipController,
                        style: AppTypography.orbitron(
                          size: 24,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          labelText: 'PS5 IP ADDRESS',
                          labelStyle: AppTypography.orbitron(
                            size: 10,
                            color: AppColors.textDim,
                            letterSpacing: 2,
                          ),
                          hintText: '192.168.1.100',
                          hintStyle: AppTypography.orbitron(
                            size: 24,
                            color: AppColors.textDim.withValues(alpha: 0.3),
                            letterSpacing: 3,
                          ),
                          filled: true,
                          fillColor: AppColors.graphite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: AppColors.darkSurface,
                              width: 0.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: AppColors.darkSurface
                                  .withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: AppColors.telemetryOrange
                                  .withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          errorStyle: AppTypography.inter(
                            size: 11,
                            color: AppColors.error,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.go,
                        onFieldSubmitted: (_) => _connect(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an IP address';
                          }
                          if (!ConnectionManager.isValidIp(value.trim())) {
                            return 'Invalid format (e.g. 192.168.1.100)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.inter(
                                size: 12,
                                color: AppColors.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      // Connect button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isConnecting ? null : _connect,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.telemetryOrange,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            disabledBackgroundColor:
                                AppColors.telemetryOrange.withValues(alpha: 0.3),
                          ),
                          child: _isConnecting
                              ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.carbonBlack,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'CONNECTING...',
                                      style: AppTypography.orbitron(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'CONNECT',
                                  style: AppTypography.orbitron(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    letterSpacing: 3,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ─── Footer info ──────────────────────────────
                Text(
                  'MAKE SURE YOUR PS5 IS RUNNING GT7',
                  style: AppTypography.inter(
                    size: 8,
                    color: AppColors.textDim.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CONNECT TO THE SAME NETWORK',
                  style: AppTypography.inter(
                    size: 8,
                    color: AppColors.textDim.withValues(alpha: 0.3),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal redirect widget that goes straight to the dashboard.
class _DashboardRedirect extends ConsumerWidget {
  const _DashboardRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final udpService = ref.read(udpServiceProvider);

    if (udpService.currentState == UdpConnectionState.listening) {
      return const DashboardScreen();
    }

    return const ConnectionScreen();
  }
}
