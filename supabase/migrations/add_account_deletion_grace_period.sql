-- Migration: Add 7-Day Account Deletion Grace Period
-- Purpose: Implement soft deletion with 7-day grace period per user request

-- 1. Create table to track deletion requests
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_deletion_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    reason TEXT,
    cancelled_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)  -- Only one active deletion request per user
);

-- 2. Add deletion_scheduled_at to profiles for quick checks
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS deletion_scheduled_at TIMESTAMPTZ;

-- 3. Create index for performance
CREATE INDEX IF NOT EXISTS idx_deletion_requests_scheduled 
    ON public.account_deletion_requests(scheduled_deletion_at) 
    WHERE cancelled_at IS NULL AND processed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_deletion_scheduled 
    ON public.profiles(deletion_scheduled_at) 
    WHERE deletion_scheduled_at IS NOT NULL;

-- 4. RLS Policies for deletion requests table
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Users can view their own deletion request
CREATE POLICY "Users can view own deletion request" 
    ON public.account_deletion_requests FOR SELECT 
    USING (auth.uid() = user_id);

-- Users can insert their own deletion request
CREATE POLICY "Users can request account deletion" 
    ON public.account_deletion_requests FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Users can update (cancel) their own deletion request
CREATE POLICY "Users can cancel own deletion request" 
    ON public.account_deletion_requests FOR UPDATE 
    USING (auth.uid() = user_id);

-- 5. Function to request account deletion
CREATE OR REPLACE FUNCTION public.request_account_deletion(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_scheduled_at TIMESTAMPTZ;
    v_request_id UUID;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    -- Calculate scheduled deletion time (7 days from now)
    v_scheduled_at := NOW() + INTERVAL '7 days';
    
    -- Insert or update deletion request
    INSERT INTO public.account_deletion_requests (user_id, scheduled_deletion_at, reason)
    VALUES (p_user_id, v_scheduled_at, p_reason)
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        scheduled_deletion_at = v_scheduled_at,
        requested_at = NOW(),
        reason = COALESCE(EXCLUDED.reason, account_deletion_requests.reason),
        cancelled_at = NULL,  -- Reset cancellation if re-requesting
        processed_at = NULL
    RETURNING id INTO v_request_id;
    
    -- Update profile with scheduled deletion time
    UPDATE public.profiles 
    SET deletion_scheduled_at = v_scheduled_at 
    WHERE id = p_user_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'scheduled_deletion_at', v_scheduled_at,
        'days_remaining', 7
    );
END;
$$;

-- 6. Function to cancel account deletion
CREATE OR REPLACE FUNCTION public.cancel_account_deletion(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if deletion request exists
    IF NOT EXISTS (
        SELECT 1 FROM public.account_deletion_requests 
        WHERE user_id = p_user_id 
        AND cancelled_at IS NULL 
        AND processed_at IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No active deletion request found'
        );
    END IF;
    
    -- Mark as cancelled
    UPDATE public.account_deletion_requests 
    SET cancelled_at = NOW() 
    WHERE user_id = p_user_id 
    AND cancelled_at IS NULL 
    AND processed_at IS NULL;
    
    -- Clear scheduled deletion from profile
    UPDATE public.profiles 
    SET deletion_scheduled_at = NULL 
    WHERE id = p_user_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Account deletion cancelled successfully'
    );
END;
$$;

-- 7. Function to check deletion status
CREATE OR REPLACE FUNCTION public.get_deletion_status(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_days_remaining NUMERIC;
    v_hours_remaining NUMERIC;
BEGIN
    -- Get active deletion request
    SELECT * INTO v_request
    FROM public.account_deletion_requests
    WHERE user_id = p_user_id
    AND cancelled_at IS NULL
    AND processed_at IS NULL
    ORDER BY requested_at DESC
    LIMIT 1;
    
    -- No active deletion request
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'deletion_scheduled', false
        );
    END IF;
    
    -- Calculate remaining time
    v_days_remaining := EXTRACT(EPOCH FROM (v_request.scheduled_deletion_at - NOW())) / 86400;
    v_hours_remaining := EXTRACT(EPOCH FROM (v_request.scheduled_deletion_at - NOW())) / 3600;
    
    RETURN jsonb_build_object(
        'deletion_scheduled', true,
        'request_id', v_request.id,
        'requested_at', v_request.requested_at,
        'scheduled_deletion_at', v_request.scheduled_deletion_at,
        'days_remaining', GREATEST(0, CEIL(v_days_remaining)),
        'hours_remaining', GREATEST(0, CEIL(v_hours_remaining)),
        'can_cancel', true,
        'reason', v_request.reason
    );
END;
$$;

-- 8. Function to process expired deletion requests (called by cron job)
CREATE OR REPLACE FUNCTION public.process_expired_deletion_requests()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT := 0;
    v_user_record RECORD;
BEGIN
    -- Find all expired deletion requests
    FOR v_user_record IN
        SELECT adr.id, adr.user_id, p.email
        FROM public.account_deletion_requests adr
        JOIN public.profiles p ON p.id = adr.user_id
        WHERE adr.scheduled_deletion_at <= NOW()
        AND adr.cancelled_at IS NULL
        AND adr.processed_at IS NULL
    LOOP
        -- Delete user data (cascading will handle related records)
        BEGIN
            -- Mark as processed first
            UPDATE public.account_deletion_requests 
            SET processed_at = NOW() 
            WHERE id = v_user_record.id;
            
            -- Delete from profiles (cascades to other tables)
            DELETE FROM public.profiles WHERE id = v_user_record.user_id;
            
            -- Delete from auth.users (if using Supabase auth)
            -- Note: This may require admin privileges or service role
            -- DELETE FROM auth.users WHERE id = v_user_record.user_id;
            
            v_deleted_count := v_deleted_count + 1;
            
            RAISE NOTICE 'Deleted account for user: % (email: %)', 
                v_user_record.user_id, v_user_record.email;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to delete account for user %: %', 
                v_user_record.user_id, SQLERRM;
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'deleted_count', v_deleted_count,
        'processed_at', NOW()
    );
END;
$$;

-- 9. Create a cron job to process deletions daily (requires pg_cron extension)
-- Note: This requires Supabase Pro plan or manual setup
-- Uncomment if pg_cron is available:
/*
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'process-expired-account-deletions',
    '0 2 * * *',  -- Run daily at 2 AM UTC
    $$SELECT public.process_expired_deletion_requests()$$
);
*/

-- 10. Trigger to auto-cancel deletion on user login
CREATE OR REPLACE FUNCTION public.auto_cancel_deletion_on_login()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If user has scheduled deletion and logs in, auto-cancel it
    IF EXISTS (
        SELECT 1 FROM public.account_deletion_requests
        WHERE user_id = NEW.id
        AND cancelled_at IS NULL
        AND processed_at IS NULL
    ) THEN
        PERFORM public.cancel_account_deletion(NEW.id);
        
        RAISE NOTICE 'Auto-cancelled account deletion for user % due to login', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger on profiles table when updated_at changes (indicating activity)
DROP TRIGGER IF EXISTS auto_cancel_deletion_on_activity ON public.profiles;
CREATE TRIGGER auto_cancel_deletion_on_activity
    AFTER UPDATE OF updated_at ON public.profiles
    FOR EACH ROW
    WHEN (OLD.updated_at IS DISTINCT FROM NEW.updated_at)
    EXECUTE FUNCTION public.auto_cancel_deletion_on_login();

-- 11. Add helpful comments
COMMENT ON TABLE public.account_deletion_requests IS 
    '7-day grace period for account deletion. Users can cancel within 7 days or by logging in.';

COMMENT ON COLUMN public.account_deletion_requests.scheduled_deletion_at IS 
    'Automatic deletion will occur after this timestamp (7 days from request)';

COMMENT ON FUNCTION public.request_account_deletion IS 
    'Request account deletion with 7-day grace period. Returns scheduled deletion time.';

COMMENT ON FUNCTION public.cancel_account_deletion IS 
    'Cancel a pending account deletion request. Automatically called on user login.';

COMMENT ON FUNCTION public.process_expired_deletion_requests IS 
    'Process and delete accounts with expired grace periods. Should be called by cron job daily.';
