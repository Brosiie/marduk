// Party endpoints. Server-authoritative; clients mirror state via /v1/party/me + WebSocket.
import type { Context } from "hono";
import type { Env } from "../index";

const MAX_PARTY_SIZE = 4;

export async function partyCreate(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  // Leave existing party first
  await leaveAll(c.env.DB, accountId);

  const partyId = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);
  await c.env.DB.prepare("INSERT INTO parties (id, leader_account_id, created_at_unix) VALUES (?, ?, ?)")
    .bind(partyId, accountId, now).run();
  await c.env.DB.prepare("INSERT INTO party_members (party_id, account_id, joined_at_unix) VALUES (?, ?, ?)")
    .bind(partyId, accountId, now).run();
  return c.json({ party_id: partyId, leader_id: accountId });
}

export async function partyInvite(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  // Phase 4: WebSocket push to target. Stub: store invite in KV/D1.
  return c.json({ ok: true });
}

export async function partyAccept(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { party_id } = await c.req.json();
  const count = await c.env.DB.prepare("SELECT COUNT(*) as n FROM party_members WHERE party_id = ?")
    .bind(party_id).first();
  if ((count?.n as number) >= MAX_PARTY_SIZE) {
    return c.json({ error: "party_full" }, 409);
  }
  await leaveAll(c.env.DB, accountId);
  await c.env.DB.prepare("INSERT INTO party_members (party_id, account_id, joined_at_unix) VALUES (?, ?, ?)")
    .bind(party_id, accountId, Math.floor(Date.now() / 1000)).run();
  return c.json({ ok: true });
}

export async function partyLeave(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  await leaveAll(c.env.DB, accountId);
  return c.body(null, 204);
}

export async function partyKick(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const leaderId = c.var.account_id;
  const { account_id } = await c.req.json();
  const party = await c.env.DB.prepare(`SELECT id FROM parties
      WHERE leader_account_id = ? AND id IN (SELECT party_id FROM party_members WHERE account_id = ?)`)
    .bind(leaderId, account_id).first();
  if (!party) return c.json({ error: "not_leader_or_member" }, 403);
  await c.env.DB.prepare("DELETE FROM party_members WHERE party_id = ? AND account_id = ?")
    .bind(party.id, account_id).run();
  return c.json({ ok: true });
}

export async function partyMe(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const party = await c.env.DB.prepare(`SELECT p.* FROM parties p
      JOIN party_members pm ON pm.party_id = p.id
      WHERE pm.account_id = ?`)
    .bind(accountId).first();
  if (!party) return c.json({ party: null });
  const members = (await c.env.DB.prepare(`SELECT a.id, a.username
      FROM party_members pm JOIN accounts a ON a.id = pm.account_id
      WHERE pm.party_id = ?`)
    .bind(party.id).all()).results;
  return c.json({ party: { ...party, members } });
}

async function leaveAll(db: D1Database, accountId: string): Promise<void> {
  await db.prepare("DELETE FROM party_members WHERE account_id = ?").bind(accountId).run();
  // Disband empty parties
  await db.prepare(`DELETE FROM parties WHERE id NOT IN (SELECT DISTINCT party_id FROM party_members)`).run();
}
