import type { FocusState } from "../types";
import { createDefaultFocusState } from "../types";
import { decodeSessions, encodeSessions } from "./sessionsCodec";
import { decodeSettings, defaultSettings } from "./settings";
import type { AppSettings } from "./settings";

export interface StorageTransport {
  read(file: "sessions" | "settings"): Promise<string | null>;
  write(
    file: "sessions" | "settings",
    json: string,
    preserve?: boolean,
  ): Promise<void>;
}
export interface IStorageProvider {
  load(): Promise<FocusState>;
  save(state: FocusState): Promise<void>;
  replace(state: FocusState): Promise<void>;
  loadSettings(): Promise<AppSettings>;
  saveSettings(settings: AppSettings): Promise<void>;
  replaceSettings(settings: AppSettings): Promise<void>;
}
export const STORAGE_KEY = "TomatoBarPersonal_sessions";
const SETTINGS_KEY = "TomatoBarPersonal_settings";

/** No silent empty-state or backup fallback: failed reads must block writes. */
export class FocusRepository implements IStorageProvider {
  private readonly transport: StorageTransport;
  constructor(transport: StorageTransport) {
    this.transport = transport;
  }
  async load() {
    const raw = await this.transport.read("sessions");
    return raw === null ? createDefaultFocusState() : decodeSessions(raw);
  }
  async save(state: FocusState) {
    await this.transport.write("sessions", encodeSessions(state));
  }
  async replace(state: FocusState) {
    await this.transport.write("sessions", encodeSessions(state), true);
  }
  async loadSettings() {
    const raw = await this.transport.read("settings");
    return raw === null ? { ...defaultSettings } : decodeSettings(raw);
  }
  async replaceSettings(settings: AppSettings) {
    await this.transport.write(
      "settings",
      JSON.stringify(decodeSettings(JSON.stringify(settings)), null, 2),
      true,
    );
  }
  async saveSettings(settings: AppSettings) {
    await this.transport.write(
      "settings",
      JSON.stringify(decodeSettings(JSON.stringify(settings)), null, 2),
    );
  }
}

export class BrowserStorageTransport implements StorageTransport {
  private readonly storage: Storage;
  constructor(storage: Storage) {
    this.storage = storage;
  }
  async read(file: "sessions" | "settings") {
    const raw = this.storage.getItem(
      file === "sessions" ? STORAGE_KEY : SETTINGS_KEY,
    );
    if (file === "settings" && raw === null) {
      const kind = this.storage.getItem("TomatoBar_petKind");
      const visible = this.storage.getItem("TomatoBar_showPet");
      if (kind !== null || visible !== null)
        return JSON.stringify({
          ...defaultSettings,
          petKind: kind === "sprout" ? "sprout" : "tomy",
          showPet: visible !== "false",
        });
    }
    return raw;
  }
  async write(file: "sessions" | "settings", json: string, preserve = false) {
    const key = file === "sessions" ? STORAGE_KEY : SETTINGS_KEY;
    const previous = this.storage.getItem(key);
    if (preserve && previous !== null)
      this.storage.setItem(
        `${key}_import_backup_${crypto.randomUUID()}`,
        previous,
      );
    if (previous !== null) this.storage.setItem(`${key}_backup`, previous);
    this.storage.setItem(key, json);
  }
}
