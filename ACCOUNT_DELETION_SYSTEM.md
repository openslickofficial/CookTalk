# CookTalk Account Deletion System - 7-Day Grace Period

## 🎯 Overview

Implements Apple App Store & Google Play compliant account deletion with a 7-day grace period, allowing users to change their mind.

## 🔄 User Flow

```
User Requests Deletion
        ↓
Scheduled for 7 days
        ↓
   Grace Period
        ↓
┌──────────────────┐
│  Two Scenarios:  │
└──────────────────┘
        ↓
    ┌───┴───┐
    │       │
    ↓       ↓
User Logs In    7 Days Pass
    ↓           ↓
Auto-Cancel   Cron Job
    ↓           ↓
Account Kept  Account Deleted
```

## 📋 Components

### 1. Database Layer
- **Table**: `account_deletion_requests`
  - Tracks all deletion requests
  - Stores reason, timestamps
  
- **Functions**:
  - `request_account_deletion(user_id, reason)` - Schedules deletion
  - `cancel_account_deletion(user_id)` - Cancels deletion
  - `get_deletion_status(user_id)` - Returns countdown info
  - `process_expired_deletion_requests()` - Deletes expired accounts

- **Trigger**: `auto_cancel_deletion_on_activity`
  - Fires on `profiles.updated_at` change
  - Automatically cancels deletion when user logs in

### 2. Mobile App (Flutter)
- **Service**: `SupabaseService`
  - `requestAccountDeletion({reason})`
  - `cancelAccountDeletion()`
  - `getDeletionStatus()`

- **UI**: `AccountDeletionScreen`
  - Request screen with optional reason
  - Cancellation screen with countdown
  - Auto-detects deletion status

### 3. Automation (Free Cron)
- **Edge Function**: `process-deletions`
  - Deployed to Supabase
  - Called by external cron service
  - Processes expired deletions daily

- **Cron Service**: cron-job.org (free)
  - Triggers daily at 2 AM
  - Zero cost, reliable
  - Email notifications on failure

## 🚀 Setup (5 Minutes)

### Quick Start:

```bash
# 1. Apply database migration
cd supabase
supabase db push

# 2. Deploy edge function
supabase functions deploy process-deletions

# 3. Setup free cron job at cron-job.org
# URL: https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions
# Schedule: Daily at 2 AM
```

**Detailed instructions**: See `supabase/setup-deletion-cron.md`

## 🧪 Testing

```bash
# Test edge function
curl https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-deletions

# Test in SQL Editor
# See: supabase/test-deletion-flow.sql
```

## 🔒 Security Features

- ✅ RLS policies on deletion requests table
- ✅ Optional cron secret for edge function
- ✅ Service role key required for deletion processing
- ✅ Audit trail (all requests logged)
- ✅ Soft delete before hard delete

## 📊 Monitoring

### Database Queries:

```sql
-- Pending deletions
SELECT * FROM account_deletion_requests 
WHERE cancelled_at IS NULL AND processed_at IS NULL;

-- Deletion statistics
SELECT 
  COUNT(*) FILTER (WHERE cancelled_at IS NULL AND processed_at IS NULL) as pending,
  COUNT(*) FILTER (WHERE cancelled_at IS NOT NULL) as cancelled,
  COUNT(*) FILTER (WHERE processed_at IS NOT NULL) as completed
FROM account_deletion_requests;
```

### Edge Function Logs:

```bash
supabase functions logs process-deletions --tail
```

Or in Supabase Dashboard: **Edge Functions → process-deletions → Logs**

## 🎨 User Experience

### Request Screen:
- Clear 7-day grace period badge
- Optional reason field
- "DELETE" confirmation required
- Success dialog with countdown

### Cancellation Screen:
- Large countdown timer
- Big green "Cancel & Keep Account" button
- Auto-shows if deletion already scheduled
- Clear deletion date/time

### Auto-Cancel:
- Silent - happens in background
- User sees normal request screen next visit
- Logged in `cancelled_at` timestamp

## 💰 Cost: $0/month

- ✅ Supabase Edge Functions: Free tier
- ✅ Cron-job.org: Free forever
- ✅ Database functions: No cost
- ✅ Alternative: GitHub Actions (free)

## 📚 File Reference

```
supabase/
├── migrations/
│   └── add_account_deletion_grace_period.sql    # Database schema
├── functions/
│   └── process-deletions/
│       ├── index.ts                              # Edge function
│       └── README.md                             # Detailed docs
├── setup-deletion-cron.md                        # Quick setup guide
└── test-deletion-flow.sql                        # Test queries

mobile/lib/
├── services/
│   └── supabase_service.dart                     # Deletion methods
└── screens/
    └── account_deletion_screen.dart              # UI (request + cancel)
```

## ✅ Compliance

- ✅ **Apple App Store**: 
  - Account deletion in-app ✓
  - Delete Account in user settings ✓
  - Links to web deletion (not required if in-app) ✓

- ✅ **Google Play**:
  - Account deletion accessible ✓
  - Clear process ✓
  - User-initiated ✓

- ✅ **GDPR**:
  - Right to erasure ✓
  - Grace period (allows correction) ✓
  - Complete data deletion ✓
  - Audit trail ✓

## 🐛 Troubleshooting

### Edge function 404:
```bash
supabase functions deploy process-deletions
```

### Cron not running:
- Check cron-job.org dashboard
- Verify URL is correct
- Test with curl manually

### Database errors:
```sql
-- Check migration applied
SELECT * FROM pg_tables WHERE tablename = 'account_deletion_requests';

-- Check function exists
SELECT * FROM pg_proc WHERE proname = 'process_expired_deletion_requests';
```

## 📞 Support

- **Setup Issues**: See `supabase/setup-deletion-cron.md`
- **Edge Function**: See `supabase/functions/process-deletions/README.md`
- **Testing**: See `supabase/test-deletion-flow.sql`

---

**Status**: ✅ Ready for production
**Last Updated**: September 8, 2026
