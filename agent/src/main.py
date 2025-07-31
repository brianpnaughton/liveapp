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
