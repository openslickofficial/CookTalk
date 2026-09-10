# Setup: Dynamic Dish Images

## Problem
Hardcoded Unsplash URLs break over time and all AI-generated dishes show the same generic image.

## Solution
Dynamic image fetching from free APIs with intelligent fallbacks.

## Quick Setup (5 minutes)

### Step 1: Get Free API Keys

#### Option A: Pexels (Recommended - 200 requests/hour)
1. Go to https://www.pexels.com/api/
2. Sign up (free)
3. Copy your API key

#### Option B: Unsplash (50 requests/hour)
1. Go to https://unsplash.com/developers
2. Register your app
3. Copy your Access Key

### Step 2: Add to .env

```bash
# Add to your root .env file
PEXELS_API_KEY=your_pexels_key_here
UNSPLASH_ACCESS_KEY=your_unsplash_key_here
```

### Step 3: Install Dependencies

```bash
cd web
pip install httpx  # For async HTTP requests (if not already installed)
```

### Step 4: Test It

```bash
# Start the token server
cd web
python token_server.py

# Generate a dish via API
curl -X POST http://localhost:8000/api/generate-dish \
  -H "Content-Type: application/json" \
  -d '{"dish_name": "Chicken Tikka Masala"}'
```

The response will include a real image URL specific to "Chicken Tikka Masala"!

## How It Works

### Image Fetching Strategy (3-tier fallback)

```
1. Pexels API (primary)
   ↓ (if fails or no API key)
2. Unsplash API (fallback)
   ↓ (if fails or no API key)  
3. Category-specific static image (guaranteed)
```

### Example Results

**Before** (all dishes):
```
https://images.unsplash.com/photo-1546069901-ba9599a7e63c?...
```
(Same generic food photo)

**After** (dish-specific):
```
Chicken Tikka Masala → https://images.pexels.com/photos/123/tikka-masala.jpg
Margherita Pizza    → https://images.pexels.com/photos/456/pizza-margherita.jpg
Chocolate Cake      → https://images.pexels.com/photos/789/chocolate-cake.jpg
```

### Category Fallbacks

If API calls fail, dishes get category-specific images:

| Category  | Fallback Image           |
|-----------|--------------------------|
| breakfast | Scrambled eggs photo     |
| lunch     | Fresh salad photo        |
| dinner    | Ribeye steak photo       |
| dessert   | Chocolate cake photo     |
| snack     | Snack mix photo          |
| default   | Generic food photo       |

## Advanced: Permanent Storage (Optional)

### Problem
API-fetched URLs may expire or change.

### Solution
Download and upload to Supabase Storage for permanent URLs.

```python
from image_service import download_and_store_image
from supabase import create_client

# After fetching temp URL from API
temp_url = await get_dish_image("Pasta Carbonara", "dinner")

# Store permanently in Supabase
supabase = create_client(supabase_url, supabase_key)
permanent_url = await download_and_store_image(
    temp_url, 
    "pasta_carbonara",
    supabase
)
```

This requires:
1. Supabase project with Storage enabled
2. Create a `dish-images` bucket (public)
3. Configure in your .env:
   ```
   SUPABASE_URL=your_project_url
   SUPABASE_SERVICE_KEY=your_service_key
   ```

## Rate Limits

| Service  | Free Tier     | Notes                           |
|----------|---------------|---------------------------------|
| Pexels   | 200 req/hour  | Best for MVP/demo               |
| Unsplash | 50 req/hour   | Good quality, lower limit       |
| Fallback | Unlimited     | Static URLs, always works       |

For production with >200 dishes/hour:
- Cache images in Supabase Storage (recommended)
- Or upgrade to paid tier
- Or use AI image generation (DALL-E, Stable Diffusion)

## Troubleshooting

### Images still showing generic photo
1. Check API keys are in .env
2. Restart token server
3. Check logs for API errors
4. Verify rate limits not exceeded

### API returning 401 Unauthorized
- Pexels: Check you're sending `Authorization: YOUR_KEY` (not `Bearer`)
- Unsplash: Check you're sending `Authorization: Client-ID YOUR_KEY`

### Slow image generation
- Add timeout (already implemented: 3 seconds)
- Falls back to category image if timeout exceeded
- Consider caching popular dishes

## Cost Analysis

### Current Setup (Free)
- **Pexels**: 200 dishes/hour = 4,800/day = FREE
- **Fallback**: Unlimited = FREE
- **Total Cost**: $0/month

### If You Exceed Limits
- **Pexels Pro**: $20/month = 20,000 req/month
- **Supabase Storage**: $0.021/GB stored + $0.09/GB bandwidth
- **AI Generation**: $0.01-0.04 per image

## Files Modified

1. **`web/image_service.py`** (NEW) - Image fetching service
2. **`web/token_server.py`** - Uses image_service in dish generation
3. **`.env`** - Add API keys

## Next Steps

1. ✅ Add API keys to .env
2. ✅ Test with a few dish generations
3. ⚠️ Monitor rate limits in production
4. 💡 Consider Supabase Storage for popular dishes
5. 💡 Add image caching to reduce API calls

## Comparison

| Approach          | Quality | Cost   | Speed  | Reliability |
|-------------------|---------|--------|--------|-------------|
| Hardcoded URLs    | Low     | Free   | Fast   | Poor ⚠️     |
| Dynamic API fetch | High    | Free*  | Medium | Good ✅     |
| AI Generation     | Highest | $$     | Slow   | Medium      |
| Supabase Storage  | High    | $      | Fast   | Excellent ✅|

*Free up to rate limits

## Summary

With Pexels/Unsplash integration:
- ✅ Dish-specific images (not generic)
- ✅ Free (up to 200/hour)
- ✅ Reliable (3-tier fallback)
- ✅ Fast (3-second timeout)
- ✅ No broken URLs
