use atomic_write_file::AtomicWriteFile;
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};
use tauri::Manager;

// Only these two files can be accessed by the WebView, never arbitrary paths.
fn filename(file: &str) -> Result<&'static str, String> {
    match file {
        "sessions" => Ok("sessions.json"),
        "settings" => Ok("settings.json"),
        _ => Err("未知数据文件".into()),
    }
}
fn path(app: &tauri::AppHandle, file: &str) -> Result<PathBuf, String> {
    Ok(app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?
        .join(filename(file)?))
}
fn read(path: &Path) -> Result<Option<String>, String> {
    match fs::read_to_string(path) {
        Ok(raw) => Ok(Some(raw)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    let mut file = AtomicWriteFile::open(path).map_err(|e| e.to_string())?;
    file.write_all(bytes).map_err(|e| e.to_string())?;
    file.commit().map_err(|e| e.to_string())
}
fn write(path: &Path, json: &str, preserve: bool) -> Result<(), String> {
    let value: serde_json::Value = serde_json::from_str(json).map_err(|e| e.to_string())?;
    if !value.is_object() {
        return Err("数据必须是 JSON 对象".into());
    }
    fs::create_dir_all(path.parent().ok_or("数据目录无效")?).map_err(|e| e.to_string())?;
    if let Some(previous) = read(path)? {
        if preserve {
            let suffix = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|e| e.to_string())?
                .as_nanos();
            atomic_write(
                &path.with_extension(format!("import-backup-{suffix}.json")),
                previous.as_bytes(),
            )?;
        }
        // Preserve invalid originals separately, even across later writes.
        let backup = if serde_json::from_str::<serde_json::Value>(&previous).is_ok() {
            path.with_extension("previous.json")
        } else {
            path.with_extension("corrupt.json")
        };
        if !backup.exists() || backup == path.with_extension("previous.json") {
            atomic_write(&backup, previous.as_bytes())?;
        }
    }
    atomic_write(path, json.as_bytes())
}
#[derive(Default)]
pub struct StorageLock(Arc<Mutex<()>>);
#[tauri::command]
pub async fn read_data(
    app: tauri::AppHandle,
    lock: tauri::State<'_, StorageLock>,
    file: String,
) -> Result<Option<String>, String> {
    let target = path(&app, &file)?;
    let mutex = lock.0.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let _guard = mutex.lock().map_err(|_| "数据锁不可用")?;
        read(&target)
    })
    .await
    .map_err(|e| e.to_string())?
}
#[tauri::command]
pub async fn write_data(
    app: tauri::AppHandle,
    lock: tauri::State<'_, StorageLock>,
    file: String,
    json: String,
    preserve: bool,
) -> Result<(), String> {
    let target = path(&app, &file)?;
    let mutex = lock.0.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let _guard = mutex.lock().map_err(|_| "数据锁不可用")?;
        write(&target, &json, preserve)
    })
    .await
    .map_err(|e| e.to_string())?
}
#[cfg(test)]
mod tests {
    use super::*;
    fn dir() -> tempfile::TempDir {
        tempfile::tempdir().unwrap()
    }
    #[test]
    fn missing_file_is_empty() {
        let d = dir();
        assert_eq!(read(&d.path().join("sessions.json")).unwrap(), None);
    }
    #[test]
    fn replacement_preserves_previous() {
        let d = dir();
        let p = d.path().join("sessions.json");
        write(&p, "{\"records\":[]}", false).unwrap();
        write(&p, "{\"records\":[1]}", false).unwrap();
        assert_eq!(read(&p).unwrap().unwrap(), "{\"records\":[1]}");
        assert_eq!(
            read(&p.with_extension("previous.json")).unwrap().unwrap(),
            "{\"records\":[]}"
        );
    }
    #[test]
    fn invalid_write_never_overwrites() {
        let d = dir();
        let p = d.path().join("sessions.json");
        write(&p, "{}", false).unwrap();
        assert!(write(&p, "broken", false).is_err());
        assert!(write(&p, "[]", false).is_err());
        assert_eq!(read(&p).unwrap().unwrap(), "{}");
    }
    #[test]
    fn corrupt_original_survives_recovery_and_later_saves() {
        let d = dir();
        let p = d.path().join("sessions.json");
        fs::write(&p, "broken").unwrap();
        write(&p, "{}", false).unwrap();
        write(&p, "{\"ok\":true}", false).unwrap();
        assert_eq!(
            read(&p.with_extension("corrupt.json")).unwrap().unwrap(),
            "broken"
        );
    }
    #[test]
    fn import_backup_survives_following_saves() {
        let d = dir();
        let p = d.path().join("sessions.json");
        fs::write(&p, "{}").unwrap();
        write(&p, "{\"imported\":true}", true).unwrap();
        write(&p, "{\"later\":true}", false).unwrap();
        let backups: Vec<_> = fs::read_dir(d.path())
            .unwrap()
            .map(|e| e.unwrap().path())
            .filter(|p| p.to_string_lossy().contains("import-backup"))
            .collect();
        assert_eq!(backups.len(), 1);
        assert_eq!(read(&backups[0]).unwrap().unwrap(), "{}");
    }
    #[test]
    fn paths_are_restricted() {
        assert!(filename("../secret").is_err());
        assert!(filename("sessions").is_ok());
    }
}
