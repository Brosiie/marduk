# Marduk API

Cloudflare Workers backend for Marduk. Serves auth, account, characters, parties, friends, worlds, store, leaderboards.

## Quick start

```bash
cd backend
npm install
wrangler login
wrangler d1 create marduk
# paste returned id into wrangler.toml [[d1_databases]].database_id

wrangler kv:namespace create RATE_LIMITS
# paste id into wrangler.toml

wrangler r2 bucket create marduk-saves

wrangler d1 execute marduk --file=migrations/0001_init.sql

wrangler secret put JWT_SECRET            # 64-byte hex
wrangler secret put ARGON2_PEPPER         # 32-byte hex
wrangler secret put STRIPE_API_KEY
wrangler secret put STRIPE_WEBHOOK_SECRET

npm run dev          # local development on http://localhost:8787
npm run deploy       # ship to Cloudflare
```

## Architecture

- **Hono** router for endpoints
- **D1** (SQLite) for persistent state
- **KV** for rate limits (sliding window)
- **R2** for save blobs > 1KB
- **PBKDF2-SHA256** for password hashing (200K iterations + server pepper)
- **JWT HS256** for short-lived auth tokens (1h)
- **Random 32-byte hex refresh tokens** stored in D1, revocable

See `../CLOUDFLARE_DEPLOY.md` for full deploy contract.
