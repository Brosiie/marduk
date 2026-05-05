// API client. Talks to https://api.marduk.game over HTTPS.
// Uses Tauri's HTTP plugin so requests bypass browser CORS limits.

import { fetch as tauriFetch } from "@tauri-apps/plugin-http";

const BASE = "https://api.marduk.game";

export interface Account {
  id: string;
  email: string;
  username: string;
  subscription_tier: string;
  is_founder: boolean;
  prestige_max: number;
  character_slots: number;
}

export interface AuthSession {
  account: Account;
  auth_token: string;
  refresh_token: string;
  expires_at: number;
  characters: any[];
}

export async function login(email_or_username: string, password: string): Promise<AuthSession> {
  const r = await tauriFetch(`${BASE}/v1/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email_or_username, password }),
  });
  if (!r.ok) throw new Error((await r.json() as any).error ?? "login failed");
  return r.json() as Promise<AuthSession>;
}

export async function register(email: string, username: string, password: string): Promise<AuthSession> {
  const r = await tauriFetch(`${BASE}/v1/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, username, password }),
  });
  if (!r.ok) throw new Error((await r.json() as any).error ?? "register failed");
  return r.json() as Promise<AuthSession>;
}

export async function refresh(refresh_token: string): Promise<{ auth_token: string; expires_at: number }> {
  const r = await tauriFetch(`${BASE}/v1/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token }),
  });
  if (!r.ok) throw new Error("refresh failed");
  return r.json();
}

export async function fetchNews(): Promise<{ entries: { title: string; body: string; date: string }[] }> {
  const r = await tauriFetch("https://marduk.game/news.json");
  if (!r.ok) return { entries: [] };
  return r.json();
}
