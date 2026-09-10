# How Dish Images Are Generated in CookTalk

## TL;DR
**Dish images are NOT actually generated** - they use static fallback Unsplash URLs. There is **no AI image generation** in the current implementation.

## Current Implementation

### Static Fallback Image
All AI-generated dishes use the **same default Unsplash image**:

```python
"image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80"
```

**Location**: `web/token_server.py:334`

This happens in the `/api/generate-dish` endpoint when creating AI-generated recipes.

### For Curated/Verified Recipes
Hand-authored recipes (scrambled_eggs, cacio_e_pepe, ribeye_steak) have **manually selected** Unsplash images:

```python
# Example from mobile/lib/services/supabase_service.dart
Dish(
  id: 'scrambled_eggs',
  title: 'Classic French Soft-Curd Scrambled Eggs',
  imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80',
  verified: true,
),
```

## Fallback Chain

When displaying a dish, the app follows this priority:

1. **Database `image_url` field** - if present, use it
2. **`getDishImageUrl()` lookup** - check if there's a curated image for this recipe ID
3. **Default fallback** - the generic food placeholder from Dish model (line 160 in `mobile/lib/models/dish.dart`)

```dart
imageUrl: json['image_url'] as String? ??
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
```

## Why No AI Image Generation?

### Reasons (Inferred from Code):
1. **Speed** - Image generation adds 3-10 seconds of latency
2. **Cost** - API calls to DALL-E, Stable Diffusion, or similar cost $0.02-0.10 per image
3. **Simplicity** - Static images work for MVP/demo purposes
4. **Reliability** - No dependency on image generation API uptime

### The Compromise:
The app uses high-quality **generic food photography** from Unsplash that works for any dish. While not specific to each recipe, it:
- ✅ Loads instantly
- ✅ Costs nothing
- ✅ Looks professional
- ✅ Never fails

## How to Add Real Image Generation

If you want to add actual AI-generated images, here's what you'd need:

### Option 1: DALL-E 3 (OpenAI)
```python
import openai

async def generate_dish_image(dish_name: str) -> str:
    """Generate dish image via DALL-E 3"""
    response = await openai.images.generate(
        model="dall-e-3",
        prompt=f"Professional food photography of {dish_name}, appetizing plating, natural lighting, overhead view",
        size="1024x1024",
        quality="standard",
        n=1,
    )
    return response.data[0].url  # Returns URL valid for 60 minutes
    # You'd need to download and re-upload to permanent storage
```

**Cost**: $0.04 per image (standard quality)

### Option 2: Stable Diffusion (Replicate/Hugging Face)
```python
import replicate

async def generate_dish_image(dish_name: str) -> str:
    """Generate via Stable Diffusion"""
    output = replicate.run(
        "stability-ai/sdxl:latest",
        input={
            "prompt": f"high quality food photography of {dish_name}, professional, appetizing, 8k",
            "negative_prompt": "cartoon, illustration, anime, low quality, blurry",
        }
    )
    return output[0]  # Download and store permanently
```

**Cost**: $0.01-0.02 per image

### Option 3: Free Alternative (Food2Fork API)
Some food APIs provide real recipe images, but you're limited to their database:
- Spoonacular API
- Edamam Recipe Search API
- TheMealDB API (free but limited)

### Implementation Location
Add image generation in `web/token_server.py` at line ~334:

```python
# Current (static):
"image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",

# With AI generation:
"image_url": await generate_dish_image(title),  # New function call
```

**Important**: You'd need to:
1. Store generated images permanently (S3, Cloudinary, Supabase Storage)
2. Handle generation failures gracefully (fallback to Unsplash)
3. Add caching to avoid regenerating for popular dishes

## Current Storage

Generated dish data (including image URLs) is saved to:
- **`agent/generated_dishes.json`** - Cache for quick lookups
- **`agent/recipes.json`** - Makes dishes available to voice agent
- **Supabase `dishes` table** - Persistent database (if configured)

Location in code: `web/token_server.py:96-117` (`save_generated_dish()` function)

## Summary

**Current State**: Static Unsplash fallback images for all AI-generated dishes

**To Add Real Images**: Integrate DALL-E, Stable Diffusion, or food API at line 334 of `web/token_server.py` and add permanent storage (S3/Supabase Storage)

**Trade-off**: Image generation adds cost ($0.01-0.04/dish) and latency (3-10 seconds) but provides more accurate visual representation.
