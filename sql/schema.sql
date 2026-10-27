-- ==============================================================================
-- COUNTER WAR - SUPABASE POSTGRESQL SCHEMA (PHASE 1)
-- ==============================================================================
-- Run this script in the Supabase SQL Editor to set up:
-- 1. Profiles table (linked to auth.users)
-- 2. Stage scores table (records high scores, accuracy, fastest times)
-- 3. Row Level Security (RLS) policies
-- 4. Automatic user profile creation trigger on signup
-- 5. Helper function & trigger to update profile total/highest score on stage completion
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    current_stage INT NOT NULL DEFAULT 1 CHECK (current_stage >= 1),
    total_score BIGINT NOT NULL DEFAULT 0 CHECK (total_score >= 0),
    highest_score BIGINT NOT NULL DEFAULT 0 CHECK (highest_score >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_profiles_total_score ON public.profiles(total_score DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_highest_score ON public.profiles(highest_score DESC);

-- 3. STAGE PROGRESS / SCORES TABLE
CREATE TABLE IF NOT EXISTS public.stage_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stage_id INT NOT NULL CHECK (stage_id >= 1),
    high_score INT NOT NULL DEFAULT 0 CHECK (high_score >= 0),
    accuracy REAL NOT NULL DEFAULT 0.0 CHECK (accuracy >= 0.0 AND accuracy <= 100.0),
    fastest_time REAL NOT NULL DEFAULT 0.0 CHECK (fastest_time >= 0.0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_user_stage UNIQUE (user_id, stage_id)
);

-- Index for querying user stage records
CREATE INDEX IF NOT EXISTS idx_stage_scores_user ON public.stage_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_stage_scores_stage ON public.stage_scores(stage_id);

-- 4. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stage_scores ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES FOR PROFILES
-- Anyone authenticated or public can read all profiles (required for global leaderboard)
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles 
FOR SELECT 
USING (true);

-- Authenticated users can insert their own profile
CREATE POLICY "Users can insert their own profile" 
ON public.profiles 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);

-- Authenticated users can update only their own profile
CREATE POLICY "Users can update their own profile" 
ON public.profiles 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 6. RLS POLICIES FOR STAGE SCORES
-- Stage scores are viewable by everyone (for stage rankings / stats)
CREATE POLICY "Stage scores are viewable by everyone" 
ON public.stage_scores 
FOR SELECT 
USING (true);

-- Authenticated users can insert scores for themselves
CREATE POLICY "Users can insert their own stage scores" 
ON public.stage_scores 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Authenticated users can update their own stage scores
CREATE POLICY "Users can update their own stage scores" 
ON public.stage_scores 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 7. TRIGGER: AUTO-CREATE PROFILE ON AUTH SIGNUP
-- Automatically extracts username from raw_user_meta_data or sets default
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    extracted_username TEXT;
BEGIN
    extracted_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        'Operative_' || SUBSTRING(NEW.id::TEXT, 1, 8)
    );

    INSERT INTO public.profiles (id, username, current_stage, total_score, highest_score)
    VALUES (
        NEW.id,
        extracted_username,
        1,
        0,
        0
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 8. TRIGGER / FUNCTION: RECALCULATE TOTAL SCORE AND CURRENT STAGE PROGRESS
CREATE OR REPLACE FUNCTION public.sync_profile_aggregates()
RETURNS TRIGGER AS $$
DECLARE
    calculated_total BIGINT;
    max_score BIGINT;
    max_unlocked_stage INT;
BEGIN
    -- Calculate sum of all stage high scores and peak high score for this user
    SELECT 
        COALESCE(SUM(high_score), 0),
        COALESCE(MAX(high_score), 0)
    INTO calculated_total, max_score
    FROM public.stage_scores
    WHERE user_id = NEW.user_id;

    -- Calculate unlocked stage (if beaten stage N, stage N+1 is unlocked)
    SELECT COALESCE(MAX(stage_id) + 1, 1)
    INTO max_unlocked_stage
    FROM public.stage_scores
    WHERE user_id = NEW.user_id AND high_score > 0;

    -- Update profile aggregates
    UPDATE public.profiles
    SET 
        total_score = calculated_total,
        highest_score = GREATEST(highest_score, max_score),
        current_stage = GREATEST(current_stage, max_unlocked_stage),
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to sync profile aggregates whenever stage score is inserted or updated
DROP TRIGGER IF EXISTS on_stage_score_modified ON public.stage_scores;
CREATE TRIGGER on_stage_score_modified
    AFTER INSERT OR UPDATE ON public.stage_scores
    FOR EACH ROW EXECUTE FUNCTION public.sync_profile_aggregates();
