# CookTalk - Free Deployment Architecture

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         User Devices                         │
│                                                              │
│  ┌──────────────┐              ┌──────────────┐            │
│  │ Android APK  │              │  Web Browser │            │
│  │ (Sideloaded) │              │              │            │
│  └──────┬───────┘              └──────┬───────┘            │
└─────────┼──────────────────────────────┼───────────────────┘
          │                              │
          │ LiveKit WebSocket            │ HTTPS
          │                              │
┌─────────┼──────────────────────────────┼───────────────────┐
│         │        Cloud Services        │                   │
│         │                              │                   │
│  ┌──────▼───────────────┐     ┌───────▼────────────┐      │
│  │   LiveKit Cloud      │     │ Cloudflare Pages   │      │
│  │  (Agent Worker)      │     │  (Web Frontend +   │      │
│  │                      │     │  Token Server)     │      │
│  │ • 1,000 min/mo FREE  │     │  • Unlimited FREE  │      │
│  │ • No cold start      │     │  • Zero cold start │      │
│  │ • Auto-scaling       │     │  • Edge functions  │      │
│  └──────┬───────────────┘     └───────┬────────────┘      │
│         │                              │                   │
│         │ API Calls                    │ API Calls         │
│         │                              │                   │
│  ┌──────▼──────────────────────────────▼────────────┐     │
│  │              External APIs                        │     │
│  │                                                   │     │
│  │  • Deepgram (STT) - $200 credit FREE             │     │
│  │  • Groq (LLM) - 14.4M tokens/day FREE            │     │
│  │  • Rime (TTS) - Free tier                        │     │
│  │  • Supabase (DB) - 500MB FREE                    │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Component Breakdown

### 1. Agent Worker (`/agent`)

**Platform**: LiveKit Cloud  
**Deployment**: `lk agent create`  
**Cost**: FREE (1,000 session minutes/month)

**Why LiveKit Cloud?**
- ✅ Native integration with LiveKit rooms
- ✅ Zero cold start (unlike Render/Railway)
- ✅ Auto-scaling for multiple sessions
- ✅ Auto-generates Dockerfile
- ✅ Secure secrets management

**Configuration**:
```bash
cd agent
lk cloud auth
lk agent create

# Environment variables (set in LiveKit dashboard):
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret
DEEPGRAM_API_KEY=your_key
GROQ_API_KEY=your_key
RIME_API_KEY=your_key
```

**Key Files**:
- `agent.py` - Main agent logic
- `requirements.txt` - Python dependencies
- `.env` - Local development config

---

### 2. Web Frontend (`/web`)

**Platform**: Cloudflare Pages  
**Deployment**: Git push (auto-deploy)  
**Cost**: FREE (unlimited bandwidth forever)

**Why Cloudflare Pages?**
- ✅ Truly unlimited bandwidth (no caps like Vercel)
- ✅ No credit card required
- ✅ No expiring credits
- ✅ Commercial use allowed
- ✅ Global CDN

**Configuration**:
```yaml
Framework: Static site
Build command: (none)
Build output: /web
Root directory: /web
```

**Deployment URL**:
```
https://cooltalk.pages.dev
(or custom domain)
```

---

### 3. Token Server (`token_server.py` → `web/functions/token.ts`)

**Platform**: Cloudflare Pages Functions (edge function)  
**Deployment**: Same as web frontend  
**Cost**: FREE (100,000 requests/day)

**Why Edge Function?**
- ✅ Zero cold start (vs 30-50s on Render)
- ✅ Same platform as frontend (single deploy)
- ✅ Perfect for JWT signing (stateless, lightweight)
- ✅ Global edge network

**Migration**:
- Original: `token_server.py` (Python)
- New: `web/functions/token.ts` (TypeScript)
- Same functionality, better performance

**Endpoint**:
```
POST https://cooltalk.pages.dev/token
Body: { "room_name": "...", "participant_name": "..." }
Response: { "token": "..." }
```

**Alternative** (if prefer not to migrate):
- Deploy `token_server.py` to Render as separate service
- Trade-off: 30-50s cold start after 15 min idle
- Workaround: Warm-up ping before demos

---

### 4. Supabase Database

**Platform**: Supabase Cloud  
**Status**: Already deployed ✅  
**Cost**: FREE (500MB database, 2GB storage)

**No action needed** - already configured and running.

**Free Tier Limits**:
- 500MB database storage
- 2GB file storage
- 50,000 monthly active users
- 1GB egress/month

---

### 5. Mobile App (`/mobile`)

**Platform**: Not "deployed" - distributed as APK  
**Build**: `flutter build apk --release`  
**Cost**: FREE

**Android Distribution**:
1. Build APK: `flutter build apk --release`
2. Share via:
   - Firebase App Distribution (recommended)
   - Google Drive
   - Direct download link
   - WhatsApp/Telegram

**iOS Distribution**:
- **Free**: Xcode install (7-day builds, personal device only)
- **Paid**: Apple Developer Program ($99/year) for TestFlight/App Store
  - Note: Same $99 account required for "Sign In with Apple"

**Configuration Files**:
- `lib/services/supabase_service.dart` - Supabase URL/key
- `lib/screens/main_nav_screen.dart` - Token server URL, LiveKit URL

---

## 🔑 API Keys Required

All free tiers, no credit card needed:

| Service | Purpose | Free Tier | Sign Up |
|---------|---------|-----------|---------|
| **LiveKit** | Voice rooms | 1,000 min/mo | https://cloud.livekit.io |
| **Deepgram** | Speech-to-text | $200 credit | https://console.deepgram.com |
| **Groq** | LLM inference | 14.4M tokens/day | https://console.groq.com |
| **Rime** | Text-to-speech | Free tier | https://app.rime.ai |
| **Supabase** | Database | 500MB | https://supabase.com |

---

## 📊 Free Tier Limits & Capacity

### LiveKit Cloud (Agent Worker)
- **Limit**: 1,000 agent session minutes/month
- **Capacity**: ~100 users @ 10 min sessions
- **Watch out**: Don't waste on benchmarks before demos!

### Cloudflare Pages (Web + Token Server)
- **Limit**: Truly unlimited bandwidth
- **Requests**: 100,000 function calls/day
- **Capacity**: Scales to millions of users

### Groq (LLM)
- **Limit**: 14.4M tokens/day (resets midnight UTC)
- **Capacity**: ~500-1000 conversations/day
- **Watch out**: Hit this limit during development already!

### Deepgram (STT)
- **Limit**: $200 initial credit
- **Capacity**: ~45 hours of transcription
- **Monitor**: https://console.deepgram.com/billing

### Supabase (Database)
- **Limit**: 500MB storage, 50k MAU
- **Capacity**: 10,000+ users easily
- **Watch out**: File storage counts toward limit

---

## 🚀 Deployment Sequence

### Step 1: Setup (One-time)
```bash
# Install tools
# 1. LiveKit CLI: Download from GitHub releases
# 2. Flutter SDK: Already installed
# 3. Git: Already installed

# Get API keys (all free, no credit card)
# • LiveKit Cloud - Sign up with GitHub
# • Deepgram - Sign up with email  
# • Groq - Sign up with Google
# • Rime - Sign up
# • Supabase - Already have
```

### Step 2: Deploy Agent (5 min)
```bash
cd agent
lk cloud auth
lk agent create
# Follow prompts, add environment variables
```

### Step 3: Deploy Web + Token Server (5 min)
```bash
# Via Cloudflare dashboard:
# 1. Sign up at dash.cloudflare.com
# 2. Workers & Pages → Create → Pages
# 3. Connect GitHub repo
# 4. Set root directory: /web
# 5. Deploy
# 6. Add environment variables:
#    - LIVEKIT_API_KEY
#    - LIVEKIT_API_SECRET
```

### Step 4: Configure Mobile (5 min)
```bash
cd mobile

# Edit lib/services/supabase_service.dart
# Update Supabase URL and key

# Edit lib/screens/main_nav_screen.dart
# Update token server URL: https://cooltalk.pages.dev/token

flutter pub get
```

### Step 5: Build APK (5 min)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Step 6: Distribute (5 min)
```bash
# Option 1: Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk

# Option 2: Direct share
# Upload to Drive/WhatsApp/Telegram
```

**Total**: ~30 minutes, $0 cost ✅

---

## ⚠️ Common Gotchas

### 1. LiveKit Session Limit
**Problem**: 1,000 min/month = ~100 users  
**Solution**: Monitor usage, don't waste on benchmarks

### 2. Groq Daily Reset
**Problem**: 14.4M tokens/day limit  
**Solution**: Check quota before demos, happened before!

### 3. iOS Distribution Cost
**Problem**: TestFlight needs $99/year Apple Developer  
**Solution**: Focus on Android APK for free deployment

### 4. Token Server Cold Start (if using Render)
**Problem**: 30-50s delay after idle  
**Solution**: Use Cloudflare Pages Functions instead

---

## 📈 Scaling Beyond Free Tier

### At 100 users/month:
- ✅ Everything stays free
- ✅ Within all limits
- ✅ $0 cost

### At 500 users/month:
- ⚠️ May exceed LiveKit 1,000 min limit
- ✅ Everything else still free
- 💡 Option: Upgrade LiveKit or optimize session length

### At 1,000+ users/month:
- ⚠️ Need LiveKit paid plan
- ⚠️ May need Supabase Pro (more storage)
- ✅ Web/Token server still free (scales infinitely)

---

## 🔄 Update & Maintenance

### Update Agent Code
```bash
cd agent
# Make changes
git push

# Redeploy
lk agent update cooltalk-agent
```

### Update Web/Token Server
```bash
cd web
# Make changes
git push

# Cloudflare auto-deploys ✅
```

### Update Mobile App
```bash
cd mobile
# Make changes
flutter build apk --release
# Redistribute new APK
```

---

## 🎯 Pre-Demo Checklist

Before live demo or judging:

- [ ] **Check Groq quota** - Not near 14.4M daily limit
- [ ] **Check LiveKit minutes** - Not near 1,000/month limit
- [ ] **Verify Deepgram credits** - Enough remaining
- [ ] **Test APK on device** - Fresh install works
- [ ] **Verify all services** - Agent, web, token server up
- [ ] **Have backup plan** - If quota limits hit
- [ ] **Phone charged** - Battery at 100%
- [ ] **Good internet** - Stable connection

**Lesson learned**: Groq daily limit hit during development! 🎓

---

## 💡 Architecture Decisions

### Why LiveKit Cloud (not Render)?
- ❌ Render: 15 min idle → 1 min cold start
- ✅ LiveKit: Zero cold start, instant room join
- ✅ Built for agent workers

### Why Cloudflare Pages (not Vercel)?
- ❌ Vercel: Bandwidth caps, commercial restrictions
- ✅ Cloudflare: Truly unlimited, no restrictions
- ✅ Better for global users

### Why Edge Functions (not separate server)?
- ❌ Render: 30-50s cold start for token server
- ✅ Edge: Zero cold start, instant response
- ✅ Same deploy as frontend

### Why Android APK (not Play Store)?
- ❌ Play Store: $25 one-time fee
- ✅ APK: $0, instant distribution
- ✅ Good for hackathon demos

---

## ✅ Success Metrics

With this architecture:
- ✅ Agent joins rooms instantly (no cold start)
- ✅ Token generation is instant (edge function)
- ✅ Web frontend loads globally fast (CDN)
- ✅ Supports ~100 users/month completely free
- ✅ Easy to scale when needed
- ✅ Professional quality despite $0 cost

**Total Cost: $0** 🎉

---

## 📚 References

- LiveKit Cloud Docs: https://docs.livekit.io/cloud
- Cloudflare Pages: https://developers.cloudflare.com/pages
- Pages Functions: https://developers.cloudflare.com/pages/functions
- Flutter APK Build: https://docs.flutter.dev/deployment/android

---

## 🆘 Troubleshooting

### Agent not joining room
- Check LiveKit credentials in environment
- Verify agent is running: `lk agent list`
- Check agent logs: `lk agent logs cooltalk-agent`

### Token generation fails
- Verify LIVEKIT_API_KEY and SECRET in Cloudflare env
- Check function logs in Cloudflare dashboard
- Test endpoint: `curl -X POST https://your-app.pages.dev/token -d '{"room_name":"test","participant_name":"test"}'`

### Mobile app can't connect
- Verify token server URL in `main_nav_screen.dart`
- Check LiveKit URL matches your project
- Test with web version first

### Quota limits hit
- LiveKit: Monitor at cloud.livekit.io/usage
- Groq: Check console.groq.com (resets daily)
- Deepgram: Check console.deepgram.com/billing

---

**Ready to deploy!** 🚀
