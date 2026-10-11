import { describe, it, expect } from "vitest";
import {
  createDefaultFocusState,
  recordSeconds,
  normalizeTags,
} from "../../types";
import { FocusStateMachine as M } from "../stateMachine";
import { decodeSessions, encodeSessions } from "../sessionsCodec";
import { defaultSettings, decodeSettings, restSeconds } from "../settings";
import { getCategoryColor, GardenPalette } from "../garden";
import { computeFocusSummary, shiftPeriodDate } from "../analytics";

const t = new Date("2026-10-11T00:00:00Z");
const at = (seconds: number) => new Date(t.getTime() + seconds * 1000);
const start = () =>
  M.startWork(
    createDefaultFocusState(),
    "专注测试",
    ["学习", "辅助"],
    1500,
    null,
    t,
  );
const finished = () => M.tick(start(), at(1500)).nextState;

describe("Timer reliability", () => {
  it.each(["work", "rest"] as const)(
    "recovers %s at saved checkpoint, excluding all offline time",
    (phase) => {
      let s =
        phase === "work" ? start() : M.startRest(finished(), 300, at(1500));
      s = { ...s, checkpoint: at(phase === "work" ? 120 : 1620).toISOString() };
      const recovered = M.recover(s);
      expect(recovered.paused).toBe(true);
      expect(recovered.deadline).toBeNull();
      expect(recovered.remaining).toBe(phase === "work" ? 1380 : 180);
      expect(
        recovered.segments.reduce(
          (sum, seg) =>
            sum + (Date.parse(seg.end) - Date.parse(seg.start)) / 1000,
          0,
        ),
      ).toBe(phase === "work" ? 120 : 0);
      expect(M.recover(recovered)).toBe(recovered);
    },
  );
  it("does not finish before the deadline, including subsecond pauses", () => {
    const s = start();
    expect(M.tick(s, at(1499.8)).nextState.phase).toBe("work");
    const paused = M.pause(s, at(0.25));
    expect(paused.remaining).toBe(1499.75);
    const resumed = M.resume(paused, at(100));
    expect(Date.parse(resumed.deadline!)).toBe(at(1599.75).getTime());
  });
  it("caps a delayed tick and records completion once", () => {
    const s = M.tick(start(), at(5000)).nextState;
    expect(recordSeconds(s.records[0])).toBe(1500);
    expect(s.records[0].endedAt).toBe(at(1500).toISOString());
    expect(M.tick(s, at(8000)).nextState.records).toHaveLength(1);
  });
  it("pause at/after deadline completes instead of creating a paused zero timer", () => {
    const s = M.pause(start(), at(1600));
    expect(s.phase).toBe("workFinished");
    expect(s.paused).toBe(false);
  });
  it("stop at deadline keeps a completed record rather than duplicating an incomplete record", () => {
    const s = M.stopEarly(start(), at(1600));
    expect(s.records).toHaveLength(1);
    expect(s.records[0].completed).toBe(true);
  });
  it("pause intervals never enter actual focus duration", () => {
    let s = M.pause(start(), at(100));
    s = M.resume(s, at(500));
    s = M.stopEarly(s, at(600));
    expect(recordSeconds(s.records[0])).toBe(200);
  });
  it("ending a short session keeps it; cancelling a long session discards it", () => {
    expect(recordSeconds(M.stopEarly(start(), at(12)).records[0])).toBe(12);
    expect(M.cancel(start(), at(600)).records).toHaveLength(0);
  });
  it("skip rest preserves rounds and requires an explicit next start", () => {
    const s = M.skipRest(M.startRest(finished(), 300, at(1500)), at(1550));
    expect(s.phase).toBe("restFinished");
    expect(s.rounds).toBe(1);
    expect(s.records).toHaveLength(1);
  });
  it("guards destructive invalid phase transitions", () => {
    const s = start();
    expect(M.startWork(s, "replacement", [], 300, null, at(5))).toBe(s);
    expect(M.startRest(s, 300, at(5))).toBe(s);
    expect(M.skipRest(s, at(5))).toBe(s);
    const done = finished();
    expect(M.resume(done, at(1600))).toBe(done);
  });
  it.each([0, -1, NaN, Infinity])("rejects invalid duration %s", (duration) => {
    const idle = createDefaultFocusState();
    expect(M.startWork(idle, "x", [], duration, null, t)).toBe(idle);
  });
});

describe("Task attribution", () => {
  function task() {
    let s = M.addProject(createDefaultFocusState(), "大任务", ["开发"], t);
    s = M.addTodo(s, "子任务", [], s.projects[0].id, t);
    s = M.selectTodo(s, s.todos[0].id, t);
    return M.startWork(s, "", [], 60, s.todos[0].id, t);
  }
  it("inherits project tags and attributes finished records to both task and project", () => {
    const s = task();
    const done = M.tick(s, at(60)).nextState;
    expect(done.records[0].tags).toEqual(["开发"]);
    expect(done.records[0].projectID).toBe(s.projects[0].id);
    expect(done.records[0].todoID).toBe(s.todos[0].id);
  });
  it("does not switch the running task or overwrite its frozen tags", () => {
    const s = task();
    expect(M.selectTodo(s, null, at(1))).toBe(s);
    expect(M.tick(s, at(60)).nextState.records[0].tags).toEqual(["开发"]);
  });
  it("completing a selected task clears the next target but preserves running attribution", () => {
    const s = task();
    const completed = M.toggleTodo(s, s.todos[0].id, at(10));
    expect(completed.currentTodoID).toBeNull();
    expect(completed.seriesTodoID).toBeNull();
    expect(completed.activeTodoID).toBe(s.todos[0].id);
  });
  it("deleting a project detaches tasks without rewriting historical records", () => {
    const done = M.tick(task(), at(60)).nextState;
    const deleted = M.deleteProject(done, done.projects[0].id, at(61));
    expect(deleted.todos[0].projectID).toBeNull();
    expect(deleted.records).toBe(done.records);
  });
  it("rejects empty names and edits to missing records", () => {
    const s = finished();
    expect(() =>
      M.updateRecord(s, s.records[0].id, { name: " " }, t),
    ).toThrow();
    expect(() =>
      M.updateRecord(s, crypto.randomUUID(), { name: "new" }, t),
    ).toThrow();
  });
});

describe("Sessions codec", () => {
  it("round-trips actual Swift dates and arbitrary category names safely", () => {
    const s = {
      ...finished(),
      categoryStyles: { start: "book|3", checkpoint: "@auto|4" },
    };
    const json = encodeSessions(s);
    const raw = JSON.parse(json);
    expect(typeof raw.records[0].startedAt).toBe("number");
    expect(raw.records[0].startedAt).toBe(
      (t.getTime() - Date.UTC(2001, 0, 1)) / 1000,
    );
    expect(decodeSessions(json)).toEqual(s);
  });
  it("reads older Windows ISO dates and missing optional collections/tags", () => {
    const raw = JSON.parse(JSON.stringify(finished()));
    delete raw.todos;
    delete raw.projects;
    delete raw.records[0].tags;
    delete raw.categoryStyles;
    const result = decodeSessions(JSON.stringify(raw));
    expect(result.todos).toEqual([]);
    expect(result.records[0].tags).toEqual([]);
  });
  it.each(["null", "[]", "{}", "{broken"])(
    "rejects %s rather than inventing an empty state",
    (json) => {
      expect(() => decodeSessions(json)).toThrow();
    },
  );
  it.each(["bad date", -Infinity, {}])("rejects malformed dates", (invalid) => {
    const s = JSON.parse(JSON.stringify(finished()));
    s.records[0].startedAt = invalid;
    expect(() => decodeSessions(JSON.stringify(s))).toThrow();
  });
  it("rejects duplicate IDs and invalid segments before import", () => {
    const s = finished();
    expect(() =>
      decodeSessions(
        JSON.stringify({ ...s, records: [...s.records, ...s.records] }),
      ),
    ).toThrow();
    const raw = JSON.parse(JSON.stringify(s));
    raw.records[0].segments[0].end = at(-1).toISOString();
    expect(() => decodeSessions(JSON.stringify(raw))).toThrow();
  });
  it("rejects wrong tag types and non-UUID identifiers instead of fabricating replacements", () => {
    const s = finished();
    expect(() =>
      decodeSessions(JSON.stringify({ ...s, draftTags: [23] })),
    ).toThrow();
    expect(() =>
      decodeSessions(
        JSON.stringify({ ...s, records: [{ ...s.records[0], id: "invalid" }] }),
      ),
    ).toThrow();
  });
  it("rejects impossible running state", () => {
    expect(() =>
      decodeSessions(JSON.stringify({ ...start(), deadline: null })),
    ).toThrow();
  });
});

describe("Settings and calendar", () => {
  it("normalizes tags without counting each tag as a separate classification", () => {
    expect(normalizeTags(["Work", " work ", "design", ""])).toEqual([
      "Work",
      "design",
    ]);
  });
  it("uses saved durations and every-fourth long rest", () => {
    const s = { ...defaultSettings, shortRestMinutes: 3, longRestMinutes: 20 };
    expect(restSeconds(3, s)).toBe(180);
    expect(restSeconds(4, s)).toBe(1200);
    expect(restSeconds(0, s)).toBe(180);
  });
  it.each([0, -5, 200, 2.5])("rejects invalid setting %s", (n) => {
    expect(() =>
      decodeSettings(JSON.stringify({ ...defaultSettings, workMinutes: n })),
    ).toThrow();
  });
  it("reads macOS symbol|palette styles", () => {
    expect(getCategoryColor("work", { work: "book|3" })).toBe(
      GardenPalette[3].hex,
    );
  });
  it("clamps month navigation at the last day", () => {
    const result = shiftPeriodDate(new Date(2026, 0, 31), "month", 1);
    expect(result.getMonth()).toBe(1);
    expect(result.getDate()).toBe(28);
  });
  it("splits cross-midnight work into local calendar days and counts only the first tag", () => {
    const a = new Date(2026, 9, 11, 23, 50);
    const b = new Date(2026, 9, 12, 0, 10);
    const s = M.tick(
      M.startWork(
        createDefaultFocusState(),
        "跨日",
        ["主分类", "辅助"],
        1200,
        null,
        a,
      ),
      b,
    );
    const one = computeFocusSummary(s.nextState.records, "day", a);
    const two = computeFocusSummary(s.nextState.records, "day", b);
    expect(one.totalSeconds).toBe(600);
    expect(two.totalSeconds).toBe(600);
    expect(one.categories).toHaveLength(1);
  });
});
