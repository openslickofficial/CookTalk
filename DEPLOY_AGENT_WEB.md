# Deploy CookTalk Agent via LiveKit Cloud Web Dashboard

## 📋 Prerequisites

- ✅ LiveKit Cloud account with a project created
- ✅ All API keys ready (LiveKit, Deepgram, Groq, Rime)
- ✅ GitHub repository with agent code

---

## 🚀 Deployment Steps

### Step 1: Push Agent Code to GitHub

Make sure your agent code is committed and pushed:

```bash
cd "e:\Hackathon Projects\cooltalk"

# Check status
git status

# Add all agent files
git add agent/

# Commit
git commit -m "Prepare agent for LiveKit Cloud deployment"

# Push to GitHub
git push origin main
```

---

### Step 2: Go to LiveKit Cloud Dashboard

1. **Navigate to**: https://cloud.livekit.io
2. **Login** with your GitHub account
3. **Select your project** (the one you created earlier)

---

### Step 3: Create Agent Worker

1. **Click on "Agents"** in the left sidebar
2. **Click "Create Agent"** button (or "Deploy Agent")
3. You'll see options for deployment

---

### Step 4: Configure Agent Deployment

#### **Option A: Deploy from GitHub (Recommended)**

1. **Connect GitHub**:
   - Click "Deploy from GitHub"
   - Authorize LiveKit to access your repositories
   - Select repository: `cooltalk`
   - Select branch: `main`

2. **Configure Build**:
   - **Root Directory**: `agent`
   - **Dockerfile**: `Dockerfile` (should auto-detect)
   - **Entry Point**: Auto-detected from Dockerfile

3. **Set Environment Variables**:
   Click "Add Environment Variable" for each:

   ```
   LIVEKIT_URL = wss://your-project.livekit.cloud
   LIVEKIT_API_KEY = your_api_key_here
   LIVEKIT_API_SECRET = your_secret_here
   DEEPGRAM_API_KEY = your_deepgram_key
   GROQ_API_KEY = your_groq_key
   RIME_API_KEY = your_rime_key
   ```

   **Important**: Replace with your actual keys!

4. **Configure Resources** (optional):
   - CPU: 1 vCPU (free tier)
   - Memory: 512MB - 1GB
   - Region: Choose closest to India (ap-south-1 or ap-southeast-1)

5. **Click "Deploy"**

---

#### **Option B: Deploy via Docker Image**

If you prefer to build locally first:

1. **Build Docker Image Locally**:
   ```bash
   cd agent
   docker build -t cooltalk-agent .
   docker tag cooltalk-agent:latest your-docker-registry/cooltalk-agent:latest
   docker push your-docker-registry/cooltalk-agent:latest
   ```

2. **In LiveKit Dashboard**:
   - Click "Deploy from Container"
   - Enter image: `your-docker-registry/cooltalk-agent:latest`
   - Add environment variables (same as above)
   - Deploy

---

### Step 5: Monitor Deployment

1. **Wait for Build** (~2-5 minutes):
   - You'll see build logs in real-time
   - Watch for any errors

2. **Check Status**:
   - Status should change to "Running" or "Active"
   - Green indicator means healthy

3. **View Logs**:
   - Click on your agent
   - Go to "Logs" tab
   - You should see: "Agent started successfully" or similar

---

### Step 6: Verify Agent is Working

1. **Check Agent List**:
   - Go to Agents tab
   - You should see your agent listed with status "Active"

2. **Test Connection**:
   - The agent should automatically join rooms when participants connect
   - No manual intervention needed

---

## 🔧 Troubleshooting

### Build Fails

**Check**:
- All files exist in `agent/` directory
- `Dockerfile` is correct
- `requirements.txt` has all dependencies

**Common Issues**:
```bash
# Missing files? Check:
ls agent/
# Should see: agent.py, recipes.json, generated_dishes.json, 
#             fallback_error_24k.wav, requirements.txt, Dockerfile
```

### Agent Won't Start

**Check Environment Variables**:
- All keys are set correctly
- No extra spaces or quotes
- LiveKit URL format: `wss://your-project.livekit.cloud`

**View Logs**:
- Go to Agents → Your Agent → Logs
- Look for error messages

### Agent Not Joining Rooms

**Check**:
- Agent status is "Running"
- Environment variables are correct
- LiveKit URL matches your project

**Test with Web Frontend**:
- Try connecting from web app
- Check if room is created
- Agent should auto-join

---

## ✅ Success Checklist

- [ ] Agent deployed successfully
- [ ] Status shows "Running" or "Active"
- [ ] Logs show no errors
- [ ] Agent appears in agent list
- [ ] Environment variables set
- [ ] Ready to test with web/mobile app

---

## 📝 What Happens Next

Once deployed:

1. **Auto-Scaling**: LiveKit handles multiple sessions automatically
2. **Always On**: Agent stays running (within free tier limits)
3. **Auto-Join**: Agent joins rooms when participants connect
4. **Logs Available**: Monitor via dashboard

---

## 🔄 Updating the Agent

When you make code changes:

1. **Commit and push to GitHub**:
   ```bash
   git add agent/
   git commit -m "Update agent"
   git push
   ```

2. **In Dashboard**:
   - Go to Agents → Your Agent
   - Click "Redeploy" or "Update"
   - New build will start automatically

---

## 💰 Free Tier Notes

- **1,000 agent session minutes/month** = ~100 users @ 10 min each
- **Monitor usage**: Dashboard → Billing → Usage
- **Don't waste on benchmarks** before demos!

---

## 🎯 Your Agent Configuration Summary

```yaml
Name: cooltalk-agent
Repository: github.com/your-username/cooltalk
Directory: agent
Dockerfile: agent/Dockerfile
Entry Point: python agent.py start
Region: ap-south-1 or ap-southeast-1 (closest to India)

Environment Variables:
  - LIVEKIT_URL
  - LIVEKIT_API_KEY
  - LIVEKIT_API_SECRET
  - DEEPGRAM_API_KEY
  - GROQ_API_KEY
  - RIME_API_KEY

Resources:
  - CPU: 1 vCPU
  - Memory: 512MB - 1GB
  - Free Tier: YES
```

---

## 🆘 Need Help?

- LiveKit Docs: https://docs.livekit.io/cloud/agents
- Support: https://livekit.io/support
- Discord: https://livekit.io/discord

---

**Ready to deploy!** 🚀

Once you see "Agent Running" status, come back and we'll move to Step 3: Deploy Web Frontend!
