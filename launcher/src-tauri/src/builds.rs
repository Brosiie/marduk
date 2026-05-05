// Game build management: list available builds, download with progress events,
// verify SHA-256 against manifest. Builds live on a CDN (Cloudflare R2 + Pages).

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use tokio::io::AsyncWriteExt;
use futures_util::StreamExt;

#[derive(Serialize, Deserialize, Clone)]
pub struct BuildEntry {
    pub channel: String,        // "stable" | "beta" | "nightly"
    pub version: String,
    pub platform: String,       // "win64" | "linux64" | "macos"
    pub url: String,
    pub size_bytes: u64,
    pub sha256: String,
    pub released_at: String,
}

#[derive(Serialize, Deserialize)]
pub struct BuildManifest {
    pub builds: Vec<BuildEntry>,
}

#[tauri::command]
pub async fn list_builds() -> Result<Vec<BuildEntry>, String> {
    let r = reqwest::get("https://builds.marduk.game/manifest.json")
        .await.map_err(|e| e.to_string())?;
    let manifest: BuildManifest = r.json().await.map_err(|e| e.to_string())?;
    Ok(manifest.builds)
}

#[tauri::command]
pub async fn download_build(
    app: tauri::AppHandle,
    build: BuildEntry,
    install_dir: String,
) -> Result<String, String> {
    let dir = PathBuf::from(&install_dir);
    std::fs::create_dir_all(&dir).map_err(|e| format!("mkdir: {}", e))?;
    let path = dir.join(format!("marduk-{}-{}", build.version, build.platform));

    let r = reqwest::get(&build.url).await.map_err(|e| e.to_string())?;
    let total = r.content_length().unwrap_or(build.size_bytes);
    let mut file = tokio::fs::File::create(&path).await.map_err(|e| e.to_string())?;
    let mut stream = r.bytes_stream();
    let mut downloaded: u64 = 0;

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        file.write_all(&chunk).await.map_err(|e| e.to_string())?;
        downloaded += chunk.len() as u64;
        // Emit progress to UI (Svelte listens via `appWindow.listen("download-progress", ...)`)
        let _ = tauri::Emitter::emit(&app, "download-progress", serde_json::json!({
            "version": build.version,
            "downloaded": downloaded,
            "total": total,
        }));
    }
    file.flush().await.map_err(|e| e.to_string())?;
    Ok(path.to_string_lossy().to_string())
}

#[tauri::command]
pub fn verify_build(path: String, expected_sha256: String) -> Result<bool, String> {
    let bytes = std::fs::read(&path).map_err(|e| format!("read: {}", e))?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);
    let result = hasher.finalize();
    let actual = hex::encode(result);
    Ok(actual.eq_ignore_ascii_case(&expected_sha256))
}
