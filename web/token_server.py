import os
import re
import time
import json
import uuid
import asyncio
from pathlib import Path
from collections import deque
from dotenv import load_dotenv
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from livekit.api import AccessToken, VideoGrants

ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / ".env")

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

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
GENERATED_DISHES_FILE = ROOT_DIR / "agent" / "generated_dishes.json"

# Benchmark recipes that are hand-authored and verified
VERIFIED_BENCHMARK_RECIPES = {"scrambled_eggs", "cacio_e_pepe", "ribeye_steak"}

# Rate limiting for generation: max 15 requests per 60 seconds (independent of voice copilot)
_generation_request_timestamps = deque()

def normalize_dish_name(name: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9\s]", " ", name).strip().lower()
    words = s.split()
    normalized_words = []
    for w in words:
        if len(w) > 3 and w.endswith("ies"):
            normalized_words.append(w[:-3] + "y")
        elif len(w) > 3 and (w.endswith("ches") or w.endswith("shes") or w.endswith("xes") or w.endswith("zes") or w.endswith("ses") or w.endswith("oes")):
            normalized_words.append(w[:-2])
        elif len(w) > 3 and w.endswith("s") and not w.endswith("ss"):
            normalized_words.append(w[:-1])
        else:
            normalized_words.append(w)
    return " ".join(normalized_words)

def load_recipes() -> dict:
    if RECIPES_FILE.exists():
        try:
            with open(RECIPES_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def load_generated_dishes() -> dict:
    if GENERATED_DISHES_FILE.exists():
        try:
            with open(GENERATED_DISHES_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_generated_dish(dish_data: dict) -> None:
    # Save to generated_dishes cache
    dishes = load_generated_dishes()
    dishes[dish_data["id"]] = dish_data
    with open(GENERATED_DISHES_FILE, "w", encoding="utf-8") as f:
        json.dump(dishes, f, indent=2)

    # Also register in agent/recipes.json so voice copilot can immediately support hands-free cooking
    recipes = load_recipes()
    recipes[dish_data["id"]] = {
        "id": dish_data["id"],
        "name": dish_data["title"],
        "description": dish_data.get("description", ""),
        "verified": False,
        "source": "ai_generated",
        "ingredients": [
            {
                "name": ing.get("name", ""),
                "quantity": str(ing.get("quantity", "")),
                "unit": ing.get("unit", ""),
            }
            for ing in dish_data.get("ingredients", [])
        ],
        "substitutions": dish_data.get("substitutions", {}),
        "steps": [
            {
                "step_number": s.get("step") or s.get("step_number") or idx + 1,
                "instruction": s.get("instruction", ""),
                "timer_seconds": s.get("timer_seconds"),
                "timer_label": s.get("timer_label"),
            }
            for idx, s in enumerate(dish_data.get("steps", []))
        ],
    }
    with open(RECIPES_FILE, "w", encoding="utf-8") as f:
        json.dump(recipes, f, indent=2)

class GenerateDishRequest(BaseModel):
    dish_name: str

@app.get("/api/health")
def health():
    return {"status": "ok", "service": "cooktalk-token-server"}

@app.get("/api/recipes")
def get_recipes():
    return load_recipes()

@app.get("/api/token")
def create_token(
    room: str = Query(default="cooktalk-kitchen"),
    identity: str = Query(default=None),
    name: str = Query(default="Chef")
):
    user_id = identity or f"user_{uuid.uuid4().hex[:8]}"
    room_name = room.strip() or "cooktalk-kitchen"

    token = (
        AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(user_id)
        .with_name(name)
        .with_grants(VideoGrants(room_join=True, room=room_name, can_publish=True, can_subscribe=True))
        .to_jwt()
    )

    return {
        "token": token,
        "url": LIVEKIT_URL,
        "room": room_name,
        "identity": user_id,
    }

@app.post("/api/generate-dish")
async def generate_dish(req: GenerateDishRequest):
    raw_query = req.dish_name.strip()
    if not raw_query:
        raise HTTPException(status_code=400, detail="dish_name cannot be empty")

    norm_query = normalize_dish_name(raw_query)

    # 1. DEDUP CHECK 1: Existing recipes in agent/recipes.json (curated or existing)
    recipes = load_recipes()
    for key, r in recipes.items():
        r_name = r.get("name", "")
        r_norm = normalize_dish_name(r_name)
        k_norm = normalize_dish_name(key)

        if norm_query == r_norm or norm_query == k_norm or (len(norm_query) > 3 and (norm_query in r_norm or norm_query in k_norm)):
            is_verified = key in VERIFIED_BENCHMARK_RECIPES
            servings = r.get("servings", 4)
            return {
                "id": key,
                "slug": key,
                "title": r_name,
                "name": r_name,
                "description": r.get("description", ""),
                "category": r.get("category", "cuisine"),
                "cuisine": r.get("cuisine", "Global"),
                "prep_time_minutes": r.get("prep_time_minutes", 15),
                "cook_time_minutes": r.get("cook_time_minutes", 20),
                "servings": servings,
                "base_servings": servings,
                "difficulty": r.get("difficulty", "Easy"),
                "image_url": r.get("image_url", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80"),
                "is_trending": False,
                "verified": is_verified,
                "source": "curated" if is_verified else "ai_generated",
                "normalized_name": r_norm,
                "ingredients": r.get("ingredients", []),
                "steps": [
                    {
                        "step": s.get("step_number") or s.get("step") or (i + 1),
                        "step_number": s.get("step_number") or s.get("step") or (i + 1),
                        "instruction": s.get("instruction", ""),
                        "timer_seconds": s.get("timer_seconds"),
                        "timer_label": s.get("timer_label"),
                    }
                    for i, s in enumerate(r.get("steps", []))
                ],
                "substitutions": r.get("substitutions", {}),
            }

    # 2. DEDUP CHECK 2: Previously generated dishes cache
    generated_dishes = load_generated_dishes()
    for g_id, g in generated_dishes.items():
        g_name = g.get("title") or g.get("name") or ""
        g_norm = g.get("normalized_name") or normalize_dish_name(g_name)
        if norm_query == g_norm or (len(norm_query) > 3 and (norm_query in g_norm or g_norm in norm_query)):
            return g

    # 3. RATE LIMITING CHECK
    now = time.time()
    while _generation_request_timestamps and now - _generation_request_timestamps[0] > 60:
        _generation_request_timestamps.popleft()
    if len(_generation_request_timestamps) >= 15:
        raise HTTPException(
            status_code=429,
            detail="Generation rate limit reached (15/min). Please try again shortly."
        )
    _generation_request_timestamps.append(now)

    # 4. LLM GENERATION VIA GROQ
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY is not configured on server.")

    system_prompt = (
        "You are an expert master chef and culinary developer. Output strictly raw valid JSON. "
        "Do not include markdown code blocks or explanations. "
        "Generate a complete, mouthwatering recipe matching this exact JSON structure:\n"
        "{\n"
        '  "id": "kebab-case-dish-name",\n'
        '  "name": "Full Title of Dish",\n'
        '  "description": "Appetizing 1-2 sentence overview.",\n'
        '  "prep_time_minutes": 15,\n'
        '  "cook_time_minutes": 25,\n'
        '  "servings": 4,\n'
        '  "difficulty": "Easy" | "Medium" | "Hard",\n'
        '  "category": "breakfast" | "lunch" | "dinner" | "cuisine" | "dessert" | "snack",\n'
        '  "cuisine": "Italian" | "Indian" | "Mexican" | "American" | "Asian" | "Mediterranean",\n'
        '  "ingredients": [\n'
        '    {"name": "ingredient name", "quantity": "1", "unit": "cup"}\n'
        "  ],\n"
        '  "steps": [\n'
        '    {"step_number": 1, "instruction": "Clear step instruction.", "timer_seconds": 180, "timer_label": "simmer"}\n'
        "  ],\n"
        '  "substitutions": {\n'
        '    "ingredient": "recommended substitute"\n'
        "  }\n"
        "}\n"
        "Note: timer_seconds and timer_label can be null if the step has no active timer. "
        "Provide between 4 and 7 detailed cooking steps."
    )

    user_prompt = f"Develop a complete, reliable recipe for: '{raw_query}'."

    async def _call_groq(messages):
        async with httpx.AsyncClient(timeout=25.0) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen/qwen3.8-27b",
                    "messages": messages,
                    "response_format": {"type": "json_object"},
                    "temperature": 0.4,
                    "max_tokens": 1200,
                },
            )
            return resp

    parsed_json = None
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    try:
        response = await _call_groq(messages)
        if response.status_code != 200:
            raise RuntimeError(f"Groq API error {response.status_code}: {response.text}")
        content = response.json()["choices"][0]["message"]["content"].strip()
        parsed_json = json.loads(content)
    except Exception as first_err:
        # RETRY ONCE with repair prompt
        try:
            repair_messages = [
                {"role": "system", "content": "You are a JSON repair tool. Return strictly valid JSON."},
                {"role": "user", "content": f"Fix and complete this recipe JSON for '{raw_query}': {first_err}"},
            ]
            response = await _call_groq(repair_messages)
            if response.status_code == 200:
                content = response.json()["choices"][0]["message"]["content"].strip()
                parsed_json = json.loads(content)
        except Exception as retry_err:
            raise HTTPException(
                status_code=500,
                detail=f"Recipe generation failed: {first_err} -> Retry: {retry_err}"
            )

    if not parsed_json:
        raise HTTPException(status_code=500, detail="Failed to obtain valid recipe JSON from LLM.")

    # 5. ASSEMBLE COMPLETE DISH MODEL
    title = parsed_json.get("name") or raw_query.title()
    dish_id = parsed_json.get("id") or norm_query.replace(" ", "-")
    dish_id = re.sub(r"[^a-zA-Z0-9_-]", "", dish_id).lower()
    servings = int(parsed_json.get("servings") or 4)

    raw_steps = parsed_json.get("steps") or []
    formatted_steps = []
    for idx, s in enumerate(raw_steps):
        s_num = s.get("step_number") or s.get("step") or (idx + 1)
        formatted_steps.append({
            "step": s_num,
            "step_number": s_num,
            "instruction": s.get("instruction", ""),
            "timer_seconds": s.get("timer_seconds"),
            "timer_label": s.get("timer_label"),
        })

    dish_payload = {
        "id": dish_id,
        "slug": dish_id,
        "title": title,
        "name": title,
        "description": parsed_json.get("description", f"Freshly created AI recipe for {title}."),
        "category": parsed_json.get("category", "dinner").lower(),
        "cuisine": parsed_json.get("cuisine", "Global"),
        "prep_time_minutes": int(parsed_json.get("prep_time_minutes") or 15),
        "cook_time_minutes": int(parsed_json.get("cook_time_minutes") or 20),
        "servings": servings,
        "base_servings": servings,
        "difficulty": parsed_json.get("difficulty", "Medium"),
        "image_url": None,  # Will be set below
        "is_trending": False,
        "verified": False,
        "source": "ai_generated",
        "normalized_name": norm_query,
        "ingredients": [
            {
                "name": i.get("name", ""),
                "quantity": str(i.get("quantity", "")),
                "unit": i.get("unit", ""),
            }
            for i in parsed_json.get("ingredients", [])
        ],
        "steps": formatted_steps,
        "substitutions": parsed_json.get("substitutions", {}),
    }
    
    # FETCH DYNAMIC IMAGE: Try to get a real dish-specific image
    try:
        try:
            from web.image_service import get_dish_image, get_cached_image_url
        except ImportError:
            from image_service import get_dish_image, get_cached_image_url

        # Async fetch with timeout - if it fails, use fallback
        try:
            dish_payload["image_url"] = await asyncio.wait_for(
                get_dish_image(title, dish_payload["category"]),
                timeout=3.0
            )
        except Exception:
            # Timeout or API error - use category fallback
            dish_payload["image_url"] = get_cached_image_url(dish_id, dish_payload["category"])
    except ImportError:
        # image_service not available - use category-specific fallback
        fallback_images = {
            "breakfast": "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80",
            "lunch": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",
            "dinner": "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80",
            "dessert": "https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=800&q=80",
            "snack": "https://images.unsplash.com/photo-1604467707321-70d5ac45adda?auto=format&fit=crop&w=800&q=80",
            "default": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",
        }
        dish_payload["image_url"] = fallback_images.get(dish_payload["category"], fallback_images["default"])

    # 6. PERSIST TO DISHES CACHE
    try:
        save_generated_dish(dish_payload)
    except Exception as e:
        print(f"[Warning] Failed to persist generated dish: {e}")

    return dish_payload

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
