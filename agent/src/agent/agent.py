# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import asyncio
import logging
import json
import base64

from google.genai.types import (
    Part,
    Content,
    Blob,
)

from google.adk.runners import InMemoryRunner
from google.adk.agents import LiveRequestQueue
from google.adk.agents.run_config import RunConfig

from google.adk.agents import Agent

logger = logging.getLogger(__name__)

root_agent = Agent(
   # A unique name for the agent.
   name="google_search_agent",
   # The Large Language Model (LLM) that agent will use.
   model="gemini-2.0-flash-exp", # if this model does not work, try below
   # model="gemini-2.0-flash-live-001",
   # A short description of the agent's purpose.
   description="Agent to answer questions.",
   # Instructions to set the agent's behavior.
   instruction="Answer the users questions.",
   # Add google_search tool to perform grounding with Google search.
   # tools=[google_search],
)

class GeminiAgent():
   def __init__(self, sio, sid, webrtc_endpoint, responseType="text"):
      self.sio = sio
      self.sid = sid
      self.webrtc_endpoint = webrtc_endpoint
      self.responseType = responseType
      self.live_request_queue = None
      self.live_events = None

   async def start(self):
      logger.info("Starting GeminiAgent...")

      is_audio = self.responseType == "audio"
      await self.start_agent_session(user_id="Brian", is_audio=is_audio)

      # Start the agent to client messaging loop
      asyncio.create_task(self.agent_to_client_messaging(self.live_events, self.sid))

   async def start_agent_session(self, user_id, is_audio=False):
      """Starts an agent session"""
      logger.info(f"Starting agent session for user {user_id} with is_audio={is_audio}")

      # Create a Runner
      runner = InMemoryRunner(
         app_name="google_live_agent",
         agent=root_agent,
      )

      # Create a Session
      session = await runner.session_service.create_session(
         app_name="google_live_agent",
         user_id=user_id,
      )

      # Set response modality
      modality = "AUDIO" if is_audio else "TEXT"
      run_config = RunConfig(response_modalities=[modality])

      # Create a LiveRequestQueue for this session
      self.live_request_queue = LiveRequestQueue()

      # Start agent session
      self.live_events = runner.run_live(
         session=session,
         live_request_queue=self.live_request_queue,
         run_config=run_config,
      )

   async def close(self):
      """Closes the agent session"""
      logger.info("Closing agent session...")

      # Cleanup the session
      if self.live_request_queue:
          self.live_request_queue.close()
      self.live_request_queue = None
      self.live_events = None

   async def agent_to_client_messaging(self, live_events, sid):
      """Agent to client communication"""
      logger.info(f"Agent to client messaging started for session {sid}")

      while True:
         async for event in live_events:
               logger.info(f"[AGENT TO CLIENT]: {event}")
               # If the turn complete or interrupted, send it
               if event.turn_complete or event.interrupted:
                  message = {
                     "turn_complete": event.turn_complete,
                     "interrupted": event.interrupted,
                  }
                  await self.sio.emit('message', json.dumps(message), room=sid)
                  logger.info(f"[AGENT TO CLIENT]: {message}")
                  continue

               # Read the Content and its first Part
               part: Part = (
                  event.content and event.content.parts and event.content.parts[0]
               )
               if not part:
                  continue

               # If it's audio, send through WebRTC channel
               is_audio = part.inline_data and part.inline_data.mime_type.startswith("audio/pcm")
               if is_audio:
                  audio_data = part.inline_data and part.inline_data.data
                  if audio_data and self.webrtc_endpoint:
                     await self.webrtc_endpoint.send_audio_to_client(audio_data)
                     logger.info(f"[AGENT TO CLIENT]: audio/pcm via WebRTC: {len(audio_data)} bytes.")
                     continue

               # If it's text and a parial text, send it
               if part.text and event.partial:
                  message = {
                     "mime_type": "text/plain",
                     "data": part.text
                  }
                  await self.sio.emit('message', json.dumps(message), room=sid)
                  logger.info(f"[AGENT TO CLIENT]: text/plain: {message}")
