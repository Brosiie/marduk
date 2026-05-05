// Marduk launcher - Tauri main entry. Exposes commands the Svelte UI calls
// via `invoke()`. Handles secure credential storage (OS keychain), game
// build downloads, integrity verification, and process spawn.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod auth;
mod builds;
mod launcher;

use serde::Serialize;

#[derive(Serialize)]
struct AppInfo {
    version: String,
    api_base: String,
    builds_base: String,
}

#[tauri::command]
fn app_info() -> AppInfo {
    AppInfo {
        version: env!("CARGO_PKG_VERSION").to_string(),
        api_base: "https://api.marduk.game".to_string(),
        builds_base: "https://builds.marduk.game".to_string(),
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_http::init())
        .invoke_handler(tauri::generate_handler![
            app_info,
            auth::store_credentials,
            auth::load_credentials,
            auth::clear_credentials,
            builds::list_builds,
            builds::download_build,
            builds::verify_build,
            launcher::launch_game,
        ])
        .run(tauri::generate_context!())
        .expect("error while running marduk launcher");
}
