# 📦 Deployment Resources

This directory contains everything you need to deploy CookTalk to production.

## 🚀 Start Here

**New to deployment?** → Start with **[QUICK_DEPLOY.md](./QUICK_DEPLOY.md)** (30 minutes)

**Want detailed guide?** → Read **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** (Complete guide)

**Need a checklist?** → Use **[DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)** (Print and check off)

**Submitting to app stores?** → See **[APP_STORE_ASSETS.md](./APP_STORE_ASSETS.md)** (All assets needed)

**Quick overview?** → Read **[DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md)** (5-minute summary)

---

## 📋 All Documents

| Document | Purpose | Time to Complete |
|----------|---------|------------------|
| **QUICK_DEPLOY.md** | Fastest path to production | 30 minutes |
| **DEPLOYMENT_GUIDE.md** | Complete step-by-step guide | 1-2 hours |
| **DEPLOYMENT_CHECKLIST.md** | Printable checklist | - |
| **DEPLOYMENT_SUMMARY.md** | Overview and costs | 5 min read |
| **APP_STORE_ASSETS.md** | App store submission guide | Reference |
| **agent/Dockerfile** | Docker config for agent | - |

---

## 🎯 Deployment Phases

### Phase 1: Setup (1 hour)
1. Get all API keys
2. Deploy Supabase database
3. Deploy agent to Railway/Render
4. Configure mobile app

### Phase 2: Testing (2 hours)
1. Build APK/IPA
2. Test on real devices
3. Verify all features work
4. Fix any issues

### Phase 3: Store Submission (4 hours)
1. Prepare screenshots
2. Write descriptions
3. Build signed releases
4. Submit to stores
5. Wait for review (1-7 days)

**Total Time**: 1-2 days of work + review time

---

## 💰 Cost Summary

### One-time
- Google Play: $25
- Apple Developer: $99/year
- **Total**: $124 first year

### Monthly
- Hosting: $5-20
- Database: $0-25
- APIs: $10-50
- **Total**: $15-95/month

**With 100 active users**: ~$50-150/month

---

## 🛠️ Tools You'll Need

### Required
- ✅ Python 3.10+ (for agent)
- ✅ Flutter 3.13+ (for mobile)
- ✅ Git
- ✅ Internet connection

### Optional but Recommended
- Docker (for containerized deployment)
- Mac + Xcode (for iOS deployment)
- Android Studio (for Android testing)

---

## 🔑 API Keys Required

Before deploying, get these API keys:

1. **LiveKit** (https://cloud.livekit.io)
   - API Key
   - API Secret
   - WebSocket URL

2. **Deepgram** (https://console.deepgram.com)
   - API Key

3. **Groq** (https://console.groq.com)
   - API Key

4. **Rime AI** (https://app.rime.ai)
   - API Key

5. **Supabase** (https://supabase.com)
   - Project URL
   - Anon Key
   - Service Role Key (optional)

---

## 📱 What Gets Deployed

### 1. Voice Agent (Backend)
- Runs in the cloud 24/7
- Handles voice AI processing
- Connects to LiveKit, Deepgram, Groq, Rime
- Manages cooking sessions

**Deploy to**: Railway, Render, Fly.io, or Google Cloud Run

### 2. Mobile App (Frontend)
- iOS and Android apps
- Downloaded from app stores
- Connects to your backend
- Beautiful UI for voice cooking

**Deploy to**: Apple App Store & Google Play Store

### 3. Database (Backend)
- Stores user data
- Manages recipes
- Tracks history
- Handles authentication

**Deploy to**: Supabase Cloud

---

## ✅ Pre-Deployment Checklist

Before starting deployment:
- [ ] All code is tested locally
- [ ] Agent runs successfully on your machine
- [ ] Mobile app works in emulator/device
- [ ] Voice sessions work end-to-end
- [ ] All API keys are obtained
- [ ] Git repository is up to date

---

## 🚦 Deployment Status Tracking

Use this to track your progress:

### Agent Deployment
- [ ] Hosting platform chosen
- [ ] Environment variables configured
- [ ] Agent deployed
- [ ] Health check passing
- [ ] Logs accessible

### Mobile App
- [ ] Supabase configured
- [ ] Agent URL configured
- [ ] Icons and splash screens generated
- [ ] APK built (Android)
- [ ] IPA built (iOS - if applicable)

### App Store Submission
- [ ] Screenshots prepared
- [ ] Descriptions written
- [ ] Privacy policy published
- [ ] Submitted to Google Play
- [ ] Submitted to App Store (if applicable)
- [ ] Apps approved and live

---

## 🆘 Getting Help

### Documentation
Start with the guides in this directory.

### Logs
- **Agent**: Check Railway/Render dashboard logs
- **Mobile**: Run `flutter logs`
- **Database**: Check Supabase dashboard

### Common Issues
See DEPLOYMENT_GUIDE.md Troubleshooting section

### Support Channels
- Flutter: https://docs.flutter.dev
- LiveKit: https://docs.livekit.io
- Supabase: https://supabase.com/docs
- Railway: https://docs.railway.app

---

## 🎉 Success!

Once deployed, you'll have:
- ✅ Live voice AI agent running 24/7
- ✅ Mobile apps in app stores
- ✅ Database storing user data
- ✅ Fully functional CookTalk platform

**Congratulations on deploying CookTalk!** 🎊

---

## 📞 Post-Deployment

After going live:
1. Monitor agent uptime
2. Track API usage and costs
3. Gather user feedback
4. Plan feature updates
5. Respond to app reviews
6. Keep dependencies updated

---

**Ready to deploy? Start with [QUICK_DEPLOY.md](./QUICK_DEPLOY.md)!** 🚀
