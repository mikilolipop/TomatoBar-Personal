import React, { useState, useEffect } from 'react';
import type { FocusState, PetKind, FocusTodo, FocusRecord } from './types';
import { createDefaultFocusState } from './types';
import { FocusStateMachine } from './core/stateMachine';
import { LocalStorageProvider } from './core/storage';
import type { FocusPeriod } from './core/analytics';
import { GardenOverview } from './components/GardenOverview';
import { ExpandedTimerModal } from './components/ExpandedTimerModal';
import { RecordEditorModal } from './components/RecordEditorModal';
import { SettingsModal } from './components/SettingsModal';
import { ReminderModal } from './components/ReminderModal';
import { HistoryList } from './components/HistoryList';
import { ChevronLeft } from 'lucide-react';

const storage = new LocalStorageProvider();

export const App: React.FC = () => {
  const [state, setState] = useState<FocusState>(createDefaultFocusState());
  const [isLoaded, setIsLoaded] = useState(false);

  // Nav tab: overview (Garden) or history
  const [activeTab, setActiveTab] = useState<'overview' | 'history'>('overview');

  // Period & Date filters for Garden
  const [period, setPeriod] = useState<FocusPeriod>('day');
  const [currentDate, setCurrentDate] = useState<Date>(new Date());

  // Modal dialog states
  const [showExpandedTimer, setShowExpandedTimer] = useState(false);
  const [editingRecord, setEditingRecord] = useState<FocusRecord | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showReminder, setShowReminder] = useState(false);

  // Settings
  const [workMinutes, setWorkMinutes] = useState(25);
  const [shortRestMinutes, setShortRestMinutes] = useState(5);
  const [longRestMinutes, setLongRestMinutes] = useState(15);
  const [petKind, setPetKind] = useState<PetKind>('tomy');
  const [showPet, setShowPet] = useState(true);

  // Load state on mount
  useEffect(() => {
    async function init() {
      const loaded = await storage.load();
      if (loaded.phase === 'work' && !loaded.paused) {
        // Interrupted session: pause to avoid overrun
        const pausedState = FocusStateMachine.pause(loaded, new Date());
        setState(pausedState);
      } else {
        setState(loaded);
      }
      setIsLoaded(true);

      const savedPet = localStorage.getItem('TomatoBar_petKind') as PetKind;
      if (savedPet) setPetKind(savedPet);
      const savedShowPet = localStorage.getItem('TomatoBar_showPet');
      if (savedShowPet !== null) setShowPet(savedShowPet === 'true');
    }
    init();
  }, []);

  // Persist state updates
  useEffect(() => {
    if (!isLoaded) return;
    storage.save(state).catch((e) => console.error('Save failed', e));
  }, [state, isLoaded]);

  // 1-second interval timer tick
  useEffect(() => {
    if (!isLoaded) return;

    const interval = window.setInterval(() => {
      setState((prev) => {
        if (prev.paused || prev.phase === 'idle') return prev;

        const { nextState, eventTriggered } = FocusStateMachine.tick(prev, new Date());
        if (eventTriggered) {
          setShowReminder(true);
        }
        return nextState;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [isLoaded]);

  // Actions
  const handleStartWork = () => {
    const currentTodo = state.todos.find((t) => t.id === state.currentTodoID);
    const taskName = currentTodo ? currentTodo.title : state.name || '专注时光';
    const taskTags = currentTodo ? currentTodo.tags : state.draftTags;

    const next = FocusStateMachine.startWork(
      state,
      taskName,
      taskTags,
      workMinutes * 60,
      state.currentTodoID,
      new Date()
    );
    setState(next);
    setShowExpandedTimer(true);
  };

  const handlePause = () => {
    setState((prev) => FocusStateMachine.pause(prev, new Date()));
  };

  const handleResume = () => {
    setState((prev) => FocusStateMachine.resume(prev, new Date()));
  };

  const handleStopEarly = () => {
    setState((prev) => FocusStateMachine.stopEarly(prev, new Date()));
  };

  const handleStartRest = (durationSec = shortRestMinutes * 60) => {
    setShowReminder(false);
    setState((prev) => FocusStateMachine.startRest(prev, durationSec, new Date()));
  };

  const handleSkipRest = () => {
    setShowReminder(false);
    setState((prev) => FocusStateMachine.skipRest(prev, new Date()));
  };

  const handleAddTodo = (title: string, tags: string[], projectID?: string | null) => {
    setState((prev) => FocusStateMachine.addTodo(prev, title, tags, projectID ?? null, new Date()));
  };

  const handleToggleTodo = (id: string) => {
    setState((prev) => FocusStateMachine.toggleTodo(prev, id, new Date()));
  };

  const handleDeleteTodo = (id: string) => {
    setState((prev) => FocusStateMachine.deleteTodo(prev, id, new Date()));
  };

  const handleSelectTodoForFocus = (todo: FocusTodo) => {
    setState((prev) => ({
      ...prev,
      currentTodoID: todo.id,
      name: todo.title,
      draftTags: todo.tags,
    }));
  };

  const handleAddProject = (name: string, tags: string[]) => {
    setState((prev) => FocusStateMachine.addProject(prev, name, tags, new Date()));
  };

  const handleDeleteProject = (id: string) => {
    setState((prev) => FocusStateMachine.deleteProject(prev, id, new Date()));
  };

  const handleSaveRecord = (id: string, name: string, tags: string[]) => {
    setState((prev) => FocusStateMachine.updateRecord(prev, id, { name, tags }, new Date()));
  };

  const handleDeleteRecord = (id: string) => {
    setState((prev) => FocusStateMachine.deleteRecord(prev, id, new Date()));
  };

  const handleExportData = () => {
    const jsonStr = storage.exportJSON(state);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sessions-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImportData = (imported: FocusState) => {
    setState(imported);
    storage.save(imported);
  };

  const handleUpdatePet = (kind: PetKind, show: boolean) => {
    setPetKind(kind);
    setShowPet(show);
    localStorage.setItem('TomatoBar_petKind', kind);
    localStorage.setItem('TomatoBar_showPet', String(show));
  };

  return (
    <div className="garden-app-wrapper">
      {activeTab === 'overview' ? (
        <GardenOverview
          state={state}
          period={period}
          currentDate={currentDate}
          onSetPeriod={setPeriod}
          onSetDate={setCurrentDate}
          onStartFocus={handleStartWork}
          onPause={handlePause}
          onResume={handleResume}
          onSkipRest={handleSkipRest}
          onOpenExpandedTimer={() => setShowExpandedTimer(true)}
          onOpenSettings={() => setShowSettings(true)}
          onSwitchTab={(tab) => setActiveTab(tab)}
          onAddTodo={handleAddTodo}
          onToggleTodo={handleToggleTodo}
          onDeleteTodo={handleDeleteTodo}
          onSelectTodoForFocus={handleSelectTodoForFocus}
          onAddProject={handleAddProject}
          onDeleteProject={handleDeleteProject}
          onEditRecord={(record) => setEditingRecord(record)}
        />
      ) : (
        <div className="garden-root">
          <div className="garden-window-topbar">
            <div className="mac-traffic-dots">
              <span className="dot dot-red" />
              <span className="dot dot-amber" />
              <span className="dot dot-green" />
              <span className="window-title-text">TomatoBar · 历史回顾</span>
            </div>

            <div className="garden-nav-tabs">
              <span className="brand-logo-text">TomatoBar</span>
              <button className="nav-link" onClick={() => setActiveTab('overview')}>
                概览
              </button>
              <button className="nav-link active" onClick={() => setActiveTab('history')}>
                历史
              </button>
            </div>

            <div className="garden-top-right">
              <button className="garden-btn-secondary" onClick={() => setActiveTab('overview')}>
                <ChevronLeft size={14} /> 返回概览
              </button>
            </div>
          </div>

          <div className="garden-divider-line" />

          <div style={{ padding: '24px 32px' }}>
            <HistoryList
              records={state.records}
              onUpdateRecord={(id, updates) =>
                setState((prev) => FocusStateMachine.updateRecord(prev, id, updates, new Date()))
              }
              onDeleteRecord={handleDeleteRecord}
            />
          </div>
        </div>
      )}

      {/* Expanded Timer Modal */}
      {showExpandedTimer && (
        <ExpandedTimerModal
          state={state}
          petKind={petKind}
          onStartWork={handleStartWork}
          onPause={handlePause}
          onResume={handleResume}
          onStopEarly={handleStopEarly}
          onStartRest={handleStartRest}
          onSkipRest={handleSkipRest}
          onClose={() => setShowExpandedTimer(false)}
        />
      )}

      {/* Record Editor Modal */}
      {editingRecord && (
        <RecordEditorModal
          record={editingRecord}
          onSave={handleSaveRecord}
          onDelete={handleDeleteRecord}
          onClose={() => setEditingRecord(null)}
        />
      )}

      {/* Settings Modal */}
      {showSettings && (
        <SettingsModal
          workMinutes={workMinutes}
          shortRestMinutes={shortRestMinutes}
          longRestMinutes={longRestMinutes}
          petKind={petKind}
          showPet={showPet}
          state={state}
          onUpdateDurations={(w, sr, lr) => {
            setWorkMinutes(w);
            setShortRestMinutes(sr);
            setLongRestMinutes(lr);
          }}
          onUpdatePet={handleUpdatePet}
          onExportData={handleExportData}
          onImportData={handleImportData}
          onClose={() => setShowSettings(false)}
        />
      )}

      {/* Silent Sticky Reminder Modal */}
      {showReminder && (
        <ReminderModal
          phase={state.phase}
          rounds={state.rounds}
          taskName={state.name}
          onStartRest={handleStartRest}
          onSkipRest={handleSkipRest}
          onStartWork={handleStartWork}
          onDismiss={() => setShowReminder(false)}
        />
      )}
    </div>
  );
};

export default App;
