# Process Expired Account Deletions - Edge Function

This Supabase Edge Function processes expired account deletion requests daily using a **free external cron service**.

## 🚀 Setup Instructions

### 1. Deploy the Edge Function

```bash
# Make sure Supabase CLI is installed
# npm install -g supabase

# Login to Supabase (if not already)
supabase login

# Link to your project (first time only)
supabase link --project-ref YOUR_PROJECT_ID

# Deploy the function
supabase functions deploy process-deletions
```

### 2. Set Environment Variables (Optional Security)

To secure the endpoint, set a secret key:

```bash
# Set a cron secret (generate a random string)
supabase secrets set CRON_SECRET=your-random-secret-here-abc123xyz789
```

### 3. Get Your Function URL

After deployment, your function URL will be:
```
https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions
```

Find your project ID in Supabase Dashboard → Project Settings → General → Reference ID

### 4. Setup Free Cron Job

Choose **ONE** of these free options:

---

#### **Option A: cron-job.org** (Recommended - Most Reliable)

1. Go to https://cron-job.org/en/
2. Sign up for a free account
3. Create a new cron job:
   - **Title**: Process CookTalk Account Deletions
   - **URL**: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions`
   - **Schedule**: Daily at 2:00 AM (or your preferred time)
   - **Request Method**: GET
   - **Headers** (if using CRON_SECRET):
     ```
     X-Cron-Secret: your-random-secret-here-abc123xyz789
     ```
4. Save and enable the cron job

---

#### **Option B: EasyCron** (Free tier: 1 job, every 5 minutes min)

1. Go to https://www.easycron.com/
2. Sign up for free account
3. Create cron job:
   - **URL**: Your function URL
   - **Schedule**: Daily at 2:00 AM
   - **HTTP Method**: GET
   - **Custom Headers** (if using secret):
     ```
     X-Cron-Secret: your-random-secret-here-abc123xyz789
     ```

---

#### **Option C: Render Cron Jobs** (Free tier available)

1. Go to https://render.com/
2. Create a new Cron Job service
3. Configure:
   - **Command**: 
     ```bash
     curl -X GET "https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions" \
       -H "X-Cron-Secret: your-random-secret-here-abc123xyz789"
     ```
   - **Schedule**: `0 2 * * *` (daily at 2 AM)

---

#### **Option D: GitHub Actions** (Free for public repos)

Create `.github/workflows/process-deletions.yml`:

```yaml
name: Process Account Deletions

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:  # Allow manual trigger

jobs:
  process-deletions:
    runs-on: ubuntu-latest
    steps:
      - name: Call Edge Function
        run: |
          curl -X GET "${{ secrets.SUPABASE_FUNCTION_URL }}" \
            -H "X-Cron-Secret: ${{ secrets.CRON_SECRET }}"
```

Add secrets in GitHub repo settings:
- `SUPABASE_FUNCTION_URL`: Your function URL
- `CRON_SECRET`: Your secret key

---

## 🧪 Testing

### Test the Edge Function Manually:

**Without secret:**
```bash
curl https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions
```

**With secret:**
```bash
curl https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions \
  -H "X-Cron-Secret: your-random-secret-here-abc123xyz789"
```

### Check Logs:

```bash
# View function logs
supabase functions logs process-deletions

# Or in Supabase Dashboard:
# Edge Functions → process-deletions → Logs
```

---

## 📊 What It Does

1. Calls `process_expired_deletion_requests()` database function
2. Finds all deletion requests where `scheduled_deletion_at <= NOW()`
3. Permanently deletes the accounts and associated data
4. Marks requests as processed
5. Returns success/failure status

---

## 🔒 Security Notes

- The function uses `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS
- Optional `CRON_SECRET` prevents unauthorized calls
- CORS is enabled for flexibility
- All actions are logged in Supabase Edge Function logs

---

## 🐛 Troubleshooting

**Function not found:**
```bash
# Redeploy
supabase functions deploy process-deletions
```

**Permission errors:**
- Ensure service role key is set (automatic in Supabase)
- Check database function exists: `SELECT * FROM pg_proc WHERE proname = 'process_expired_deletion_requests';`

**Cron not triggering:**
- Verify cron service is active
- Check function URL is correct
- Review cron service logs
- Test function manually with curl

---

## 📝 Notes

- Free cron services typically have 99%+ uptime
- If a day is missed, the next run will catch up
- Consider setting up email notifications in your cron service
- Monitor logs regularly to ensure smooth operation
