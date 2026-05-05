// Spawn the Godot game binary with --auth-token flag so the game starts
// already signed in.

use std::process::Command;

#[tauri::command]
pub fn launch_game(executable_path: String, auth_token: String) -> Result<u32, String> {
    let mut cmd = Command::new(&executable_path);
    cmd.arg(format!("--auth-token={}", auth_token));
    cmd.arg("--launcher-mode=1");
    let child = cmd.spawn().map_err(|e| format!("spawn failed: {}", e))?;
    Ok(child.id())
}
