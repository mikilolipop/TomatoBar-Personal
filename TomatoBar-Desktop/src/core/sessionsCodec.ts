import type {
  FocusState,
  FocusRecord,
  FocusSegment,
  FocusTodo,
  FocusProject,
} from "../types";
import { createDefaultFocusState, normalizeTags } from "../types";

const SWIFT_EPOCH = Date.UTC(2001, 0, 1);
const phases = ["idle", "work", "rest", "workFinished", "restFinished"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fail = (field: string): never => {
  throw new Error(`数据格式无效：${field}。原有数据未被修改。`);
};
function object(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    return fail(field);
  return value as Record<string, unknown>;
}
function string(value: unknown, field: string): string {
  return typeof value === "string" ? value : fail(field);
}
function number(value: unknown, field: string): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : fail(field);
}
function boolean(value: unknown, field: string): boolean {
  return typeof value === "boolean" ? value : fail(field);
}
function id(value: unknown, field: string): string {
  const s = string(value, field);
  return UUID.test(s) ? s : fail(field);
}
function optionalID(value: unknown, field: string): string | null {
  return value == null ? null : id(value, field);
}
function date(value: unknown, field: string): string {
  const ms =
    typeof value === "number"
      ? SWIFT_EPOCH + value * 1000
      : typeof value === "string"
        ? Date.parse(value)
        : NaN;
  return Number.isFinite(ms) && Math.abs(ms) <= 8640000000000000
    ? new Date(ms).toISOString()
    : fail(field);
}
function optionalDate(value: unknown, field: string): string | null {
  return value == null ? null : date(value, field);
}
function array<T>(
  value: unknown,
  field: string,
  parse: (v: unknown, f: string) => T,
): T[] {
  if (!Array.isArray(value)) return fail(field);
  return value.map((v, i) => parse(v, `${field}[${i}]`));
}
function tags(value: unknown, field: string): string[] {
  return normalizeTags(array(value ?? [], field, string));
}
function segments(value: unknown, field: string): FocusSegment[] {
  let previousEnd = -Infinity;
  return array(value, field, (v, f) => {
    const o = object(v, f);
    const start = date(o.start, `${f}.start`);
    const end = date(o.end, `${f}.end`);
    if (Date.parse(end) < Date.parse(start) || Date.parse(start) < previousEnd)
      return fail(f);
    previousEnd = Date.parse(end);
    return { start, end };
  });
}
function unique<T extends { id: string }>(values: T[], field: string): T[] {
  if (new Set(values.map((v) => v.id.toLowerCase())).size !== values.length)
    return fail(`${field} 包含重复 ID`);
  return values;
}
function record(value: unknown, field: string): FocusRecord {
  const o = object(value, field);
  const startedAt = date(o.startedAt, `${field}.startedAt`);
  const endedAt = date(o.endedAt, `${field}.endedAt`);
  const segs = segments(o.segments, `${field}.segments`);
  if (
    Date.parse(endedAt) < Date.parse(startedAt) ||
    segs.some(
      (s) =>
        Date.parse(s.start) < Date.parse(startedAt) ||
        Date.parse(s.end) > Date.parse(endedAt),
    )
  )
    return fail(field);
  return {
    id: id(o.id, `${field}.id`),
    name: string(o.name, `${field}.name`),
    startedAt,
    endedAt,
    plannedSeconds: number(o.plannedSeconds, `${field}.plannedSeconds`),
    completed: boolean(o.completed, `${field}.completed`),
    segments: segs,
    tags: tags(o.tags, `${field}.tags`),
    todoID: optionalID(o.todoID, `${field}.todoID`),
    projectID: optionalID(o.projectID, `${field}.projectID`),
  };
}
function todo(value: unknown, f: string): FocusTodo {
  const o = object(value, f);
  return {
    id: id(o.id, `${f}.id`),
    title: string(o.title, `${f}.title`),
    isCompleted: boolean(o.isCompleted, `${f}.isCompleted`),
    createdAt: date(o.createdAt, `${f}.createdAt`),
    completedAt: optionalDate(o.completedAt, `${f}.completedAt`),
    tags: tags(o.tags, `${f}.tags`),
    projectID: optionalID(o.projectID, `${f}.projectID`),
  };
}
function project(value: unknown, f: string): FocusProject {
  const o = object(value, f);
  return {
    id: id(o.id, `${f}.id`),
    name: string(o.name, `${f}.name`),
    tags: tags(o.tags, `${f}.tags`),
    color: o.color == null ? null : string(o.color, `${f}.color`),
    isArchived: boolean(o.isArchived, `${f}.isArchived`),
    createdAt: date(o.createdAt, `${f}.createdAt`),
  };
}

/** Accepts the earlier ISO desktop format and Swift JSONEncoder's numeric dates. */
export function decodeSessions(json: string): FocusState {
  const o = object(JSON.parse(json), "sessions");
  const phase = string(o.phase, "phase");
  if (!phases.includes(phase)) return fail("phase");
  const state: FocusState = {
    ...createDefaultFocusState(),
    phase: phase as FocusState["phase"],
    paused: boolean(o.paused, "paused"),
    name: string(o.name, "name"),
    startedAt: optionalDate(o.startedAt, "startedAt"),
    segmentStart: optionalDate(o.segmentStart, "segmentStart"),
    deadline: optionalDate(o.deadline, "deadline"),
    remaining: number(o.remaining, "remaining"),
    planned: number(o.planned, "planned"),
    segments: segments(o.segments, "segments"),
    rounds: number(o.rounds, "rounds"),
    records: unique(array(o.records, "records", record), "records"),
    todos: unique(array(o.todos ?? [], "todos", todo), "todos"),
    projects: unique(array(o.projects ?? [], "projects", project), "projects"),
    activeTodoID: optionalID(o.activeTodoID, "activeTodoID"),
    seriesTodoID: optionalID(o.seriesTodoID, "seriesTodoID"),
    currentTodoID: optionalID(o.currentTodoID, "currentTodoID"),
    draftTags: tags(o.draftTags, "draftTags"),
    activeTags: tags(o.activeTags, "activeTags"),
    checkpoint: date(o.checkpoint, "checkpoint"),
    categoryStyles: Object.fromEntries(
      Object.entries(object(o.categoryStyles ?? {}, "categoryStyles")).map(
        ([k, v]) => [k, string(v, `categoryStyles.${k}`)],
      ),
    ),
  };
  if (!Number.isInteger(state.rounds)) return fail("rounds");
  if (phase === "work" || phase === "rest") {
    if (
      state.planned <= 0 ||
      state.remaining > state.planned ||
      (!state.paused && !state.deadline) ||
      (phase === "work" && !state.startedAt)
    )
      return fail("计时状态");
    if (phase === "work" && !state.paused && !state.segmentStart)
      return fail("segmentStart");
    if (
      state.segmentStart &&
      Date.parse(state.segmentStart) > Date.parse(state.checkpoint)
    )
      return fail("checkpoint");
    if (
      state.deadline &&
      state.segmentStart &&
      Date.parse(state.deadline) < Date.parse(state.segmentStart)
    )
      return fail("deadline");
  }
  if (o.seriesTodoID === undefined)
    state.seriesTodoID =
      phase === "work"
        ? state.activeTodoID
        : phase !== "idle"
          ? (state.records[0]?.todoID ?? null)
          : null;
  return state;
}

const swiftDate = (value: string | null | undefined) =>
  value == null ? value : (Date.parse(value) - SWIFT_EPOCH) / 1000;
const swiftSegments = (values: FocusSegment[]) =>
  values.map((s) => ({ start: swiftDate(s.start), end: swiftDate(s.end) }));
/** Explicit date fields avoid treating arbitrary category names as date keys. */
export function encodeSessions(state: FocusState): string {
  return JSON.stringify(
    {
      ...state,
      startedAt: swiftDate(state.startedAt),
      segmentStart: swiftDate(state.segmentStart),
      deadline: swiftDate(state.deadline),
      checkpoint: swiftDate(state.checkpoint),
      segments: swiftSegments(state.segments),
      records: state.records.map((r) => ({
        ...r,
        startedAt: swiftDate(r.startedAt),
        endedAt: swiftDate(r.endedAt),
        segments: swiftSegments(r.segments),
      })),
      todos: state.todos.map((t) => ({
        ...t,
        createdAt: swiftDate(t.createdAt),
        completedAt: swiftDate(t.completedAt),
      })),
      projects: state.projects.map((p) => ({
        ...p,
        createdAt: swiftDate(p.createdAt),
      })),
    },
    null,
    2,
  );
}
