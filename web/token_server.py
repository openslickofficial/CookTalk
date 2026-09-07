import os
import json
import uuid
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from livekit import api

ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / ".env")

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

if not all([LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET]):
    raise RuntimeError("Missing LIVEKIT_URL, LIVEKIT_API_KEY, or LIVEKIT_API_SECRET in environment.")

app = FastAPI(title="CookTalk Token & Recipe Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

RECIPES_FILE = ROOT_DIR / "agent" / "recipes.json"

@app.get("/api/health")
def health():
    return {"status": "ok", "service": "cooktalk-token-server"}

@app.get("/api/recipes")
def get_recipes():
    if RECIPES_FILE.exists():
        with open(RECIPES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

@app.get("/api/token")
def create_token(
    room: str = Query(default="cooktalk-kitchen"),
    identity: str = Query(default=None),
    name: str = Query(default="Chef")
):
    user_id = identity or f"user_{uuid.uuid4().hex[:8]}"
    room_name = room.strip() or "cooktalk-kitchen"

    token = (
        api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(user_id)
        .with_name(name)
        .with_grants(api.VideoGrants(room_join=True, room=room_name, can_publish=True, can_subscribe=True))
        .to_jwt()
    )

    return {
        "token": token,
        "url": LIVEKIT_URL,
        "room": room_name,
        "identity": user_id,
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
