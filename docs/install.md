# Build Instructions

Instructions to run the demo with a browser on your local machine. Subsequent versions will run on GCP and Android.

## Pre-requisites

You need the following software/cloud subscription to run the demo. 

* [Flutter](https://docs.flutter.dev/get-started/quick)
* [Python3](https://www.python.org/downloads/)
* [GCP account for gemini live](https://console.cloud.google.com/)

## Run the Agent 

To run the agent, run the following commands

```
cd agent
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