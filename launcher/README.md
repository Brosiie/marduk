# Marduk Launcher

PC launcher for Marduk. Tauri-based (Rust backend + React/Svelte frontend).
Handles: account login, game build downloads, auto-update, news feed,
launch into Godot game.

## Quick start

```bash
cd launcher
# prerequisites: rustup, node, pnpm
pnpm install
pnpm tauri dev          # local dev with hot reload
pnpm tauri build        # produces signed installer
```

## Features

- **Login screen:** email + password, persisted via OS keychain (Tauri secure storage)
- **News feed:** pulls from https://marduk.game/news.json
- **Build manager:** downloads latest Godot build from CDN, verifies signature, applies delta updates
- **Launch:** spawns the Godot binary with `--auth-token=<token>` so the game starts already signed in
- **Self-update:** Tauri's built-in updater checks every launch
- **Donation prompt:** $1 prompt once per 24h before launch (Bond's spec)

## Code structure (planned)

```
launcher/
├── src/                 # Rust backend (Tauri commands)
│   └── main.rs
├── src-tauri/
│   └── tauri.conf.json
└── ui/                  # frontend (Vite + Svelte)
    ├── src/
    │   ├── App.svelte
    │   ├── routes/
    │   │   ├── login.svelte
    │   │   ├── home.svelte
    │   │   └── settings.svelte
    │   └── api/
    │       └── client.ts   # talks to api.marduk.game
    └── public/
```

## Phase 2 work

This is scaffold + intent. The actual launcher binary is built in Phase 2 alongside
the first packaged Godot build. Until then, players run Godot 4.6 directly with
`project.godot`.
