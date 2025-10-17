# Build Instructions

Instructions to run the demo with a browser on your local machine. Subsequent versions will run on GCP and Android.

## Pre-requisites

You need the following software/cloud subscription to run the demo. 

* [Flutter](https://docs.flutter.dev/get-started/quick)
* [Python3](https://www.python.org/downloads/)
* [GCP account for gemini live](https://console.cloud.google.com/)

## Run the Agent 

Setup a virtual environment. 

```
cd agent
python3 -m venv .venv
source .venv/bin/activate
pip install -r ./requirements.txt
```

To run the agent, run the following commands

```
cd src
export GOOGLE_CLOUD_PROJECT=<YOUR PROJECT>
export GOOGLE_CLOUD_LOCATION=<YOUR REGION>
export GOOGLE_GENAI_USE_VERTEXAI=TRUE
python3 main.py
```

## Run the App

To run the app in a browser, run the following commands

```
cd app
flutter run -d chrome
```

## Interact with the agent

You can access the connection type and agent response type from the drawer menu on the top left of the app.

You can choose to a video or audio connection type and also how you would like the agent to respond, via text or audio. The connection button in the middle of the screen will change accordingly. 

Pushing the connection button will start a webrtc session with the agent and you can interact with the agent live. 


