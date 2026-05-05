// Auth endpoints: register / login / refresh / logout.
import type { Context } from "hono";
import type { Env } from "../index";
import { hashPassword, verifyPassword } from "../lib/password";
import { issueAuthToken, createRefreshToken, revokeRefreshToken, validateRefreshToken } from "../lib/jwt";
import { rateLimit } from "../lib/rate_limit";

const REFRESH_TTL_DAYS = 30;

function uuid(): string {
  // Simple v4-ish; for production use crypto.randomUUID()
  return crypto.randomUUID();
}

export async function register(c: Context<{ Bindings: Env }>) {
  const body = await c.req.json();
  const { email, username, password } = body;
  if (!email || !username || !password || password.length < 8) {
    return c.json({ error: "invalid_input" }, 400);
  }

  // Rate limit by IP
  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  if (!(await rateLimit(c.env.RATE_LIMITS, `register:${ip}`, 3, 3600))) {
    return c.json({ error: "rate_limit" }, 429);
  }

  // Uniqueness check
  const dup = await c.env.DB
    .prepare("SELECT id FROM accounts WHERE email = ? OR username = ?")
    .bind(email, username)
    .first();
  if (dup) return c.json({ error: "email_or_username_taken" }, 409);

  const accountId = uuid();
  const hash = await hashPassword(password, c.env.ARGON2_PEPPER);
  const now = Math.floor(Date.now() / 1000);

  await c.env.DB
    .prepare(`INSERT INTO accounts
      (id, email, username, password_hash, created_at_unix, last_seen_unix)
      VALUES (?, ?, ?, ?, ?, ?)`)
    .bind(accountId, email, username, hash, now, now)
    .run();

  return issueSession(c, accountId, email, username);
}

export async function login(c: Context<{ Bindings: Env }>) {
  const body = await c.req.json();
  const { email_or_username, password } = body;
  if (!email_or_username || !password) {
    return c.json({ error: "invalid_input" }, 400);
  }

  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  if (!(await rateLimit(c.env.RATE_LIMITS, `login:${ip}`, 5, 300))) {
    return c.json({ error: "rate_limit" }, 429);
  }

  const row = await c.env.DB
    .prepare("SELECT id, email, username, password_hash, subscription_tier, prestige_max, character_slots, created_at_unix, is_founder FROM accounts WHERE email = ? OR username = ?")
    .bind(email_or_username, email_or_username)
    .first();

  if (!row) return c.json({ error: "invalid_credentials" }, 401);

  const ok = await verifyPassword(password, row.password_hash as string, c.env.ARGON2_PEPPER);
  if (!ok) return c.json({ error: "invalid_credentials" }, 401);

  await c.env.DB
    .prepare("UPDATE accounts SET last_seen_unix = ? WHERE id = ?")
    .bind(Math.floor(Date.now() / 1000), row.id)
    .run();

  return issueSession(c, row.id as string, row.email as string, row.username as string, row);
}

export async function refresh(c: Context<{ Bindings: Env }>) {
  const { refresh_token } = await c.req.json();
  const accountId = await validateRefreshToken(c.env.DB, refresh_token);
  if (!accountId) return c.json({ error: "invalid_refresh" }, 401);

  const auth_token = await issueAuthToken(c.env.JWT_SECRET, accountId, c.env.JWT_ISSUER);
  return c.json({ auth_token, expires_at: Math.floor(Date.now() / 1000) + 3600 });
}

export async function logout(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  await revokeRefreshToken(c.env.DB, accountId);
  return c.body(null, 204);
}

async function issueSession(c: Context<{ Bindings: Env }>, accountId: string, email: string, username: string, row?: any) {
  const auth_token = await issueAuthToken(c.env.JWT_SECRET, accountId, c.env.JWT_ISSUER);
  const refresh_token = await createRefreshToken(c.env.DB, accountId, REFRESH_TTL_DAYS);
  const now = Math.floor(Date.now() / 1000);

  const characters = (await c.env.DB
    .prepare("SELECT slot, character_name, class_id, level, prestige, current_zone, saved_at_unix FROM characters WHERE account_id = ? ORDER BY slot")
    .bind(accountId)
    .all()).results;

  return c.json({
    account: {
      id: accountId,
      email,
      username,
      subscription_tier: row?.subscription_tier ?? "free",
      prestige_max: row?.prestige_max ?? 0,
      character_slots: row?.character_slots ?? 6,
      is_founder: row?.is_founder ? true : false,
      created_at_unix: row?.created_at_unix ?? now,
    },
    auth_token,
    refresh_token,
    expires_at: now + 3600,
    characters,
  });
}
