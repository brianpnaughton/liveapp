import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../appstate.dart';

class ConnectionTypeToggle extends StatefulWidget {
  const ConnectionTypeToggle({super.key});

  @override
  State<ConnectionTypeToggle> createState() => _ConnectionTypeToggleState();
}

class _ConnectionTypeToggleState extends State<ConnectionTypeToggle> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return ToggleButtons(
      isSelected: [
        appState.connectionType == 'audio',
        appState.connectionType == 'video',
      ],
      onPressed: (int index) {
        if (index == 0) {
          appState.setConnectionType('audio', context);
        } else {
          appState.setConnectionType('video', context);
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
          child: Text('Audio'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Video'),
        ),
      ],
    );
  }
}
