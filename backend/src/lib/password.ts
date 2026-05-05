// Password hashing. Uses Web Crypto's PBKDF2-SHA256 with a server-side pepper.
// Real production should use argon2id (@phc/argon2 has a Workers-compatible build);
// PBKDF2 is good-enough fallback that works without native deps.

const PBKDF2_ITERATIONS = 200000;
const SALT_BYTES = 16;
const KEY_BYTES = 32;

async function pbkdf2(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const baseKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
    baseKey,
    KEY_BYTES * 8
  );
  return new Uint8Array(bits);
}

export async function hashPassword(password: string, pepper: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES));
  const peppered = password + pepper;
  const derived = await pbkdf2(peppered, salt, PBKDF2_ITERATIONS);
  // Encode: $pbkdf2-sha256$iter$saltbase64$keybase64
  return `$pbkdf2-sha256$${PBKDF2_ITERATIONS}$${b64(salt)}$${b64(derived)}`;
}

export async function verifyPassword(password: string, encoded: string, pepper: string): Promise<boolean> {
  const parts = encoded.split("$");
  if (parts.length !== 5 || parts[1] !== "pbkdf2-sha256") return false;
  const iterations = parseInt(parts[2]);
  const salt = b64decode(parts[3]);
  const stored = b64decode(parts[4]);
  const peppered = password + pepper;
  const derived = await pbkdf2(peppered, salt, iterations);
  return constantTimeEqual(derived, stored);
}

function b64(arr: Uint8Array): string {
  return btoa(String.fromCharCode(...arr));
}

function b64decode(s: string): Uint8Array {
  return Uint8Array.from(atob(s), c => c.charCodeAt(0));
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
