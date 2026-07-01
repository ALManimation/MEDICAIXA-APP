import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../data/services/llm_providers.dart';
import '../../data/services/voice_providers.dart';
import '../../data/services/voice_service.dart';

class VoiceAssistantSheet extends ConsumerStatefulWidget {
  const VoiceAssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const VoiceAssistantSheet(),
    );
  }

  @override
  ConsumerState<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends ConsumerState<VoiceAssistantSheet> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;
  bool _isThinking = false;
  bool _isListeningBusy = false;
  String _transcribedText = '';
  late final VoiceService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceServiceProvider);

    // Sync locale with the voice service complying with Rule 57
    final selectedLanguage = ref.read(appLocaleProvider);
    final langCode = selectedLanguage.split('_').first.split('-').first.toLowerCase();
    String voiceLocale = 'pt-BR';
    if (langCode == 'en') {
      voiceLocale = 'en-US';
    } else if (langCode == 'es') {
      voiceLocale = 'es-ES';
    }
    _voiceService.setLocale(voiceLocale);

    _messages.add({
      'role': 'model',
      'parts': [
        {'text': t('chat_welcome')}
      ]
    });
  }

  @override
  void dispose() {
    // Stop recording and speaking when closing to ensure proper cleanup
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListeningBusy) return;
    setState(() {
      _isListeningBusy = true;
    });

    try {
      if (_isListening) {
        await _voiceService.stopListening();
        if (context.mounted) {
          setState(() {
            _isListening = false;
          });
        }
        if (_transcribedText.isNotEmpty) {
          final query = _transcribedText;
          _transcribedText = '';
          await _processQuery(query);
        }
      } else {
        _transcribedText = '';
        await _voiceService.startListening(
          onResult: (text) {
            if (context.mounted) {
              setState(() {
                _transcribedText = text;
              });
            }
          },
          onListeningStatusChanged: (listening) async {
            if (context.mounted) {
              setState(() {
                _isListening = listening;
              });
              if (!listening && _transcribedText.isNotEmpty) {
                final query = _transcribedText;
                _transcribedText = '';
                await _processQuery(query);
              }
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error toggling listening: $e');
    } finally {
      if (context.mounted) {
        setState(() {
          _isListeningBusy = false;
        });
      }
    }
  }

  Future<void> _processQuery(String text) async {
    if (text.trim().isEmpty) return;

    final llmService = ref.read(hybridLlmServiceProvider);
    final executor = ref.read(actionExecutorProvider);

    setState(() {
      _messages.add({
        'role': 'user',
        'parts': [
          {'text': text}
        ]
      });
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final response = await llmService.generateResponse(
        text,
        history: _messages.sublist(0, _messages.length - 1),
      );

      if (!context.mounted) return;

      setState(() {
        _messages.add({
          'role': 'model',
          'parts': [
            {'text': response.message}
          ]
        });
        _isThinking = false;
      });
      _scrollToBottom();

      if (!context.mounted) return;

      // Execute actions
      if (response.actions.isNotEmpty) {
        await executor.execute(response.actions);
      }

      if (!context.mounted) return;

      // Voice response
      await _voiceService.speak(response.message);
      await _voiceService.playFeedbackTone('success');
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _messages.add({
          'role': 'model',
          'parts': [
            {'text': t('voice_error')}
          ]
        });
        _isThinking = false;
      });
      _scrollToBottom();

      if (!context.mounted) return;

      await _voiceService.playFeedbackTone('error');
    }
  }

  void _submitText() {
    final query = _textController.text.trim();
    if (query.isNotEmpty) {
      _textController.clear();
      _processQuery(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardHeight = bottomInset > 0 ? bottomInset : 0.0;
    final double sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight + keyboardHeight,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header with drag handle, title, and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('voice_title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.text),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.border, height: 1),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  final parts = msg['parts'] as List? ?? [];
                  final text = parts.isNotEmpty ? parts.first['text'] as String? ?? '' : '';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? AppColors.primary.withValues(alpha: 0.15) 
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                        border: isUser 
                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) 
                            : null,
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // "Pensando..." or "Listening..." Overlay / Indicator
            if (_isListening) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulsingWaveIndicator(),
                    const SizedBox(height: 6),
                    Text(
                      _transcribedText.isNotEmpty ? _transcribedText : t('voice_listening_label'),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isThinking) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t('voice_thinking_label'),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input area
            Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // Microphone button
                  GestureDetector(
                    key: const ValueKey('voice_mic_button'),
                    onTap: _isListeningBusy ? null : _toggleListening,
                    child: Opacity(
                      opacity: _isListeningBusy ? 0.6 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isListening 
                              ? AppColors.missed.withValues(alpha: 0.2) 
                              : AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isListening ? AppColors.missed : AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: _isListening ? AppColors.missed : AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text Field
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat_text_field'),
                      controller: _textController,
                      style: TextStyle(color: AppColors.text),
                      onSubmitted: (_) => _submitText(),
                      decoration: InputDecoration(
                        hintText: t('chat_placeholder'),
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  IconButton(
                    key: const ValueKey('chat_send_button'),
                    icon: Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _submitText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PulsingWaveIndicator extends StatefulWidget {
  const PulsingWaveIndicator({super.key});

  @override
  State<PulsingWaveIndicator> createState() => _PulsingWaveIndicatorState();
}

class _PulsingWaveIndicatorState extends State<PulsingWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final delay = index * 0.2;
            double value = (_controller.value - delay);
            if (value < 0) value += 1.0;
            final angle = value * 2 * math.pi;
            final scale = 0.3 + 0.7 * (math.sin(angle).abs());
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 20 * scale,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
