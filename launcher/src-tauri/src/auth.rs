// Credential storage via OS keychain (macOS Keychain, Windows Credential Manager,
// Linux Secret Service). Auth tokens are short-lived and discarded; only the
// long-lived refresh token + account id are persisted to the keychain.

use keyring::Entry;
use serde::{Deserialize, Serialize};

const SERVICE: &str = "marduk-launcher";

#[derive(Serialize, Deserialize, Default)]
pub struct StoredCredentials {
    pub account_id: String,
    pub username: String,
    pub email: String,
    pub refresh_token: String,
}

#[tauri::command]
pub fn store_credentials(creds: StoredCredentials) -> Result<(), String> {
    let entry = Entry::new(SERVICE, "default")
        .map_err(|e| format!("keyring error: {}", e))?;
    let json = serde_json::to_string(&creds).map_err(|e| e.to_string())?;
    entry.set_password(&json).map_err(|e| format!("keyring set: {}", e))?;
    Ok(())
}

#[tauri::command]
pub fn load_credentials() -> Result<Option<StoredCredentials>, String> {
    let entry = Entry::new(SERVICE, "default")
        .map_err(|e| format!("keyring error: {}", e))?;
    match entry.get_password() {
        Ok(json) => {
            let creds: StoredCredentials = serde_json::from_str(&json).map_err(|e| e.to_string())?;
            Ok(Some(creds))
        }
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(format!("keyring get: {}", e)),
    }
}

#[tauri::command]
pub fn clear_credentials() -> Result<(), String> {
    let entry = Entry::new(SERVICE, "default")
        .map_err(|e| format!("keyring error: {}", e))?;
    let _ = entry.delete_password();  // ignore "not found"
    Ok(())
}
