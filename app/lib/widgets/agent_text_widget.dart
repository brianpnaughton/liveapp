import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../appstate.dart';

class AgentTextWidget extends StatefulWidget {
  const AgentTextWidget({super.key});

  @override
  State<AgentTextWidget> createState() => _AgentTextWidgetState();
}

class _AgentTextWidgetState extends State<AgentTextWidget> {
  final ScrollController _scrollController = ScrollController();
  String _lastDisplayedText = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Check if text has changed and scroll to bottom
        final currentText = appState.currentDisplayText;
        if (currentText != _lastDisplayedText) {
          _lastDisplayedText = currentText;
          _scrollToBottom();
        }

        return FractionallySizedBox(
          heightFactor: 1.0 / 3.0,
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.5), // Translucent grey
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16.0),
            child: currentText.isNotEmpty
                ? SingleChildScrollView(
                    controller: _scrollController,
                    child: Text(
                      currentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      appState.isConnected
                          ? 'WebRTC Connected - Ready for ${appState.connectionType} communication'
                          : appState.isSocketConnected
                          ? 'Socket Connected - Ready for communication'
                          : 'Connecting...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
