// JWT issuance and validation. HS256, 1-hour TTL for auth tokens.
// Refresh tokens are random 32-byte hex strings stored in D1 (revocable).
import { sign, verify } from "@tsndr/cloudflare-worker-jwt";
import type { Context } from "hono";

const AUTH_TOKEN_TTL_SECONDS = 3600;

export async function issueAuthToken(secret: string, accountId: string, issuer: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return await sign(
    {
      sub: accountId,
      iss: issuer,
      iat: now,
      exp: now + AUTH_TOKEN_TTL_SECONDS,
    },
    secret
  );
}

export async function verifyAuthToken(secret: string, token: string): Promise<string | null> {
  try {
    const valid = await verify(token, secret);
    if (!valid) return null;
    const decoded = JSON.parse(atob(token.split(".")[1]));
    if (decoded.exp < Math.floor(Date.now() / 1000)) return null;
    return decoded.sub as string;
  } catch {
    return null;
  }
}

export async function createRefreshToken(db: D1Database, accountId: string, ttlDays: number): Promise<string> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const token = Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
  const issued = Math.floor(Date.now() / 1000);
  const expires = issued + ttlDays * 86400;
  await db.prepare(`INSERT INTO refresh_tokens (token, account_id, issued_at_unix, expires_at_unix) VALUES (?, ?, ?, ?)`)
    .bind(token, accountId, issued, expires)
    .run();
  return token;
}

export async function validateRefreshToken(db: D1Database, token: string): Promise<string | null> {
  const row = await db.prepare(`SELECT account_id, expires_at_unix, revoked FROM refresh_tokens WHERE token = ?`)
    .bind(token).first();
  if (!row) return null;
  if (row.revoked) return null;
  if ((row.expires_at_unix as number) < Math.floor(Date.now() / 1000)) return null;
  return row.account_id as string;
}

export async function revokeRefreshToken(db: D1Database, accountId: string): Promise<void> {
  await db.prepare(`UPDATE refresh_tokens SET revoked = 1 WHERE account_id = ?`)
    .bind(accountId).run();
}

export async function authMiddleware(c: Context<any>, next: any) {
  const authz = c.req.header("Authorization");
  if (!authz || !authz.startsWith("Bearer ")) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const accountId = await verifyAuthToken(c.env.JWT_SECRET, authz.substring(7));
  if (!accountId) return c.json({ error: "unauthorized" }, 401);
  c.set("account_id", accountId);
  await next();
}
