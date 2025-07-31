import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'utils/webrtcclient.dart';
import 'utils/socketclient.dart';

class AppState extends ChangeNotifier {
  WebRTCClient? _webrtcClient;
  MediaStream? _localStream;
  bool _isConnected = false;
  String _connectionType = 'audio';

  SocketClient? _socketClient;
  bool _isSocketConnected = false;
  String _lastMessage = '';
  List<String> _messages = [];

  // Agent text display
  String _currentLineText = '';
  String _displayText = '';

  // Response type
  String _responseType = 'text';

  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;
  WebRTCClient? get webrtcClient => _webrtcClient;
  MediaStream? get localStream => _localStream;

  bool get isSocketConnected => _isSocketConnected;
  String get lastMessage => _lastMessage;
  List<String> get messages => List.unmodifiable(_messages);
  SocketClient? get socketClient => _socketClient;
  String get displayText => _displayText;
  String get responseType => _responseType;

  String get currentDisplayText {
    if (_currentLineText.isEmpty) {
      return _displayText;
    }

    if (_displayText.isEmpty) {
      return _currentLineText;
    }

    return _displayText + '\n' + _currentLineText;
  }

  AppState() {
    // Auto-connect socket when AppState is created
    _initializeSocket();
  }

  void _initializeSocket() async {
    await connectSocket();
  }

  void _onCallStatusChanged(bool status) {
    _isConnected = status;
    notifyListeners();
  }

  void _onLocalStream(MediaStream? stream) {
    _localStream = stream;
    notifyListeners();
  }

  Future<void> startAudioCall() async {
    if (_webrtcClient != null) {
      await _webrtcClient!.stopCall();
    }

    _webrtcClient = WebRTCClient(
      username: 'user_${DateTime.now().millisecondsSinceEpoch}',
      socketId: 'socket_${DateTime.now().millisecondsSinceEpoch}',
      callStatus: _onCallStatusChanged,
      responseType: _responseType,
      onLocalStream: _onLocalStream,
    );

    await _webrtcClient!.makeCall();
    notifyListeners();
  }

  Future<void> startVideoCall() async {
    if (_webrtcClient != null) {
      await _webrtcClient!.stopCall();
    }

    _webrtcClient = WebRTCClient(
      username: 'user_${DateTime.now().millisecondsSinceEpoch}',
      socketId: 'socket_${DateTime.now().millisecondsSinceEpoch}',
      callStatus: _onCallStatusChanged,
      responseType: _responseType,
      onLocalStream: _onLocalStream,
    );

    await _webrtcClient!.makeVideoCall();
    notifyListeners();
  }

  Future<void> stopCall() async {
    if (_webrtcClient != null) {
      await _webrtcClient!.stopCall();
      _webrtcClient = null;
      _localStream = null;
    }
    notifyListeners();
  }

  // Socket connection methods
  void _onSocketConnectionChanged(bool connected) {
    _isSocketConnected = connected;
    notifyListeners();
  }

  void _onSocketMessageReceived(String message) {
    print('Received message: $message');
    _lastMessage = message;
    _messages.add(message);

    // Parse the JSON message from the agent
    try {
      Map<String, dynamic> messageData = jsonDecode(message);
      _handleAgentMessage(messageData);
    } catch (e) {
      print('Error parsing message JSON: $e');
      // If it's not JSON, treat as plain text
      _currentLineText += message;
      _updateDisplayText();
    }

    notifyListeners();
  }

  void _onSocketDataReceived(Map<String, dynamic> data) {
    print('Received data: $data');
    String message = 'Data received: ${data.toString()}';
    _lastMessage = message;
    _messages.add(message);
    notifyListeners();
  }

  void _handleAgentMessage(Map<String, dynamic> messageData) {
    // Check if this is a turn completion message
    if (messageData.containsKey('turn_complete') ||
        messageData.containsKey('interrupted')) {
      bool turnComplete = messageData['turn_complete'] ?? false;
      bool interrupted = messageData['interrupted'] ?? false;

      if (turnComplete || interrupted) {
        // Add current line to display text and start a new line
        if (_currentLineText.isNotEmpty) {
          if (_displayText.isNotEmpty) {
            _displayText += '\n';
          }
          _displayText += _currentLineText;
          _currentLineText = '';
        }
      }
      return;
    }

    // Check if this is a text message
    if (messageData.containsKey('mime_type') &&
        messageData.containsKey('data')) {
      String mimeType = messageData['mime_type'] ?? '';
      String data = messageData['data'] ?? '';

      if (mimeType == 'text/plain' && data.isNotEmpty) {
        // Accumulate text on the current line
        _currentLineText += data;
        _updateDisplayText();
      }
    }
  }

  void _updateDisplayText() {
    // This method is called when we receive partial text
    // We don't need to do anything here since we'll update the display
    // when we get the turn complete message
  }

  Future<void> connectSocket() async {
    if (_socketClient != null && _socketClient!.isConnected) {
      print('Socket already connected');
      return;
    }

    _socketClient = SocketClient(
      onConnectionChanged: _onSocketConnectionChanged,
      onMessageReceived: _onSocketMessageReceived,
      onDataReceived: _onSocketDataReceived,
    );

    await _socketClient!.connect();
    notifyListeners();
  }

  Future<void> disconnectSocket() async {
    if (_socketClient != null) {
      await _socketClient!.disconnect();
      _socketClient = null;
      _isSocketConnected = false;
    }
    notifyListeners();
  }

  void sendSocketMessage(String message) {
    if (_socketClient != null && _socketClient!.isConnected) {
      _socketClient!.sendMessage(message);
    }
  }

  void sendSocketData(String event, Map<String, dynamic> data) {
    if (_socketClient != null && _socketClient!.isConnected) {
      _socketClient!.sendData(event, data);
    }
  }

  void clearMessages() {
    _messages.clear();
    _lastMessage = '';
    notifyListeners();
  }

  void clearDisplayText() {
    _displayText = '';
    _currentLineText = '';
    notifyListeners();
  }

  void setConnectionType(String type, BuildContext context) {
    if (type == _connectionType) return;

    if (_isConnected) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Change'),
            content: const Text(
              'Changing the connection type will restart the current session. Are you sure?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Confirm'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _connectionType = type;
                  notifyListeners();
                  _restartCall();
                },
              ),
            ],
          );
        },
      );
    } else {
      _connectionType = type;
      notifyListeners();
    }
  }

  void setResponseType(String type, BuildContext context) {
    if (type == _responseType) return;

    if (_isConnected) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Change'),
            content: const Text(
              'Changing the response type will restart the current session. Are you sure?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Confirm'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _responseType = type;
                  notifyListeners();
                  _restartCall();
                },
              ),
            ],
          );
        },
      );
    } else {
      _responseType = type;
      notifyListeners();
    }
  }

  void _restartCall() async {
    if (_isConnected) {
      final currentConnectionType = _connectionType;
      await stopCall();
      if (currentConnectionType == 'audio') {
        await startAudioCall();
      } else if (currentConnectionType == 'video') {
        await startVideoCall();
      }
    }
  }
}
