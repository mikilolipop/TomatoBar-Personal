import { describe, it, expect } from 'vitest';
import { FocusStateMachine } from '../stateMachine';
import { createDefaultFocusState, parseInputWithTags, segmentSeconds } from '../../types';
import { computeFocusSummary, formatDurationChinese } from '../analytics';


describe('FocusStateMachine Core Logic', () => {
  it('should parse user input with #tags properly', () => {
    const { title, tags } = parseInputWithTags('编写方案设计 #工作 #架构');
    expect(title).toBe('编写方案设计');
    expect(tags).toEqual(['工作', '架构']);

    const emptyTags = parseInputWithTags('纯文本任务');
    expect(emptyTags.title).toBe('纯文本任务');
    expect(emptyTags.tags).toEqual([]);
  });

  it('should start work session accurately', () => {
    const initial = createDefaultFocusState();
    const t0 = new Date('2026-10-07T10:00:00Z');
    const state = FocusStateMachine.startWork(initial, '测试工作', ['开发', '前端'], 25 * 60, 'todo-1', t0);

    expect(state.phase).toBe('work');
    expect(state.paused).toBe(false);
    expect(state.name).toBe('测试工作');
    expect(state.activeTags).toEqual(['开发', '前端']);
    expect(state.remaining).toBe(1500);
    expect(state.planned).toBe(1500);
    expect(state.activeTodoID).toBe('todo-1');
    expect(state.segmentStart).toBe(t0.toISOString());
    expect(state.deadline).toBe(new Date('2026-10-07T10:25:00Z').toISOString());
  });

  it('should handle pause and resume with segment recording', () => {
    const initial = createDefaultFocusState();
    const t0 = new Date('2026-10-07T10:00:00Z');
    let state = FocusStateMachine.startWork(initial, '设计任务', ['设计'], 1500, null, t0);

    // 10 minutes pass (600s)
    const t1 = new Date('2026-10-07T10:10:00Z');
    state = FocusStateMachine.pause(state, t1);

    expect(state.paused).toBe(true);
    expect(state.remaining).toBe(900);
    expect(state.segments.length).toBe(1);
    expect(segmentSeconds(state.segments[0])).toBe(600);
    expect(state.deadline).toBeNull();
    expect(state.segmentStart).toBeNull();

    // 5 minutes pause (10:15:00Z)
    const t2 = new Date('2026-10-07T10:15:00Z');
    state = FocusStateMachine.resume(state, t2);

    expect(state.paused).toBe(false);
    expect(state.segmentStart).toBe(t2.toISOString());
    expect(state.deadline).toBe(new Date('2026-10-07T10:30:00Z').toISOString()); // 900s remaining from 10:15
  });

  it('should complete work when deadline reached', () => {
    const initial = createDefaultFocusState();
    const t0 = new Date('2026-10-07T10:00:00Z');
    let state = FocusStateMachine.startWork(initial, '快速专注', ['写作'], 60, null, t0);

    // Tick at 30s
    const t1 = new Date('2026-10-07T10:00:30Z');
    const { nextState: state30 } = FocusStateMachine.tick(state, t1);
    expect(state30.remaining).toBe(30);
    expect(state30.phase).toBe('work');

    // Tick at 60s (deadline hit)
    const t2 = new Date('2026-10-07T10:01:00Z');
    const { nextState: finishedState, eventTriggered } = FocusStateMachine.tick(state30, t2);

    expect(eventTriggered).toBe('workFinished');
    expect(finishedState.phase).toBe('workFinished');
    expect(finishedState.rounds).toBe(1);
    expect(finishedState.records.length).toBe(1);
    expect(finishedState.records[0].name).toBe('快速专注');
    expect(finishedState.records[0].completed).toBe(true);
    expect(finishedState.records[0].tags).toEqual(['写作']);
    expect(segmentSeconds(finishedState.records[0].segments[0])).toBe(60);
  });

  it('should handle stopEarly properly: saves if >= 60s', () => {
    const initial = createDefaultFocusState();
    const t0 = new Date('2026-10-07T10:00:00Z');
    const state = FocusStateMachine.startWork(initial, '提前退出任务', ['代码'], 1500, null, t0);

    // Stop at 120s
    const t1 = new Date('2026-10-07T10:02:00Z');
    const stoppedState = FocusStateMachine.stopEarly(state, t1);

    expect(stoppedState.phase).toBe('idle');
    expect(stoppedState.records.length).toBe(1);
    expect(stoppedState.records[0].completed).toBe(false);
    expect(stoppedState.records[0].name).toContain('提前结束');
    expect(segmentSeconds(stoppedState.records[0].segments[0])).toBe(120);
  });

  it('should format durations correctly in Chinese', () => {
    expect(formatDurationChinese(45)).toBe('45秒');
    expect(formatDurationChinese(120)).toBe('2分钟');
    expect(formatDurationChinese(3600)).toBe('1小时');
    expect(formatDurationChinese(3720)).toBe('1小时2分');
  });

  it('should compute analytics summary accurately', () => {
    const r1 = {
      id: '1',
      name: '任务1',
      startedAt: '2026-10-07T09:00:00Z',
      endedAt: '2026-10-07T09:25:00Z',
      plannedSeconds: 1500,
      completed: true,
      segments: [{ start: '2026-10-07T09:00:00Z', end: '2026-10-07T09:25:00Z' }],
      tags: ['开发'],
    };
    const r2 = {
      id: '2',
      name: '任务2',
      startedAt: '2026-10-07T10:00:00Z',
      endedAt: '2026-10-07T10:25:00Z',
      plannedSeconds: 1500,
      completed: true,
      segments: [{ start: '2026-10-07T10:00:00Z', end: '2026-10-07T10:25:00Z' }],
      tags: ['设计'],
    };

    const summary = computeFocusSummary([r1, r2], 'day', new Date('2026-10-07T12:00:00Z'));
    expect(summary.totalSeconds).toBe(3000);
    expect(summary.categories.length).toBe(2);
    expect(summary.categories[0].seconds).toBe(1500);
  });
});
