import type { Context } from "hono";
import type { Env } from "../index";

export async function friendsAdd(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { target_account_id, note } = await c.req.json();
  const now = Math.floor(Date.now() / 1000);
  await c.env.DB.prepare(`INSERT OR IGNORE INTO friends (account_id, friend_account_id, added_at_unix, note) VALUES (?, ?, ?, ?)`)
    .bind(accountId, target_account_id, now, note ?? null).run();
  return c.json({ ok: true });
}

export async function friendsRemove(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { target_account_id } = await c.req.json();
  await c.env.DB.prepare("DELETE FROM friends WHERE account_id = ? AND friend_account_id = ?")
    .bind(accountId, target_account_id).run();
  return c.body(null, 204);
}

export async function friendsList(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const friends = (await c.env.DB.prepare(`SELECT a.id as account_id, a.username, a.last_seen_unix
      FROM friends f JOIN accounts a ON a.id = f.friend_account_id
      WHERE f.account_id = ?`)
    .bind(accountId).all()).results;
  return c.json({ friends });
}

export async function blockAdd(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { target_account_id, reason } = await c.req.json();
  const now = Math.floor(Date.now() / 1000);
  await c.env.DB.prepare(`INSERT OR IGNORE INTO blocks (account_id, blocked_account_id, blocked_at_unix, reason) VALUES (?, ?, ?, ?)`)
    .bind(accountId, target_account_id, now, reason ?? null).run();
  // Auto-unfriend
  await c.env.DB.prepare("DELETE FROM friends WHERE account_id = ? AND friend_account_id = ?")
    .bind(accountId, target_account_id).run();
  return c.json({ ok: true });
}

export async function blockRemove(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { target_account_id } = await c.req.json();
  await c.env.DB.prepare("DELETE FROM blocks WHERE account_id = ? AND blocked_account_id = ?")
    .bind(accountId, target_account_id).run();
  return c.body(null, 204);
}

export async function blockList(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const blocks = (await c.env.DB.prepare(`SELECT a.id as account_id, a.username, b.blocked_at_unix, b.reason
      FROM blocks b JOIN accounts a ON a.id = b.blocked_account_id
      WHERE b.account_id = ?`)
    .bind(accountId).all()).results;
  return c.json({ blocks });
}
