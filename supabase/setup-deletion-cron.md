# Quick Setup Guide: Account Deletion Grace Period with Free Cron

## Step-by-Step Setup (5 minutes)

### ✅ Step 1: Apply Database Migration

```bash
cd supabase
supabase db push
```

This creates:
- `account_deletion_requests` table
- Database functions for deletion management
- Auto-cancel trigger on login
- RLS policies

---

### ✅ Step 2: Deploy Edge Function

```bash
# Deploy the edge function
supabase functions deploy process-deletions
```

After deployment, you'll get a URL like:
```
https://abcdefghij.supabase.co/functions/v1/process-deletions
```

**Copy this URL** - you'll need it for Step 3!

---

### ✅ Step 3: Setup Free Cron Job

#### **Option 1: cron-job.org** (Recommended - Easiest)

1. **Sign up**: https://cron-job.org/en/signup
   - Free forever
   - No credit card required
   - Reliable service

2. **Create Cron Job**:
   - Click "Create Cron Job"
   - **Title**: `CookTalk Delete Expired Accounts`
   - **URL**: Paste your function URL from Step 2
   - **Execution Schedule**: 
     - Select "Every day"
     - Time: `02:00` (2 AM)
     - Timezone: Your preferred timezone
   - **Request Method**: `GET`
   - Click "Create"

3. **Done!** ✅ Your cron job is now active

---

#### **Option 2: GitHub Actions** (If you have a GitHub repo)

1. Create `.github/workflows/process-deletions.yml` in your repo:

```yaml
name: Process Account Deletions Daily

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:  # Manual trigger button

jobs:
  process:
    runs-on: ubuntu-latest
    steps:
      - name: Process Expired Deletions
        run: |
          curl -f https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions || exit 1
```

2. Replace `YOUR_PROJECT_ID` with your actual project ID

3. Commit and push - GitHub will run it daily automatically

---

### ✅ Step 4: Test Everything

#### 4.1 Test Edge Function:

```bash
# Test the function manually
curl https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions
```

Expected response:
```json
{
  "success": true,
  "message": "Deletion processing completed",
  "result": {...}
}
```

#### 4.2 Test Full Flow:

1. **Request Deletion**:
   - Open CookTalk mobile app
   - Go to Profile → Delete Account
   - Type "DELETE" and confirm
   - Should see "Deletion Scheduled" screen

2. **Check Database**:
   ```sql
   -- In Supabase SQL Editor
   SELECT * FROM account_deletion_requests;
   SELECT deletion_scheduled_at FROM profiles WHERE id = 'YOUR_USER_ID';
   ```

3. **Test Auto-Cancel on Login**:
   - Log out of the app
   - Log back in
   - Check deletion screen - should show request form (not countdown)
   - Database: `cancelled_at` should be set

4. **Test Manual Cancel**:
   - Request deletion again
   - In app, go to Delete Account screen
   - Click "Cancel Deletion & Keep My Account"
   - Should see success message

---

## 🔐 Optional: Add Security (Recommended)

### Generate a Secret Key:

```bash
# Generate a random secret (copy this)
openssl rand -hex 32
```

### Set it in Supabase:

```bash
# Set the secret
supabase secrets set CRON_SECRET=paste-your-generated-secret-here
```

### Update Your Cron Job:

In cron-job.org (or your chosen service):
- Click "Edit" on your cron job
- Add **Custom Headers**:
  ```
  X-Cron-Secret: paste-your-generated-secret-here
  ```
- Save

Now only requests with the correct secret will work! 🔒

---

## 📊 Monitoring

### View Edge Function Logs:

```bash
supabase functions logs process-deletions --tail
```

Or in Supabase Dashboard:
- Go to **Edge Functions** → **process-deletions** → **Logs**

### Check Cron Job Status:

- **cron-job.org**: Dashboard shows execution history
- **GitHub Actions**: Go to Actions tab in your repo
- **Render**: Check cron job logs in dashboard

---

## 🎉 You're Done!

Your account deletion system is now fully operational:

- ✅ Users can request account deletion
- ✅ 7-day grace period is enforced
- ✅ Auto-cancellation on login
- ✅ Daily cron job processes expired accounts
- ✅ Completely free infrastructure

---

## 🆘 Troubleshooting

**Edge function not working:**
```bash
# Check if it's deployed
supabase functions list

# Redeploy if needed
supabase functions deploy process-deletions
```

**Cron job not running:**
- Verify URL is correct
- Check cron service is enabled
- Review execution logs
- Test function manually with curl

**Database errors:**
- Ensure migration was applied: `supabase db pull`
- Check function exists: 
  ```sql
  SELECT * FROM pg_proc WHERE proname = 'process_expired_deletion_requests';
  ```

---

## 📞 Need Help?

Check the detailed README:
```
supabase/functions/process-deletions/README.md
```
