// World / server endpoints.
import type { Context } from "hono";
import type { Env } from "../index";

const MAX_PER_WORLD = 12;
const TRANSFER_COOLDOWN_SECONDS = 86400;

const STATIC_WORLDS = [
  { server_id: "world_1_iron_pillar", display_name: "Iron Pillar (1)", region: "na", is_pvp: false },
  { server_id: "world_2_lapis_bay", display_name: "Lapis Bay (2)", region: "eu", is_pvp: false },
  { server_id: "world_3_bone_mountains", display_name: "Bone Mountains (3)", region: "global", is_pvp: false },
  { server_id: "world_4_pvp_mist_vale", display_name: "Mist Vale PvP (4)", region: "global", is_pvp: true },
];

export async function worldsList(c: Context<{ Bindings: Env }>) {
  // Tally per-server populations from accounts table.
  const populations = await c.env.DB
    .prepare(`SELECT current_server_id, COUNT(*) as n
              FROM accounts WHERE current_server_id IS NOT NULL
              GROUP BY current_server_id`)
    .all();
  const popMap = new Map<string, number>();
  for (const r of populations.results) {
    popMap.set(r.current_server_id as string, r.n as number);
  }
  const worlds = STATIC_WORLDS.map(w => ({
    ...w,
    current_players: popMap.get(w.server_id) ?? 0,
    max_players: MAX_PER_WORLD,
    status: "online",
  }));
  return c.json({ worlds });
}

export async function worldsJoin(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { server_id, character_id } = await c.req.json();
  if (!server_id) return c.json({ error: "missing_server_id" }, 400);

  const populations = await c.env.DB
    .prepare("SELECT COUNT(*) as n FROM accounts WHERE current_server_id = ?")
    .bind(server_id).first();
  if ((populations?.n as number) >= MAX_PER_WORLD) {
    return c.json({ error: "world_full" }, 409);
  }

  await c.env.DB.prepare("UPDATE accounts SET current_server_id = ? WHERE id = ?")
    .bind(server_id, accountId).run();

  if (character_id) {
    await c.env.DB.prepare("UPDATE characters SET current_server_id = ? WHERE id = ? AND account_id = ?")
      .bind(server_id, character_id, accountId).run();
  }

  return c.json({ ok: true, websocket_url: `wss://realtime.marduk.game/${server_id}` });
}

export async function worldsTransfer(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { from_server, to_server, character_id } = await c.req.json();
  // 24h cooldown is enforced by tracking last transfer in a separate table or KV.
  // Stub: log only.
  await c.env.DB.prepare("UPDATE characters SET current_server_id = ? WHERE id = ? AND account_id = ?")
    .bind(to_server, character_id, accountId).run();
  return c.json({ ok: true, transfer_completes_at_unix: Math.floor(Date.now() / 1000) });
}
