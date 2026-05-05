// Character endpoints. Save blobs <1KB inline; larger to R2.
import type { Context } from "hono";
import type { Env } from "../index";

const INLINE_BLOB_LIMIT = 1024;

export async function charactersList(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const characters = (await c.env.DB
    .prepare("SELECT slot, character_name, class_id, level, prestige, current_zone, saved_at_unix FROM characters WHERE account_id = ? ORDER BY slot")
    .bind(accountId)
    .all()).results;
  return c.json({ characters });
}

export async function characterSync(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { slot, save_blob, character_name, class_id, level, prestige, current_zone } = await c.req.json();
  if (slot === undefined) return c.json({ error: "missing_slot" }, 400);

  const blobJson = JSON.stringify(save_blob);
  const inline = blobJson.length <= INLINE_BLOB_LIMIT;
  const blob_key = inline ? null : `account_${accountId}/slot_${slot}.json`;
  if (!inline) {
    await c.env.SAVES.put(blob_key, blobJson);
  }
  const now = Math.floor(Date.now() / 1000);

  const existing = await c.env.DB
    .prepare("SELECT id FROM characters WHERE account_id = ? AND slot = ?")
    .bind(accountId, slot)
    .first();

  if (existing) {
    await c.env.DB.prepare(`UPDATE characters
        SET character_name = ?, class_id = ?, level = ?, prestige = ?, current_zone = ?,
            blob_key = ?, blob_inline = ?, saved_at_unix = ?
        WHERE id = ?`)
      .bind(character_name, class_id, level, prestige, current_zone,
            blob_key, inline ? blobJson : null, now, existing.id)
      .run();
  } else {
    const charId = crypto.randomUUID();
    await c.env.DB.prepare(`INSERT INTO characters
        (id, account_id, slot, character_name, class_id, level, prestige, current_zone, blob_key, blob_inline, saved_at_unix)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(charId, accountId, slot, character_name, class_id, level, prestige, current_zone,
            blob_key, inline ? blobJson : null, now)
      .run();
  }

  return c.json({ ok: true, saved_at_unix: now });
}

export async function characterDelete(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const slot = parseInt(c.req.param("slot"));
  const row = await c.env.DB
    .prepare("SELECT blob_key FROM characters WHERE account_id = ? AND slot = ?")
    .bind(accountId, slot).first();
  if (row?.blob_key) await c.env.SAVES.delete(row.blob_key as string);
  await c.env.DB.prepare("DELETE FROM characters WHERE account_id = ? AND slot = ?")
    .bind(accountId, slot).run();
  return c.json({ ok: true });
}
