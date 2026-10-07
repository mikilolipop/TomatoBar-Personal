import React, { useState, useEffect } from 'react';
import type { FocusState, PetKind, FocusTodo } from './types';
import { createDefaultFocusState } from './types';
import { FocusStateMachine } from './core/stateMachine';
import { LocalStorageProvider } from './core/storage';
import { TimerCard } from './components/TimerCard';
import { TaskInput } from './components/TaskInput';
import { TodoList } from './components/TodoList';
import { AnalyticsView } from './components/AnalyticsView';
import { HistoryList } from './components/HistoryList';
import { DesktopPet } from './components/DesktopPet';
import { ReminderModal } from './components/ReminderModal';
import { SettingsModal } from './components/SettingsModal';
import { Timer, BarChart3, History, Settings } from 'lucide-react';

const storage = new LocalStorageProvider();

export const App: React.FC = () => {
  const [state, setState] = useState<FocusState>(createDefaultFocusState());
  const [isLoaded, setIsLoaded] = useState(false);

  // Nav tab
  const [activeTab, setActiveTab] = useState<'timer' | 'analytics' | 'history'>('timer');

  // Modal dialogs
  const [showSettings, setShowSettings] = useState(false);
  const [showReminder, setShowReminder] = useState(false);

  // Settings
  const [workMinutes, setWorkMinutes] = useState(25);
  const [shortRestMinutes, setShortRestMinutes] = useState(5);
  const [longRestMinutes, setLongRestMinutes] = useState(15);
  const [petKind, setPetKind] = useState<PetKind>('tomy');
  const [showPet, setShowPet] = useState(true);

  // Draft inputs
  const [taskName, setTaskName] = useState('');
  const [taskTags, setTaskTags] = useState<string[]>([]);

  // Load state on mount
  useEffect(() => {
    async function init() {
      const loaded = await storage.load();
      // Recover interrupted state if needed
      if (loaded.phase === 'work' && !loaded.paused) {
        // Mark as paused on reload to prevent accidental overrun
        const pausedState = FocusStateMachine.pause(loaded, new Date());
        setState(pausedState);
      } else {
        setState(loaded);
      }
      setIsLoaded(true);

      // Load pet settings
      const savedPet = localStorage.getItem('TomatoBar_petKind') as PetKind;
      if (savedPet) setPetKind(savedPet);
      const savedShowPet = localStorage.getItem('TomatoBar_showPet');
      if (savedShowPet !== null) setShowPet(savedShowPet === 'true');
    }
    init();
  }, []);

  // Save state whenever it updates (once loaded)
  useEffect(() => {
    if (!isLoaded) return;
    storage.save(state).catch((e) => console.error('Save failed', e));
  }, [state, isLoaded]);

  // Main 1-second timer tick loop
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
    const next = FocusStateMachine.startWork(
      state,
      taskName || state.name,
      taskTags.length > 0 ? taskTags : state.draftTags,
      workMinutes * 60,
      state.currentTodoID,
      new Date()
    );
    setState(next);
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

  const handleAddTodo = (title: string, tags: string[]) => {
    setState((prev) => FocusStateMachine.addTodo(prev, title, tags, null, new Date()));
  };

  const handleToggleTodo = (id: string) => {
    setState((prev) => FocusStateMachine.toggleTodo(prev, id, new Date()));
  };

  const handleDeleteTodo = (id: string) => {
    setState((prev) => FocusStateMachine.deleteTodo(prev, id, new Date()));
  };

  const handleSelectTodoForFocus = (todo: FocusTodo) => {
    setTaskName(todo.title);
    setTaskTags(todo.tags);
    setState((prev) => ({
      ...prev,
      currentTodoID: todo.id,
      name: todo.title,
      draftTags: todo.tags,
    }));
  };

  const handleUpdateRecord = (id: string, updates: any) => {
    setState((prev) => FocusStateMachine.updateRecord(prev, id, updates, new Date()));
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

  // Known tags for autocomplete
  const knownTags = Array.from(
    new Set([
      ...state.records.flatMap((r) => r.tags),
      ...state.todos.flatMap((t) => t.tags),
      ...state.draftTags,
      ...taskTags,
    ])
  ).filter(Boolean);

  return (
    <div className="app-container">
      {/* Top Brand & Navigation Header */}
      <header className="app-header">
        <div className="brand-section">
          <img src="/icons/icon_128x128@2x.png" alt="TomatoBar Logo" className="brand-logo" />
          <span className="brand-title">TomatoBar</span>
          <span className="brand-tag">Windows</span>
        </div>

        <div className="nav-and-settings">
          <nav className="nav-tabs">
            <button
              className={`nav-tab-btn ${activeTab === 'timer' ? 'active' : ''}`}
              onClick={() => setActiveTab('timer')}
            >
              <Timer size={15} /> 专注时钟
            </button>
            <button
              className={`nav-tab-btn ${activeTab === 'analytics' ? 'active' : ''}`}
              onClick={() => setActiveTab('analytics')}
            >
              <BarChart3 size={15} /> 复盘统计
            </button>
            <button
              className={`nav-tab-btn ${activeTab === 'history' ? 'active' : ''}`}
              onClick={() => setActiveTab('history')}
            >
              <History size={15} /> 历史记录
            </button>
          </nav>

          <button
            className="settings-btn"
            onClick={() => setShowSettings(true)}
            title="偏好设置 & 数据管理"
          >
            <Settings size={17} />
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="app-main-content">
        {activeTab === 'timer' && (
          <div className="main-view-grid">
            <div className="timer-column">
              <TimerCard
                state={state}
                onStartWork={handleStartWork}
                onPause={handlePause}
                onResume={handleResume}
                onStopEarly={handleStopEarly}
                onStartRest={handleStartRest}
                onSkipRest={handleSkipRest}
              />

              <TaskInput
                currentName={taskName}
                currentTags={taskTags}
                knownTags={knownTags}
                onCommit={(name, tags) => {
                  setTaskName(name);
                  setTaskTags(tags);
                  setState((prev) => ({
                    ...prev,
                    name: name || prev.name,
                    draftTags: tags,
                  }));
                }}
                disabled={state.phase === 'work'}
              />
            </div>

            <div className="todo-column">
              <TodoList
                todos={state.todos}
                activeTodoID={state.activeTodoID}
                onAddTodo={handleAddTodo}
                onToggleTodo={handleToggleTodo}
                onDeleteTodo={handleDeleteTodo}
                onSelectTodoForFocus={handleSelectTodoForFocus}
              />
            </div>
          </div>
        )}

        {activeTab === 'analytics' && <AnalyticsView records={state.records} />}

        {activeTab === 'history' && (
          <HistoryList
            records={state.records}
            onUpdateRecord={handleUpdateRecord}
            onDeleteRecord={handleDeleteRecord}
          />
        )}
      </main>

      {/* Floating Desktop Pet Widget */}
      {showPet && (
        <DesktopPet
          kind={petKind}
          phase={state.phase}
          paused={state.paused}
          size={100}
          floating={true}
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
    </div>
  );
};

export default App;
