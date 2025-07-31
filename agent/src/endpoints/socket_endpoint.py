import asyncio
import logging
import json
import base64

logger = logging.getLogger(__name__)

class SocketEndpoint:
    """
    Socket.IO endpoint for handling client connections.    
    """

    _instance = None

    def __init__(self, sio, webrtc_endpoint):
        logger.info("Initializing SocketEndpoint")

        SocketEndpoint._instance = self

        self.sio = sio
        self.webrtc_endpoint = webrtc_endpoint
        self.callbacks()

    def callbacks(self):
        @self.sio.event
        async def connect(sid, environ, auth):
            logger.info("connected client %s", sid)
            self.webrtc_endpoint.set_sid(sid)

        @self.sio.event
        async def disconnect(sid, reason=None):
            logger.info("disconnected from %s, reason: %s", sid, reason)
            await self.webrtc_endpoint.shutdown_agent()
            logger.info("GeminiAgent cleaned up")
