// Account management endpoints.
import type { Context } from "hono";
import type { Env } from "../index";

export async function accountMe(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const account = await c.env.DB
    .prepare("SELECT id, email, username, subscription_tier, prestige_max, character_slots, is_founder, created_at_unix FROM accounts WHERE id = ?")
    .bind(accountId)
    .first();
  if (!account) return c.json({ error: "not_found" }, 404);

  const characters = (await c.env.DB
    .prepare("SELECT slot, character_name, class_id, level, prestige, current_zone, current_server_id, saved_at_unix FROM characters WHERE account_id = ? ORDER BY slot")
    .bind(accountId)
    .all()).results;

  return c.json({ account, characters });
}

export async function accountUpdate(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const body = await c.req.json();
  const updates: string[] = [];
  const binds: any[] = [];

  if (body.username) {
    updates.push("username = ?");
    binds.push(body.username);
  }
  if (body.email) {
    updates.push("email = ?");
    binds.push(body.email);
  }
  if (updates.length === 0) return c.json({ error: "no_changes" }, 400);

  binds.push(accountId);
  await c.env.DB.prepare(`UPDATE accounts SET ${updates.join(", ")} WHERE id = ?`)
    .bind(...binds)
    .run();
  return c.json({ ok: true });
}
