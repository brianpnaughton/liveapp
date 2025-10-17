// # Copyright 2024-2025 Google LLC
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//     http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../appstate.dart';
import '../widgets/agent_text_widget.dart';
import '../widgets/connection_type_toggle.dart';
import '../widgets/response_type_toggle.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isConnecting = false;
  bool _buttonAtBottom = false;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  void _onConnectPressed() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.isConnected) {
      setState(() {
        _isConnecting = false;
        _buttonAtBottom = false;
      });
      await appState.stopCall();
    } else {
      if (!appState.isSocketConnected) {
        _showNotConnectedMessage();
        return;
      }

      // Start animation immediately
      setState(() {
        _isConnecting = true;
        _buttonAtBottom = true;
      });

      // Wait for animation to complete before starting connection
      await Future.delayed(const Duration(milliseconds: 500));

      if (appState.connectionType == 'audio') {
        await appState.startAudioCall();
      } else {
        await appState.startVideoCall();
      }
    }
  }

  void _showNotConnectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to server. Please check your connection.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildConnectionStatusIcon(AppState appState) {
    // Determine the icon color and animation based on connection status
    Color iconColor;
    IconData iconData = Icons.wifi;
    String tooltipMessage;

    if (appState.isConnected) {
      // WebRTC is connected - bright green
      iconColor = const Color(0xFF00FF00); // Bright green
      tooltipMessage =
          'WebRTC Connected (${appState.connectionType.toUpperCase()})';
    } else if (appState.isSocketConnected) {
      // Only socket is connected - blue
      iconColor = Colors.blue;
      tooltipMessage = 'Socket Connected';
    } else {
      // No connection - grey
      iconColor = Colors.grey;
      tooltipMessage = 'Not Connected';
    }

    Widget icon = Icon(iconData, color: iconColor, size: 24);

    // Wrap with Tooltip
    return Tooltip(message: tooltipMessage, child: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.localStream != null) {
          _localRenderer.srcObject = appState.localStream;
        }

        // Reset _isConnecting when connection is established, but keep button at bottom
        if (_isConnecting && appState.isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isConnecting = false;
              // Keep _buttonAtBottom = true since we're now connected
            });
          });
        }

        // Reset button position when disconnected
        if (!_isConnecting && !appState.isConnected && _buttonAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _buttonAtBottom = false;
            });
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: _buildConnectionStatusIcon(appState),
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.blue),
                  child: Text(
                    'Settings',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                ListTile(
                  title: const Text('Response Type'),
                  trailing: ResponseTypeToggle(),
                ),
                ListTile(
                  title: const Text('Connection Type'),
                  trailing: const ConnectionTypeToggle(),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              children: [
                // Main content area
                Column(
                  children: [
                    // Expanded center container with AgentTextWidget
                    Expanded(
                      child: Stack(
                        children: [
                          if (appState.connectionType == 'video' &&
                              appState.localStream != null)
                            RTCVideoView(
                              _localRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          if (appState.webrtcClient != null)
                            ValueListenableBuilder<RTCVideoRenderer?>(
                              valueListenable:
                                  appState.webrtcClient!.remoteRendererNotifier,
                              builder: (context, remoteRenderer, _) {
                                if (remoteRenderer != null) {
                                  return Offstage(
                                    offstage: true,
                                    child: RTCVideoView(remoteRenderer),
                                  );
                                }
                                return Container();
                              },
                            ),
                          if (appState.isConnected &&
                              appState.responseType == 'text')
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child:
                                    AgentTextWidget(), // This will be overlaid
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Reserve space for the button when it's at the bottom
                    if (_buttonAtBottom || appState.isConnected)
                      const SizedBox(height: 96), // Height for button + padding
                  ],
                ),

                // Animated connect button
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  left: MediaQuery.of(context).size.width / 2 - 40,
                  bottom: (_buttonAtBottom || appState.isConnected)
                      ? 24
                      : MediaQuery.of(context).size.height / 2 + 40,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    child: ElevatedButton(
                      onPressed: _onConnectPressed,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: appState.isConnected
                            ? Colors.red
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          appState.isConnected
                              ? Icons.call_end
                              : appState.connectionType == 'video'
                              ? Icons.videocam
                              : Icons.mic,
                          key: ValueKey(
                            appState.isConnected ? 'connected' : 'disconnected',
                          ),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
