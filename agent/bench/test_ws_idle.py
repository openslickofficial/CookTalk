import asyncio
import os
import time
import aiohttp
from dotenv import load_dotenv

load_dotenv()

RIME_API_KEY = os.getenv("RIME_API_KEY")

async def test_idle():
    headers = {"Authorization": f"Bearer {RIME_API_KEY}"}
    url = "wss://users-ws.rime.ai/ws3?speaker=astra&modelId=coda&audioFormat=pcm&samplingRate=24000&segment=bySentence"

    print("Connecting to Rime WS...")
    t0 = time.perf_counter()
    async with aiohttp.ClientSession() as session:
        t_conn0 = time.perf_counter()
        ws = await session.ws_connect(url, headers=headers)
        conn_time = (time.perf_counter() - t_conn0) * 1000
        print(f"Connected in {conn_time:.1f} ms. WS closed? {ws.closed}")

        # Send turn 1
        t_t1_0 = time.perf_counter()
        await ws.send_str('{"text": "Hello world. ", "contextId": "turn1"}')
        await ws.send_str('{"operation": "flush", "contextId": "turn1"}')
        first_chunk = None
        while True:
            msg = await ws.receive()
            if msg.type == aiohttp.WSMsgType.TEXT:
                data = msg.json()
                if data.get("type") == "chunk" and first_chunk is None:
                    first_chunk = (time.perf_counter() - t_t1_0) * 1000
                elif data.get("type") == "done":
                    break
            elif msg.type in (aiohttp.WSMsgType.CLOSE, aiohttp.WSMsgType.CLOSED):
                print(f"WS closed during turn 1! {msg}")
                break
        print(f"Turn 1 completed. First chunk in: {first_chunk:.1f} ms. WS closed? {ws.closed}")

        # Now wait up to 60 seconds while actively checking ws.receive()
        print("Waiting up to 60 seconds idle while actively checking ws.receive()...")
        drop_sec = None
        for i in range(1, 61):
            try:
                msg = await asyncio.wait_for(ws.receive(), timeout=1.0)
                print(f"WS received at second {i}: {msg.type} data={getattr(msg, 'data', None)}")
                if msg.type in (aiohttp.WSMsgType.CLOSE, aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.CLOSING):
                    drop_sec = i
                    break
            except asyncio.TimeoutError:
                pass
            if ws.closed:
                drop_sec = i
                print(f"WS closed flag became True at second {i}!")
                break
        print(f"Idle check complete. Dropped at second: {drop_sec}. WS closed? {ws.closed}")
        if not ws.closed:
            print("Attempting Turn 2 on same socket...")
            t_t2_0 = time.perf_counter()
            try:
                await ws.send_str('{"text": "Next step please. ", "contextId": "turn2"}')
                await ws.send_str('{"operation": "flush", "contextId": "turn2"}')
                t2_chunk = None
                while True:
                    msg = await ws.receive(timeout=5.0)
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = msg.json()
                        if data.get("type") == "chunk" and t2_chunk is None:
                            t2_chunk = (time.perf_counter() - t_t2_0) * 1000
                        elif data.get("type") == "done":
                            break
                    elif msg.type in (aiohttp.WSMsgType.CLOSE, aiohttp.WSMsgType.CLOSED):
                        print(f"WS closed during turn 2: {msg}")
                        break
                print(f"Turn 2 on reused socket completed. First chunk in: {t2_chunk:.1f} ms.")
            except Exception as e:
                print(f"Turn 2 failed on reused socket: {e}")

        # Now test reconnect time
        print("\nTesting new connection handshake time...")
        t_rec0 = time.perf_counter()
        ws2 = await session.ws_connect(url, headers=headers)
        rec_time = (time.perf_counter() - t_rec0) * 1000
        print(f"New connection established in: {rec_time:.1f} ms.")
        await ws2.close()

if __name__ == "__main__":
    asyncio.run(test_idle())
