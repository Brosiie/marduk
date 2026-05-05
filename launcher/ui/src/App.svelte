<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { listen } from "@tauri-apps/api/event";
  import * as api from "./lib/api";
  import Login from "./routes/Login.svelte";
  import Home from "./routes/Home.svelte";

  let session: api.AuthSession | null = null;
  let loading = true;
  let error = "";

  // Donation prompt state - shows once per 24h on first session per day
  let showDonation = false;
  const DONATION_KEY = "marduk_donation_shown_unix";
  const DONATION_INTERVAL_S = 86400;

  function maybeShowDonation() {
    const last = parseInt(localStorage.getItem(DONATION_KEY) ?? "0");
    const now = Math.floor(Date.now() / 1000);
    const never = localStorage.getItem("marduk_donation_never") === "1";
    if (!never && now - last > DONATION_INTERVAL_S) {
      showDonation = true;
      localStorage.setItem(DONATION_KEY, String(now));
    }
  }

  async function handleSignIn(s: api.AuthSession) {
    session = s;
    await invoke("store_credentials", {
      creds: {
        account_id: s.account.id,
        username: s.account.username,
        email: s.account.email,
        refresh_token: s.refresh_token,
      },
    });
    maybeShowDonation();
  }

  async function handleSignOut() {
    await invoke("clear_credentials");
    session = null;
  }

  onMount(async () => {
    try {
      const stored = await invoke<{ account_id: string; refresh_token: string; username: string; email: string } | null>(
        "load_credentials"
      );
      if (stored?.refresh_token) {
        const r = await api.refresh(stored.refresh_token);
        // Build minimal session from stored + refreshed token
        session = {
          account: {
            id: stored.account_id,
            email: stored.email,
            username: stored.username,
            subscription_tier: "free",
            is_founder: false,
            prestige_max: 0,
            character_slots: 6,
          },
          auth_token: r.auth_token,
          refresh_token: stored.refresh_token,
          expires_at: r.expires_at,
          characters: [],
        };
        maybeShowDonation();
      }
    } catch (e) {
      // refresh failed; user must log in again
    } finally {
      loading = false;
    }
  });
</script>

<main>
  {#if loading}
    <div class="loading">Loading...</div>
  {:else if !session}
    <Login on:signed-in={(e) => handleSignIn(e.detail)} bind:error />
  {:else}
    <Home {session} on:sign-out={handleSignOut} />
  {/if}

  {#if showDonation}
    <div class="donation-overlay">
      <div class="donation-card">
        <h2>Support Marduk</h2>
        <p>
          Marduk is free and open-source. A one-time $1 donation helps keep the servers running
          and the codebase in active development.
        </p>
        <div class="donation-buttons">
          <button class="primary" on:click={() => {
            window.open("https://ko-fi.com/marduk_game", "_blank");
            showDonation = false;
          }}>Donate $1</button>
          <button on:click={() => showDonation = false}>Maybe later</button>
          <button class="muted" on:click={() => {
            localStorage.setItem("marduk_donation_never", "1");
            showDonation = false;
          }}>Never show again</button>
        </div>
      </div>
    </div>
  {/if}
</main>

<style>
  :global(html, body, #app) {
    margin: 0;
    padding: 0;
    height: 100%;
    background: #0a0612;
    color: #e0d8c0;
    font-family: system-ui, -apple-system, sans-serif;
  }
  main { height: 100vh; }
  .loading { display: flex; align-items: center; justify-content: center; height: 100%; }
  .donation-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.75);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .donation-card {
    background: #1c1428;
    border: 1px solid #4a3a3a;
    padding: 24px 28px;
    border-radius: 8px;
    max-width: 420px;
    text-align: left;
  }
  .donation-card h2 { color: #f5d061; margin-top: 0; }
  .donation-buttons { display: flex; flex-direction: column; gap: 8px; margin-top: 16px; }
  button {
    background: #2a2030;
    color: #e0d8c0;
    border: 1px solid #4a3a3a;
    padding: 10px 16px;
    border-radius: 4px;
    cursor: pointer;
  }
  button.primary {
    background: #f5d061;
    color: #0a0612;
    font-weight: bold;
  }
  button.muted { color: #80706a; font-size: 0.85em; }
  button:hover { filter: brightness(1.15); }
</style>
