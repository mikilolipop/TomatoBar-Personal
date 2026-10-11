import { useState, useEffect } from "react";
import type { FocusRecord, FocusTodo } from "./types";
import type { FocusPeriod } from "./core/analytics";
import { FocusStateMachine as Machine, isTiming } from "./core/stateMachine";
import { restSeconds } from "./core/settings";
import { encodeSessions } from "./core/sessionsCodec";
import { createRepository, desktop } from "./platform/desktop";
import { FocusController } from "./application/focusController";
import { useFocusController } from "./hooks/useFocusController";
import { GardenOverview } from "./components/GardenOverview";
import { ExpandedTimerModal } from "./components/ExpandedTimerModal";
import { RecordEditorModal } from "./components/RecordEditorModal";
import { SettingsModal } from "./components/SettingsModal";
import { ReminderModal } from "./components/ReminderModal";
import { HistoryList } from "./components/HistoryList";
import { WindowHeader } from "./components/WindowHeader";
import { DesktopPet } from "./components/DesktopPet";

const controller = new FocusController(createRepository());
export default function App() {
  const { state, settings, ready, busy, error, reminder } =
    useFocusController(controller);
  const [activeTab, setActiveTab] = useState<"overview" | "history">(
    "overview",
  );
  const [period, setPeriod] = useState<FocusPeriod>("day");
  const [currentDate, setCurrentDate] = useState(() => new Date());
  const [showTimer, setShowTimer] = useState(false);
  const [editingRecord, setEditingRecord] = useState<FocusRecord | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [desktopError, setDesktopError] = useState<string | null>(null);
  const restMinutes = restSeconds(state.rounds, settings) / 60;

  useEffect(() => {
    let disposed = false;
    const cleanups: (() => void)[] = [];
    const bind = async () => {
      for (const subscribe of [
        () =>
          desktop.onQuit(() => {
            void controller
              .prepareQuit()
              .then((saved) => (saved ? desktop.quit() : undefined))
              .catch((e) => setDesktopError(String(e)));
          }),
        () =>
          desktop.onToggle(() => {
            void controller.toggle();
          }),
      ]) {
        const cleanup = await subscribe();
        if (disposed) cleanup();
        else cleanups.push(cleanup);
      }
    };
    void bind().catch((e) => setDesktopError(String(e)));
    return () => {
      disposed = true;
      cleanups.forEach((fn) => fn());
    };
  }, []);
  useEffect(() => {
    void (reminder ? desktop.showReminder() : desktop.dismissReminder()).catch(
      (e) => setDesktopError(`窗口提醒未能更新：${String(e)}`),
    );
  }, [reminder]);

  const startWork = () => {
    void controller.startWork().then((saved) => {
      if (saved) setShowTimer(true);
    });
  };
  const exportData = () => {
    const url = URL.createObjectURL(
      new Blob([encodeSessions(state)], { type: "application/json" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = "sessions.json";
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  const saveRecord = (id: string, name: string, tags: string[]) =>
    controller.transition((s, now) =>
      Machine.updateRecord(s, id, { name, tags }, now),
    );
  const deleteRecord = (id: string) =>
    controller.transition((s, now) => Machine.deleteRecord(s, id, now));
  const selectTodo = (todo: FocusTodo) => {
    void controller.transition((s, now) => Machine.selectTodo(s, todo.id, now));
  };
  const blocked = !ready || busy || !!error;
  const displayState =
    state.phase === "idle"
      ? { ...state, remaining: settings.workMinutes * 60 }
      : state;

  return (
    <div className="garden-app-wrapper">
      {(error || desktopError) && (
        <div className="app-status-banner" role="alert">
          <span>{error || desktopError}</span>
          {error && (
            <>
              <button
                onClick={() => {
                  void controller.retry();
                }}
                disabled={busy}
              >
                重试
              </button>
              <button onClick={() => setShowSettings(true)}>备份与恢复</button>
            </>
          )}
          {desktopError && !error && (
            <button onClick={() => setDesktopError(null)}>关闭提示</button>
          )}
        </div>
      )}
      {!ready && !error && (
        <div className="app-status-banner" role="status">
          正在读取本地记录…
        </div>
      )}
      <main inert={blocked} aria-busy={busy}>
        <div className="garden-root">
          <WindowHeader
            tab={activeTab}
            onTab={setActiveTab}
            onSettings={() => setShowSettings(true)}
          />
          <div className="garden-divider-line" />
          {activeTab === "overview" ? (
            <GardenOverview
              state={displayState}
              period={period}
              currentDate={currentDate}
              onSetPeriod={setPeriod}
              onSetDate={setCurrentDate}
              onStartFocus={startWork}
              onPause={() => {
                void controller.pause();
              }}
              onResume={() => {
                void controller.resume();
              }}
              onStartRest={() => {
                void controller.startRest();
              }}
              onSkipRest={() => {
                void controller.skipRest();
              }}
              onOpenExpandedTimer={() => setShowTimer(true)}
              restMinutes={restMinutes}
              onAddTodo={(title, tags, projectID) => {
                void controller.transition((s, now) =>
                  Machine.addTodo(s, title, tags, projectID ?? null, now),
                );
              }}
              onToggleTodo={(id) => {
                void controller.transition((s, now) =>
                  Machine.toggleTodo(s, id, now),
                );
              }}
              onDeleteTodo={(id) => {
                void controller.transition((s, now) =>
                  Machine.deleteTodo(s, id, now),
                );
              }}
              onSelectTodoForFocus={selectTodo}
              onAddProject={(name, tags) => {
                void controller.transition((s, now) =>
                  Machine.addProject(s, name, tags, now),
                );
              }}
              onDeleteProject={(id) => {
                void controller.transition((s, now) =>
                  Machine.deleteProject(s, id, now),
                );
              }}
              onEditRecord={setEditingRecord}
              onFreeFocus={() => {
                void controller.transition((s, now) =>
                  Machine.selectTodo(s, null, now),
                );
              }}
            />
          ) : (
            <div className="history-page">
              <HistoryList
                records={state.records}
                onEditRecord={setEditingRecord}
                onDeleteRecord={(id) => {
                  void deleteRecord(id);
                }}
              />
            </div>
          )}
        </div>
      </main>
      {ready &&
        settings.showPet &&
        !showTimer &&
        !showSettings &&
        !editingRecord &&
        !reminder && (
          <DesktopPet
            kind={settings.petKind}
            phase={state.phase}
            paused={state.paused}
            size={80}
            floating
          />
        )}
      {showTimer && (
        <ExpandedTimerModal
          state={displayState}
          petKind={settings.petKind}
          restMinutes={restMinutes}
          busy={blocked}
          onStartWork={startWork}
          onPause={() => {
            void controller.pause();
          }}
          onResume={() => {
            void controller.resume();
          }}
          onStopEarly={() => {
            void controller.stop();
          }}
          onCancel={() => {
            void controller.cancel();
          }}
          onStartRest={() => {
            void controller.startRest();
          }}
          onSkipRest={() => {
            void controller.skipRest();
          }}
          onClose={() => setShowTimer(false)}
        />
      )}
      {editingRecord && (
        <RecordEditorModal
          record={editingRecord}
          onSave={saveRecord}
          onDelete={deleteRecord}
          onClose={() => setEditingRecord(null)}
        />
      )}
      {showSettings && (
        <SettingsModal
          settings={settings}
          state={state}
          canExport={ready}
          busy={busy}
          error={error}
          onUpdateSettings={(changes) => controller.updateSettings(changes)}
          onExportData={exportData}
          onImportData={(json) => controller.importJSON(json)}
          onRestoreDefaults={() => controller.restoreDefaultSettings()}
          onClose={() => setShowSettings(false)}
        />
      )}
      {reminder && (
        <ReminderModal
          phase={state.phase}
          rounds={state.rounds}
          taskName={state.name}
          workMinutes={settings.workMinutes}
          restMinutes={restMinutes}
          busy={blocked}
          onStartRest={() => {
            void controller.startRest();
          }}
          onSkipRest={() => {
            void controller.skipRest();
          }}
          onStartWork={startWork}
          onDismiss={controller.dismissReminder}
        />
      )}
      {isTiming(state) && (
        <span className="visually-hidden" role="status">
          {state.paused
            ? "计时已暂停"
            : state.phase === "work"
              ? "正在专注"
              : "正在休息"}
        </span>
      )}
    </div>
  );
}
