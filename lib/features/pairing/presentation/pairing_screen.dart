import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/presentation/app_shell.dart';
import '../domain/connection_state.dart';
import 'pairing_notifier.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(pairingNotifierProvider);
    final notifier = ref.read(pairingNotifierProvider.notifier);

    // If connected, auto navigate to dashboard
    if (connectionState.status == ConnectionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDashboard();
      });
    }

    if (connectionState.status == ConnectionStatus.searching) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing Logo Container
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.12);
                      return Transform.scale(
                        scale: connectionState.status == ConnectionStatus.searching ? scale : 1.0,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.3),
                                AppColors.primary.withOpacity(0.0),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(
                                  color: connectionState.status == ConnectionStatus.connected
                                      ? AppColors.success
                                      : AppColors.primary.withOpacity(0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Icon(
                                Icons.biotech_rounded, // Premium tech icon representing medicalbox
                                size: 50,
                                color: connectionState.status == ConnectionStatus.connected
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Title
                  Text(
                    'MediCaixa',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conecte com seu dispensador inteligente',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Status Indicator / Error Message
                  if (connectionState.status == ConnectionStatus.searching) ...[
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 16),
                    const Text(
                      'Buscando MediCaixa na rede local...',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ] else if (connectionState.status == ConnectionStatus.connecting) ...[
                    CircularProgressIndicator(strokeWidth: 3, color: AppColors.secondary),
                    const SizedBox(height: 16),
                    Text(
                      'Conectando ao dispositivo (${connectionState.ip})...',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  ] else if (connectionState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.missed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.missed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.missed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              connectionState.errorMessage!,
                              style: TextStyle(color: AppColors.missed),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Actions Group
                  if (connectionState.status != ConnectionStatus.searching &&
                      connectionState.status != ConnectionStatus.connecting) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await notifier.discoverAndConnect();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text(
                        'Buscar Automaticamente (mDNS)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await notifier.useStandalone();
                        _navigateToDashboard();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Usar sem caixinha (Modo Offline)',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OU INSERIR IP MANUAL',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'Ex: 192.168.1.100',
                        labelText: 'Endereço IP do Dispositivo',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                          onPressed: () {
                            if (_ipController.text.isNotEmpty) {
                              notifier.connectManual(_ipController.text);
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          notifier.connectManual(value);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
