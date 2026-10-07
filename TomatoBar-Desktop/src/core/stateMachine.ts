/**
 * TomatoBar Personal - Domain State Machine
 * Implements segment-based timing, deadline bounding, and atomic state transitions.
 * All mutation functions take an explicit `now: Date` parameter for 100% determinism.
 */

import type {
  FocusState,
  FocusRecord,
  FocusSegment,
  FocusTodo,
} from '../types';
import {
  normalizeTags,
  segmentSeconds,
} from '../types';

export function generateUUID(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export class FocusStateMachine {
  /**
   * Closes the active segment if one is open, bounding by deadline.
   */
  private static closeActiveSegment(state: FocusState, now: Date): FocusSegment[] {
    if (!state.segmentStart) return [...state.segments];
    const segStart = new Date(state.segmentStart).getTime();
    const nowTime = now.getTime();
    const deadTime = state.deadline ? new Date(state.deadline).getTime() : nowTime;
    const boundedEnd = Math.min(nowTime, deadTime);

    if (boundedEnd > segStart) {
      const newSeg: FocusSegment = {
        start: new Date(segStart).toISOString(),
        end: new Date(boundedEnd).toISOString(),
      };
      return [...state.segments, newSeg];
    }
    return [...state.segments];
  }

  /**
   * Start a work (pomodoro) focus session
   */
  static startWork(
    state: FocusState,
    name: string,
    tags: string[],
    durationSeconds = 25 * 60,
    todoID: string | null = null,
    now: Date = new Date()
  ): FocusState {
    const normTags = normalizeTags(tags);
    const deadline = new Date(now.getTime() + durationSeconds * 1000).toISOString();

    return {
      ...state,
      phase: 'work',
      paused: false,
      name: name.trim() || '未命名专注',
      startedAt: now.toISOString(),
      segmentStart: now.toISOString(),
      deadline,
      planned: durationSeconds,
      remaining: durationSeconds,
      segments: [],
      activeTags: normTags,
      activeTodoID: todoID,
      seriesTodoID: todoID ?? state.seriesTodoID,
      currentTodoID: todoID ?? state.currentTodoID,
      checkpoint: now.toISOString(),
    };
  }

  /**
   * Pause the active focus or rest timer
   */
  static pause(state: FocusState, now: Date = new Date()): FocusState {
    if (state.paused || state.phase === 'idle' || state.phase === 'workFinished' || state.phase === 'restFinished') {
      return state;
    }

    const segments = state.phase === 'work' ? this.closeActiveSegment(state, now) : state.segments;
    let remaining = state.remaining;
    if (state.deadline) {
      const deadTime = new Date(state.deadline).getTime();
      remaining = Math.max(0, Math.round((deadTime - now.getTime()) / 1000));
    }

    return {
      ...state,
      paused: true,
      segmentStart: null,
      deadline: null,
      remaining,
      segments,
      checkpoint: now.toISOString(),
    };
  }

  /**
   * Resume a paused focus or rest timer
   */
  static resume(state: FocusState, now: Date = new Date()): FocusState {
    if (!state.paused || state.phase === 'idle') {
      return state;
    }

    const deadline = new Date(now.getTime() + state.remaining * 1000).toISOString();

    return {
      ...state,
      paused: false,
      segmentStart: state.phase === 'work' ? now.toISOString() : null,
      deadline,
      checkpoint: now.toISOString(),
    };
  }

  /**
   * Regular 1-second interval tick to advance countdown & auto-finish
   */
  static tick(state: FocusState, now: Date = new Date()): { nextState: FocusState; eventTriggered?: 'workFinished' | 'restFinished' } {
    if (state.paused || state.phase === 'idle' || state.phase === 'workFinished' || state.phase === 'restFinished') {
      return { nextState: state };
    }

    if (!state.deadline) {
      return { nextState: state };
    }

    const deadTime = new Date(state.deadline).getTime();
    const remaining = Math.max(0, Math.round((deadTime - now.getTime()) / 1000));

    if (remaining > 0) {
      return {
        nextState: {
          ...state,
          remaining,
          checkpoint: now.toISOString(),
        },
      };
    }

    // Time is up!
    if (state.phase === 'work') {
      const segments = this.closeActiveSegment(state, new Date(deadTime));
      const record: FocusRecord = {
        id: generateUUID(),
        name: state.name || '未命名专注',
        startedAt: state.startedAt || now.toISOString(),
        endedAt: new Date(deadTime).toISOString(),
        plannedSeconds: state.planned,
        completed: true,
        segments,
        tags: state.activeTags,
        todoID: state.activeTodoID,
        projectID: null,
      };

      return {
        nextState: {
          ...state,
          phase: 'workFinished',
          paused: false,
          remaining: 0,
          segmentStart: null,
          deadline: null,
          segments: [],
          rounds: state.rounds + 1,
          records: [record, ...state.records],
          checkpoint: now.toISOString(),
        },
        eventTriggered: 'workFinished',
      };
    }

    if (state.phase === 'rest') {
      return {
        nextState: {
          ...state,
          phase: 'restFinished',
          paused: false,
          remaining: 0,
          segmentStart: null,
          deadline: null,
          checkpoint: now.toISOString(),
        },
        eventTriggered: 'restFinished',
      };
    }

    return { nextState: state };
  }

  /**
   * Start a rest interval (short rest 5m or long rest 15m)
   */
  static startRest(state: FocusState, durationSeconds = 5 * 60, now: Date = new Date()): FocusState {
    const deadline = new Date(now.getTime() + durationSeconds * 1000).toISOString();

    return {
      ...state,
      phase: 'rest',
      paused: false,
      planned: durationSeconds,
      remaining: durationSeconds,
      startedAt: now.toISOString(),
      segmentStart: null,
      deadline,
      checkpoint: now.toISOString(),
    };
  }

  /**
   * Skip rest and return to idle
   */
  static skipRest(state: FocusState, _now: Date = new Date()): FocusState {
    return {
      ...state,
      phase: 'idle',
      paused: false,
      deadline: null,
      remaining: 25 * 60,
      planned: 25 * 60,
      checkpoint: _now.toISOString(),
    };
  }

  /**
   * Stop work early
   */
  static stopEarly(state: FocusState, now: Date = new Date()): FocusState {
    if (state.phase === 'work') {
      const segments = this.closeActiveSegment(state, now);
      const totalSec = segments.reduce((sum, s) => sum + segmentSeconds(s), 0);

      // If user worked for at least 60s, keep an incomplete record
      let updatedRecords = state.records;
      if (totalSec >= 60) {
        const incompleteRecord: FocusRecord = {
          id: generateUUID(),
          name: (state.name || '未命名专注') + ' (提前结束)',
          startedAt: state.startedAt || now.toISOString(),
          endedAt: now.toISOString(),
          plannedSeconds: state.planned,
          completed: false,
          segments,
          tags: state.activeTags,
          todoID: state.activeTodoID,
          projectID: null,
        };
        updatedRecords = [incompleteRecord, ...state.records];
      }

      return {
        ...state,
        phase: 'idle',
        paused: false,
        segmentStart: null,
        deadline: null,
        remaining: 25 * 60,
        planned: 25 * 60,
        segments: [],
        records: updatedRecords,
        activeTodoID: null,
        checkpoint: now.toISOString(),
      };
    }

    return {
      ...state,
      phase: 'idle',
      paused: false,
      segmentStart: null,
      deadline: null,
      remaining: 25 * 60,
      planned: 25 * 60,
      checkpoint: now.toISOString(),
    };
  }

  // MARK: - Todo Actions

  static addTodo(
    state: FocusState,
    title: string,
    tags: string[] = [],
    projectID: string | null = null,
    now: Date = new Date()
  ): FocusState {
    const cleanTitle = title.trim();
    if (!cleanTitle) return state;

    const newTodo: FocusTodo = {
      id: generateUUID(),
      title: cleanTitle,
      isCompleted: false,
      createdAt: now.toISOString(),
      tags: normalizeTags(tags),
      projectID,
    };

    return {
      ...state,
      todos: [newTodo, ...state.todos],
      checkpoint: now.toISOString(),
    };
  }

  static toggleTodo(state: FocusState, todoID: string, now: Date = new Date()): FocusState {
    const updated = state.todos.map((todo) => {
      if (todo.id === todoID) {
        const isCompleted = !todo.isCompleted;
        return {
          ...todo,
          isCompleted,
          completedAt: isCompleted ? now.toISOString() : null,
        };
      }
      return todo;
    });

    return {
      ...state,
      todos: updated,
      checkpoint: now.toISOString(),
    };
  }

  static deleteTodo(state: FocusState, todoID: string, now: Date = new Date()): FocusState {
    return {
      ...state,
      todos: state.todos.filter((t) => t.id !== todoID),
      activeTodoID: state.activeTodoID === todoID ? null : state.activeTodoID,
      seriesTodoID: state.seriesTodoID === todoID ? null : state.seriesTodoID,
      currentTodoID: state.currentTodoID === todoID ? null : state.currentTodoID,
      checkpoint: now.toISOString(),
    };
  }

  // MARK: - History Record Actions

  static updateRecord(
    state: FocusState,
    recordID: string,
    updates: Partial<Pick<FocusRecord, 'name' | 'tags'>>,
    now: Date = new Date()
  ): FocusState {
    const updated = state.records.map((r) => {
      if (r.id === recordID) {
        return {
          ...r,
          name: updates.name !== undefined ? updates.name.trim() : r.name,
          tags: updates.tags !== undefined ? normalizeTags(updates.tags) : r.tags,
        };
      }
      return r;
    });

    return {
      ...state,
      records: updated,
      checkpoint: now.toISOString(),
    };
  }

  static deleteRecord(state: FocusState, recordID: string, now: Date = new Date()): FocusState {
    return {
      ...state,
      records: state.records.filter((r) => r.id !== recordID),
      checkpoint: now.toISOString(),
    };
  }
}
