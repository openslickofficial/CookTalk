"""
Dish Image Service - Dynamic food image fetching via free APIs

Provides reliable, dish-specific images instead of hardcoded URLs.
Uses multiple fallback sources to ensure images always work.

APIs Used (in order):
1. Pexels API (primary) - 200 req/hour free
2. Unsplash API (fallback) - 50 req/hour free  
3. Static fallback - guaranteed to work

Setup:
1. Get free API keys:
   - Pexels: https://www.pexels.com/api/
   - Unsplash: https://unsplash.com/developers
2. Add to .env:
   PEXELS_API_KEY=your_key_here
   UNSPLASH_ACCESS_KEY=your_key_here
"""

import os
import httpx
import hashlib
from typing import Optional
from pathlib import Path

# Fallback images (known good Unsplash URLs by category)
FALLBACK_IMAGES = {
    "breakfast": "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80",  # eggs
    "lunch": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",  # salad
    "dinner": "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80",  # steak
    "dessert": "https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=800&q=80",  # cake
    "snack": "https://images.unsplash.com/photo-1604467707321-70d5ac45adda?auto=format&fit=crop&w=800&q=80",  # snacks
    "cuisine": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80",  # pasta
    "default": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",  # generic food
}

PEXELS_API_KEY = os.getenv("PEXELS_API_KEY", "")
UNSPLASH_ACCESS_KEY = os.getenv("UNSPLASH_ACCESS_KEY", "")


async def get_dish_image(dish_name: str, category: str = "default") -> str:
    """
    Get a relevant image URL for a dish.
    
    Args:
        dish_name: Name of the dish (e.g., "Chicken Tikka Masala")
        category: Category for fallback (breakfast, lunch, dinner, etc.)
    
    Returns:
        Image URL (guaranteed to be valid)
    """
    
    # 1. Try Pexels (most generous free tier)
    if PEXELS_API_KEY:
        url = await _fetch_pexels_image(dish_name)
        if url:
            return url
    
    # 2. Try Unsplash (good quality, lower rate limit)
    if UNSPLASH_ACCESS_KEY:
        url = await _fetch_unsplash_image(dish_name)
        if url:
            return url
    
    # 3. Category-specific fallback
    fallback = FALLBACK_IMAGES.get(category.lower(), FALLBACK_IMAGES["default"])
    return fallback


async def _fetch_pexels_image(query: str) -> Optional[str]:
    """Fetch image from Pexels API"""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                "https://api.pexels.com/v1/search",
                headers={"Authorization": PEXELS_API_KEY},
                params={
                    "query": f"{query} food dish meal",
                    "per_page": 1,
                    "orientation": "landscape",
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get("photos") and len(data["photos"]) > 0:
                    # Get medium size image (suitable for cards)
                    return data["photos"][0]["src"]["medium"]
            
            return None
    except Exception as e:
        print(f"[Pexels API Error] {e}")
        return None


async def _fetch_unsplash_image(query: str) -> Optional[str]:
    """Fetch image from Unsplash API"""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                "https://api.unsplash.com/search/photos",
                headers={"Authorization": f"Client-ID {UNSPLASH_ACCESS_KEY}"},
                params={
                    "query": f"{query} food dish",
                    "per_page": 1,
                    "orientation": "landscape",
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get("results") and len(data["results"]) > 0:
                    # Get regular size with our standard params
                    raw_url = data["results"][0]["urls"]["regular"]
                    # Add consistent formatting
                    return f"{raw_url}&fit=crop&w=800&q=80"
            
            return None
    except Exception as e:
        print(f"[Unsplash API Error] {e}")
        return None


def get_cached_image_url(dish_id: str, category: str = "default") -> str:
    """
    Get cached or fallback image URL (synchronous, for when async isn't available).
    Returns category-specific fallback immediately.
    """
    return FALLBACK_IMAGES.get(category.lower(), FALLBACK_IMAGES["default"])


# ---------------------------------------------------------------------------
# ALTERNATIVE: Upload to Supabase Storage for permanent URLs
# ---------------------------------------------------------------------------

async def download_and_store_image(
    image_url: str, 
    dish_id: str,
    supabase_client=None
) -> Optional[str]:
    """
    Download image and upload to Supabase Storage for permanent URL.
    
    This solves the "external API URLs can expire" problem.
    Returns permanent Supabase Storage URL.
    """
    if not supabase_client:
        return image_url  # Return original if no storage available
    
    try:
        # Download image
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(image_url)
            if response.status_code != 200:
                return None
            
            image_data = response.content
        
        # Upload to Supabase Storage
        file_name = f"dishes/{dish_id}.jpg"
        result = supabase_client.storage.from_("dish-images").upload(
            file_name,
            image_data,
            {"content-type": "image/jpeg", "upsert": "true"}
        )
        
        # Get public URL
        public_url = supabase_client.storage.from_("dish-images").get_public_url(file_name)
        return public_url
        
    except Exception as e:
        print(f"[Storage Upload Error] {e}")
        return image_url  # Return original on failure


# ---------------------------------------------------------------------------
# USAGE EXAMPLES
# ---------------------------------------------------------------------------

"""
# Example 1: Quick fallback (synchronous, no API calls)
image_url = get_cached_image_url("chicken_tikka_masala", category="dinner")

# Example 2: Dynamic API fetch (async)
image_url = await get_dish_image("Chicken Tikka Masala", category="dinner")

# Example 3: Fetch and store permanently
temp_url = await get_dish_image("Margherita Pizza", category="dinner")
permanent_url = await download_and_store_image(temp_url, "margherita_pizza", supabase_client)
"""
