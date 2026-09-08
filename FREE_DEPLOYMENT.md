# 🆓 Deploy CookTalk Completely FREE

Deploy the entire CookTalk project without spending a single cent!

---

## 💰 Total Cost: $0

Everything can run on free tiers:
- ✅ **Agent Worker**: LiveKit Cloud (1,000 session minutes/month)
- ✅ **Web Frontend**: Cloudflare Pages (unlimited bandwidth)
- ✅ **Token Server**: Cloudflare Pages Functions (edge function)
- ✅ **Database**: Supabase (already deployed)
- ✅ **Mobile Testing**: Direct APK sideload (Android) or Xcode (iOS)

---

## 📋 Deployment Components

| Component | Where | Why | Free Tier Limit |
|-----------|-------|-----|-----------------|
| **Agent Worker** | LiveKit Cloud | Native agent deploy, no cold start, instant room join | 1,000 session min/month |
| **Web Frontend** | Cloudflare Pages | Unlimited bandwidth, no credit card, no expiring credits | Truly unlimited |
| **Token Server** | Cloudflare Pages Functions | Edge function, zero cold-start, same platform as frontend | 100k requests/day |
| **Supabase** | Already deployed | Cloud-hosted, nothing needed | 500MB DB, 2GB storage |
| **Mobile App** | Local build | APK sideload (Android), Xcode (iOS) | N/A |

---

## ⚠️ Critical Notes Before Deployment

1. **LiveKit Free Tier**: 1,000 agent session minutes/month
   - Don't burn quota on benchmarks before judging
   - Same lesson as Groq daily cap issue earlier
   
2. **No Cold Start Issues**: Unlike Render (15 min idle → 1 min cold restart), LiveKit agents join rooms instantly

3. **iOS Distribution**: Requires $99/year Apple Developer Program for TestFlight/App Store
   - Free Apple ID: 7-day installs via Xcode only
   - Same $99 account needed for Sign In with Apple anyway

---

## 1️⃣ Free API Keys (No Credit Card Required)

### LiveKit Cloud - FREE
- **Free Tier**: 50GB/month bandwidth
- **Sign up**: https://cloud.livekit.io
- **Steps**:
  1. Sign up with GitHub/Google
  2. Create new project
  3. Copy URL, API Key, and Secret
- **Cost**: $0 ✅

### Deepgram - FREE
- **Free Tier**: $200 credit (45 hours of audio)
- **Sign up**: https://console.deepgram.com
- **Steps**:
  1. Sign up with email
  2. Create API key
- **Cost**: $0 ✅

### Groq - FREE
- **Free Tier**: 14.4M tokens/day (generous!)
- **Sign up**: https://console.groq.com
- **Steps**:
  1. Sign up with Google/GitHub
  2. Create API key
- **Cost**: $0 ✅

### Rime TTS - FREE Trial
- **Free Tier**: Check their free tier
- **Sign up**: https://app.rime.ai
- **Steps**:
  1. Sign up
  2. Create API key
- **Cost**: $0 (or free trial) ✅

### Supabase - FREE
- **Free Tier**: 500MB database, 2GB file storage
- **Sign up**: https://supabase.com
- **Steps**:
  1. Sign up with GitHub
  2. Create project (no credit card!)
- **Cost**: $0 ✅

---

## 2️⃣ Deploy Agent Worker - LiveKit Cloud (Recommended)

### Why LiveKit Cloud?
- ✅ **No cold start**: Agents join rooms instantly (unlike Render's 1-min wake-up)
- ✅ **Native integration**: Built for LiveKit agents
- ✅ **Auto-scaling**: Handles multiple sessions automatically
- ✅ **Free tier**: 1,000 agent session minutes/month
- ✅ **One command deploy**: `lk agent create`

### Prerequisites

```bash
# Install LiveKit CLI
# Download from: https://github.com/livekit/livekit-cli/releases

# Or via package manager
# Windows (via Scoop):
scoop install livekit

# Verify installation
lk version
```

### Deploy Steps

```bash
# 1. Navigate to agent directory
cd agent

# 2. Login to LiveKit Cloud (if not already)
lk cloud auth

# 3. Set environment variables in .env file
# Create agent/.env:
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret
DEEPGRAM_API_KEY=your_key
GROQ_API_KEY=your_key
RIME_API_KEY=your_key

# 4. Deploy agent (auto-generates Dockerfile, handles everything)
lk agent create

# Follow prompts:
# - Agent name: cooltalk-agent
# - Entry point: agent.py
# - Environment: production
# - Region: Choose closest to India (ap-south or ap-southeast)

# 5. Agent is now deployed! 🎉
```

### What LiveKit Does Automatically:
- ✅ Creates Dockerfile
- ✅ Builds container
- ✅ Deploys to LiveKit infrastructure
- ✅ Injects secrets securely
- ✅ Sets up auto-scaling
- ✅ Provides monitoring dashboard

### Verify Deployment

```bash
# List deployed agents
lk agent list

# View logs
lk agent logs cooltalk-agent

# Update agent (after code changes)
lk agent update cooltalk-agent
```

**Deployment Time**: ~5 minutes ✅  
**Cost**: $0 (within 1,000 session min/month) ✅

---

### ⚠️ Important: Free Tier Limits

**1,000 agent session minutes/month**
- ~16 hours of total agent conversation time
- For 100 users @ 10 min each = plenty
- **Don't burn quota on benchmarks before judging!**
- Monitor usage: https://cloud.livekit.io/projects/your-project/usage

### Alternative: Render.com (If You Prefer)

**Only if you want to avoid LiveKit Cloud deploy**

⚠️ **Trade-offs**:
- ✅ More control over hosting
- ❌ 15 min idle → 1 min cold start (bad for room joins)
- ❌ Need UptimeRobot to keep awake
- ❌ More complex setup

```bash
# Use Render.com web service
# Settings:
# - Build: pip install -r requirements.txt
# - Start: python agent.py start
# - Environment variables: Add all keys
# - Plan: Free (750 hrs/month)
```

**Recommendation**: Use LiveKit Cloud for better user experience ✅

---

## 3️⃣ Deploy Web Frontend - Cloudflare Pages

### Why Cloudflare Pages?
- ✅ **Truly unlimited bandwidth** (not capped like Vercel)
- ✅ **No credit card required**
- ✅ **No expiring credits**
- ✅ **Commercial use allowed** (Vercel Hobby restricts this)
- ✅ **Same platform for token server** (Pages Functions)

### Deploy Steps

```bash
# 1. Sign up at https://dash.cloudflare.com with GitHub

# 2. Go to "Workers & Pages" → "Create application" → "Pages"

# 3. Connect to Git
# - Select your GitHub repository
# - Choose cooltalk repo

# 4. Configure build settings:
```

**Build Configuration**:
- **Framework preset**: None (or Static site)
- **Build command**: (leave empty - static files)
- **Build output directory**: `/web`
- **Root directory**: `/web`

**Click "Save and Deploy"**

### Your Frontend URL:
```
https://cooltalk.pages.dev
```

**Deployment Time**: ~2 minutes ✅  
**Cost**: $0 forever ✅

---

## 4️⃣ Deploy Token Server - Cloudflare Pages Functions

### Option A: Cloudflare Pages Functions (Recommended)

**Why Edge Functions?**
- ✅ Zero cold start (unlike Render/Railway)
- ✅ Same platform as frontend (single deploy)
- ✅ Perfect for JWT signing (lightweight, stateless)
- ✅ 100k requests/day free

### Convert Python to TypeScript

Create `web/functions/token.ts`:

```typescript
// web/functions/token.ts
import { sign } from 'jsonwebtoken';

interface Env {
  LIVEKIT_API_KEY: string;
  LIVEKIT_API_SECRET: string;
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env } = context;
  
  // Handle CORS
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    });
  }

  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const { room_name, participant_name } = await request.json();

    if (!room_name || !participant_name) {
      return new Response(
        JSON.stringify({ error: 'room_name and participant_name required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Generate JWT token
    const token = sign(
      {
        video: { roomJoin: true, room: room_name },
        name: participant_name,
        exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour
      },
      env.LIVEKIT_API_SECRET,
      {
        header: {
          alg: 'HS256',
          kid: env.LIVEKIT_API_KEY,
        },
      }
    );

    return new Response(
      JSON.stringify({ token }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Token generation failed' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
};
```

### Setup Dependencies

Create `web/package.json`:

```json
{
  "name": "cooltalk-web",
  "version": "1.0.0",
  "dependencies": {
    "jsonwebtoken": "^9.0.2",
    "@types/jsonwebtoken": "^9.0.5"
  }
}
```

### Deploy

```bash
# Add environment variables in Cloudflare dashboard
# Settings → Environment variables:
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret

# Deploy (automatic via Git push)
git add web/functions/token.ts web/package.json
git commit -m "Add token server edge function"
git push

# Cloudflare auto-deploys on push ✅
```

### Token Server URL:
```
https://cooltalk.pages.dev/token
```

**Cost**: $0 (100k requests/day) ✅

---

### Option B: Keep Python on Render (Simpler, but cold start)

**If you prefer not to touch code:**

```bash
# Deploy token_server.py to Render as separate web service
# Trade-off: 30-50s cold start after 15 min idle
# Pro tip: Warm-up ping right before live demo
```

**Settings**:
- **Build**: `pip install -r requirements.txt`
- **Start**: `python token_server.py`
- **Environment**: Add LIVEKIT keys

**Recommendation**: Use Cloudflare Pages Functions for zero cold start ✅

---

## 5️⃣ Mobile App Distribution

### Android - Direct APK Sideload (100% FREE)

**No Play Store needed, completely free!**

```bash
cd mobile

# Update configs first (see section 6)

# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

**Distribution Methods**:
1. **Direct share** - WhatsApp, Telegram, email
2. **Google Drive** - Upload and share link
3. **Firebase App Distribution** - Professional (still free)
4. **Your own website** - Host the APK file

**User Installation**:
```
1. Download APK
2. Settings → Security → "Install from unknown sources"
3. Open APK file
4. Install
```

**Cost**: $0 ✅

---

### iOS - Xcode Personal Install (FREE for personal device)

**Free Option (7-day builds)**:

```bash
# Requirements:
# - Mac with Xcode
# - Free Apple ID

# Steps:
1. Open mobile/ios/Runner.xcworkspace in Xcode
2. Sign in with free Apple ID
3. Select your device
4. Build and run
5. App installs for 7 days

# Reinstall every 7 days (free limitation)
```

**Cost**: $0 (personal device only) ✅

---

### iOS - TestFlight / App Store (Requires $99/year)

**For wider distribution:**

⚠️ **Apple Developer Program required**: $99/year
- TestFlight beta testing
- App Store distribution
- Also needed for "Sign In with Apple" feature

**If you already have $99 account:**

```bash
# 1. Build for iOS
cd mobile
flutter build ios --release

# 2. Open in Xcode
open ios/Runner.xcworkspace

# 3. Archive and submit to TestFlight
# Product → Archive → Distribute App → TestFlight

# 4. TestFlight allows up to 10,000 testers (free after initial $99)
```

**Cost**: $99/year (if needed) ⚠️

**Recommendation for free deployment**: Focus on Android APK ✅

---

## 6️⃣ Update Mobile App Configuration

### Update Supabase Config (Already Deployed)

`mobile/lib/services/supabase_service.dart`:
```dart
static const String _supabaseUrl = 'YOUR_SUPABASE_URL';
static const String _supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Update LiveKit/Token Server Config

`mobile/lib/screens/main_nav_screen.dart`:

```dart
void _launchCookingSession(Dish? dish) {
  // Update with your Cloudflare Pages URL
  final tokenServerUrl = 'https://cooltalk.pages.dev/token';
  
  // Your LiveKit Cloud URL (unchanged)
  final livekitUrl = 'wss://your-project.livekit.cloud';
  
  // ... rest of the function
}
```

### Build Release APK

```bash
cd mobile

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK ready at:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 7️⃣ Complete Free Deployment Steps

### Step 1: Get Free API Keys (30 min)
```
✅ LiveKit Cloud (sign up)
✅ Deepgram ($200 credit)
✅ Groq (14.4M tokens/day)
✅ Rime TTS (free tier)
✅ Supabase (already deployed)
```

### Step 2: Deploy Agent to LiveKit Cloud (5 min)
```bash
cd agent
lk cloud auth
lk agent create
# Follow prompts, add environment variables
```

### Step 3: Deploy Web Frontend to Cloudflare Pages (5 min)
```bash
# Via Cloudflare dashboard:
# 1. Connect GitHub repo
# 2. Set root directory: /web
# 3. Deploy
```

### Step 4: Deploy Token Server to Pages Functions (10 min)
```bash
# Option A: Create token.ts edge function (recommended)
# Option B: Deploy Python to Render (simpler but cold start)
```

### Step 5: Configure Mobile App (5 min)
```bash
# Update Supabase URL, token server URL
cd mobile
flutter pub get
```

### Step 6: Build APK (5 min)
```bash
flutter build apk --release
```

### Step 7: Distribute APK (5 min)
```bash
# Share via Drive/WhatsApp/Firebase App Distribution
# File: build/app/outputs/flutter-apk/app-release.apk
```

**Total Time**: ~65 minutes ⏱️  
**Total Cost**: $0 💰

---

## 8️⃣ Free Service Comparison

| Service | Free Tier | Limits | Gotchas |
|---------|-----------|--------|---------|
| **LiveKit Cloud** | Build plan | 1,000 session min/mo | Monitor usage, don't waste on benchmarks |
| **Cloudflare Pages** | Unlimited | Unlimited bandwidth | None - truly free |
| **Pages Functions** | Free | 100k requests/day | More than enough |
| **Supabase** | Free forever | 500MB DB, 2GB storage | Already deployed |
| **Deepgram** | $200 credit | ~45 hours audio | Monitor usage |
| **Groq** | Free | 14.4M tokens/day | Daily limit (learned this earlier!) |

---

## 9️⃣ Staying Within Free Tiers

### Critical Monitoring:

**LiveKit Agent Sessions** (Most Important):
- 1,000 minutes/month = ~16 hours total
- Average session: 10 minutes
- Supports: ~100 sessions/month
- **Don't waste on benchmarks before judging!**
- Monitor: https://cloud.livekit.io/projects/your-project/usage

**Groq Tokens** (Daily Limit):
- 14.4M tokens/day limit
- Resets at midnight UTC
- Learned this lesson during development
- Check before live demos

**Deepgram Credits**:
- $200 initial credit
- ~45 hours of transcription
- Monitor: https://console.deepgram.com/billing

### Tips to Optimize:
1. ✅ Test thoroughly on local agent first
2. ✅ Warm up before demos (Groq quota check)
3. ✅ Monitor LiveKit usage dashboard weekly
4. ✅ Use shorter test sessions during development
5. ✅ Keep benchmarks minimal on production agent

---

## 🔟 Free Tools & Monitoring

### Built-in Free Monitoring:
- **LiveKit Dashboard**: Session logs, usage metrics (free)
- **Cloudflare Analytics**: Page views, bandwidth (free)
- **Supabase Dashboard**: Database stats, queries (free)
- **Firebase Crashlytics**: Crash reports (free tier)

### Optional Free Tools:
- **Sentry**: 5k events/month (free)
- **Google Analytics**: Unlimited (free)
- **LogRocket**: 1k sessions/month (free)

---

## 📊 Usage Estimates

### For 100 Active Users/Month:
- **Agent sessions**: ~100 sessions @ 10 min = 1,000 min ✅ (at limit)
- **Database**: ~50MB ✅ (within 500MB)
- **Groq tokens**: ~500K tokens/day ✅ (within 14.4M)
- **Deepgram**: ~16 hours audio ✅ (within credit)
- **Cloudflare**: Unlimited ✅

**Result**: Stays FREE ✅

### For 500 Active Users/Month:
⚠️ **Would exceed LiveKit free tier**
- Need: ~5,000 agent minutes
- Free tier: 1,000 minutes
- **Need to upgrade** or optimize session length

**Alternative**: Limit to 100 sessions/month on free tier

---

## ⚠️ Free Tier Gotchas

### 1. LiveKit Agent Session Limit
**Problem**: 1,000 min/month = ~100 users @ 10 min sessions  
**Solution**: Monitor usage, optimize session length, or upgrade when needed

### 2. Groq Daily Token Reset
**Problem**: Hitting 14.4M daily limit breaks the agent  
**Solution**: Check quota before demos, implement fallback responses

### 3. iOS Distribution Requires $99/Year
**Problem**: TestFlight and App Store need paid developer account  
**Solution**: Focus on Android APK for free deployment, iOS only if needed

### 4. Cold Starts (if using Render for token server)
**Problem**: 30-50s delay after 15 min idle  
**Solution**: Use Cloudflare Pages Functions instead (zero cold start)

---

## 🎯 Pre-Launch Checklist

### Before Judging / Demo:

- [ ] Check Groq daily quota (not near 14.4M limit)
- [ ] Check LiveKit session minutes used this month
- [ ] Verify Deepgram credits remaining
- [ ] Test APK on real device
- [ ] Warm up services (if using Render)
- [ ] Backup plan if hitting limits
- [ ] Phone charged, good internet connection
- [ ] Fallback responses configured

**Learned from experience**: Don't burn quota on benchmarks! 🎓

---

## 🚀 Quick Deploy Commands Summary

```bash
# 1. Deploy agent to LiveKit Cloud
cd agent
lk agent create

# 2. Deploy web to Cloudflare Pages
# (via dashboard - connect GitHub)

# 3. Deploy token server
# Option A: Create web/functions/token.ts
# Option B: Deploy token_server.py to Render

# 4. Build mobile APK
cd mobile
flutter build apk --release

# 5. Distribute
# Share: build/app/outputs/flutter-apk/app-release.apk
```

---

## 💡 Pro Tips

1. **LiveKit Cloud > Render**: No cold start, built for agents
2. **Cloudflare Pages > Vercel**: Truly unlimited, no bandwidth cap
3. **Pages Functions > Separate server**: Zero cold start, same deploy
4. **Monitor usage weekly**: Avoid surprises before demos
5. **Android first**: iOS needs $99/year, Android is free
6. **Test locally first**: Don't waste production quota

---

## 🎉 Success - $0 Deployment!

With this setup:
- ✅ Agent deploys instantly to LiveKit Cloud
- ✅ Web frontend on unlimited Cloudflare
- ✅ Token server with zero cold start
- ✅ Supabase already deployed
- ✅ Android APK ready to share
- ✅ Monitoring dashboards included
- ✅ **Total cost: $0** (within free tiers)

Good for ~100 users @ 10 min sessions/month ✅

---

## 🔮 When to Upgrade

Consider paid plans when:
- More than 100 active users/month (LiveKit limit)
- Need iOS TestFlight/App Store ($99/year)
- Hitting Groq daily limits frequently
- Want custom domain (Cloudflare Pro)
- Need more database storage

**But for launch: 100% FREE works great!** ✅

---

## ✅ Deploy Now - Step by Step

```bash
# Total time: ~65 minutes
# Total cost: $0

# 1. Get API keys → 30 min
# 2. Deploy agent → 5 min (lk agent create)
# 3. Deploy web → 5 min (Cloudflare dashboard)
# 4. Token server → 10 min (Pages Functions)
# 5. Config mobile → 5 min (update URLs)
# 6. Build APK → 5 min (flutter build)
# 7. Share APK → 5 min (Drive/WhatsApp/Firebase)
```

**Ready to deploy CookTalk for $0!** 🚀💚
