import { invoke, isTauri } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { FocusRepository, BrowserStorageTransport } from "../core/storage";
import type { StorageTransport } from "../core/storage";

class NativeStorageTransport implements StorageTransport {
  async read(file: "sessions" | "settings") {
    const raw = await invoke<string | null>("read_data", { file });
    // First native launch migrates the earlier WebView data; the original stays intact.
    return raw ?? new BrowserStorageTransport(window.localStorage).read(file);
  }
  write(file: "sessions" | "settings", json: string, preserve = false) {
    return invoke<void>("write_data", { file, json, preserve });
  }
}

/** Only this adapter depends on Tauri. The browser preview never accesses native data. */
export function createRepository() {
  return new FocusRepository(
    isTauri()
      ? new NativeStorageTransport()
      : new BrowserStorageTransport(window.localStorage),
  );
}
export const desktop = {
  isNative: isTauri,
  async onTick(handler: () => void) {
    return isTauri() ? listen("focus-tick", handler) : () => {};
  },
  async showReminder() {
    if (isTauri()) await invoke("set_reminder", { visible: true });
  },
  async dismissReminder() {
    if (isTauri()) await invoke("set_reminder", { visible: false });
  },
  async quit() {
    if (isTauri()) await invoke("quit_app");
  },
  async onQuit(handler: () => void) {
    return isTauri() ? listen("request-quit", handler) : () => {};
  },
  async onToggle(handler: () => void) {
    return isTauri() ? listen("toggle-timer", handler) : () => {};
  },
};
