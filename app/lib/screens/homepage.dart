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
      await appState.stopCall();
    } else {
      if (!appState.isSocketConnected) {
        _showNotConnectedMessage();
        return;
      }
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
            child: Column(
              children: [
                // Expanded center container with AgentTextWidget
                Expanded(
                  child: Stack(
                    children: [
                      if (appState.connectionType == 'video' &&
                          appState.localStream != null)
                        RTCVideoView(
                          _localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                            child: AgentTextWidget(), // This will be overlaid
                          ),
                        ),
                    ],
                  ),
                ),

                // Bottom button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onConnectPressed,
                      icon: Icon(
                        appState.isConnected
                            ? Icons.call_end
                            : appState.connectionType == 'video'
                            ? Icons.videocam
                            : Icons.mic,
                      ),
                      label: Text(
                        appState.isConnected ? 'Disconnect' : 'Connect',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: appState.isConnected
                            ? Colors.red
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
