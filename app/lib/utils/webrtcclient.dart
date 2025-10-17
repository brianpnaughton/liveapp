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
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:app/utils/constants.dart' as constants;

class WebRTCClient {
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  MediaStream? _localStream;
  final ValueNotifier<RTCVideoRenderer?> remoteRendererNotifier = ValueNotifier(
    null,
  );

  MediaStream? get localStream => _localStream;
  RTCVideoRenderer? get remoteRenderer => remoteRendererNotifier.value;

  String get sdpSemantics => 'unified-plan';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };

  Map<String, dynamic> _dcConstraints = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
    'optional': [],
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  // Audio constraints with echo cancellation enabled
  final Map<String, dynamic> _audioConstraints = {
    'audio': true,
    'video': false,
  };

  final Map<String, dynamic> _videoConstraints = {'audio': true, 'video': true};

  String username;
  String socketId; // the socket id of the user
  String responseType; // 'text' or 'audio'

  // widget callbacks
  Function(bool status) callStatus;
  Function(MediaStream? stream) onLocalStream;

  WebRTCClient({
    required this.username,
    required this.socketId,
    required this.callStatus,
    required this.responseType,
    required this.onLocalStream,
  }) {
    remoteRendererNotifier.value = RTCVideoRenderer();
    remoteRendererNotifier.value?.initialize();
  }

  Future<void> _negotiateRemoteConnection() async {
    return _peerConnection!
        .createOffer(_dcConstraints)
        .then((offer) {
          return _peerConnection!.setLocalDescription(offer);
        })
        .then((_) async {
          var des = await _peerConnection!.getLocalDescription();
          var headers = {'Content-Type': 'application/json'};
          var request = http.Request(
            'POST',
            Uri.parse(constants.ApiPath.OFFER_URL),
          );
          request.body = json.encode({
            "sdp": des!.sdp,
            "type": des.type,
            "username": username,
            "socketId": socketId,
            "responseType": responseType,
          });

          print("SENDING OFFER TO SERVER");
          print(request.body);

          request.headers.addAll(headers);
          http.StreamedResponse response = await request.send();

          print("RESPONSE FROM SERVER");

          String data = "";
          if (response.statusCode == 200) {
            data = await response.stream.bytesToString();
            var dataMap = await json.decode(data);
            print(dataMap);
            await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(dataMap["sdp"], dataMap["type"]),
            );
          } else {
            print(response.reasonPhrase);
          }
        });
  }

  Future<void> makeCall() async {
    print("MAKE AUDIO CALL to server");

    // Set constraints for audio only
    _dcConstraints = {
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
      'optional': [],
    };

    await _createConnection(_audioConstraints);
  }

  Future<void> makeVideoCall() async {
    print("MAKE VIDEO CALL to server");

    // Set constraints for video call
    _dcConstraints = {
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      'optional': [],
    };

    await _createConnection(_videoConstraints);
  }

  Future<void> _createConnection(Map<String, dynamic> mediaConstraints) async {
    //* Create Peer Connection
    if (_peerConnection != null) return;
    print("Creating Peer Connection");
    _peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics},
    }, _config);

    _peerConnection!.onTrack = (track) {
      print("ON TRACK EVENT RECEIVED: ${track.track?.kind}");

      if (track.track?.kind == 'audio') {
        print("Received audio track from server");

        // Store the remote stream for audio playback
        _remoteStream = track.streams.isNotEmpty ? track.streams[0] : null;
        remoteRendererNotifier.value?.srcObject = _remoteStream;

        // Enable audio playback
        _setupAudioPlayback();
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print("CONNECTION STATE: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print("DISCONNECTED");
        callStatus(false);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print("CONNECTED");
        callStatus(true);
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      print("ICE CONNECTION STATE: $state");
    };

    try {
      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream = stream;
      onLocalStream(_localStream);

      stream.getTracks().forEach((element) {
        print('adding track: ${element.kind}');
        _peerConnection!.addTrack(element, stream);
      });

      print("NEGOTIATING REMOTE CONNECTION");
      await _negotiateRemoteConnection();
    } catch (e) {
      print(e.toString());
    }
  }

  void _setupAudioPlayback() {
    if (_remoteStream != null) {
      print("Setting up audio playback for remote stream");

      // Get audio tracks from the remote stream
      var audioTracks = _remoteStream!.getAudioTracks();

      if (audioTracks.isNotEmpty) {
        print("Found ${audioTracks.length} audio track(s) in remote stream");

        // Enable audio playback for each track
        for (var track in audioTracks) {
          track.enabled = true;
          print("Enabled audio track: ${track.id}");
        }

        // Set audio output to speaker (important for mobile devices)
        Helper.setSpeakerphoneOn(true);
        print("Audio playback configured successfully");
      } else {
        print("No audio tracks found in remote stream");
      }
    } else {
      print("No remote stream available for audio playback");
    }
  }

  Future<void> stopCall() async {
    try {
      // Disable speakerphone
      Helper.setSpeakerphoneOn(false);

      // Clean up remote stream
      if (_remoteStream != null) {
        _remoteStream!.dispose();
        _remoteStream = null;
      }
      await remoteRendererNotifier.value?.dispose();
      remoteRendererNotifier.value = null;

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        _localStream!.dispose();
        _localStream = null;
      }
      onLocalStream(null);

      await _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      print(e.toString());
    }
    callStatus(false);
  }
}
