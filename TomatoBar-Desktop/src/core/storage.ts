/**
 * TomatoBar Personal - Pluggable Storage Layer
 * Supports LocalStorage (Web/Dev mode) and Desktop Native File I/O.
 * Fully compatible with macOS sessions.json schema, with atomic write and recovery.
 */

import type { FocusState } from '../types';
import { createDefaultFocusState, normalizeTags } from '../types';

export interface IStorageProvider {
  load(): Promise<FocusState>;
  save(state: FocusState): Promise<void>;
  exportJSON(state: FocusState): string;
  importJSON(jsonString: string): FocusState;
}

const STORAGE_KEY = 'TomatoBarPersonal_sessions';
const BACKUP_KEY = 'TomatoBarPersonal_sessions_backup';

export class LocalStorageProvider implements IStorageProvider {
  async load(): Promise<FocusState> {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        return createDefaultFocusState();
      }

      const parsed = JSON.parse(raw);
      return this.sanitizeState(parsed);
    } catch (err) {
      console.error('[Storage] Failed to load state, attempting backup recovery', err);
      try {
        const backupRaw = localStorage.getItem(BACKUP_KEY);
        if (backupRaw) {
          const parsed = JSON.parse(backupRaw);
          return this.sanitizeState(parsed);
        }
      } catch (backupErr) {
        console.error('[Storage] Backup recovery failed', backupErr);
      }
      return createDefaultFocusState();
    }
  }

  async save(state: FocusState): Promise<void> {
    try {
      const serialized = JSON.stringify(state, null, 2);
      // Keep previous as backup before overwriting (similar to atomic write logic)
      const existing = localStorage.getItem(STORAGE_KEY);
      if (existing) {
        localStorage.setItem(BACKUP_KEY, existing);
      }
      localStorage.setItem(STORAGE_KEY, serialized);
    } catch (err) {
      console.error('[Storage] Failed to save state to localStorage', err);
      throw err;
    }
  }

  exportJSON(state: FocusState): string {
    return JSON.stringify(state, null, 2);
  }

  importJSON(jsonString: string): FocusState {
    const parsed = JSON.parse(jsonString);
    return this.sanitizeState(parsed);
  }

  /**
   * Sanitizes and migrates old format records/todos to ensure full compatibility
   */
  private sanitizeState(data: any): FocusState {
    const defaults = createDefaultFocusState();
    if (!data || typeof data !== 'object') return defaults;

    const records = Array.isArray(data.records)
      ? data.records.map((r: any) => ({
          id: r.id || crypto.randomUUID(),
          name: r.name || '未命名专注',
          startedAt: r.startedAt || new Date().toISOString(),
          endedAt: r.endedAt || new Date().toISOString(),
          plannedSeconds: Number(r.plannedSeconds) || 1500,
          completed: Boolean(r.completed),
          segments: Array.isArray(r.segments) ? r.segments : [],
          tags: normalizeTags(Array.isArray(r.tags) ? r.tags : []),
          todoID: r.todoID || null,
          projectID: r.projectID || null,
        }))
      : [];

    const todos = Array.isArray(data.todos)
      ? data.todos.map((t: any) => ({
          id: t.id || crypto.randomUUID(),
          title: t.title || '',
          isCompleted: Boolean(t.isCompleted),
          createdAt: t.createdAt || new Date().toISOString(),
          completedAt: t.completedAt || null,
          tags: normalizeTags(Array.isArray(t.tags) ? t.tags : []),
          projectID: t.projectID || null,
        }))
      : [];

    const projects = Array.isArray(data.projects)
      ? data.projects.map((p: any) => ({
          id: p.id || crypto.randomUUID(),
          name: p.name || '',
          tags: normalizeTags(Array.isArray(p.tags) ? p.tags : []),
          color: p.color || null,
          isArchived: Boolean(p.isArchived),
          createdAt: p.createdAt || new Date().toISOString(),
        }))
      : [];

    return {
      phase: ['idle', 'work', 'rest', 'workFinished', 'restFinished'].includes(data.phase) ? data.phase : 'idle',
      paused: Boolean(data.paused),
      name: typeof data.name === 'string' ? data.name : '',
      startedAt: data.startedAt || null,
      segmentStart: data.segmentStart || null,
      deadline: data.deadline || null,
      remaining: typeof data.remaining === 'number' ? data.remaining : 1500,
      planned: typeof data.planned === 'number' ? data.planned : 1500,
      segments: Array.isArray(data.segments) ? data.segments : [],
      rounds: typeof data.rounds === 'number' ? data.rounds : 0,
      records,
      todos,
      projects,
      activeTodoID: data.activeTodoID || null,
      seriesTodoID: data.seriesTodoID || null,
      currentTodoID: data.currentTodoID || null,
      draftTags: normalizeTags(Array.isArray(data.draftTags) ? data.draftTags : []),
      activeTags: normalizeTags(Array.isArray(data.activeTags) ? data.activeTags : []),
      checkpoint: data.checkpoint || new Date(0).toISOString(),
      categoryStyles: data.categoryStyles && typeof data.categoryStyles === 'object' ? data.categoryStyles : {},
    };
  }
}
