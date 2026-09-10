-- Migration: Add user_id to dishes table for ownership tracking
-- Date: 2024-01-XX
-- Purpose: Track which user created each dish (AI-generated dishes)

-- Add user_id column
ALTER TABLE public.dishes 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_dishes_user_id ON public.dishes(user_id);

-- Update RLS policies to allow users to manage their own dishes

-- Allow users to update their own AI-generated dishes
CREATE POLICY "Users can update own ai_generated dishes" 
    ON public.dishes FOR UPDATE 
    USING (auth.uid() = user_id AND source = 'ai_generated');

-- Allow users to delete their own AI-generated dishes
CREATE POLICY "Users can delete own ai_generated dishes" 
    ON public.dishes FOR DELETE 
    USING (auth.uid() = user_id AND source = 'ai_generated');

-- Update the insert policy to require user_id
DROP POLICY IF EXISTS "Authenticated users can insert dishes" ON public.dishes;

CREATE POLICY "Authenticated users can insert dishes with their user_id" 
    ON public.dishes FOR INSERT 
    WITH CHECK (
        auth.role() = 'authenticated' 
        AND auth.uid() = user_id
    );

-- Add comment for documentation
COMMENT ON COLUMN public.dishes.user_id IS 
    'User who created this dish. NULL for curated/verified dishes, required for ai_generated dishes.';
