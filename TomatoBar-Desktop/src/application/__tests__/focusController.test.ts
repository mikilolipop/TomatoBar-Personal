import { describe, it, expect } from "vitest";
import { FocusController } from "../focusController";
import type { FocusState } from "../../types";
import { createDefaultFocusState, recordSeconds } from "../../types";
import type { IStorageProvider } from "../../core/storage";
import {
  BrowserStorageTransport,
  FocusRepository,
  STORAGE_KEY,
} from "../../core/storage";
import { defaultSettings } from "../../core/settings";
import type { AppSettings } from "../../core/settings";
import { FocusStateMachine as M } from "../../core/stateMachine";
import { encodeSessions } from "../../core/sessionsCodec";
const startDate = new Date("2026-10-11T00:00:00Z");
class MemoryRepository implements IStorageProvider {
  state = createDefaultFocusState();
  settings = { ...defaultSettings };
  writes = 0;
  fail = false;
  loadError = false;
  async load() {
    if (this.loadError) throw new Error("invalid data");
    return structuredClone(this.state);
  }
  async save(state: FocusState) {
    if (this.fail) throw new Error("disk full");
    this.writes++;
    this.state = structuredClone(state);
  }
  async replace(state: FocusState) {
    return this.save(state);
  }
  async loadSettings() {
    return { ...this.settings };
  }
  async replaceSettings(settings: AppSettings) {
    return this.saveSettings(settings);
  }
  async saveSettings(settings: AppSettings) {
    if (this.fail) throw new Error("disk full");
    this.settings = { ...settings };
  }
}
async function setup() {
  const repository = new MemoryRepository();
  let seconds = 0;
  const controller = new FocusController(
    repository,
    () => new Date(startDate.getTime() + seconds * 1000),
  );
  await controller.initialize();
  return {
    controller,
    repository,
    at: (n: number) => {
      seconds = n;
    },
  };
}
describe("Single timer owner and durable transactions", () => {
  it("manual skip does not produce a second completion reminder", async () => {
    const { controller: c, at } = await setup();
    await c.transition((s, now) => M.startWork(s, "quick", [], 2, null, now));
    at(2);
    await c.tick();
    expect(c.getSnapshot().reminder).toBe(true);
    await c.startRest();
    expect(c.getSnapshot().reminder).toBe(false);
    await c.skipRest();
    expect(c.getSnapshot().state.phase).toBe("restFinished");
    expect(c.getSnapshot().reminder).toBe(false);
  });
  it("initializes once even under React StrictMode", async () => {
    const r = new MemoryRepository();
    const c = new FocusController(r);
    await Promise.all([c.initialize(), c.initialize()]);
    expect(r.writes).toBe(1);
  });
  it("blocks actions after corrupt load without writing empty data", async () => {
    const r = new MemoryRepository();
    r.loadError = true;
    const c = new FocusController(r);
    await c.initialize();
    expect(c.getSnapshot().ready).toBe(false);
    expect(await c.startWork()).toBe(false);
    expect(r.writes).toBe(0);
  });
  it("serializes simultaneous edits so neither task is lost", async () => {
    const { controller: c } = await setup();
    await Promise.all([
      c.transition((s, now) => M.addTodo(s, "A", [], null, now)),
      c.transition((s, now) => M.addTodo(s, "B", [], null, now)),
    ]);
    expect(c.getSnapshot().state.todos.map((t) => t.title)).toEqual(["A", "B"]);
  });
  it("never publishes an edit before persistence completes", async () => {
    const { controller: c, repository: r } = await setup();
    let release: () => void = () => {};
    const barrier = new Promise<void>((resolve) => {
      release = resolve;
    });
    const save = r.save.bind(r);
    r.save = async (state) => {
      await barrier;
      await save(state);
    };
    const pending = c.transition((s, now) =>
      M.addTodo(s, "transaction", [], null, now),
    );
    await Promise.resolve();
    expect(c.getSnapshot().state.todos).toHaveLength(0);
    release();
    await pending;
    expect(c.getSnapshot().state.todos).toHaveLength(1);
  });
  it("retains failed edits for retry and blocks further mutations", async () => {
    const { controller: c, repository: r } = await setup();
    r.fail = true;
    expect(
      await c.transition((s, now) => M.addTodo(s, "unsaved", [], null, now)),
    ).toBe(false);
    expect(c.getSnapshot().state.todos).toHaveLength(0);
    expect(c.getSnapshot().error).toContain("disk full");
    expect(await c.startWork()).toBe(false);
    r.fail = false;
    expect(await c.retry()).toBe(true);
    expect(c.getSnapshot().state.todos[0].title).toBe("unsaved");
  });
  it("stores checkpoints every five seconds, excluding offline recovery time", async () => {
    const { controller: c, repository: r, at } = await setup();
    await c.startWork();
    const writes = r.writes;
    for (let i = 1; i <= 4; i++) {
      at(i);
      await c.tick();
    }
    expect(r.writes).toBe(writes);
    at(5);
    await c.tick();
    expect(r.writes).toBe(writes + 1);
    const resumed = new FocusController(
      r,
      () => new Date("2026-10-12T00:00:00Z"),
    );
    await resumed.initialize();
    expect(resumed.getSnapshot().state.paused).toBe(true);
    expect(resumed.getSnapshot().state.remaining).toBe(1495);
  });
  it("treats a sleep-sized tick gap as an interrupted session", async () => {
    const { controller: c, at } = await setup();
    await c.startWork();
    at(5);
    await c.tick();
    at(1000);
    await c.tick();
    expect(c.getSnapshot().state.paused).toBe(true);
    expect(c.getSnapshot().state.remaining).toBe(1495);
  });
  it("keeps completion for retry after a failed save, emits no premature reminder", async () => {
    const { controller: c, repository: r, at } = await setup();
    await c.transition((s, now) => M.startWork(s, "quick", [], 5, null, now));
    r.fail = true;
    at(5);
    await c.tick();
    expect(c.getSnapshot().reminder).toBe(false);
    expect(c.getSnapshot().state.records).toHaveLength(0);
    r.fail = false;
    await c.retry();
    expect(c.getSnapshot().reminder).toBe(true);
    expect(recordSeconds(c.getSnapshot().state.records[0])).toBe(5);
  });
  it("quit pauses and saves first, and refuses to quit after persistence failure", async () => {
    const { controller: c, repository: r, at } = await setup();
    await c.startWork();
    at(20);
    expect(await c.prepareQuit()).toBe(true);
    expect(r.state.paused).toBe(true);
    expect(r.state.remaining).toBe(1480);
    await c.resume();
    r.fail = true;
    at(25);
    expect(await c.prepareQuit()).toBe(false);
  });
  it("persists settings and uses them for new rounds", async () => {
    const { controller: c, repository: r } = await setup();
    await c.updateSettings({
      workMinutes: 45,
      longRestMinutes: 20,
      showPet: false,
    });
    const restarted = new FocusController(r, () => startDate);
    await restarted.initialize();
    await restarted.startWork();
    expect(restarted.getSnapshot().state.planned).toBe(2700);
    expect(restarted.getSnapshot().settings.showPet).toBe(false);
  });
  it("import parses before writing and refuses replacement during a live timer", async () => {
    const { controller: c, repository: r } = await setup();
    const writes = r.writes;
    await expect(c.importJSON("{}")).rejects.toThrow();
    expect(r.writes).toBe(writes);
    await c.startWork();
    await expect(
      c.importJSON(encodeSessions(createDefaultFocusState())),
    ).rejects.toThrow("计时");
  });
  it("import durably recovers running data rather than starting its timer", async () => {
    const { controller: c } = await setup();
    const live = {
      ...M.startWork(
        createDefaultFocusState(),
        "import",
        [],
        1500,
        null,
        startDate,
      ),
      checkpoint: new Date(startDate.getTime() + 5000).toISOString(),
    };
    expect(await c.importJSON(encodeSessions(live))).toBe(true);
    expect(c.getSnapshot().state.paused).toBe(true);
    expect(c.getSnapshot().state.remaining).toBe(1495);
  });
});

class MemoryStorage implements Storage {
  private values = new Map<string, string>();
  length = 0;
  clear() {
    this.values.clear();
    this.length = 0;
  }
  getItem(key: string) {
    return this.values.get(key) ?? null;
  }
  key(index: number) {
    return [...this.values.keys()][index] ?? null;
  }
  removeItem(key: string) {
    this.values.delete(key);
    this.length = this.values.size;
  }
  setItem(key: string, value: string) {
    this.values.set(key, value);
    this.length = this.values.size;
  }
}
describe("Browser data protection", () => {
  it("restoring sessions preserves previously saved preferences after a corrupt read", async () => {
    const local = new MemoryStorage();
    local.setItem(STORAGE_KEY, "broken");
    local.setItem(
      "TomatoBarPersonal_settings",
      JSON.stringify({ ...defaultSettings, workMinutes: 45 }),
    );
    const c = new FocusController(
      new FocusRepository(new BrowserStorageTransport(local)),
    );
    await c.initialize();
    expect(c.getSnapshot().ready).toBe(false);
    await c.importJSON(encodeSessions(createDefaultFocusState()));
    expect(c.getSnapshot().settings.workMinutes).toBe(45);
    const backupKey = Array.from({ length: local.length }, (_, i) =>
      local.key(i),
    ).find((k) => k?.includes("_import_backup_"));
    expect(local.getItem(backupKey!)).toBe("broken");
  });
  it("restores corrupt settings only on explicit reset and preserves their original", async () => {
    const local = new MemoryStorage();
    local.setItem(STORAGE_KEY, encodeSessions(createDefaultFocusState()));
    const bad = JSON.stringify({ ...defaultSettings, workMinutes: -5 });
    local.setItem("TomatoBarPersonal_settings", bad);
    const c = new FocusController(
      new FocusRepository(new BrowserStorageTransport(local)),
    );
    await c.initialize();
    expect(c.getSnapshot().ready).toBe(false);
    expect(await c.restoreDefaultSettings()).toBe(true);
    expect(c.getSnapshot().ready).toBe(true);
    const backupKey = Array.from({ length: local.length }, (_, i) =>
      local.key(i),
    ).find((k) => k?.includes("settings_import_backup_"));
    expect(local.getItem(backupKey!)).toBe(bad);
  });
  it("preserves corrupt original and valid backup without silently overwriting either", async () => {
    const local = new MemoryStorage();
    local.setItem(STORAGE_KEY, "{broken");
    local.setItem(
      `${STORAGE_KEY}_backup`,
      encodeSessions(createDefaultFocusState()),
    );
    const repository = new FocusRepository(new BrowserStorageTransport(local));
    await expect(repository.load()).rejects.toThrow();
    expect(local.getItem(STORAGE_KEY)).toBe("{broken");
    expect(local.getItem(`${STORAGE_KEY}_backup`)).not.toBeNull();
  });
  it("migrates legacy pet preferences", async () => {
    const local = new MemoryStorage();
    local.setItem("TomatoBar_petKind", "sprout");
    local.setItem("TomatoBar_showPet", "false");
    const s = await new FocusRepository(
      new BrowserStorageTransport(local),
    ).loadSettings();
    expect(s.petKind).toBe("sprout");
    expect(s.showPet).toBe(false);
  });
});
