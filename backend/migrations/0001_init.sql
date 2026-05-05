-- Marduk D1 schema, initial migration.
-- Run via: wrangler d1 execute marduk --file=migrations/0001_init.sql

CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  prestige_max INTEGER NOT NULL DEFAULT 0,
  character_slots INTEGER NOT NULL DEFAULT 6,
  created_at_unix INTEGER NOT NULL,
  last_seen_unix INTEGER NOT NULL,
  email_verified INTEGER NOT NULL DEFAULT 0,
  is_founder INTEGER NOT NULL DEFAULT 0,
  current_server_id TEXT
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  token TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  issued_at_unix INTEGER NOT NULL,
  expires_at_unix INTEGER NOT NULL,
  device_id TEXT,
  revoked INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS characters (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  slot INTEGER NOT NULL,
  character_name TEXT NOT NULL,
  class_id TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  prestige INTEGER NOT NULL DEFAULT 0,
  current_zone TEXT,
  current_server_id TEXT,
  blob_key TEXT,
  blob_inline TEXT,
  saved_at_unix INTEGER NOT NULL,
  UNIQUE(account_id, slot)
);

CREATE TABLE IF NOT EXISTS leaderboard_speed (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  boss_id TEXT NOT NULL,
  seconds REAL NOT NULL,
  replay_hash TEXT,
  achieved_at_unix INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS friends (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  friend_account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  added_at_unix INTEGER NOT NULL,
  note TEXT,
  PRIMARY KEY (account_id, friend_account_id)
);

CREATE TABLE IF NOT EXISTS blocks (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  blocked_account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  blocked_at_unix INTEGER NOT NULL,
  reason TEXT,
  PRIMARY KEY (account_id, blocked_account_id)
);

CREATE TABLE IF NOT EXISTS parties (
  id TEXT PRIMARY KEY,
  leader_account_id TEXT NOT NULL REFERENCES accounts(id),
  loot_mode TEXT NOT NULL DEFAULT 'round_robin',
  open_to_join INTEGER NOT NULL DEFAULT 0,
  name_for_lfg TEXT,
  created_at_unix INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS party_members (
  party_id TEXT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  joined_at_unix INTEGER NOT NULL,
  PRIMARY KEY (party_id, account_id)
);

CREATE TABLE IF NOT EXISTS store_purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  sku_id TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  stripe_session_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending / paid / refunded
  created_at_unix INTEGER NOT NULL,
  paid_at_unix INTEGER
);

CREATE TABLE IF NOT EXISTS owned_cosmetics (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  sku_id TEXT NOT NULL,
  granted_at_unix INTEGER NOT NULL,
  PRIMARY KEY (account_id, sku_id)
);

CREATE INDEX IF NOT EXISTS idx_speed_boss ON leaderboard_speed(boss_id, seconds);
CREATE INDEX IF NOT EXISTS idx_chars_account ON characters(account_id);
CREATE INDEX IF NOT EXISTS idx_purchases_account ON store_purchases(account_id);
