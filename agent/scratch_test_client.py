import asyncio
import os
import sys
from dotenv import load_dotenv
from livekit import api, rtc

load_dotenv(os.path.join(os.path.dirname(__file__), "../.env"))

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

async def test_join():
    room_name = "bench-test-room"
    
    token = (
        api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity("synthetic_caller")
        .with_name("Synthetic Caller")
        .with_grants(api.VideoGrants(room_join=True, room=room_name))
        .to_jwt()
    )
    
    room = rtc.Room()
    
    @room.on("participant_connected")
    def on_participant_connected(participant: rtc.RemoteParticipant):
        print(f"[EVENT] Participant connected: {participant.identity} (kind: {participant.kind})")

    @room.on("track_published")
    def on_track_published(pub: rtc.RemoteTrackPublication, participant: rtc.RemoteParticipant):
        print(f"[EVENT] Track published by {participant.identity}: {pub.kind} (sid: {pub.sid})")

    @room.on("track_subscribed")
    def on_track_subscribed(track: rtc.Track, pub: rtc.RemoteTrackPublication, participant: rtc.RemoteParticipant):
        print(f"[EVENT] Track subscribed from {participant.identity}: {track.kind}")

    print(f"Connecting to {LIVEKIT_URL}, room={room_name}...")
    await room.connect(LIVEKIT_URL, token)
    print("Connected! Waiting 5 seconds to see if agent joins...")
    
    for i in range(10):
        print(f"Checking participants ({len(room.remote_participants)}): {[p.identity for p in room.remote_participants.values()]}")
        await asyncio.sleep(1)
        
    await room.disconnect()
    print("Disconnected.")

if __name__ == "__main__":
    asyncio.run(test_join())
