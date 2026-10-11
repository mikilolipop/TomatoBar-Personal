/** Pure transitions: time is supplied by the caller, never sampled here. */
import type { FocusState, FocusRecord, FocusSegment } from "../types";
import { normalizeTags } from "../types";

export const isTiming = (s: FocusState) =>
  s.phase === "work" || s.phase === "rest";
export const canStartWork = (s: FocusState) =>
  s.phase === "idle" || s.phase === "restFinished";

export class FocusStateMachine {
  private static closeSegment(state: FocusState, now: Date): FocusSegment[] {
    if (!state.segmentStart) return state.segments;
    const start = Date.parse(state.segmentStart);
    const end = Math.max(
      start,
      Math.min(
        now.getTime(),
        state.deadline ? Date.parse(state.deadline) : now.getTime(),
      ),
    );
    return end > start
      ? [
          ...state.segments,
          { start: state.segmentStart, end: new Date(end).toISOString() },
        ]
      : state.segments;
  }

  private static record(
    state: FocusState,
    now: Date,
    completed: boolean,
  ): FocusRecord {
    return {
      id: crypto.randomUUID(),
      name: state.name.trim() || "未命名专注",
      startedAt: state.startedAt!,
      endedAt: now.toISOString(),
      plannedSeconds: state.planned,
      completed,
      segments: this.closeSegment(state, now),
      tags: state.activeTags,
      todoID: state.activeTodoID ?? null,
      projectID:
        state.todos.find((t) => t.id === state.activeTodoID)?.projectID ?? null,
    };
  }

  static startWork(
    state: FocusState,
    name: string,
    tags: string[],
    durationSeconds: number,
    todoID: string | null,
    now: Date,
  ): FocusState {
    if (
      !canStartWork(state) ||
      !Number.isFinite(durationSeconds) ||
      durationSeconds <= 0
    )
      return state;
    const id =
      todoID ??
      (state.phase === "restFinished"
        ? (state.seriesTodoID ?? state.currentTodoID)
        : state.currentTodoID);
    const todo = state.todos.find((t) => t.id === id && !t.isCompleted);
    const inherited = todo?.tags.length
      ? todo.tags
      : (state.projects.find((p) => p.id === todo?.projectID)?.tags ?? []);
    return {
      ...state,
      phase: "work",
      paused: false,
      name: todo?.title ?? (name.trim() || "未命名专注"),
      startedAt: now.toISOString(),
      segmentStart: now.toISOString(),
      deadline: new Date(now.getTime() + durationSeconds * 1000).toISOString(),
      planned: durationSeconds,
      remaining: durationSeconds,
      segments: [],
      activeTags: normalizeTags(todo ? inherited : tags),
      activeTodoID: todo?.id ?? null,
      seriesTodoID: todo?.id ?? null,
      checkpoint: now.toISOString(),
    };
  }

  static tick(
    state: FocusState,
    now: Date,
  ): {
    nextState: FocusState;
    eventTriggered?: "workFinished" | "restFinished";
  } {
    if (!isTiming(state) || state.paused || !state.deadline)
      return { nextState: state };
    const deadline = Date.parse(state.deadline);
    // Never complete half a second early by rounding the display value.
    if (now.getTime() < deadline)
      return {
        nextState: {
          ...state,
          remaining: Math.ceil((deadline - now.getTime()) / 1000),
        },
      };
    const phase = state.phase === "work" ? "workFinished" : "restFinished";
    return {
      nextState: {
        ...state,
        phase,
        paused: false,
        remaining: 0,
        segmentStart: null,
        deadline: null,
        startedAt: null,
        segments: [],
        activeTodoID: null,
        activeTags: [],
        rounds: state.rounds + (state.phase === "work" ? 1 : 0),
        records:
          state.phase === "work"
            ? [this.record(state, new Date(deadline), true), ...state.records]
            : state.records,
        checkpoint: now.toISOString(),
      },
      eventTriggered: phase,
    };
  }

  static pause(state: FocusState, now: Date): FocusState {
    const { nextState } = this.tick(state, now);
    if (!isTiming(nextState) || nextState.paused) return nextState;
    return {
      ...nextState,
      paused: true,
      segments:
        nextState.phase === "work"
          ? this.closeSegment(nextState, now)
          : nextState.segments,
      remaining: nextState.deadline
        ? Math.max(0, (Date.parse(nextState.deadline) - now.getTime()) / 1000)
        : nextState.remaining,
      segmentStart: null,
      deadline: null,
      checkpoint: now.toISOString(),
    };
  }

  static resume(state: FocusState, now: Date): FocusState {
    if (!isTiming(state) || !state.paused) return state;
    return {
      ...state,
      paused: false,
      segmentStart: state.phase === "work" ? now.toISOString() : null,
      deadline: new Date(now.getTime() + state.remaining * 1000).toISOString(),
      checkpoint: now.toISOString(),
    };
  }

  static recover(state: FocusState): FocusState {
    return isTiming(state) && !state.paused
      ? this.pause(state, new Date(state.checkpoint))
      : state;
  }

  static startRest(state: FocusState, seconds: number, now: Date): FocusState {
    if (
      state.phase !== "workFinished" ||
      !Number.isFinite(seconds) ||
      seconds <= 0
    )
      return state;
    return {
      ...state,
      phase: "rest",
      paused: false,
      planned: seconds,
      remaining: seconds,
      startedAt: now.toISOString(),
      segmentStart: null,
      segments: [],
      deadline: new Date(now.getTime() + seconds * 1000).toISOString(),
      checkpoint: now.toISOString(),
    };
  }

  static skipRest(state: FocusState, now: Date): FocusState {
    if (state.phase !== "rest" && state.phase !== "workFinished") return state;
    return {
      ...state,
      phase: "restFinished",
      paused: false,
      deadline: null,
      segmentStart: null,
      startedAt: null,
      segments: [],
      remaining: 0,
      checkpoint: now.toISOString(),
    };
  }

  static stopEarly(state: FocusState, now: Date): FocusState {
    const next = this.tick(state, now).nextState;
    const records =
      next.phase === "work" && next.startedAt
        ? [this.record(next, now, false), ...next.records]
        : next.records;
    return {
      ...next,
      phase: "idle",
      paused: false,
      deadline: null,
      segmentStart: null,
      startedAt: null,
      remaining: 0,
      planned: 0,
      segments: [],
      records,
      activeTodoID: null,
      seriesTodoID: null,
      activeTags: [],
      rounds: 0,
      checkpoint: now.toISOString(),
    };
  }

  static cancel(state: FocusState, now: Date): FocusState {
    if (state.phase !== "work") return state;
    return {
      ...state,
      phase: "idle",
      paused: false,
      deadline: null,
      segmentStart: null,
      startedAt: null,
      remaining: 0,
      planned: 0,
      segments: [],
      activeTodoID: null,
      seriesTodoID: null,
      activeTags: [],
      checkpoint: now.toISOString(),
    };
  }

  static selectTodo(
    state: FocusState,
    id: string | null,
    now: Date,
  ): FocusState {
    if (!canStartWork(state)) return state;
    const todo = state.todos.find((t) => t.id === id && !t.isCompleted);
    return {
      ...state,
      currentTodoID: todo?.id ?? null,
      seriesTodoID: null,
      name: todo?.title ?? "",
      draftTags: todo?.tags ?? [],
      checkpoint: now.toISOString(),
    };
  }

  static addTodo(
    state: FocusState,
    title: string,
    tags: string[],
    projectID: string | null,
    now: Date,
  ): FocusState {
    if (!title.trim()) return state;
    const project = state.projects.find(
      (p) => p.id === projectID && !p.isArchived,
    );
    return {
      ...state,
      todos: [
        ...state.todos,
        {
          id: crypto.randomUUID(),
          title: title.trim(),
          tags: normalizeTags(tags.length ? tags : (project?.tags ?? [])),
          projectID: project?.id ?? null,
          isCompleted: false,
          createdAt: now.toISOString(),
          completedAt: null,
        },
      ],
      checkpoint: now.toISOString(),
    };
  }

  static toggleTodo(state: FocusState, id: string, now: Date): FocusState {
    const completing = state.todos.some((t) => t.id === id && !t.isCompleted);
    return {
      ...state,
      todos: state.todos.map((t) =>
        t.id === id
          ? {
              ...t,
              isCompleted: !t.isCompleted,
              completedAt: t.isCompleted ? null : now.toISOString(),
            }
          : t,
      ),
      currentTodoID:
        completing && state.currentTodoID === id ? null : state.currentTodoID,
      seriesTodoID:
        completing && state.seriesTodoID === id ? null : state.seriesTodoID,
      checkpoint: now.toISOString(),
    };
  }

  static deleteTodo(state: FocusState, id: string, now: Date): FocusState {
    return {
      ...state,
      todos: state.todos.filter((t) => t.id !== id),
      currentTodoID: state.currentTodoID === id ? null : state.currentTodoID,
      seriesTodoID: state.seriesTodoID === id ? null : state.seriesTodoID,
      checkpoint: now.toISOString(),
    };
  }

  static updateRecord(
    state: FocusState,
    id: string,
    updates: Partial<Pick<FocusRecord, "name" | "tags">>,
    now: Date,
  ): FocusState {
    if (updates.name !== undefined && !updates.name.trim())
      throw new Error("事件名称不能为空。");
    if (!state.records.some((r) => r.id === id))
      throw new Error("这条记录已不存在，请重新打开记录列表。");
    return {
      ...state,
      records: state.records.map((r) =>
        r.id === id
          ? {
              ...r,
              name: updates.name?.trim() ?? r.name,
              tags: updates.tags ? normalizeTags(updates.tags) : r.tags,
            }
          : r,
      ),
      checkpoint: now.toISOString(),
    };
  }

  static deleteRecord(state: FocusState, id: string, now: Date): FocusState {
    return {
      ...state,
      records: state.records.filter((r) => r.id !== id),
      checkpoint: now.toISOString(),
    };
  }

  static addProject(
    state: FocusState,
    name: string,
    tags: string[],
    now: Date,
  ): FocusState {
    if (!name.trim()) return state;
    return {
      ...state,
      projects: [
        ...state.projects,
        {
          id: crypto.randomUUID(),
          name: name.trim(),
          tags: normalizeTags(tags),
          color: null,
          isArchived: false,
          createdAt: now.toISOString(),
        },
      ],
      checkpoint: now.toISOString(),
    };
  }

  static deleteProject(state: FocusState, id: string, now: Date): FocusState {
    return {
      ...state,
      projects: state.projects.filter((p) => p.id !== id),
      todos: state.todos.map((t) =>
        t.projectID === id ? { ...t, projectID: null } : t,
      ),
      checkpoint: now.toISOString(),
    };
  }
}
