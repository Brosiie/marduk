// KV-backed sliding window rate limiter. Lightweight - one read + one put per check.
// Returns true if the request is allowed, false if it exceeds the limit.

export async function rateLimit(
  kv: KVNamespace,
  key: string,
  max_requests: number,
  window_seconds: number
): Promise<boolean> {
  const now = Math.floor(Date.now() / 1000);
  const window_start = now - window_seconds;
  const stored = await kv.get(key, { type: "json" }) as { ts: number[] } | null;
  const recent = stored ? stored.ts.filter(t => t >= window_start) : [];
  if (recent.length >= max_requests) return false;
  recent.push(now);
  await kv.put(key, JSON.stringify({ ts: recent }), { expirationTtl: window_seconds });
  return true;
}
