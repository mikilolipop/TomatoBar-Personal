mod desktop;
mod storage;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _, _| {
            desktop::show_main(app)
        }))
        .manage(storage::StorageLock::default())
        .invoke_handler(tauri::generate_handler![
            storage::read_data,
            storage::write_data,
            desktop::set_reminder,
            desktop::quit_app
        ])
        .setup(|app| {
            desktop::setup(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                // Windows close hides the window; the single timer owner stays alive.
                api.prevent_close();
                if let Err(error) = window.hide() {
                    log::error!("Cannot hide window: {error}");
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running TomatoBar Personal");
}
