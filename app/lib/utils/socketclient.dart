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
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:app/utils/constants.dart' as constants;

class SocketClient {
  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  // Callbacks
  Function(bool connected)? onConnectionChanged;
  Function(String message)? onMessageReceived;
  Function(Map<String, dynamic> data)? onDataReceived;

  SocketClient({
    this.onConnectionChanged,
    this.onMessageReceived,
    this.onDataReceived,
  });

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      print('Socket already connected');
      return;
    }

    try {
      print('Connecting to socket server: ${constants.ApiPath.WS_URL}');

      _socket = IO.io(constants.ApiPath.WS_URL, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.onConnect((_) {
        print('Socket connected');
        _isConnected = true;
        onConnectionChanged?.call(true);
      });

      _socket!.onDisconnect((_) {
        print('Socket disconnected');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });

      _socket!.onConnectError((data) {
        print('Socket connection error: $data');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });

      _socket!.onError((data) {
        print('Socket error: $data');
      });

      // Listen for messages
      _socket!.on('message', (data) {
        print('Received message: $data');
        if (data is String) {
          onMessageReceived?.call(data);
        } else if (data is Map<String, dynamic>) {
          onDataReceived?.call(data);
        }
      });

      // Listen for transcription data
      _socket!.on('transcription', (data) {
        print('Received transcription: $data');
        onDataReceived?.call({'type': 'transcription', 'data': data});
      });

      _socket!.connect();
    } catch (e) {
      print('Error connecting to socket: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  void sendMessage(String message) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('message', message);
      print('Sent message: $message');
    } else {
      print('Socket not connected, cannot send message');
    }
  }

  void sendData(String event, Map<String, dynamic> data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
      print('Sent data to $event: $data');
    } else {
      print('Socket not connected, cannot send data');
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      onConnectionChanged?.call(false);
      print('Socket disconnected and disposed');
    }
  }
}
