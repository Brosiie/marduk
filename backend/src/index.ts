// Marduk API entry point. Cloudflare Workers + Hono router.
import { Hono } from "hono";
import { cors } from "hono/cors";
import { register, login, refresh, logout } from "./auth";
import { accountMe, accountUpdate } from "./account";
import { charactersList, characterSync, characterDelete } from "./characters";
import { worldsList, worldsJoin, worldsTransfer } from "./worlds";
import { partyCreate, partyInvite, partyAccept, partyLeave, partyKick, partyMe } from "./party";
import { friendsAdd, friendsRemove, friendsList, blockAdd, blockRemove, blockList } from "./friends";
import { storeCatalog, purchaseInitiate, stripeWebhook, storeInventory } from "./store";
import { prestigeLeaderboard, speedLeaderboard, speedSubmit } from "./leaderboards";
import { authMiddleware } from "./lib/jwt";

export type Env = {
  DB: D1Database;
  RATE_LIMITS: KVNamespace;
  SAVES: R2Bucket;
  JWT_SECRET: string;
  ARGON2_PEPPER: string;
  STRIPE_API_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
  JWT_ISSUER: string;
  ALLOWED_ORIGINS: string;
};

const app = new Hono<{ Bindings: Env }>();

// CORS
app.use("*", async (c, next) => {
  const origins = c.env.ALLOWED_ORIGINS.split(",");
  return cors({ origin: origins, credentials: true })(c, next);
});

// === Public endpoints ===
app.post("/v1/auth/register", register);
app.post("/v1/auth/login", login);
app.post("/v1/auth/refresh", refresh);
app.get("/v1/leaderboards/prestige", prestigeLeaderboard);
app.get("/v1/leaderboards/speed/:boss_id", speedLeaderboard);
app.get("/v1/store/catalog", storeCatalog);
app.post("/v1/store/webhook/stripe", stripeWebhook);

// === Authed endpoints ===
const auth = new Hono<{ Bindings: Env; Variables: { account_id: string } }>();
auth.use("*", authMiddleware);

auth.post("/v1/auth/logout", logout);
auth.get("/v1/account/me", accountMe);
auth.post("/v1/account/update", accountUpdate);
auth.get("/v1/characters", charactersList);
auth.post("/v1/characters/sync", characterSync);
auth.delete("/v1/characters/:slot", characterDelete);
auth.get("/v1/worlds/list", worldsList);
auth.post("/v1/worlds/join", worldsJoin);
auth.post("/v1/worlds/transfer", worldsTransfer);
auth.post("/v1/party/create", partyCreate);
auth.post("/v1/party/invite", partyInvite);
auth.post("/v1/party/accept", partyAccept);
auth.post("/v1/party/leave", partyLeave);
auth.post("/v1/party/kick", partyKick);
auth.get("/v1/party/me", partyMe);
auth.post("/v1/friends/add", friendsAdd);
auth.post("/v1/friends/remove", friendsRemove);
auth.get("/v1/friends/list", friendsList);
auth.post("/v1/blocks/add", blockAdd);
auth.post("/v1/blocks/remove", blockRemove);
auth.get("/v1/blocks/list", blockList);
auth.post("/v1/store/purchase/initiate", purchaseInitiate);
auth.get("/v1/store/inventory", storeInventory);
auth.post("/v1/leaderboards/speed/submit", speedSubmit);

app.route("/", auth);

// Health check
app.get("/health", (c) => c.json({ ok: true, service: "marduk-api", version: "0.1.0" }));

export default app;
