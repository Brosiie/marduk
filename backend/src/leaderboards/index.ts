import type { Context } from "hono";
import type { Env } from "../index";

export async function prestigeLeaderboard(c: Context<{ Bindings: Env }>) {
  const entries = (await c.env.DB.prepare(`SELECT username, prestige_max as prestige
      FROM accounts ORDER BY prestige_max DESC LIMIT 100`).all()).results;
  return c.json({ entries });
}

export async function speedLeaderboard(c: Context<{ Bindings: Env }>) {
  const bossId = c.req.param("boss_id");
  const entries = (await c.env.DB.prepare(`SELECT a.username, ls.seconds, ls.achieved_at_unix
      FROM leaderboard_speed ls JOIN accounts a ON a.id = ls.account_id
      WHERE ls.boss_id = ?
      ORDER BY ls.seconds ASC LIMIT 50`).bind(bossId).all()).results;
  return c.json({ entries });
}

export async function speedSubmit(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { boss_id, seconds, replay_hash } = await c.req.json();
  if (!boss_id || typeof seconds !== "number") return c.json({ error: "invalid_input" }, 400);
  await c.env.DB.prepare(`INSERT INTO leaderboard_speed (account_id, boss_id, seconds, replay_hash, achieved_at_unix)
      VALUES (?, ?, ?, ?, ?)`)
    .bind(accountId, boss_id, seconds, replay_hash ?? null, Math.floor(Date.now() / 1000))
    .run();
  // Return rank + percentile (cheap calc on submission)
  const rank = await c.env.DB.prepare(`SELECT COUNT(*) + 1 as rank FROM leaderboard_speed
      WHERE boss_id = ? AND seconds < ?`).bind(boss_id, seconds).first();
  const total = await c.env.DB.prepare("SELECT COUNT(*) as n FROM leaderboard_speed WHERE boss_id = ?")
    .bind(boss_id).first();
  const percentile = total ? (1 - (rank!.rank as number) / (total.n as number + 1)) : 0;
  return c.json({ rank: rank?.rank, percentile });
}
