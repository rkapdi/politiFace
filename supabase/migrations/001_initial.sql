-- ============================================================================
-- Politiface: Initial Schema Migration
-- Run via: supabase db push
-- ============================================================================

-- ── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- GOVERNMENT GRAPH LAYER
-- ============================================================================

CREATE TABLE countries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        CHAR(2) UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  flag_emoji  TEXT NOT NULL,
  is_active   BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE governments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id          UUID REFERENCES countries(id) UNIQUE,
  formal_name         TEXT NOT NULL,
  system_type         TEXT NOT NULL,
  map_building_name   TEXT,
  map_building_icon   TEXT,
  map_accent_color    TEXT,
  constitution_year   INTEGER,
  notes               TEXT,
  is_active           BOOLEAN DEFAULT false,
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE gov_nodes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  government_id       UUID REFERENCES governments(id),
  external_id         TEXT NOT NULL,
  name                TEXT NOT NULL,
  short_name          TEXT,
  description         TEXT,
  node_type           TEXT NOT NULL,
  is_head_of_state    BOOLEAN DEFAULT false,
  is_head_of_govt     BOOLEAN DEFAULT false,
  is_elected          BOOLEAN,
  map_x               NUMERIC(6,3),
  map_y               NUMERIC(6,3),
  map_width           NUMERIC(6,3),
  map_height          NUMERIC(6,3),
  map_shape           TEXT DEFAULT 'rectangle',
  map_icon            TEXT,
  map_color           TEXT,
  map_label_position  TEXT DEFAULT 'bottom',
  tier_order          INTEGER NOT NULL,
  unlock_requires     UUID[] DEFAULT '{}',
  is_active           BOOLEAN DEFAULT true,
  sort_order          INTEGER DEFAULT 0,
  UNIQUE(government_id, external_id)
);

CREATE TABLE gov_edges (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  government_id       UUID REFERENCES governments(id),
  from_node_id        UUID REFERENCES gov_nodes(id),
  to_node_id          UUID REFERENCES gov_nodes(id),
  relationship_type   TEXT NOT NULL,
  description         TEXT,
  is_visible_on_map   BOOLEAN DEFAULT true,
  line_style          TEXT DEFAULT 'solid',
  line_color          TEXT,
  arrow_direction     TEXT DEFAULT 'to',
  UNIQUE(from_node_id, to_node_id, relationship_type)
);

CREATE TABLE node_concepts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id         UUID REFERENCES gov_nodes(id),
  language_code   TEXT DEFAULT 'en',
  concept_title   TEXT NOT NULL,
  concept_body    TEXT NOT NULL,
  sort_order      INTEGER DEFAULT 0
);

-- ============================================================================
-- CONTENT LAYER
-- ============================================================================

CREATE TABLE decks (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id               UUID REFERENCES gov_nodes(id),
  government_id         UUID REFERENCES governments(id),
  external_id           TEXT UNIQUE NOT NULL,
  name                  TEXT NOT NULL,
  description           TEXT,
  tier_order            INTEGER NOT NULL DEFAULT 0,
  is_premium            BOOLEAN DEFAULT false,
  is_community_deck     BOOLEAN DEFAULT false,
  contributor_github    TEXT,
  status                TEXT DEFAULT 'draft',
  card_count            INTEGER DEFAULT 0,
  last_verified_at      TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE cards (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_id           UUID REFERENCES decks(id) ON DELETE CASCADE,
  external_id       TEXT UNIQUE NOT NULL,
  politician_name   TEXT NOT NULL,
  photo_url         TEXT,
  photo_source_url  TEXT,
  lqip_base64       TEXT,
  title             TEXT NOT NULL,
  party             TEXT,
  jurisdiction      TEXT,
  in_office_since   DATE,
  in_office_until   DATE,
  is_active         BOOLEAN DEFAULT true,
  content_hash      TEXT,
  tags              TEXT[] DEFAULT '{}',
  source_url        TEXT NOT NULL,
  last_verified_at  TIMESTAMPTZ NOT NULL,
  sort_order        INTEGER DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE card_content (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id         UUID REFERENCES cards(id) ON DELETE CASCADE,
  language_code   TEXT DEFAULT 'en',
  one_liner       TEXT,
  extended_bio    TEXT,
  UNIQUE(card_id, language_code)
);

-- ============================================================================
-- USER AND PROGRESS LAYER
-- ============================================================================

CREATE TABLE user_profiles (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name          TEXT,
  avatar_url            TEXT,
  streak_count          INTEGER DEFAULT 0,
  streak_freeze_tokens  INTEGER DEFAULT 0,
  last_active_date      DATE,
  xp_total              BIGINT DEFAULT 0,
  level                 INTEGER DEFAULT 1,
  cards_mastered_count  INTEGER DEFAULT 0,
  is_pro                BOOLEAN DEFAULT false,
  pro_expires_at        TIMESTAMPTZ,
  country_preference    CHAR(2) DEFAULT 'US',
  analytics_opt_in      BOOLEAN DEFAULT false,
  fsrs_weights          JSONB,
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_map_progress (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES user_profiles(id),
  government_id   UUID REFERENCES governments(id),
  node_id         UUID REFERENCES gov_nodes(id),
  status          TEXT DEFAULT 'locked',
  unlocked_at     TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  UNIQUE(user_id, node_id)
);

-- Server-side reviews (partitioned by hash on user_id)
CREATE TABLE reviews (
  id              UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL,
  card_id         UUID NOT NULL,
  device_id       TEXT NOT NULL,
  reviewed_at     TIMESTAMPTZ NOT NULL,
  result          TEXT NOT NULL CHECK (result IN ('pass', 'fail', 'hint')),
  ease_factor     NUMERIC(4,2) NOT NULL DEFAULT 2.5,
  interval_days   INTEGER NOT NULL DEFAULT 1,
  next_review_at  TIMESTAMPTZ NOT NULL,
  session_id      UUID,
  synced_at       TIMESTAMPTZ DEFAULT now()
) PARTITION BY HASH(user_id);

-- 16 hash partitions — distributes load evenly regardless of time
CREATE TABLE reviews_p0  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 0);
CREATE TABLE reviews_p1  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 1);
CREATE TABLE reviews_p2  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 2);
CREATE TABLE reviews_p3  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 3);
CREATE TABLE reviews_p4  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 4);
CREATE TABLE reviews_p5  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 5);
CREATE TABLE reviews_p6  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 6);
CREATE TABLE reviews_p7  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 7);
CREATE TABLE reviews_p8  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 8);
CREATE TABLE reviews_p9  PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 9);
CREATE TABLE reviews_p10 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 10);
CREATE TABLE reviews_p11 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 11);
CREATE TABLE reviews_p12 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 12);
CREATE TABLE reviews_p13 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 13);
CREATE TABLE reviews_p14 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 14);
CREATE TABLE reviews_p15 PARTITION OF reviews FOR VALUES WITH (MODULUS 16, REMAINDER 15);

-- ── Daily challenge ───────────────────────────────────────────────────────────
CREATE TABLE daily_challenges (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_date  DATE UNIQUE NOT NULL,
  card_ids        UUID[] NOT NULL,
  share_template  TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE daily_challenge_results (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES user_profiles(id),
  challenge_date  DATE NOT NULL,
  card_results    JSONB NOT NULL,
  score           INTEGER NOT NULL,
  share_text      TEXT NOT NULL,
  completed_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, challenge_date)
);

-- ── Leagues ──────────────────────────────────────────────────────────────────
CREATE TABLE leagues (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  tier        INTEGER NOT NULL,
  week_start  DATE NOT NULL,
  week_end    DATE NOT NULL,
  is_private  BOOLEAN DEFAULT false,
  invite_code TEXT UNIQUE,
  max_members INTEGER DEFAULT 30
);

CREATE TABLE league_members (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  league_id     UUID REFERENCES leagues(id),
  user_id       UUID REFERENCES user_profiles(id),
  xp_this_week  INTEGER DEFAULT 0,
  rank          INTEGER,
  joined_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE(league_id, user_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Cards: deck lookup and tag search
CREATE INDEX idx_cards_deck     ON cards(deck_id) WHERE is_active = true;
CREATE INDEX idx_cards_external ON cards(external_id);
CREATE INDEX idx_cards_tags     ON cards USING GIN(tags);

-- Decks
CREATE INDEX idx_decks_node ON decks(node_id) WHERE status = 'published';

-- Gov nodes
CREATE INDEX idx_nodes_government ON gov_nodes(government_id) WHERE is_active = true;
CREATE INDEX idx_nodes_external   ON gov_nodes(external_id);

-- User map progress
CREATE INDEX idx_map_progress_user ON user_map_progress(user_id);

-- Daily challenge
CREATE INDEX idx_challenge_date   ON daily_challenges(challenge_date);
CREATE INDEX idx_challenge_results ON daily_challenge_results(user_id, challenge_date);

-- Leagues
CREATE INDEX idx_league_members_xp ON league_members(league_id, xp_this_week DESC);

-- Reviews (applied to each partition automatically)
CREATE INDEX idx_reviews_user_next ON reviews(user_id, next_review_at)
  WHERE next_review_at <= (now() + INTERVAL '7 days');

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Public read: content tables
ALTER TABLE countries         ENABLE ROW LEVEL SECURITY;
ALTER TABLE governments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE gov_nodes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE gov_edges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE node_concepts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE decks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards             ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_content      ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_challenges  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "countries_public_read"     ON countries       FOR SELECT USING (true);
CREATE POLICY "governments_public_read"   ON governments     FOR SELECT USING (is_active = true);
CREATE POLICY "nodes_public_read"         ON gov_nodes       FOR SELECT USING (is_active = true);
CREATE POLICY "edges_public_read"         ON gov_edges       FOR SELECT USING (true);
CREATE POLICY "concepts_public_read"      ON node_concepts   FOR SELECT USING (true);
CREATE POLICY "decks_public_read"         ON decks           FOR SELECT USING (status = 'published');
CREATE POLICY "cards_public_read"         ON cards           FOR SELECT USING (is_active = true);
CREATE POLICY "card_content_public_read"  ON card_content    FOR SELECT USING (true);
CREATE POLICY "challenges_public_read"    ON daily_challenges FOR SELECT USING (true);

-- Private: user data
ALTER TABLE user_profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_map_progress         ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_challenge_results   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_profile"    ON user_profiles
  USING (auth.uid() = id);
CREATE POLICY "users_insert_profile" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "users_own_progress"   ON user_map_progress
  USING (auth.uid() = user_id);
CREATE POLICY "users_own_reviews"    ON reviews
  USING (auth.uid() = user_id);
CREATE POLICY "users_insert_reviews" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_own_challenge_results" ON daily_challenge_results
  USING (auth.uid() = user_id);

-- Leagues: members see their own leagues
ALTER TABLE leagues        ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "leagues_public_read" ON leagues
  FOR SELECT USING (true);
CREATE POLICY "league_members_read" ON league_members
  FOR SELECT USING (
    league_id IN (
      SELECT league_id FROM league_members WHERE user_id = auth.uid()
    )
  );
CREATE POLICY "league_members_insert" ON league_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Keep deck card_count accurate
CREATE OR REPLACE FUNCTION update_deck_card_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE decks SET card_count = (
    SELECT COUNT(*) FROM cards
    WHERE deck_id = COALESCE(NEW.deck_id, OLD.deck_id)
    AND is_active = true
  ), updated_at = now()
  WHERE id = COALESCE(NEW.deck_id, OLD.deck_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_deck_card_count
AFTER INSERT OR UPDATE OR DELETE ON cards
FOR EACH ROW EXECUTE FUNCTION update_deck_card_count();

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update cards.updated_at on change (watermark sync depends on this)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cards_updated_at
BEFORE UPDATE ON cards
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER decks_updated_at
BEFORE UPDATE ON decks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
