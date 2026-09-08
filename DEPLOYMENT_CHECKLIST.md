# CookTalk Deployment Checklist

Use this checklist to ensure smooth deployment.

## Pre-Deployment

### API Keys & Services
- [ ] LiveKit account created
- [ ] LiveKit API Key & Secret obtained
- [ ] Deepgram API key obtained
- [ ] Groq API key obtained  
- [ ] Rime TTS API key obtained
- [ ] Supabase project created
- [ ] Supabase URL & keys obtained

### Development Environment
- [ ] Python 3.10+ installed
- [ ] Flutter 3.13+ installed
- [ ] All dependencies tested locally
- [ ] Agent runs successfully locally
- [ ] Mobile app runs on emulator/device
- [ ] Voice sessions work end-to-end

## Database Deployment

- [ ] Supabase project is live
- [ ] Database schema deployed
- [ ] Storage buckets configured (if needed)
- [ ] Row Level Security (RLS) policies configured
- [ ] Test data added (optional)

## Agent Deployment

- [ ] Hosting platform selected (Railway/Render/Fly/GCP)
- [ ] Repository connected to hosting platform
- [ ] Environment variables configured:
  - [ ] LIVEKIT_URL
  - [ ] LIVEKIT_API_KEY
  - [ ] LIVEKIT_API_SECRET
  - [ ] DEEPGRAM_API_KEY
  - [ ] GROQ_API_KEY
  - [ ] RIME_API_KEY
- [ ] Agent deployed successfully
- [ ] Agent URL noted down: `_______________________`
- [ ] Health check endpoint working (if applicable)
- [ ] Logs accessible
- [ ] Test voice session with agent

## Mobile App Configuration

- [ ] Supabase URL updated in code
- [ ] Supabase keys updated in code
- [ ] Agent server URL updated in code
- [ ] App icons generated
- [ ] Splash screens generated
- [ ] App bundle ID set (Android)
- [ ] Bundle identifier set (iOS)

## Android Deployment

- [ ] Keystore generated
- [ ] Signing configuration added
- [ ] APK built successfully
- [ ] APK tested on real device
- [ ] App bundle built for Play Store
- [ ] Google Play Console account created
- [ ] Store listing completed:
  - [ ] App name
  - [ ] Short description
  - [ ] Full description
  - [ ] Screenshots (phone & tablet)
  - [ ] Feature graphic
  - [ ] App icon
  - [ ] Privacy policy URL
  - [ ] Content rating completed
- [ ] App bundle uploaded
- [ ] Internal testing completed
- [ ] Submitted for review

## iOS Deployment

- [ ] Apple Developer account active ($99/year)
- [ ] Mac with Xcode available
- [ ] Development team selected in Xcode
- [ ] Bundle identifier registered
- [ ] Provisioning profiles configured
- [ ] IPA built successfully
- [ ] App Store Connect account set up
- [ ] Store listing completed:
  - [ ] App name
  - [ ] Subtitle
  - [ ] Description
  - [ ] Keywords
  - [ ] Screenshots (all required sizes)
  - [ ] App preview video (optional)
  - [ ] App icon
  - [ ] Privacy policy URL
  - [ ] Content rating completed
- [ ] Build uploaded via Xcode/Transporter
- [ ] TestFlight build available
- [ ] Internal testing completed
- [ ] Submitted for review

## Post-Deployment

### Monitoring
- [ ] Error tracking configured (Sentry/Crashlytics)
- [ ] Analytics configured (Firebase/Mixpanel)
- [ ] Uptime monitoring configured
- [ ] API usage monitoring set up
- [ ] Cost alerts configured

### Documentation
- [ ] README updated with deployment info
- [ ] API documentation updated
- [ ] User guide created
- [ ] Privacy policy updated
- [ ] Terms of service updated

### Testing
- [ ] End-to-end testing completed
- [ ] Authentication flow tested
- [ ] Voice sessions tested
- [ ] Recipe browsing tested
- [ ] Favorites & history tested
- [ ] Profile management tested
- [ ] Dark mode tested
- [ ] Tested on multiple devices
- [ ] Performance acceptable

### Marketing (Optional)
- [ ] App Store Optimization (ASO) completed
- [ ] Social media accounts created
- [ ] Landing page created (if needed)
- [ ] Press kit prepared
- [ ] Launch announcement prepared

## Maintenance Plan

- [ ] Backup strategy defined
- [ ] Update schedule planned
- [ ] Support channel established
- [ ] Bug tracking system set up
- [ ] Feature request process defined
- [ ] CI/CD pipeline considered

## Notes & URLs

**Agent URL**: _______________________

**Supabase Project URL**: _______________________

**Google Play URL**: _______________________

**App Store URL**: _______________________

**Support Email**: _______________________

**Monitoring Dashboard**: _______________________

---

## Quick Reference

### Agent Restart Commands

**Railway**: 
```bash
railway restart
```

**Render**: Dashboard → Manual Deploy

**Fly.io**:
```bash
fly deploy
```

**Google Cloud Run**:
```bash
gcloud run deploy cooltalk-agent
```

### Mobile App Update

**Android**:
```bash
cd mobile
flutter build appbundle --release
# Upload to Play Console
```

**iOS**:
```bash
cd mobile
flutter build ios --release
# Archive and upload via Xcode
```

---

**Deployment Date**: _______________

**Deployed By**: _______________

**Version**: _______________
