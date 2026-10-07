/**
 * TomatoBar Personal - Core Domain Data Types
 * 100% strictly compatible with macOS Swift State.swift schema and sessions.json
 */

export type FocusPhase = 'idle' | 'work' | 'rest' | 'workFinished' | 'restFinished';

export interface FocusSegment {
  start: string; // ISO 8601 string
  end: string;   // ISO 8601 string
}

export function segmentSeconds(segment: FocusSegment): number {
  const start = new Date(segment.start).getTime();
  const end = new Date(segment.end).getTime();
  return Math.max(0, (end - start) / 1000);
}

export interface FocusRecord {
  id: string; // UUID
  name: string;
  startedAt: string;
  endedAt: string;
  plannedSeconds: number;
  completed: boolean;
  segments: FocusSegment[];
  tags: string[];
  todoID?: string | null;
  projectID?: string | null;
}

export function recordSeconds(record: FocusRecord): number {
  return record.segments.reduce((acc, seg) => acc + segmentSeconds(seg), 0);
}

export function recordCategory(record: FocusRecord): string {
  return record.tags[0] || '未分类';
}

export interface FocusProject {
  id: string; // UUID
  name: string;
  tags: string[];
  color?: string | null;
  isArchived: boolean;
  createdAt: string;
}

export interface FocusTodo {
  id: string; // UUID
  title: string;
  isCompleted: boolean;
  createdAt: string;
  completedAt?: string | null;
  tags: string[];
  projectID?: string | null;
}

export interface FocusState {
  phase: FocusPhase;
  paused: boolean;
  name: string;
  startedAt?: string | null;
  segmentStart?: string | null;
  deadline?: string | null;
  remaining: number;
  planned: number;
  segments: FocusSegment[];
  rounds: number;
  records: FocusRecord[];
  todos: FocusTodo[];
  projects: FocusProject[];
  activeTodoID?: string | null;
  seriesTodoID?: string | null;
  currentTodoID?: string | null;
  draftTags: string[];
  activeTags: string[];
  checkpoint: string;
  categoryStyles?: Record<string, string>;
}

export function createDefaultFocusState(): FocusState {
  return {
    phase: 'idle',
    paused: false,
    name: '',
    startedAt: null,
    segmentStart: null,
    deadline: null,
    remaining: 25 * 60,
    planned: 25 * 60,
    segments: [],
    rounds: 0,
    records: [],
    todos: [],
    projects: [],
    activeTodoID: null,
    seriesTodoID: null,
    currentTodoID: null,
    draftTags: [],
    activeTags: [],
    checkpoint: new Date(0).toISOString(),
    categoryStyles: {},
  };
}

export function normalizeTags(tags: string[]): string[] {
  const result: string[] = [];
  for (const raw of tags) {
    const tag = raw.trim();
    if (tag && !result.some((t) => t.toLowerCase() === tag.toLowerCase())) {
      result.push(tag);
    }
  }
  return result;
}

export function parseInputWithTags(raw: string): { title: string; tags: string[] } {
  const parts = raw.split(/\s+/).filter(Boolean);
  const tags: string[] = [];
  const titleWords: string[] = [];

  for (const part of parts) {
    if (part.startsWith('#') && part.length > 1) {
      const tag = part.slice(1).trim();
      if (tag) tags.push(tag);
    } else {
      titleWords.push(part);
    }
  }

  const title = titleWords.join(' ').trim();
  return {
    title: title || raw.trim(),
    tags: normalizeTags(tags),
  };
}

export type PetKind = 'tomy' | 'sprout' | 'chip' | 'clay';

export interface PetConfig {
  kind: PetKind;
  visible: boolean;
  scale: number;
}
