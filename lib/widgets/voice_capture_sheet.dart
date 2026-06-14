import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Prompts the user for RECORD_AUDIO (contextually, on first tap) and streams
/// recognized words in a modal sheet. Returns the final transcription, or
/// `null` if the user cancels, the recognizer is unavailable, or permission
/// is denied.
Future<String?> showVoiceCaptureSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: const SafeArea(
        top: false,
        child: _VoiceCaptureSheet(),
      ),
    ),
  );
}

class _VoiceCaptureSheet extends StatefulWidget {
  const _VoiceCaptureSheet();

  @override
  State<_VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

enum _Phase { initializing, listening, error }

class _VoiceCaptureSheetState extends State<_VoiceCaptureSheet> {
  final SpeechToText _stt = SpeechToText();
  _Phase _phase = _Phase.initializing;
  String _heard = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await _stt.initialize(
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _errorMessage = _friendlyError(e.errorMsg);
        });
      },
      onStatus: (_) {},
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _phase = _Phase.error;
        _errorMessage =
            'Voice input unavailable. Check microphone permission or install a speech recognizer.';
      });
      return;
    }
    setState(() => _phase = _Phase.listening);
    await _stt.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('permission')) {
      return 'Microphone permission denied. Enable it in Settings to use voice.';
    }
    if (raw.contains('no_match') || raw.contains('no match')) {
      return 'Didn\'t catch that — try again.';
    }
    if (raw.contains('network')) {
      return 'No network for speech recognition.';
    }
    return 'Voice input error: $raw';
  }

  Future<void> _stopAndAccept() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
    if (!mounted) return;
    final text = _heard.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  Future<void> _cancel() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (_stt.isListening) {
      _stt.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _phase == _Phase.error ? Icons.error_outline : Icons.mic,
                color: _phase == _Phase.error
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                switch (_phase) {
                  _Phase.initializing => 'Preparing…',
                  _Phase.listening => 'Listening…',
                  _Phase.error => 'Voice unavailable',
                },
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_phase == _Phase.error)
            Text(_errorMessage, style: theme.textTheme.bodyMedium)
          else
            Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _heard.isEmpty ? 'Say a task title…' : _heard,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _heard.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              if (_phase != _Phase.error)
                FilledButton.icon(
                  onPressed: _heard.trim().isEmpty ? null : _stopAndAccept,
                  icon: const Icon(Icons.check),
                  label: const Text('Use'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
