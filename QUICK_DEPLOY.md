# Quick Deploy Guide - CookTalk

## 🚀 Deploy in 30 Minutes

Follow these steps in order for the fastest deployment.

---

## Step 1: Setup Supabase (5 minutes)

1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Fill in:
   - Name: `cooltalk`
   - Database Password: (generate strong password)
   - Region: Select closest to you
4. Wait for project to be ready
5. Copy these values:
   - **Project URL**: Settings → API → Project URL
   - **Anon Key**: Settings → API → Project API keys → anon/public

---

## Step 2: Deploy Agent (10 minutes)

### Using Railway (Easiest)

1. Go to https://railway.app
2. Sign up with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Select your `cooltalk` repository
5. Click "Add variables" and add:
   ```
   LIVEKIT_URL=wss://your-project.livekit.cloud
   LIVEKIT_API_KEY=your_key
   LIVEKIT_API_SECRET=your_secret
   DEEPGRAM_API_KEY=your_key
   GROQ_API_KEY=your_key
   RIME_API_KEY=your_key
   ```
6. In Settings:
   - Root Directory: `agent`
   - Start Command: `python agent.py start`
7. Click "Deploy"
8. Copy the deployment URL (e.g., `https://cooltalk-agent.up.railway.app`)

---

## Step 3: Configure Mobile App (5 minutes)

### Update Supabase Configuration

Edit `mobile/lib/services/supabase_service.dart`:

```dart
// Line ~20
static const String _supabaseUrl = 'YOUR_SUPABASE_URL';
static const String _supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Update Agent URL

Edit `mobile/lib/screens/main_nav_screen.dart`:

```dart
// Line ~22
void _launchCookingSession(Dish? dish) {
  final host = 'YOUR_AGENT_URL'; // e.g., 'https://cooltalk-agent.up.railway.app'
  ...
}
```

---

## Step 4: Build Mobile App (10 minutes)

### Android (Test Build)

```powershell
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

Your APK will be at: `mobile\build\app\outputs\flutter-apk\app-release.apk`

Install on your Android device:
```powershell
adb install build/app/outputs/flutter-apk/app-release.apk
```

### iOS (requires Mac)

```bash
cd mobile
flutter clean
flutter pub get
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode and archive.

---

## Step 5: Test Everything

1. **Test Agent**
   - Check Railway logs for startup messages
   - Should see "Agent started successfully"

2. **Test Mobile App**
   - Open app on device
   - Sign in with Google/Apple
   - Try starting a voice session
   - Test recipe browsing

---

## 🎯 What's Next?

### For Production Deployment:

1. **Android Play Store**:
   - Generate keystore
   - Build app bundle: `flutter build appbundle --release`
   - Upload to Google Play Console

2. **iOS App Store**:
   - Join Apple Developer Program ($99/year)
   - Configure signing in Xcode
   - Archive and submit

3. **Monitoring**:
   - Set up Sentry for error tracking
   - Add Firebase Analytics
   - Monitor API usage

---

## 📊 Cost Breakdown (Free Tier Start)

- ✅ Railway: Free 500 hours/month ($5 after)
- ✅ Supabase: Free tier (500MB database)
- ✅ LiveKit: Free 50GB/month
- ✅ Deepgram: Free tier available
- ✅ Groq: Free tier (14.4M tokens/day)
- ✅ Rime TTS: Check pricing

**Total to start**: $0-10/month

---

## ❓ Troubleshooting

### Agent won't start
- Check Railway logs for errors
- Verify all environment variables are set
- Make sure `requirements.txt` is in agent folder

### Mobile app can't connect
- Verify Supabase URL and keys
- Check agent URL is correct (include https://)
- Check device has internet connection

### Voice session fails
- Verify all API keys (LiveKit, Deepgram, Groq, Rime)
- Check agent logs for error messages
- Test with good microphone

---

## 🆘 Need Help?

1. Check Railway logs: Dashboard → Deployments → Logs
2. Check mobile logs: `flutter logs`
3. Test agent locally first: `cd agent && python agent.py dev`

---

## ✅ Success Checklist

- [ ] Agent deployed and running
- [ ] Mobile app configured
- [ ] APK/IPA built
- [ ] Tested on real device
- [ ] Voice session works
- [ ] Recipe browsing works
- [ ] Authentication works

**Congratulations! CookTalk is deployed!** 🎉
