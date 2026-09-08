# CookTalk Deployment Guide

## Overview
This guide covers deploying CookTalk components (excluding the web frontend):
- ✅ LiveKit Voice Agent (Backend)
- ✅ Flutter Mobile App (iOS & Android)
- ✅ Supabase Database

---

## 1️⃣ Prerequisites

### Required Accounts & API Keys
- [ ] LiveKit Cloud account (https://cloud.livekit.io)
- [ ] Deepgram API key (https://console.deepgram.com)
- [ ] Groq API key (https://console.groq.com)
- [ ] Rime TTS API key (https://app.rime.ai)
- [ ] Supabase project (https://supabase.com)
- [ ] Google Cloud Console (for Android deployment)
- [ ] Apple Developer Account (for iOS deployment)

### Development Tools
- Python 3.10+ (for agent)
- Flutter SDK 3.13+ (for mobile)
- Git
- Docker (optional, for containerized deployment)

---

## 2️⃣ Deploy Supabase Database

### Option A: Use Existing Supabase Project
1. Go to https://supabase.com
2. Create a new project or use existing
3. Note down:
   - Project URL: `https://your-project.supabase.co`
   - Anon/Public Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - Service Role Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### Option B: Deploy Database Schema
If you have a `supabase` directory with migrations:

```bash
cd supabase
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Push database schema
supabase db push

# (Optional) Push storage buckets and functions
supabase functions deploy
```

### Configure Database Tables
Your app needs these tables:
- `profiles` - User profiles
- `dishes` - Recipe database
- `cook_history` - Cooking session history
- `favorites` - User favorite recipes

---

## 3️⃣ Deploy LiveKit Voice Agent

### Hosting Options

#### Option A: Railway.app (Recommended - Easy)
1. Sign up at https://railway.app
2. Create new project
3. Connect GitHub repository
4. Add environment variables:
   ```
   LIVEKIT_URL=wss://your-project.livekit.cloud
   LIVEKIT_API_KEY=your_key
   LIVEKIT_API_SECRET=your_secret
   DEEPGRAM_API_KEY=your_key
   GROQ_API_KEY=your_key
   RIME_API_KEY=your_key
   ```
5. Set start command: `python agent/agent.py start`
6. Deploy!

#### Option B: Render.com
1. Sign up at https://render.com
2. Create new **Web Service**
3. Connect GitHub repository
4. Settings:
   - **Root Directory**: `agent`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `python agent.py start`
5. Add environment variables (same as above)
6. Deploy!

#### Option C: Fly.io (For Production)

Create `agent/fly.toml`:
```toml
app = "cooltalk-agent"
primary_region = "sin"  # Singapore (or your preferred region)

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8080"

[[services]]
  internal_port = 8080
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

Create `agent/Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "agent.py", "start"]
```

Deploy:
```bash
cd agent
fly auth login
fly launch
fly secrets set LIVEKIT_URL=wss://... LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... DEEPGRAM_API_KEY=... GROQ_API_KEY=... RIME_API_KEY=...
fly deploy
```

#### Option D: Google Cloud Run

Create `agent/Dockerfile` (same as above)

Deploy:
```bash
cd agent

# Build container
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/cooltalk-agent

# Deploy to Cloud Run
gcloud run deploy cooltalk-agent \
  --image gcr.io/YOUR_PROJECT_ID/cooltalk-agent \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars LIVEKIT_URL=wss://...,LIVEKIT_API_KEY=...,LIVEKIT_API_SECRET=...,DEEPGRAM_API_KEY=...,GROQ_API_KEY=...,RIME_API_KEY=...
```

---

## 4️⃣ Deploy Flutter Mobile App

### Update Configuration

1. **Update Supabase Config**
   
   Edit `mobile/lib/services/supabase_service.dart`:
   ```dart
   static const String _supabaseUrl = 'https://your-project.supabase.co';
   static const String _supabaseAnonKey = 'your-anon-key';
   ```

2. **Update Agent Server URL**
   
   Edit `mobile/lib/screens/main_nav_screen.dart`:
   ```dart
   void _launchCookingSession(Dish? dish) {
     // Update this URL to your deployed agent
     final host = 'https://your-agent-url.com'; // Remove Platform.isAndroid check
     ...
   }
   ```

3. **Update App Bundle ID**
   
   - iOS: Edit `mobile/ios/Runner/Info.plist` and update bundle identifier
   - Android: Edit `mobile/android/app/build.gradle` and update `applicationId`

### Android Deployment

#### Build APK for Testing
```bash
cd mobile
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Build App Bundle for Google Play
```bash
cd mobile

# Generate keystore (first time only)
keytool -genkey -v -keystore ~/cooltalk-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cooltalk

# Create key.properties
cat > android/key.properties << EOF
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=cooltalk
storeFile=C:/Users/subha/cooltalk-release-key.jks
EOF

# Update android/app/build.gradle to use signing config
# Then build
flutter build appbundle --release
```

#### Upload to Google Play Console
1. Go to https://play.google.com/console
2. Create new app
3. Fill in app details, screenshots, descriptions
4. Upload `build/app/outputs/bundle/release/app-release.aab`
5. Submit for review

### iOS Deployment

#### Prerequisites
- Mac computer
- Xcode installed
- Apple Developer account ($99/year)

#### Build IPA
```bash
cd mobile

# Open Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select your team in Signing & Capabilities
# 2. Update Bundle Identifier
# 3. Archive: Product > Archive
# 4. Distribute App > App Store Connect
```

#### Upload to App Store Connect
1. Go to https://appstoreconnect.apple.com
2. Create new app
3. Fill in metadata, screenshots, descriptions
4. Upload build via Xcode or Transporter
5. Submit for review

---

## 5️⃣ Environment Variables Summary

### Agent `.env`
```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=API_xxx
LIVEKIT_API_SECRET=secret_xxx
DEEPGRAM_API_KEY=xxx
GROQ_API_KEY=gsk_xxx
RIME_API_KEY=xxx
```

### Mobile App
Update in code:
- Supabase URL & Keys (in `supabase_service.dart`)
- Agent Server URL (in `main_nav_screen.dart`)

---

## 6️⃣ Post-Deployment Checklist

### Testing
- [ ] Test agent connection via LiveKit
- [ ] Test mobile app authentication
- [ ] Test voice cooking session
- [ ] Test recipe browsing
- [ ] Test favorites & history
- [ ] Test both light and dark mode
- [ ] Test on real devices (not just emulator)

### Monitoring
- [ ] Set up error tracking (Sentry, Firebase Crashlytics)
- [ ] Monitor API usage (LiveKit, Deepgram, Groq, Rime)
- [ ] Set up uptime monitoring (UptimeRobot, Pingdom)

### Documentation
- [ ] Update README with live URLs
- [ ] Document API rate limits
- [ ] Create user guide
- [ ] Update privacy policy with deployed URLs

---

## 7️⃣ Cost Estimates

### Monthly Costs (Estimated)
- **LiveKit Cloud**: Free tier (50GB/month) or $99/month
- **Supabase**: Free tier or $25/month
- **Agent Hosting**: 
  - Railway: $5-20/month
  - Render: Free tier or $7/month
  - Fly.io: ~$10/month
  - Google Cloud Run: Pay per use (~$5-15/month)
- **APIs (per 1000 users)**:
  - Deepgram STT: ~$10-30
  - Groq LLM: Free tier (14.4M tokens/day)
  - Rime TTS: Check pricing
- **App Store Fees**:
  - Google Play: $25 one-time
  - Apple App Store: $99/year

**Total**: ~$50-200/month depending on usage

---

## 8️⃣ Quick Deploy Commands

### Agent (Railway)
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
cd agent
railway init

# Add environment variables via dashboard
# Deploy
railway up
```

### Mobile App
```bash
cd mobile

# Android
flutter build apk --release

# iOS (on Mac)
flutter build ios --release
```

---

## 9️⃣ Troubleshooting

### Agent Issues
- **Can't connect to LiveKit**: Check URL format (must start with `wss://`)
- **API key errors**: Verify all keys are set in environment
- **Module not found**: Run `pip install -r requirements.txt`

### Mobile App Issues
- **Supabase connection fails**: Check URL and keys
- **Voice session not starting**: Verify agent URL is correct
- **Build errors**: Run `flutter clean` and `flutter pub get`

### iOS Specific
- **Signing errors**: Select development team in Xcode
- **Provisioning profile errors**: Regenerate in Apple Developer portal

---

## 🎯 Next Steps

After successful deployment:
1. Submit apps to stores
2. Set up analytics (Firebase, Mixpanel)
3. Configure push notifications (optional)
4. Set up CI/CD pipeline (GitHub Actions, Codemagic)
5. Monitor usage and costs
6. Gather user feedback
7. Plan updates and improvements

---

## 📞 Support Resources

- LiveKit Docs: https://docs.livekit.io
- Flutter Docs: https://docs.flutter.dev
- Supabase Docs: https://supabase.com/docs
- Railway Docs: https://docs.railway.app

Good luck with your deployment! 🚀
