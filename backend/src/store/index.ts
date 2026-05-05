// Store endpoints. Stripe-backed, server-authoritative.
import type { Context } from "hono";
import type { Env } from "../index";
import { verifyStripeSignature, createCheckoutSession } from "../lib/stripe";

// Pricing: $20 pets, $30 mounts, $50 Yak (utility outlier).
// Catalog mirrors the Godot MountRegistry/PetRegistry; single source of truth
// would be a shared JSON, but for now we duplicate intentionally so the backend
// is self-contained.
const CATALOG = {
  mounts: [
    { sku_id: "mount_war_destrier", name: "War Destrier", price_cents: 3000 },
    { sku_id: "mount_lapis_pony", name: "Lapis-Spotted Pony", price_cents: 3000 },
    { sku_id: "mount_steppe_runner", name: "Steppe Runner", price_cents: 3000 },
    { sku_id: "mount_bone_charger", name: "Bone Charger", price_cents: 3000 },
    { sku_id: "mount_ember_steed", name: "Ember Steed", price_cents: 3000 },
    { sku_id: "mount_shadow_courser", name: "Shadow Courser", price_cents: 3000 },
    { sku_id: "mount_sun_pegasus", name: "Sun-Marked Stallion", price_cents: 3000 },
    { sku_id: "mount_dragon_pup", name: "Wyrmling (ground form)", price_cents: 3000 },
    { sku_id: "mount_marduks_chariot", name: "Marduk's Replica Chariot", price_cents: 3000 },
    { sku_id: "mount_lifetime_white_stag", name: "The White Stag (Founder)", price_cents: 3000, founder_only: true },
  ],
  pets: [
    // Yak is the only utility pet; priced higher to match its mechanical value.
    { sku_id: "pet_yak", name: "Bone-Mountains Pack-Yak (+30 inv slots party-wide)", price_cents: 5000 },
    { sku_id: "pet_raven", name: "Cradle Raven", price_cents: 2000 },
    { sku_id: "pet_lapis_otter", name: "Lapis Bay Otter", price_cents: 2000 },
    { sku_id: "pet_steppe_dog", name: "Ash-Step Sheepdog", price_cents: 2000 },
    { sku_id: "pet_temple_butterfly", name: "Temple Butterfly", price_cents: 2000 },
    { sku_id: "pet_sun_chick", name: "Sun-Sworn Chick", price_cents: 2000 },
    { sku_id: "pet_bone_lamb", name: "Bone-Mountains Lamb", price_cents: 2000 },
    { sku_id: "pet_apsu_eel", name: "Apsu Eel (jar)", price_cents: 2000 },
    { sku_id: "pet_crown_kitten", name: "Crown Stables Kitten", price_cents: 2000 },
    { sku_id: "pet_storyteller_cat", name: "The Storyteller's Cat", price_cents: 2000 },
    { sku_id: "pet_lifetime_world_serpent", name: "World-Serpent (Founder)", price_cents: 2000, founder_only: true },
  ],
  cosmetics: [],
};

export async function storeCatalog(c: Context<{ Bindings: Env }>) {
  return c.json(CATALOG);
}

export async function purchaseInitiate(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const { sku_id } = await c.req.json();
  const item = findSku(sku_id);
  if (!item) return c.json({ error: "unknown_sku" }, 404);

  const account = await c.env.DB
    .prepare("SELECT email FROM accounts WHERE id = ?")
    .bind(accountId).first();
  if (!account) return c.json({ error: "account_not_found" }, 404);

  let session: { id: string; url: string };
  try {
    session = await createCheckoutSession(c.env.STRIPE_API_KEY, {
      sku_id,
      name: item.name,
      amount_cents: item.price_cents,
      success_url: "https://marduk.game/store/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://marduk.game/store/cancel",
      customer_email: account.email as string,
      metadata: { account_id: accountId, sku_id },
    });
  } catch (e) {
    console.error("Stripe error:", e);
    return c.json({ error: "stripe_error" }, 502);
  }

  await c.env.DB
    .prepare(`INSERT INTO store_purchases (account_id, sku_id, amount_cents, stripe_session_id, status, created_at_unix)
              VALUES (?, ?, ?, ?, 'pending', ?)`)
    .bind(accountId, sku_id, item.price_cents, session.id, Math.floor(Date.now() / 1000))
    .run();

  return c.json({ stripe_session_url: session.url, session_id: session.id });
}

export async function stripeWebhook(c: Context<{ Bindings: Env }>) {
  const signature = c.req.header("Stripe-Signature") ?? "";
  const payload = await c.req.text();
  const valid = await verifyStripeSignature(payload, signature, c.env.STRIPE_WEBHOOK_SECRET);
  if (!valid) return c.json({ error: "invalid_signature" }, 400);

  const event = JSON.parse(payload);
  switch (event.type) {
    case "checkout.session.completed":
      await handleCheckoutCompleted(c.env, event.data.object);
      break;
    case "checkout.session.expired":
      await handleCheckoutExpired(c.env, event.data.object);
      break;
    case "charge.refunded":
      await handleRefund(c.env, event.data.object);
      break;
  }
  return c.json({ received: true });
}

async function handleCheckoutCompleted(env: Env, session: any): Promise<void> {
  const purchase = await env.DB
    .prepare("SELECT * FROM store_purchases WHERE stripe_session_id = ?")
    .bind(session.id).first();
  if (!purchase) return;
  const now = Math.floor(Date.now() / 1000);
  await env.DB
    .prepare("UPDATE store_purchases SET status = 'paid', paid_at_unix = ? WHERE id = ?")
    .bind(now, purchase.id).run();
  await env.DB
    .prepare(`INSERT OR IGNORE INTO owned_cosmetics (account_id, sku_id, granted_at_unix) VALUES (?, ?, ?)`)
    .bind(purchase.account_id, purchase.sku_id, now).run();
}

async function handleCheckoutExpired(env: Env, session: any): Promise<void> {
  await env.DB
    .prepare("UPDATE store_purchases SET status = 'expired' WHERE stripe_session_id = ? AND status = 'pending'")
    .bind(session.id).run();
}

async function handleRefund(env: Env, charge: any): Promise<void> {
  const purchase = await env.DB
    .prepare("SELECT * FROM store_purchases WHERE stripe_session_id LIKE ?")
    .bind(`%${charge.payment_intent}%`).first();
  if (!purchase) return;
  await env.DB
    .prepare("UPDATE store_purchases SET status = 'refunded' WHERE id = ?")
    .bind(purchase.id).run();
  await env.DB
    .prepare("DELETE FROM owned_cosmetics WHERE account_id = ? AND sku_id = ?")
    .bind(purchase.account_id, purchase.sku_id).run();
}

export async function storeInventory(c: Context<{ Bindings: Env; Variables: { account_id: string } }>) {
  const accountId = c.var.account_id;
  const owned = (await c.env.DB
    .prepare("SELECT sku_id, granted_at_unix FROM owned_cosmetics WHERE account_id = ?")
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
