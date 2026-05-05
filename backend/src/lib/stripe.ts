// Stripe webhook signature verification + checkout session creation.
// Uses Stripe's REST API directly - no SDK required, keeps the Worker bundle small.

const STRIPE_API_BASE = "https://api.stripe.com/v1";

// Verify Stripe-Signature header against payload using HMAC-SHA256.
// Throws on invalid signature.
export async function verifyStripeSignature(
  payload: string,
  signatureHeader: string,
  webhookSecret: string,
  toleranceSeconds: number = 300
): Promise<boolean> {
  if (!signatureHeader) return false;
  const parts = Object.fromEntries(
    signatureHeader.split(",").map(kv => kv.split("=") as [string, string])
  );
  const timestamp = parseInt(parts["t"]);
  const sigs = signatureHeader.split(",")
    .filter(p => p.startsWith("v1="))
    .map(p => p.substring(3));
  if (!timestamp || sigs.length === 0) return false;

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - timestamp) > toleranceSeconds) return false;

  const signedPayload = `${timestamp}.${payload}`;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(signedPayload));
  const expected = Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");

  // Constant-time compare across all v1 signatures (Stripe rotates)
  for (const candidate of sigs) {
    if (constantTimeEqualHex(candidate, expected)) return true;
  }
  return false;
}

function constantTimeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

// Create a Stripe Checkout session via Stripe REST API.
// Returns the session URL the client should redirect to.
export async function createCheckoutSession(
  apiKey: string,
  params: {
    sku_id: string;
    name: string;
    amount_cents: number;
    currency?: string;
    success_url: string;
    cancel_url: string;
    customer_email?: string;
    metadata?: Record<string, string>;
  }
): Promise<{ id: string; url: string }> {
  const body = new URLSearchParams();
  body.append("mode", "payment");
  body.append("success_url", params.success_url);
  body.append("cancel_url", params.cancel_url);
  body.append("line_items[0][price_data][currency]", params.currency ?? "usd");
  body.append("line_items[0][price_data][product_data][name]", params.name);
  body.append("line_items[0][price_data][unit_amount]", String(params.amount_cents));
  body.append("line_items[0][quantity]", "1");
  if (params.customer_email) body.append("customer_email", params.customer_email);
  body.append("metadata[sku_id]", params.sku_id);
  if (params.metadata) {
    for (const [k, v] of Object.entries(params.metadata)) {
      body.append(`metadata[${k}]`, v);
    }
  }

  const r = await fetch(`${STRIPE_API_BASE}/checkout/sessions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });
  if (!r.ok) {
    const errText = await r.text();
    throw new Error(`Stripe API error: ${r.status} ${errText}`);
  }
  const data = await r.json() as { id: string; url: string };
  return { id: data.id, url: data.url };
}
