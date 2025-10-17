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
import 'package:provider/provider.dart';
import '../appstate.dart';

class ResponseTypeToggle extends StatefulWidget {
  const ResponseTypeToggle({super.key});

  @override
  State<ResponseTypeToggle> createState() => _ResponseTypeToggleState();
}

class _ResponseTypeToggleState extends State<ResponseTypeToggle> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return ToggleButtons(
      isSelected: [
        appState.responseType == 'text',
        appState.responseType == 'audio',
      ],
      onPressed: (int index) {
        if (index == 0) {
          appState.setResponseType('text', context);
        } else {
          appState.setResponseType('audio', context);
        }
      },
      borderRadius: BorderRadius.circular(8.0),
      selectedBorderColor: Colors.blue,
      selectedColor: Colors.white,
      fillColor: Colors.blue,
      color: Colors.blue,
      constraints: const BoxConstraints(minHeight: 40.0, minWidth: 80.0),
      children: const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Text'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Audio'),
        ),
      ],
    );
  }
}
