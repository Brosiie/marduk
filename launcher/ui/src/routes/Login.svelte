<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import * as api from "../lib/api";
  export let error = "";

  const dispatch = createEventDispatcher();
  let mode: "login" | "register" = "login";
  let email_or_username = "";
  let username = "";
  let email = "";
  let password = "";
  let busy = false;

  async function submit() {
    busy = true;
    error = "";
    try {
      if (mode === "login") {
        const s = await api.login(email_or_username, password);
        dispatch("signed-in", s);
      } else {
        const s = await api.register(email, username, password);
        dispatch("signed-in", s);
      }
    } catch (e) {
      error = (e as Error).message;
    } finally {
      busy = false;
    }
  }
</script>

<div class="login">
  <div class="brand">
    <h1>Marduk</h1>
    <p class="tagline">A free, open-source Babylonian fantasy ARPG.</p>
  </div>

  <div class="form-card">
    <div class="tabs">
      <button class:active={mode === "login"} on:click={() => mode = "login"}>Sign In</button>
      <button class:active={mode === "register"} on:click={() => mode = "register"}>Register</button>
    </div>

    {#if mode === "login"}
      <input bind:value={email_or_username} placeholder="Email or username" autocomplete="username" />
      <input bind:value={password} type="password" placeholder="Password" autocomplete="current-password" />
    {:else}
      <input bind:value={email} type="email" placeholder="Email" />
      <input bind:value={username} placeholder="Username" />
      <input bind:value={password} type="password" placeholder="Password (8+ chars)" />
    {/if}

    {#if error}
      <div class="error">{error}</div>
    {/if}

    <button class="primary" on:click={submit} disabled={busy}>
      {busy ? "..." : (mode === "login" ? "Sign In" : "Create Account")}
    </button>

    <p class="legal">
      Marduk is free and open-source under the MIT license. Source on
      <a href="https://github.com/Brosiie/marduk" target="_blank">GitHub</a>.
    </p>
  </div>
</div>

<style>
  .login {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 24px;
    background: linear-gradient(180deg, #0a0612 0%, #1c1024 100%);
  }
  .brand { text-align: center; margin-bottom: 32px; }
  .brand h1 { color: #f5d061; font-size: 3em; margin: 0; letter-spacing: 0.1em; }
  .tagline { color: #a09080; }

  .form-card {
    background: #1c1428;
    border: 1px solid #4a3a3a;
    padding: 24px;
    border-radius: 8px;
    width: 360px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .tabs { display: flex; gap: 4px; }
  .tabs button {
    flex: 1;
    background: transparent;
    border: 1px solid #4a3a3a;
    color: #80706a;
    padding: 8px;
    cursor: pointer;
    border-radius: 4px;
  }
  .tabs button.active { color: #f5d061; border-color: #f5d061; }
  input {
    background: #0e0a16;
    border: 1px solid #4a3a3a;
    color: #e0d8c0;
    padding: 10px 12px;
    border-radius: 4px;
    font-size: 14px;
  }
  input:focus { outline: 1px solid #f5d061; }
  .error { color: #f08080; font-size: 0.9em; }
  button.primary {
    background: #f5d061;
    color: #0a0612;
    border: none;
    padding: 12px;
    border-radius: 4px;
    font-weight: bold;
    cursor: pointer;
  }
  button.primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .legal { font-size: 0.8em; color: #80706a; text-align: center; margin: 0; }
  .legal a { color: #c0a070; }
</style>
