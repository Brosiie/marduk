<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { listen } from "@tauri-apps/api/event";
  import * as api from "../lib/api";

  export let session: api.AuthSession;
  const dispatch = createEventDispatcher();

  let news: { title: string; body: string; date: string }[] = [];
  let builds: any[] = [];
  let installed_path = "";
  let download_progress: { downloaded: number; total: number } | null = null;
  let launching = false;

  onMount(async () => {
    try {
      const n = await api.fetchNews();
      news = n.entries.slice(0, 5);
    } catch {}
    try {
      builds = await invoke<any[]>("list_builds");
    } catch {}
    listen("download-progress", (event: any) => {
      download_progress = event.payload;
    });
  });

  async function downloadAndPlay() {
    const stable = builds.find(b => b.channel === "stable");
    if (!stable) return;
    download_progress = { downloaded: 0, total: stable.size_bytes };
    try {
      const path = await invoke<string>("download_build", {
        build: stable,
        installDir: "~/.marduk/game",
      });
      const ok = await invoke<boolean>("verify_build", {
        path,
        expectedSha256: stable.sha256,
      });
      if (!ok) {
        alert("Downloaded build failed integrity check. Aborting.");
        download_progress = null;
        return;
      }
      installed_path = path;
      download_progress = null;
      await launch();
    } catch (e) {
      alert("Download failed: " + e);
      download_progress = null;
    }
  }

  async function launch() {
    if (!installed_path) {
      await downloadAndPlay();
      return;
    }
    launching = true;
    try {
      await invoke("launch_game", {
        executablePath: installed_path,
        authToken: session.auth_token,
      });
    } catch (e) {
      alert("Failed to launch: " + e);
    } finally {
      launching = false;
    }
  }
</script>

<div class="home">
  <header>
    <h1>Marduk</h1>
    <div class="account">
      <span>{session.account.username}</span>
      {#if session.account.is_founder}<span class="founder">FOUNDER</span>{/if}
      <button on:click={() => dispatch("sign-out")}>Sign Out</button>
    </div>
  </header>

  <main class="content">
    <section class="news">
      <h2>News</h2>
      {#if news.length === 0}
        <p class="muted">No news. The Storyteller is between cycles.</p>
      {:else}
        {#each news as n}
          <article>
            <h3>{n.title}</h3>
            <p class="date">{n.date}</p>
            <p>{n.body}</p>
          </article>
        {/each}
      {/if}
    </section>

    <aside class="play-panel">
      <h2>Play</h2>
      {#if download_progress}
        <p>Downloading...</p>
        <progress value={download_progress.downloaded} max={download_progress.total}></progress>
        <p>{Math.round(download_progress.downloaded / 1024 / 1024)} / {Math.round(download_progress.total / 1024 / 1024)} MB</p>
      {:else}
        <button class="play-btn" on:click={launch} disabled={launching}>
          {launching ? "Launching..." : (installed_path ? "Play" : "Download & Play")}
        </button>
      {/if}
      <p class="muted small">
        Build channel: <strong>stable</strong>
        {#if builds.length > 0}
          v{builds[0].version}
        {/if}
      </p>
    </aside>
  </main>
</div>

<style>
  .home { height: 100%; display: flex; flex-direction: column; }
  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 24px;
    background: #1c1428;
    border-bottom: 1px solid #4a3a3a;
  }
  header h1 { color: #f5d061; margin: 0; letter-spacing: 0.08em; }
  .account { display: flex; gap: 12px; align-items: center; }
  .account .founder { color: #f5d061; font-size: 0.8em; border: 1px solid #f5d061; padding: 2px 6px; border-radius: 3px; }
  .account button { background: transparent; color: #c0a070; border: 1px solid #4a3a3a; padding: 6px 10px; border-radius: 3px; cursor: pointer; }
  .content { display: grid; grid-template-columns: 1fr 320px; gap: 20px; padding: 20px; flex: 1; overflow: hidden; }
  .news, .play-panel { background: #1c1428; padding: 18px; border-radius: 8px; overflow-y: auto; }
  .news h2, .play-panel h2 { color: #f5d061; margin-top: 0; }
  .news article { margin-bottom: 18px; padding-bottom: 14px; border-bottom: 1px solid #2a2030; }
  .news article:last-child { border-bottom: none; }
  .news .date { color: #80706a; font-size: 0.8em; margin: 0 0 6px 0; }
  .play-btn { width: 100%; background: #f5d061; color: #0a0612; border: none; padding: 18px; font-size: 1.2em; font-weight: bold; border-radius: 6px; cursor: pointer; }
  .play-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .muted { color: #80706a; }
  .small { font-size: 0.85em; }
</style>
