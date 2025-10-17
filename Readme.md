# Interactive Gemini Live Agent

Simple demo of a mobile app that can interact with a Gemini live agent through video or text. The agent can respond in text or audio and has access to a set of tools. The agent monitors the live conversation with the user and can call a tool to notify an external system of key moments in the conversation. 

<p align=center>
<img src="docs/demo.drawio.svg"  width="500">
</p>

The demo consists of a flutter app and an [ADK](https://google.github.io/adk-docs/) based AI agent. The app communicates with the AI agent using [WebRTC](https://webrtc.org/). The agent listens to the live conversation and can call a tool that notifies an external system of any significant voice or video patterns it has been trained to watch out for. 

Follow these instructions to [run the demo](docs/install.md)
