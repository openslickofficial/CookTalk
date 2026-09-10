-- Migration: Add favorites field to profiles table
-- Purpose: Store user's favorite dishes as an array of dish IDs
-- Date: 2026-09-08

-- Add favorites column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS favorites TEXT[] DEFAULT '{}';

-- Create index for faster queries on favorites array
CREATE INDEX IF NOT EXISTS idx_profiles_favorites 
ON profiles USING GIN (favorites);

-- Add comment to document the column
COMMENT ON COLUMN profiles.favorites IS 'Array of dish IDs that the user has marked as favorite';

-- Example queries:

-- Get user with their favorites
-- SELECT id, email, full_name, favorites FROM profiles WHERE id = 'user-id';

-- Check if specific dish is in user's favorites
-- SELECT EXISTS(SELECT 1 FROM profiles WHERE id = 'user-id' AND 'dish-id' = ANY(favorites));

-- Add dish to favorites (if not already present)
-- UPDATE profiles 
-- SET favorites = array_append(favorites, 'dish-id')
-- WHERE id = 'user-id' AND NOT ('dish-id' = ANY(favorites));

-- Remove dish from favorites
-- UPDATE profiles 
-- SET favorites = array_remove(favorites, 'dish-id')
-- WHERE id = 'user-id';

-- Get count of favorites for a user
-- SELECT array_length(favorites, 1) as favorite_count FROM profiles WHERE id = 'user-id';
