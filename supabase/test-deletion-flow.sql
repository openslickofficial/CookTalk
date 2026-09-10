-- Test Script: Account Deletion Grace Period Flow
-- Run this in Supabase SQL Editor to test the deletion system

-- ============================================
-- TEST 1: Request Account Deletion
-- ============================================

-- Replace 'YOUR_USER_ID' with an actual user ID from your profiles table
SELECT request_account_deletion(
  'YOUR_USER_ID'::uuid,
  'Testing the grace period'
);

-- Expected result: JSON with success=true, scheduled_deletion_at, days_remaining=7


-- ============================================
-- TEST 2: Check Deletion Status
-- ============================================

SELECT get_deletion_status('YOUR_USER_ID'::uuid);

-- Expected result: JSON with deletion_scheduled=true, days_remaining, hours_remaining


-- ============================================
-- TEST 3: View Deletion Request
-- ============================================

SELECT * FROM account_deletion_requests 
WHERE user_id = 'YOUR_USER_ID'::uuid;

-- Should show: requested_at, scheduled_deletion_at (7 days from now), cancelled_at=NULL


-- ============================================
-- TEST 4: Cancel Account Deletion
-- ============================================

SELECT cancel_account_deletion('YOUR_USER_ID'::uuid);

-- Expected result: JSON with success=true


-- ============================================
-- TEST 5: Verify Cancellation
-- ============================================

SELECT * FROM account_deletion_requests 
WHERE user_id = 'YOUR_USER_ID'::uuid;

-- Should show: cancelled_at is now set to current timestamp


SELECT get_deletion_status('YOUR_USER_ID'::uuid);

-- Expected result: JSON with deletion_scheduled=false


-- ============================================
-- TEST 6: Test Auto-Cancel Trigger (Simulate Login)
-- ============================================

-- Request deletion again
SELECT request_account_deletion('YOUR_USER_ID'::uuid, 'Testing auto-cancel');

-- Simulate user login by updating profile
UPDATE profiles 
SET updated_at = NOW() 
WHERE id = 'YOUR_USER_ID'::uuid;

-- Check if deletion was auto-cancelled
SELECT * FROM account_deletion_requests 
WHERE user_id = 'YOUR_USER_ID'::uuid
ORDER BY requested_at DESC 
LIMIT 1;

-- Should show: cancelled_at is set (auto-cancelled by trigger)


-- ============================================
-- TEST 7: Process Expired Deletions (Manual Test)
-- ============================================

-- Create a test account with expired deletion (backdated)
-- WARNING: This will actually delete the test account!

-- First, create or use a test user
-- Then request deletion with backdated time:
INSERT INTO account_deletion_requests (user_id, requested_at, scheduled_deletion_at)
VALUES (
  'YOUR_TEST_USER_ID'::uuid,
  NOW() - INTERVAL '8 days',  -- 8 days ago
  NOW() - INTERVAL '1 day'    -- Expired 1 day ago
);

-- Process expired deletions
SELECT process_expired_deletion_requests();

-- Expected result: JSON with deleted_count >= 1

-- Verify the test account was deleted
SELECT * FROM profiles WHERE id = 'YOUR_TEST_USER_ID'::uuid;
-- Should return no rows (deleted)


-- ============================================
-- CLEANUP: Remove Test Data
-- ============================================

-- Delete test deletion requests
DELETE FROM account_deletion_requests 
WHERE user_id = 'YOUR_USER_ID'::uuid;

-- Reset profile
UPDATE profiles 
SET deletion_scheduled_at = NULL 
WHERE id = 'YOUR_USER_ID'::uuid;


-- ============================================
-- USEFUL QUERIES FOR MONITORING
-- ============================================

-- View all pending deletions
SELECT 
  u.email,
  p.display_name,
  dr.requested_at,
  dr.scheduled_deletion_at,
  EXTRACT(DAY FROM (dr.scheduled_deletion_at - NOW())) as days_remaining,
  dr.reason
FROM account_deletion_requests dr
JOIN auth.users u ON dr.user_id = u.id
JOIN profiles p ON dr.user_id = p.id
WHERE dr.cancelled_at IS NULL 
  AND dr.processed_at IS NULL
ORDER BY dr.scheduled_deletion_at;


-- View cancelled deletions
SELECT 
  u.email,
  dr.requested_at,
  dr.cancelled_at,
  EXTRACT(HOUR FROM (dr.cancelled_at - dr.requested_at)) as hours_before_cancel
FROM account_deletion_requests dr
JOIN auth.users u ON dr.user_id = u.id
WHERE dr.cancelled_at IS NOT NULL
ORDER BY dr.cancelled_at DESC
LIMIT 10;


-- View processed (completed) deletions
SELECT 
  dr.user_id,
  dr.requested_at,
  dr.processed_at,
  dr.reason
FROM account_deletion_requests dr
WHERE dr.processed_at IS NOT NULL
ORDER BY dr.processed_at DESC
LIMIT 10;


-- Count deletion statistics
SELECT 
  COUNT(*) FILTER (WHERE cancelled_at IS NULL AND processed_at IS NULL) as pending_deletions,
  COUNT(*) FILTER (WHERE cancelled_at IS NOT NULL) as cancelled_deletions,
  COUNT(*) FILTER (WHERE processed_at IS NOT NULL) as completed_deletions,
  COUNT(*) as total_requests
FROM account_deletion_requests;
