from aiortc import RTCPeerConnection, RTCSessionDescription, RTCConfiguration, RTCIceServer
from aiortc.contrib.media import MediaStreamTrack
from av import AudioFrame, AudioResampler
from aiohttp import web
import asyncio
import json
import os
import logging
import numpy as np
import fractions

from google.genai.types import (
    Part,
    Content,
    Blob,
)

logger = logging.getLogger(__name__)

######################################################################
# Custom Audio Track for sending agent audio to client
######################################################################
class AgentAudioTrack(MediaStreamTrack):
    """
    A custom audio track that sends audio data from the Gemini agent to the client
    """
    kind = "audio"

    def __init__(self):
        super().__init__()
        self.audio_queue = asyncio.Queue()
        self.sample_rate = 24000  # Gemini typically uses 24kHz
        self.channels = 1  # Mono audio
        self.samples_per_frame = int(self.sample_rate * 0.02)  # 20ms frames
        self.frame_duration = 0.02  # 20ms
        self.start_time = None
        self.buffer = bytearray()

    async def recv(self):
        """
        Receive the next audio frame
        """
        if self.start_time is None:
            self.start_time = asyncio.get_event_loop().time()
            self.last_frame_time = self.start_time

        # Get audio data from queue (blocking)
        while len(self.buffer) < self.samples_per_frame * 2:
            try:
                audio_data = await asyncio.wait_for(self.audio_queue.get(), timeout=0.1)
                self.buffer.extend(audio_data)
            except asyncio.TimeoutError:
                # If no audio data available, send silence
                self.buffer.extend(np.zeros(self.samples_per_frame, dtype=np.int16).tobytes())

        # Get a frame's worth of data from the buffer
        frame_data = self.buffer[:self.samples_per_frame * 2]
        self.buffer = self.buffer[self.samples_per_frame * 2:]

        # Convert bytes to numpy array
        audio_array = np.frombuffer(frame_data, dtype=np.int16)

        # Create AudioFrame
        frame = AudioFrame.from_ndarray(
            audio_array.reshape(1, -1),  # Shape: (channels, samples)
            format="s16",
            layout="mono"
        )
        
        # Set timestamp
        self.last_frame_time += self.frame_duration
        frame.pts = int(self.last_frame_time * self.sample_rate)
        frame.sample_rate = self.sample_rate
        frame.time_base = fractions.Fraction(1, self.sample_rate)
        
        return frame

    async def add_audio_data(self, audio_data):
        """
        Add audio data to the queue to be sent to the client
        """
        await self.audio_queue.put(audio_data)

######################################################################
# WebRTC APIs
######################################################################
class WebRTCEndpoint:
    
    def __init__(self, app, cors, sio):
        logger.info("Initializing WebRTCEndpoint")
        self.app=app
        self.pc=None
        self.cors = cors
        self.sio = sio
        self.sid = None
        self.gemini_agent = None
        self.agent_audio_track = None
        self.addRoutes()
        self.resampler = AudioResampler(format='s16', layout='mono', rate=24000)

    def set_sid(self, sid):
        """Set the socket io sid"""
        self.sid = sid
        logger.info(f"Socket.IO session set: {sid}")

    async def shutdown_agent(self):
        """Shutdown the Gemini agent"""
        if self.gemini_agent:
            await self.gemini_agent.close()
            self.gemini_agent = None
            logger.info("GeminiAgent shut down")

    def addRoutes(self):
        offerRoute = self.app.router.add_post("/offer", self.offer)
        self.cors.add(offerRoute)
        
    async def shutdown(self):
        logger.info("Shutting down WebRTCEndpoint")
        if ( self.pc is not None ):
            coros = self.pc.close()
            await asyncio.gather(*coros)

    # route for webrtc offer
    async def offer(self, request):
        logger.info("Received offer request")
        params = await request.json()
        logger.info("Offer received %s", params)

        self.pc=RTCPeerConnection(        
            configuration=RTCConfiguration(
                iceServers=[
                    RTCIceServer(urls="stun:stun1.l.google:19302"),
                    RTCIceServer(urls="stun:stun2.l.google:19302")
                    # RTCIceServer("turn:192.168.1.30:3478?transport=udp", "swarm", "swarm123"),
                ]
            ))

        # either "text" or "audio"
        responseType = params.get("responseType", "text")

        offer = RTCSessionDescription(sdp=params["sdp"], type=params["type"])

        @self.pc.on("connectionstatechange")
        async def on_connectionstatechange():
            logger.info("Connection state change event received")
            # “connected”, “connecting”, “closed”, “failed”, “new”.
            if self.pc is None:
                logger.info("Connection state is None")
                return
            else:
                logger.info("Connection state is %s", self.pc.connectionState)

            if self.pc.connectionState == "failed" or self.pc.connectionState == "closed":
                await self.pc.close()
                self.pc = None

        @self.pc.on("iceconnectionstatechange")
        async def on_iceconnectionstatechange():
            logger.info("Ice connection state change event received")
            # “checking”, “completed”, “closed”, “failed”, “new”.
            if self.pc is None:
                logger.info("Ice connection state is None")
                return
            else:
                logger.info("Ice connection state is %s", self.pc.iceConnectionState)

            if self.pc.iceConnectionState == "failed" or self.pc.iceConnectionState == "closed":
                await self.pc.close()
                self.pc = None

        @self.pc.on("icegatheringstate")
        async def on_icegatheringstate():
            logger.info("Ice gathering state change event received")
            # “complete”, “gathering”, “new”.
            if self.pc is None:
                logger.info("Ice gathering state is None")
                return
            else:
                logger.info("Ice gathering state is %s", self.pc.iceGatheringState)

        @self.pc.on("track")
        async def on_track(track):
            logger.info("Track %s received", track.kind)
            
            if track.kind == "audio":
                logger.info("Starting audio processing task")
                asyncio.create_task(self.process_audio_track(track))
            elif track.kind == "video":
                logger.info("Starting video processing task")
                asyncio.create_task(self.process_video_track(track))

        # Create and add agent audio track for sending audio to client
        self.agent_audio_track = AgentAudioTrack()
        self.pc.addTrack(self.agent_audio_track)
        logger.info("Added agent audio track to peer connection")

        # handle offer
        await self.pc.setRemoteDescription(offer)
        logger.info("Offer set %s", offer.sdp)
        
        # send answer
        answer = await self.pc.createAnswer()
        logger.info("Answer created %s", answer.sdp)

        await self.pc.setLocalDescription(answer)
        logger.info("local description =%s", self.pc.localDescription.sdp)
        
        # Initialize GeminiAgent for this session
        from agent.agent import GeminiAgent
        self.gemini_agent = GeminiAgent(
            self.sio, 
            self.sid, 
            self, 
            responseType
        )
        
        # Start the GeminiAgent
        await self.gemini_agent.start()
        logger.info("GeminiAgent initialized and started for session %s", self.sid)

        logger.info("start streaming audio")
        return web.Response(
            content_type="application/json",
            text=json.dumps(
                {"sdp": self.pc.localDescription.sdp, 
                 "type": self.pc.localDescription.type}
            ),
        )

    async def send_audio_to_client(self, audio_data):
        """
        Send audio data from Gemini agent to the client via WebRTC
        """
        if self.agent_audio_track:
            await self.agent_audio_track.add_audio_data(audio_data)
        else:
            logger.warning("No agent audio track available to send audio")

    async def process_audio_track(self, track):
        """Process incoming audio track and send to GeminiAgent"""
        logger.info("Processing audio track")
        
        try:
            while True:
                frame = await track.recv()
                if frame is None:
                    break

                mono_frames = self.resampler.resample(frame)
                
                # Push to GeminiAgent's live request queue
                if self.gemini_agent and self.gemini_agent.live_request_queue:
                    audio_data = mono_frames[0].to_ndarray().tobytes()
                    self.gemini_agent.live_request_queue.send_realtime(Blob(data=audio_data, mime_type="audio/pcm"))
                    logger.debug(f"Pushed audio frame to queue: {len(audio_data)} bytes")
                
        except Exception as e:
            logger.error(f"Error processing audio track: {e}")

    async def process_video_track(self, track):
        """Process incoming video track and send to GeminiAgent"""
        logger.info("Processing video track")
        
        try:
            while True:
                frame = await track.recv()
                if frame is None:
                    break
                
                # Convert video frame to image data (JPEG format)
                pil_image = frame.to_image()
                import io
                img_buffer = io.BytesIO()
                pil_image.save(img_buffer, format='JPEG')
                image_data = img_buffer.getvalue()
                
                # Push to GeminiAgent's live request queue
                if self.gemini_agent and self.gemini_agent.live_request_queue:
                    self.gemini_agent.live_request_queue.send_realtime(Blob(data=image_data, mime_type="image/jpeg"))
                    logger.debug(f"Pushed video frame to queue: {len(image_data)} bytes")

        except Exception as e:
            logger.error(f"Error processing video track: {e}")
