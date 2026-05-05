# Marduk Backend on Cloudflare

The server side of Marduk's account system runs on Cloudflare's free tier:
- **Workers** for the auth + character sync API
- **D1** (SQLite) for the persistent database
- **Pages** for the marketing site + launcher download
- **R2** (object storage) for character save blobs > 1KB

This doc is the deploy contract. It pairs with `scripts/auth/auth_client.gd` on the
Godot side; whatever this doc says the API does, that file expects.

## Architecture

```
┌─────────────────┐       HTTPS/JSON       ┌──────────────────┐
│  Godot client   │ ─────────────────────▶ │ Cloudflare       │
│  (PC + mobile)  │                        │ Worker @ api.    │
└─────────────────┘                        │ marduk.game      │
       │                                   └────────┬─────────┘
       │                                            │
       │                          ┌─────────────────┼─────────────────┐
       │                          ▼                 ▼                 ▼
       │                       ┌─────┐         ┌─────────┐      ┌──────┐
       │                       │ D1  │         │ Workers │      │  R2  │
       │                       │ DB  │         │   KV    │      │ blob │
       │                       └─────┘         └─────────┘      └──────┘
       │
       └── downloads launcher from marduk.game (Pages, separate worker)
```

## API endpoints

Base URL: `https://api.marduk.game`. Local dev: `http://localhost:8787` (Wrangler dev).

### Auth
```
POST /v1/auth/register
  body: { email, username, password }
  -> 201 { account, auth_token, refresh_token, expires_at }

POST /v1/auth/login
  body: { email_or_username, password }
  -> 200 { account, auth_token, refresh_token, expires_at }

POST /v1/auth/refresh
  body: { refresh_token }
  -> 200 { auth_token, expires_at }

POST /v1/auth/logout
  header: Authorization: Bearer <auth_token>
  -> 204
```

### Account
```
GET /v1/account/me
  header: Authorization: Bearer <auth_token>
  -> 200 { account, characters: [...] }

POST /v1/account/update
  header: Authorization: Bearer <auth_token>
  body: { username?, email?, password? (with current) }
  -> 200 { account }
```

### Characters
```
GET /v1/characters
  -> 200 { characters: [{slot, character_name, class_id, level, prestige, current_zone, saved_at_iso}, ...] }

POST /v1/characters/sync
  body: { slot, save_blob: <base64-or-json> }
  -> 200 { ok: true, saved_at_iso }
  Notes: blobs > 1KB go to R2 (worker stores key, fetches on read).

DELETE /v1/characters/:slot
  -> 200 { ok: true }
```

### Leaderboards
```
GET /v1/leaderboards/prestige
  -> 200 { entries: [{username, prestige, title, country?}, ...] }

GET /v1/leaderboards/speed/:boss_id
  -> 200 { entries: [{username, seconds, title, achieved_at}, ...] }

POST /v1/leaderboards/speed/submit
  body: { boss_id, seconds, replay_hash }
  -> 200 { rank, percentile }
```

### Worlds / Servers
```
GET /v1/worlds/list
  -> 200 { worlds: [{server_id, display_name, region, current_players, max_players, status, is_pvp}] }

POST /v1/worlds/join
  body: { server_id, character_id }
  -> 200 { ok: true, websocket_url }
  -> 409 { error: "world_full" }

POST /v1/worlds/transfer
  body: { from_server, to_server, character_id }
  Cooldown: 24h per character.
  -> 200 { ok: true, transfer_completes_at_unix }
  -> 429 { error: "transfer_cooldown" }
```

### Party
```
POST /v1/party/create     {} -> { party_id, leader_id }
POST /v1/party/invite     { target_account_id }
POST /v1/party/accept     { party_id }
POST /v1/party/decline    { party_id }
POST /v1/party/leave      {} -> 204
POST /v1/party/kick       { account_id } -- leader only
GET  /v1/party/me         -> { party }
POST /v1/party/lfg/list   { class_filter, level_min, level_max } -> { open_parties: [...] }
POST /v1/party/lfg/post   { name, requirements } -> { ok }
```

### Friends / Block
```
POST /v1/friends/add        { target_account_id, note? } -> 200
POST /v1/friends/remove     { target_account_id } -> 204
GET  /v1/friends/list       -> { friends: [{account_id, username, online, current_zone, level}] }
POST /v1/blocks/add         { target_account_id, reason? } -> 200
POST /v1/blocks/remove      { target_account_id } -> 204
GET  /v1/blocks/list        -> { blocks: [...] }
```

### Store (real-money purchases via Stripe)
```
GET /v1/store/catalog                        -> { mounts: [...], pets: [...], cosmetics: [...] }
POST /v1/store/purchase/initiate
  body: { sku_id }
  -> { stripe_session_url }   (redirect player; on success backend webhook fires)

POST /v1/store/webhook/stripe
  Stripe webhook endpoint. Verifies signature, grants ownership flag on success.

GET  /v1/store/inventory                     -> { owned_mounts: [...], owned_pets: [...], owned_cosmetics: [...] }
```

## D1 schema

```sql
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,                    -- UUID
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,            -- bcrypt or argon2
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  prestige_max INTEGER NOT NULL DEFAULT 0,
  character_slots INTEGER NOT NULL DEFAULT 6,
  created_at_unix INTEGER NOT NULL,
  last_seen_unix INTEGER NOT NULL,
  email_verified INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE refresh_tokens (
  token TEXT PRIMARY KEY,                 -- random 32-byte hex
  account_id TEXT NOT NULL REFERENCES accounts(id),
  issued_at_unix INTEGER NOT NULL,
  expires_at_unix INTEGER NOT NULL,
  device_id TEXT,
  revoked INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE characters (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  slot INTEGER NOT NULL,
  character_name TEXT NOT NULL,
  class_id TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  prestige INTEGER NOT NULL DEFAULT 0,
  current_zone TEXT,
  blob_key TEXT,                          -- R2 key if blob > 1KB; NULL if inline
  blob_inline TEXT,                       -- JSON for small saves
  saved_at_unix INTEGER NOT NULL,
  UNIQUE(account_id, slot)
);

CREATE TABLE leaderboard_speed (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  boss_id TEXT NOT NULL,
  seconds REAL NOT NULL,
  replay_hash TEXT,
  achieved_at_unix INTEGER NOT NULL
);

CREATE INDEX idx_speed_boss ON leaderboard_speed(boss_id, seconds);
CREATE INDEX idx_chars_account ON characters(account_id);
```

## Worker code structure

```
backend/
├── wrangler.toml          # bindings to D1 / KV / R2
├── src/
│   ├── index.ts           # router
│   ├── auth/
│   │   ├── register.ts
│   │   ├── login.ts
│   │   ├── refresh.ts
│   │   └── logout.ts
│   ├── account/
│   │   ├── me.ts
│   │   └── update.ts
│   ├── characters/
│   │   ├── list.ts
│   │   ├── sync.ts
│   │   └── delete.ts
│   ├── leaderboards/
│   │   ├── prestige.ts
│   │   ├── speed.ts
│   │   └── submit.ts
│   ├── lib/
│   │   ├── jwt.ts         # HS256, 1-hour auth tokens
│   │   ├── password.ts    # argon2id via @phc/argon2
│   │   ├── rate_limit.ts  # KV-backed sliding window
│   │   └── audit.ts       # logging
│   └── types.ts
└── package.json
```

## Wrangler config (sketch)

```toml
name = "marduk-api"
main = "src/index.ts"
compatibility_date = "2026-05-05"

[[d1_databases]]
binding = "DB"
database_name = "marduk"
database_id = "<paste from `wrangler d1 create marduk`>"

[[kv_namespaces]]
binding = "RATE_LIMITS"
id = "<paste from `wrangler kv:namespace create RATE_LIMITS`>"

[[r2_buckets]]
binding = "SAVES"
bucket_name = "marduk-saves"

[vars]
JWT_ISSUER = "marduk.game"
ALLOWED_ORIGINS = "https://marduk.game,https://app.marduk.game"

# secrets (set via `wrangler secret put`)
# JWT_SECRET
# ARGON2_PEPPER
```

## Deploy steps

```bash
# 1. Fork the repo, clone the backend
git clone https://github.com/Brosiie/marduk.git
cd marduk/backend

# 2. Install Wrangler and dependencies
npm install -g wrangler
npm install

# 3. Create the D1 database
wrangler d1 create marduk
# paste the printed id into wrangler.toml [[d1_databases]].database_id

# 4. Run the schema migration
wrangler d1 execute marduk --file=migrations/0001_init.sql

# 5. Create KV namespace for rate limits
wrangler kv:namespace create RATE_LIMITS

# 6. Create R2 bucket for save blobs
wrangler r2 bucket create marduk-saves

# 7. Set secrets
wrangler secret put JWT_SECRET            # 64-byte random hex
wrangler secret put ARGON2_PEPPER         # 32-byte random hex

# 8. Deploy the worker
wrangler deploy

# 9. Configure custom domain
wrangler triggers put api.marduk.game

# 10. Pages site (separate)
cd ../site
wrangler pages deploy dist --project-name=marduk-site
```

## Rate limits

- `POST /v1/auth/login`: 5 attempts per 5 minutes per IP, 10 per hour per email
- `POST /v1/auth/register`: 3 per hour per IP
- `POST /v1/characters/sync`: 60 per minute per account
- `POST /v1/leaderboards/speed/submit`: 10 per hour per account, replay verification required

## Cost (estimated)

Cloudflare free tier should cover ~10K monthly active accounts:
- Workers: 100K requests/day free
- D1: 5GB storage + 100K reads/day free
- KV: 100K reads/day free
- R2: 10GB storage free, no egress fees

Beyond that, paid Workers tier ($5/mo) covers significantly more. Marduk being free + open-source means cost stays low even at scale.

## Launcher

A separate Tauri or Electron app downloads the latest Godot build, manages updates,
and signs in to the Cloudflare API on launch. Source lives in `launcher/` (Phase 2).

## Open Source + Donations

Marduk is **MIT licensed** and free to play. The launcher prompts for an optional
$1 donation on first login per day (skippable, "never show" available). Donations
flow through Ko-fi (https://ko-fi.com/marduk_game). All code on this repo is
public; modifications are welcome via PR.
