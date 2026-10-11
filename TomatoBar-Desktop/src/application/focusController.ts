import type { FocusState } from "../types";
import { createDefaultFocusState } from "../types";
import type { IStorageProvider } from "../core/storage";
import type { AppSettings } from "../core/settings";
import { defaultSettings, decodeSettings, restSeconds } from "../core/settings";
import { decodeSessions } from "../core/sessionsCodec";
import { FocusStateMachine as Machine, isTiming } from "../core/stateMachine";

type Transition = (state: FocusState, now: Date) => FocusState;
export interface FocusSnapshot {
  state: FocusState;
  settings: AppSettings;
  ready: boolean;
  busy: boolean;
  error: string | null;
  reminder: boolean;
}
const errorMessage = (e: unknown) =>
  e instanceof Error ? e.message : String(e);

/** Single writer shared by React, the timer and native tray actions. */
export class FocusController {
  private snapshot: FocusSnapshot = {
    state: createDefaultFocusState(),
    settings: { ...defaultSettings },
    ready: false,
    busy: false,
    error: null,
    reminder: false,
  };
  private listeners = new Set<() => void>();
  private queue: Promise<unknown> = Promise.resolve();
  private initializing?: Promise<void>;
  private pending?: { state?: FocusState; settings?: AppSettings };
  private lastTick?: number;
  private tickQueued = false;
  private readonly repository: IStorageProvider;
  private readonly clock: () => Date;
  constructor(
    repository: IStorageProvider,
    clock: () => Date = () => new Date(),
  ) {
    this.repository = repository;
    this.clock = clock;
  }
  getSnapshot = () => this.snapshot;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private publish(changes: Partial<FocusSnapshot>) {
    this.snapshot = { ...this.snapshot, ...changes };
    this.listeners.forEach((fn) => fn());
  }
  initialize(): Promise<void> {
    return (this.initializing ??= this.load());
  }
  private async load() {
    this.publish({ busy: true, error: null });
    try {
      const settings = await this.repository.loadSettings();
      this.publish({ settings });
      const state = Machine.recover(await this.repository.load());
      // Startup also durably pauses an interrupted work OR rest session.
      await this.repository.save(state);
      await this.repository.saveSettings(settings);
      this.publish({
        state,
        settings,
        ready: true,
        reminder:
          state.phase === "workFinished" || state.phase === "restFinished",
      });
    } catch (e) {
      this.publish({
        ready: false,
        error: `读取或恢复数据失败：${errorMessage(e)}`,
      });
    } finally {
      this.publish({ busy: false });
    }
  }
  private serialize(operation: () => Promise<boolean>): Promise<boolean> {
    const result = this.queue.then(operation);
    this.queue = result.catch(() => {});
    return result;
  }
  transition(change: Transition, notifyFinished = true): Promise<boolean> {
    return this.serialize(async () => {
      if (!this.snapshot.ready || this.snapshot.error) return false;
      this.publish({ busy: true });
      let next: FocusState | undefined;
      try {
        next = change(this.snapshot.state, this.clock());
        if (next === this.snapshot.state) return true;
        await this.repository.save(next);
        const finished =
          next.phase === "workFinished" || next.phase === "restFinished";
        this.publish({
          state: next,
          reminder:
            finished &&
            notifyFinished &&
            (next.phase !== this.snapshot.state.phase ||
              this.snapshot.reminder),
        });
        this.lastTick = this.clock().getTime();
        return true;
      } catch (e) {
        // Edits remain uncommitted until retry succeeds; timing freezes at the checkpoint.
        if (next) this.pending = { state: Machine.recover(next) };
        this.publish({ error: `保存失败，计时操作已暂停：${errorMessage(e)}` });
        return false;
      } finally {
        this.publish({ busy: false });
      }
    });
  }
  startWork = () =>
    this.transition((s, now) =>
      Machine.startWork(
        s,
        s.name,
        s.draftTags,
        this.snapshot.settings.workMinutes * 60,
        s.currentTodoID ?? null,
        now,
      ),
    );
  pause = () => this.transition((s, now) => Machine.pause(s, now));
  resume = () => this.transition((s, now) => Machine.resume(s, now));
  stop = () => this.transition((s, now) => Machine.stopEarly(s, now));
  cancel = () => this.transition((s, now) => Machine.cancel(s, now));
  startRest = () =>
    this.transition((s, now) =>
      Machine.startRest(s, restSeconds(s.rounds, this.snapshot.settings), now),
    );
  skipRest = () => this.transition((s, now) => Machine.skipRest(s, now), false);
  dismissReminder = () => this.publish({ reminder: false });
  toggle = () =>
    isTiming(this.snapshot.state)
      ? this.snapshot.state.paused
        ? this.resume()
        : this.pause()
      : this.snapshot.state.phase === "workFinished"
        ? this.startRest()
        : this.startWork();

  tick(): Promise<boolean> {
    if (this.tickQueued) return Promise.resolve(false);
    this.tickQueued = true;
    return this.serialize(async () => {
      if (!this.snapshot.ready || this.snapshot.error) return false;
      const now = this.clock();
      const state = this.snapshot.state;
      const gap =
        this.lastTick === undefined ? 0 : now.getTime() - this.lastTick;
      this.lastTick = now.getTime();
      // WebView timers may suspend during Windows sleep. Never count that gap.
      const interrupted =
        isTiming(state) && !state.paused && (gap > 10_000 || gap < 0);
      const next = interrupted
        ? Machine.recover(state)
        : Machine.tick(state, now).nextState;
      if (next === state) return true;
      const persist =
        interrupted ||
        next.phase !== state.phase ||
        now.getTime() - Date.parse(state.checkpoint) >= 5000;
      if (!persist) {
        this.publish({ state: next });
        return true;
      }
      const saved = {
        ...next,
        checkpoint: interrupted ? next.checkpoint : now.toISOString(),
      };
      try {
        await this.repository.save(saved);
        this.publish({
          state: saved,
          reminder:
            next.phase !== state.phase &&
            (next.phase === "workFinished" || next.phase === "restFinished")
              ? true
              : this.snapshot.reminder,
        });
        return true;
      } catch (e) {
        this.pending = { state: Machine.pause(saved, now) };
        this.publish({
          state: Machine.recover(state),
          error: `计时记录未能保存：${errorMessage(e)}`,
        });
        return false;
      }
    }).finally(() => {
      this.tickQueued = false;
    });
  }
  updateSettings(changes: Partial<AppSettings>): Promise<boolean> {
    return this.serialize(async () => {
      if (!this.snapshot.ready || this.snapshot.error) return false;
      this.publish({ busy: true });
      let settings: AppSettings | undefined;
      try {
        settings = decodeSettings(
          JSON.stringify({ ...this.snapshot.settings, ...changes }),
        );
        await this.repository.saveSettings(settings);
        this.publish({ settings });
        return true;
      } catch (e) {
        if (settings)
          this.pending = {
            settings,
            state: Machine.recover(this.snapshot.state),
          };
        this.publish({ error: `设置未能保存：${errorMessage(e)}` });
        return false;
      } finally {
        this.publish({ busy: false });
      }
    });
  }
  importJSON(json: string): Promise<boolean> {
    return this.serialize(async () => {
      if (this.snapshot.busy) return false;
      const state = Machine.recover(decodeSessions(json));
      if (this.pending)
        throw new Error("有未保存修改，请先重试保存，再导入备份。");
      const settings = await this.repository.loadSettings();
      if (this.snapshot.ready && isTiming(this.snapshot.state))
        throw new Error("请先结束或取消当前计时，再导入数据。");
      this.publish({ busy: true });
      try {
        await this.repository.replace(state);
        this.pending = undefined;
        this.publish({
          state,
          settings,
          ready: true,
          error: null,
          reminder: false,
        });
        return true;
      } catch (e) {
        this.publish({ error: `导入数据未能保存：${errorMessage(e)}` });
        return false;
      } finally {
        this.publish({ busy: false });
      }
    });
  }
  restoreDefaultSettings(): Promise<boolean> {
    return this.serialize(async () => {
      if (this.snapshot.ready || this.snapshot.busy) return false;
      try {
        await this.repository.replaceSettings({ ...defaultSettings });
        await this.load();
        return this.snapshot.ready;
      } catch (e) {
        this.publish({ error: `设置恢复失败：${errorMessage(e)}` });
        return false;
      }
    });
  }
  retry(): Promise<boolean> {
    return this.serialize(async () => {
      if (!this.pending) {
        await this.load();
        return this.snapshot.ready;
      }
      this.publish({ busy: true });
      try {
        if (this.pending.state) await this.repository.save(this.pending.state);
        if (this.pending.settings)
          await this.repository.saveSettings(this.pending.settings);
        const state = this.pending.state ?? this.snapshot.state;
        this.publish({
          state,
          settings: this.pending.settings ?? this.snapshot.settings,
          error: null,
          reminder:
            state.phase === "workFinished" || state.phase === "restFinished",
        });
        this.pending = undefined;
        this.lastTick = this.clock().getTime();
        return true;
      } catch (e) {
        this.publish({ error: `重试保存失败：${errorMessage(e)}` });
        return false;
      } finally {
        this.publish({ busy: false });
      }
    });
  }
  async prepareQuit(): Promise<boolean> {
    if (this.snapshot.error || !this.snapshot.ready) return false;
    return this.pause();
  }
}
