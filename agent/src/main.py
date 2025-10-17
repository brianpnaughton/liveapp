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
import socketio
from aiohttp import web
import aiohttp_cors
import logging

log_format = "%(asctime)s::%(levelname)s::%(name)s::"\
             "%(filename)s::%(lineno)d::%(message)s"
logging.basicConfig(level=logging.INFO, format=log_format)
logger = logging.getLogger(__name__)

# Initialize Socket.IO server with CORS enabled for all origins
sio = socketio.AsyncServer(
    async_mode='aiohttp',
    cors_allowed_origins="*",
    logger=False,
    engineio_logger=False
)

# Initialize aiohttp application with no middleware
app = web.Application()
sio.attach(app)

# Setup CORS for aiohttp routes
cors = aiohttp_cors.setup(app, defaults={
    "*": aiohttp_cors.ResourceOptions(
        allow_credentials=True,
        expose_headers="*",
        allow_headers="*",
        allow_methods="*"
    )
})

async def init():
    runner = web.AppRunner(app)
    await runner.setup()

    port = 8080
    logger.info("starting server on port %s",port)
    site = web.TCPSite(runner, host="0.0.0.0", port=port, ssl_context=None)
    await site.start()

if __name__ == "__main__":
    logger.info("starting live agent...")

    import endpoints
    webrtcEndpoint = endpoints.WebRTCEndpoint(app, cors, sio)
    socketEndpoint = endpoints.SocketEndpoint(sio, webrtcEndpoint)  # Pass webrtc_endpoint

    async def startup():
        await init()

    loop=asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(startup())
    loop.run_forever()
