-- ==============================================================================
-- CookTalk Database Schema (Supabase / PostgreSQL)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USER PROFILES TABLE (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT DEFAULT 'Chef',
    avatar_url TEXT DEFAULT 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    favorite_cuisines TEXT[] DEFAULT ARRAY[]::TEXT[],
    cooking_frequency TEXT DEFAULT 'A few times a week',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. DISHES / RECIPES CATALOG TABLE
CREATE TABLE IF NOT EXISTS public.dishes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('breakfast', 'lunch', 'dinner', 'snack', 'cuisine', 'smoothies', 'dessert', 'more')),
    cuisine TEXT NOT NULL,
    prep_time_minutes INT NOT NULL DEFAULT 15,
    cook_time_minutes INT NOT NULL DEFAULT 20,
    servings INT NOT NULL DEFAULT 2,
    difficulty TEXT NOT NULL DEFAULT 'Easy' CHECK (difficulty IN ('Easy', 'Medium', 'Hard')),
    image_url TEXT NOT NULL,
    is_trending BOOLEAN DEFAULT FALSE,
    ingredients JSONB NOT NULL DEFAULT '[]'::jsonb,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    substitutions JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. COOKING HISTORY / SESSIONS TABLE
CREATE TABLE IF NOT EXISTS public.cooking_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE SET NULL,
    dish_title TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    current_step INT DEFAULT 1,
    total_steps INT DEFAULT 1,
    duration_seconds INT DEFAULT 0,
    notes TEXT,
    metrics JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. FAVORITE DISHES TABLE
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    dish_id UUID NOT NULL REFERENCES public.dishes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, dish_id)
);

-- ==============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cooking_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view and update their own profile
CREATE POLICY "Public profiles are viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Dishes: Anyone can read dishes; only admins can modify
CREATE POLICY "Dishes are viewable by everyone" 
    ON public.dishes FOR SELECT USING (true);

-- Cooking History: Users can view, insert, update their own history
CREATE POLICY "Users can view own cooking history" 
    ON public.cooking_history FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own cooking history" 
    ON public.cooking_history FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cooking history" 
    ON public.cooking_history FOR UPDATE USING (auth.uid() = user_id);

-- Favorites: Users can manage their own favorites
CREATE POLICY "Users can view own favorites" 
    ON public.favorites FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites" 
    ON public.favorites FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites" 
    ON public.favorites FOR DELETE USING (auth.uid() = user_id);

-- ==============================================================================
-- 7. AUTH TRIGGER (Auto-create profile upon Google OAuth signup)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url, onboarding_completed)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Samantha'),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80'),
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 8. SEED DATA (Populating Catalog with Matching UI Photography)
-- ==============================================================================

INSERT INTO public.dishes (slug, title, description, category, cuisine, prep_time_minutes, cook_time_minutes, difficulty, image_url, is_trending, ingredients, steps, substitutions)
VALUES 
(
    'steamed-dimsum-dumplings',
    'Steamed Pork & Shrimp Dumplings',
    'Delicate, juicy Cantonese dim sum dumplings steamed in bamboo baskets with ginger scallion dipping sauce.',
    'snack',
    'Asian',
    25,
    15,
    'Medium',
    'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=800&q=80',
    TRUE,
    '[
        {"name": "dumpling wrappers", "quantity": "24", "unit": "pieces"},
        {"name": "ground pork", "quantity": "300", "unit": "g"},
        {"name": "shrimp minced", "quantity": "150", "unit": "g"},
        {"name": "sesame oil", "quantity": "1", "unit": "tbsp"},
        {"name": "green onion", "quantity": "2", "unit": "stalks"},
        {"name": "ginger grated", "quantity": "1", "unit": "tsp"}
    ]'::jsonb,
    '[
        {"step": 1, "instruction": "In a mixing bowl, combine ground pork, minced shrimp, ginger, scallions, and sesame oil."},
        {"step": 2, "instruction": "Place one teaspoon of filling into the center of each wrapper."},
        {"step": 3, "instruction": "Wet edges with water and pleat firmly to seal the dumpling tightly."},
        {"step": 4, "instruction": "Arrange dumplings in a lined steamer basket without touching."},
        {"step": 5, "instruction": "Steam over high boiling water for 10 to 12 minutes until cooked through."}
    ]'::jsonb,
    '{"pork": "Ground chicken or firm pressed tofu with shiitake mushrooms."}'::jsonb
),
(
    'smoky-bbq-grilled-chicken',
    'Smoky Flame-Grilled BBQ Chicken',
    'Tender chicken thighs basted in rich homemade smoky barbecue glaze with charred herbs.',
    'dinner',
    'American',
    15,
    30,
    'Easy',
    'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=800&q=80',
    TRUE,
    '[
        {"name": "chicken thighs", "quantity": "4", "unit": "pieces"},
        {"name": "bbq sauce", "quantity": "0.5", "unit": "cup"},
        {"name": "smoked paprika", "quantity": "1", "unit": "tsp"},
        {"name": "garlic powder", "quantity": "1", "unit": "tsp"},
        {"name": "olive oil", "quantity": "2", "unit": "tbsp"}
    ]'::jsonb,
    '[
        {"step": 1, "instruction": "Pat chicken dry with paper towels and season with paprika, garlic powder, salt, and pepper."},
        {"step": 2, "instruction": "Preheat grill or grill pan to medium-high heat (around 400 degrees)."},
        {"step": 3, "instruction": "Grill chicken for 6 to 8 minutes per side until nicely charred."},
        {"step": 4, "instruction": "Brush generously with BBQ sauce on both sides during the final 4 minutes."},
        {"step": 5, "instruction": "Rest for 5 minutes before serving with extra sauce."}
    ]'::jsonb,
    '{"bbq sauce": "Honey mustard glaze or chimichurri for a fresh herb profile."}'::jsonb
),
(
    'pancakes',
    'Golden Fluffy Buttermilk Pancakes',
    'Classic diner-style pancakes with golden crisp edges, pillow-soft centers, and warm maple butter.',
    'breakfast',
    'American',
    10,
    15,
    'Easy',
    'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
    TRUE,
    '[
        {"name": "all-purpose flour", "quantity": "2", "unit": "cups"},
        {"name": "buttermilk", "quantity": "1.75", "unit": "cups"},
        {"name": "eggs", "quantity": "2", "unit": "large"},
        {"name": "melted butter", "quantity": "3", "unit": "tbsp"},
        {"name": "baking powder", "quantity": "2", "unit": "tsp"},
        {"name": "sugar", "quantity": "2", "unit": "tbsp"}
    ]'::jsonb,
    '[
        {"step": 1, "instruction": "Whisk dry ingredients together in a large bowl: flour, baking powder, baking soda, sugar, and salt."},
        {"step": 2, "instruction": "Pour wet ingredients into dry: buttermilk, eggs, melted butter. Whisk gently until just combined with small lumps."},
        {"step": 3, "instruction": "Preheat griddle to 350 degrees F and brush lightly with butter."},
        {"step": 4, "instruction": "Pour 1/3 cup batter per pancake. Cook 2-3 minutes until bubbles form on surface and edges look set."},
        {"step": 5, "instruction": "Flip carefully and cook 1-2 minutes more until golden brown on both sides."}
    ]'::jsonb,
    '{"buttermilk": "1 cup whole milk + 1 tbsp white vinegar or lemon juice. Let sit 5 minutes."}'::jsonb
),
(
    'classic-carbonara',
    'Traditional Roman Carbonara',
    'Silky Roman pasta with crispy guanciale, pecorino romano, fresh egg yolks, and coarse black pepper.',
    'dinner',
    'Italian',
    10,
    15,
    'Medium',
    'https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=800&q=80',
    FALSE,
    '[
        {"name": "spaghetti", "quantity": "400", "unit": "g"},
        {"name": "guanciale or pancetta", "quantity": "150", "unit": "g"},
        {"name": "egg yolks", "quantity": "4", "unit": "large"},
        {"name": "pecorino romano", "quantity": "80", "unit": "g"},
        {"name": "black pepper", "quantity": "1", "unit": "tbsp"}
    ]'::jsonb,
    '[
        {"step": 1, "instruction": "Bring a large pot of salted water to boil. Cook spaghetti until al dente."},
        {"step": 2, "instruction": "Crisp diced guanciale in a skillet over medium heat until golden; set aside rendering."},
        {"step": 3, "instruction": "Whisk egg yolks, grated Pecorino, and freshly cracked black pepper in a bowl into a thick paste."},
        {"step": 4, "instruction": "Transfer hot pasta into the skillet off the heat, stir in the egg mixture rapidly with starchy pasta water to form a glossy sauce."},
        {"step": 5, "instruction": "Serve immediately topped with crispy guanciale and extra pecorino."}
    ]'::jsonb,
    '{"guanciale": "Pancetta or thick-cut smoked bacon."}'::jsonb
),
(
    'tropical-green-smoothie',
    'Mango Pineapple Energy Smoothie',
    'Vibrant tropical smoothie packed with ripe mango, sweet pineapple, baby spinach, and coconut water.',
    'smoothies',
    'Healthy',
    5,
    5,
    'Easy',
    'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=800&q=80',
    FALSE,
    '[
        {"name": "frozen mango", "quantity": "1", "unit": "cup"},
        {"name": "pineapple chunks", "quantity": "0.5", "unit": "cup"},
        {"name": "baby spinach", "quantity": "1", "unit": "handful"},
        {"name": "coconut water", "quantity": "1", "unit": "cup"},
        {"name": "chia seeds", "quantity": "1", "unit": "tbsp"}
    ]'::jsonb,
    '[
        {"step": 1, "instruction": "Add coconut water, spinach, mango, and pineapple into blender."},
        {"step": 2, "instruction": "Blend on high speed for 60 seconds until completely silky smooth."},
        {"step": 3, "instruction": "Pour into chilled glass and sprinkle chia seeds on top."}
    ]'::jsonb,
    '{"coconut water": "Almond milk, oat milk, or freshly squeezed orange juice."}'::jsonb
)
ON CONFLICT (slug) DO NOTHING;
