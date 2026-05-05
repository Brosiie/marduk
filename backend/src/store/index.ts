// Store endpoints. Stripe-backed, server-authoritative.
import type { Context } from "hono";
import type { Env } from "../index";

// Static catalog mirroring the Godot MountRegistry / PetRegistry. Single source of truth
// would be a shared JSON file; for now this is duplicated here intentionally.
const CATALOG = {
  mounts: [
    { sku_id: "mount_war_destrier", name: "War Destrier", price_cents: 499 },
    { sku_id: "mount_lapis_pony", name: "Lapis-Spotted Pony", price_cents: 499 },
    { sku_id: "mount_steppe_runner", name: "Steppe Runner", price_cents: 499 },
    { sku_id: "mount_bone_charger", name: "Bone Charger", price_cents: 799 },
    { sku_id: "mount_ember_steed", name: "Ember Steed", price_cents: 799 },
    { sku_id: "mount_shadow_courser", name: "Shadow Courser", price_cents: 999 },
    { sku_id: "mount_sun_pegasus", name: "Sun-Marked Stallion", price_cents: 1299 },
    { sku_id: "mount_dragon_pup", name: "Wyrmling (ground form)", price_cents: 1499 },
    { sku_id: "mount_marduks_chariot", name: "Marduk's Replica Chariot", price_cents: 1999 },
    { sku_id: "mount_lifetime_white_stag", name: "The White Stag (Founder)", price_cents: 2999, founder_only: true },
  ],
  pets: [
    { sku_id: "pet_yak", name: "Bone-Mountains Pack-Yak (+30 inv slots party-wide)", price_cents: 999 },
    { sku_id: "pet_raven", name: "Cradle Raven", price_cents: 299 },
    { sku_id: "pet_lapis_otter", name: "Lapis Bay Otter", price_cents: 299 },
    { sku_id: "pet_steppe_dog", name: "Ash-Step Sheepdog", price_cents: 299 },
    { sku_id: "pet_temple_butterfly", name: "Temple Butterfly", price_cents: 399 },
    { sku_id: "pet_sun_chick", name: "Sun-Sworn Chick", price_cents: 399 },
    { sku_id: "pet_bone_lamb", name: "Bone-Mountains Lamb", price_cents: 399 },
    { sku_id: "pet_apsu_eel", name: "Apsu Eel (jar)", price_cents: 499 },
    { sku_id: "pet_crown_kitten", name: "Crown Stables Kitten", price_cents: 399 },
    { sku_id: "pet_storyteller_cat", name: "The Storyteller's Cat", price_cents: 799 },
    { sku_id: "pet_lifetime_world_serpent", name: "World-Serpent (Founder)", price_cents: 1999, founder_only: true },
  ],
  cosmetics: [],  // Phase 2
};

export async function storeCatalog(c: Context<{ Bindings: Env }>) {
  return c.json(CATALOG);
}

export async function purchaseInitiate(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { sku_id } = await c.req.json();
  const item = findSku(sku_id);
  if (!item) return c.json({ error: "unknown_sku" }, 404);

  // Stripe checkout session. In a real deployment, hit Stripe's API and return the URL.
  // Stub: return a deterministic placeholder URL.
  const stripeSessionId = `cs_test_${crypto.randomUUID()}`;
  const now = Math.floor(Date.now() / 1000);
  await c.env.DB.prepare(`INSERT INTO store_purchases (account_id, sku_id, amount_cents, stripe_session_id, status, created_at_unix)
      VALUES (?, ?, ?, ?, 'pending', ?)`)
    .bind(accountId, sku_id, item.price_cents, stripeSessionId, now).run();

  return c.json({
    stripe_session_url: `https://checkout.stripe.com/c/pay/${stripeSessionId}`,
    session_id: stripeSessionId,
  });
}

export async function stripeWebhook(c: Context<{ Bindings: Env }>) {
  // Verify Stripe signature using STRIPE_WEBHOOK_SECRET (skipped in stub).
  // On payment_intent.succeeded -> mark purchase paid, grant ownership.
  const payload = await c.req.json();
  if (payload.type === "checkout.session.completed") {
    const sessionId = payload.data.object.id;
    const purchase = await c.env.DB.prepare("SELECT * FROM store_purchases WHERE stripe_session_id = ?")
      .bind(sessionId).first();
    if (purchase) {
      await c.env.DB.prepare("UPDATE store_purchases SET status = 'paid', paid_at_unix = ? WHERE id = ?")
        .bind(Math.floor(Date.now() / 1000), purchase.id).run();
      await c.env.DB.prepare(`INSERT OR IGNORE INTO owned_cosmetics (account_id, sku_id, granted_at_unix) VALUES (?, ?, ?)`)
        .bind(purchase.account_id, purchase.sku_id, Math.floor(Date.now() / 1000)).run();
    }
  }
  return c.json({ received: true });
}

export async function storeInventory(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const owned = (await c.env.DB.prepare("SELECT sku_id, granted_at_unix FROM owned_cosmetics WHERE account_id = ?")
    .bind(accountId).all()).results;
  const owned_ids = owned.map(r => r.sku_id);
  return c.json({
    owned_mounts: CATALOG.mounts.filter(m => owned_ids.includes(m.sku_id)).map(m => m.sku_id),
    owned_pets: CATALOG.pets.filter(p => owned_ids.includes(p.sku_id)).map(p => p.sku_id),
    owned_cosmetics: owned,
  });
}

function findSku(sku: string) {
  return [...CATALOG.mounts, ...CATALOG.pets, ...CATALOG.cosmetics].find(i => i.sku_id === sku);
}
