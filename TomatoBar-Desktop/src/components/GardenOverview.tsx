import React, { useState } from 'react';
import type { FocusRecord, FocusState, FocusTodo } from '../types';
import { parseInputWithTags } from '../types';
import type { FocusPeriod } from '../core/analytics';
import { computeFocusSummary, formatDurationChinese, formatTimeRange, getRecordCategory } from '../core/analytics';
import { getCategoryColor, GardenTokens } from '../core/garden';
import {
  Settings,
  ChevronLeft,
  ChevronRight,
  Plus,
  ChevronDown,
  Folder,
  Circle,
  CheckCircle2,
  Play,
  MoreHorizontal,
  Maximize2,
  FolderPlus,
  BookOpen,
  Hammer,
  Paintbrush,
  Headphones,
  FileText,
  Tag as TagIcon,
  X,
  Target,
} from 'lucide-react';

interface GardenOverviewProps {
  state: FocusState;
  period: FocusPeriod;
  currentDate: Date;
  onSetPeriod: (p: FocusPeriod) => void;
  onSetDate: (d: Date) => void;
  onStartFocus: () => void;
  onPause: () => void;
  onResume: () => void;
  onSkipRest: () => void;
  onOpenExpandedTimer: () => void;
  onOpenSettings: () => void;
  onSwitchTab: (tab: 'overview' | 'history') => void;
  onAddTodo: (title: string, tags: string[], projectID?: string | null) => void;
  onToggleTodo: (id: string) => void;
  onDeleteTodo: (id: string) => void;
  onSelectTodoForFocus: (todo: FocusTodo) => void;
  onAddProject: (name: string, tags: string[]) => void;
  onDeleteProject: (id: string) => void;
  onEditRecord: (record: FocusRecord) => void;
}

export const GardenOverview: React.FC<GardenOverviewProps> = ({
  state,
  period,
  currentDate,
  onSetPeriod,
  onSetDate,
  onStartFocus,
  onPause,
  onResume,
  onSkipRest,
  onOpenExpandedTimer,
  onOpenSettings,
  onSwitchTab,
  onAddTodo,
  onToggleTodo,
  onDeleteTodo,
  onSelectTodoForFocus,
  onAddProject,
  onDeleteProject,
  onEditRecord,
}) => {
  const [newTodoInput, setNewTodoInput] = useState('');
  const [collapsedProjects, setCollapsedProjects] = useState<Set<string>>(new Set());
  const [showNewProjectDialog, setShowNewProjectDialog] = useState(false);
  const [newProjectName, setNewProjectName] = useState('');
  const [newProjectTags, setNewProjectTags] = useState('');

  const summary = computeFocusSummary(state.records, period, currentDate);

  const currentTodo = state.todos.find((t) => t.id === state.currentTodoID);
  const currentProject = currentTodo?.projectID
    ? state.projects.find((p) => p.id === currentTodo.projectID)
    : null;

  const handlePrevDate = () => {
    const d = new Date(currentDate);
    if (period === 'day') d.setDate(d.getDate() - 1);
    else if (period === 'week') d.setDate(d.getDate() - 7);
    else d.setMonth(d.getMonth() - 1);
    onSetDate(d);
  };

  const handleNextDate = () => {
    const d = new Date(currentDate);
    if (period === 'day') d.setDate(d.getDate() + 1);
    else if (period === 'week') d.setDate(d.getDate() + 7);
    else d.setMonth(d.getMonth() + 1);
    onSetDate(d);
  };

  const formatDateHeader = () => {
    const d = currentDate;
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const date = d.getDate();
    const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return `${year}年 ${month}月${date}日 ${weekdays[d.getDay()]}`;
  };

  const handleAddTodoSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoInput.trim()) return;
    const { title, tags } = parseInputWithTags(newTodoInput);
    onAddTodo(title, tags);
    setNewTodoInput('');
  };

  const handleCreateProjectSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProjectName.trim()) return;
    const cleanTags = newProjectTags
      .split(/[,，\s]+/)
      .map((t) => t.trim())
      .filter(Boolean);
    onAddProject(newProjectName.trim(), cleanTags);
    setNewProjectName('');
    setNewProjectTags('');
    setShowNewProjectDialog(false);
  };

  const toggleProjectCollapse = (id: string) => {
    const next = new Set(collapsedProjects);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setCollapsedProjects(next);
  };

  // Icon selector based on category
  const renderCategoryIcon = (cat: string) => {
    switch (cat) {
      case '开发':
      case '编程':
        return <Hammer size={24} color="#FFF" />;
      case '设计':
      case '建模':
        return <Paintbrush size={24} color="#FFF" />;
      case '阅读':
      case '材料力学':
        return <BookOpen size={24} color="#FFF" />;
      case '英语':
        return <Headphones size={24} color="#FFF" />;
      case '数学':
      case '写作':
        return <FileText size={24} color="#FFF" />;
      default:
        return <TagIcon size={24} color="#FFF" />;
    }
  };

  const uncompletedCount = state.todos.filter((t) => !t.isCompleted).length;

  return (
    <div className="garden-root">
      {/* 1. Window Top Title Bar */}
      <div className="garden-window-topbar">
        <div className="mac-traffic-dots">
          <span className="dot dot-red" />
          <span className="dot dot-amber" />
          <span className="dot dot-green" />
          <span className="window-title-text">TomatoBar · 专注时光</span>
        </div>

        <div className="garden-nav-tabs">
          <span className="brand-logo-text">TomatoBar</span>
          <button className="nav-link active" onClick={() => onSwitchTab('overview')}>
            概览
          </button>
          <button className="nav-link" onClick={() => onSwitchTab('history')}>
            历史
          </button>
        </div>

        <div className="garden-top-right">
          <span className="poetic-motto">让专注，慢慢生长</span>
          <button className="garden-icon-btn" onClick={onOpenSettings} title="偏好设置">
            <Settings size={17} color={GardenTokens.muted} />
          </button>
        </div>
      </div>

      <div className="garden-divider-line" />

      {/* 2. Hero Section */}
      <div className="garden-hero-section">
        <div className="hero-left">
          <h2 className="hero-heading">今天，把时间留给了什么？</h2>
          <div className="hero-date-nav">
            <button className="date-arrow" onClick={handlePrevDate}>
              <ChevronLeft size={16} />
            </button>
            <span className="date-label">{formatDateHeader()}</span>
            <button className="date-arrow" onClick={handleNextDate}>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>

        <div className="hero-right">
          <div className="period-pill-group">
            <button
              className={`period-pill ${period === 'day' ? 'active' : ''}`}
              onClick={() => onSetPeriod('day')}
            >
              日
            </button>
            <button
              className={`period-pill ${period === 'week' ? 'active' : ''}`}
              onClick={() => onSetPeriod('week')}
            >
              周
            </button>
            <button
              className={`period-pill ${period === 'month' ? 'active' : ''}`}
              onClick={() => onSetPeriod('month')}
            >
              月
            </button>
          </div>
        </div>
      </div>

      {/* 3. 2x2 Overview Dashboard Grid */}
      <div className="garden-dashboard-grid">
        {/* Card 1: 当日累计专注 */}
        <div className="garden-card summary-card">
          <div className="card-header-label">当日累计专注（不含进行中）</div>
          <div className="big-duration-stat">{formatDurationChinese(summary.totalSeconds)}</div>

          <div className="category-stats-list">
            {summary.categories.length === 0 ? (
              <div className="empty-hint">今日暂无完成的专注记录</div>
            ) : (
              summary.categories.map((cat) => {
                const color = getCategoryColor(cat.name, state.categoryStyles);
                return (
                  <div key={cat.name} className="cat-stat-row">
                    <div className="cat-name-group">
                      <span className="cat-color-chip" style={{ backgroundColor: color }} />
                      <span className="cat-name">{cat.name}</span>
                    </div>
                    <span className="cat-duration">{formatDurationChinese(cat.seconds)}</span>
                  </div>
                );
              })
            )}
          </div>

          <div className="card-bottom-caption">每一段投入，都有迹可循</div>
        </div>

        {/* Card 2: 专注足迹 */}
        <div className="garden-card footprints-card">
          <div className="footprints-header">
            <span className="card-title">专注足迹</span>
            <span className="footprint-count">{summary.recordsInPeriod.length} 段</span>
          </div>

          <div className="footprints-canvas">
            {summary.recordsInPeriod.length === 0 ? (
              <div className="empty-footprints">还没有足迹。完成一段专注后，它会留在这里。</div>
            ) : (
              <div className="footprints-tiles-row">
                {summary.recordsInPeriod.map((record) => {
                  const cat = getRecordCategory(record);
                  const color = getCategoryColor(cat, state.categoryStyles);
                  const totalSec = record.segments.reduce(
                    (acc, s) => acc + (new Date(s.end).getTime() - new Date(s.start).getTime()) / 1000,
                    0
                  );

                  return (
                    <button
                      key={record.id}
                      className="footprint-tile"
                      style={{ backgroundColor: color }}
                      onClick={() => onEditRecord(record)}
                      title={`${record.name} (${cat})\n${formatTimeRange(record.startedAt, record.endedAt)}\n${formatDurationChinese(totalSec)}`}
                    >
                      {renderCategoryIcon(cat)}
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          <div className="card-bottom-caption">每一块是一段专注，按时间排列。点击色块，编辑名称、分类和标签。</div>
        </div>

        {/* Card 3: 待办 */}
        <div className="garden-card todos-card">
          <div className="todos-card-top">
            <div className="todos-title-row">
              <span className="card-title">待办</span>
              <span className="uncompleted-count">{uncompletedCount} 项未完成</span>
            </div>
            <button className="btn-new-project" onClick={() => setShowNewProjectDialog(true)}>
              <FolderPlus size={13} /> 新建大任务
            </button>
          </div>

          <form className="add-todo-inline-form" onSubmit={handleAddTodoSubmit}>
            <input
              type="text"
              className="garden-input"
              placeholder="添加待办，例如：阅读章节 #学习"
              value={newTodoInput}
              onChange={(e) => setNewTodoInput(e.target.value)}
            />
            <button type="submit" className="btn-add-todo" disabled={!newTodoInput.trim()}>
              <Plus size={16} color="#FFF" />
            </button>
          </form>

          <div className="todos-tree-scroll">
            {/* Render Project Folders */}
            {state.projects.map((proj) => {
              const isCollapsed = collapsedProjects.has(proj.id);
              const subtasks = state.todos.filter((t) => t.projectID === proj.id);
              const completedSubtasks = subtasks.filter((t) => t.isCompleted);

              // Calculate total focus time spent on this project
              const projRecords = state.records.filter((r) => r.projectID === proj.id);
              const projTotalSec = projRecords.reduce(
                (sum, r) => sum + r.segments.reduce((acc, s) => acc + (new Date(s.end).getTime() - new Date(s.start).getTime()) / 1000, 0),
                0
              );

              return (
                <div key={proj.id} className="project-group">
                  <div className="project-folder-header">
                    <button className="proj-collapse-arrow" onClick={() => toggleProjectCollapse(proj.id)}>
                      <ChevronDown
                        size={14}
                        style={{ transform: isCollapsed ? 'rotate(-90deg)' : 'none', transition: 'transform 0.2s' }}
                      />
                    </button>
                    <Folder size={15} color={GardenTokens.red} />
                    <span className="proj-title">{proj.name}</span>
                    {proj.tags[0] && <span className="proj-tag">#{proj.tags[0]}</span>}
                    <span className="proj-progress-pill">
                      {completedSubtasks.length}/{subtasks.length}
                    </span>
                    {projTotalSec > 0 && (
                      <span className="proj-time-pill">
                        🎯 {formatDurationChinese(projTotalSec)}
                      </span>
                    )}
                    <button
                      className="proj-more-btn"
                      onClick={() => {
                        if (window.confirm(`删除大任务「${proj.name}」？子任务将保留为独立待办。`)) {
                          onDeleteProject(proj.id);
                        }
                      }}
                      title="删除大任务"
                    >
                      <MoreHorizontal size={14} />
                    </button>
                  </div>

                  {!isCollapsed && (
                    <div className="project-subtasks-list">
                      {subtasks.length === 0 ? (
                        <div className="empty-subtasks">暂无子任务</div>
                      ) : (
                        subtasks.map((todo) => {
                          const isCurrent = todo.id === state.currentTodoID;
                          return (
                            <div key={todo.id} className={`subtask-item ${isCurrent ? 'active' : ''}`}>
                              <button className="todo-circle-btn" onClick={() => onToggleTodo(todo.id)}>
                                {todo.isCompleted ? (
                                  <CheckCircle2 size={16} color={GardenTokens.red} />
                                ) : (
                                  <Circle size={16} color={GardenTokens.muted} />
                                )}
                              </button>
                              <span className="target-dot">🎯</span>
                              <span className={`subtask-title ${todo.isCompleted ? 'line-through' : ''}`}>
                                {todo.title}
                              </span>
                              {todo.tags[0] && <span className="todo-subtag">#{todo.tags[0]}</span>}
                              <button
                                className="btn-play-todo"
                                onClick={() => onSelectTodoForFocus(todo)}
                                title="以此任务开启专注"
                              >
                                <Play size={12} fill="currentColor" />
                              </button>
                              <button
                                className="btn-delete-todo"
                                onClick={() => onDeleteTodo(todo.id)}
                                title="删除"
                              >
                                <X size={12} />
                              </button>
                            </div>
                          );
                        })
                      )}
                    </div>
                  )}
                </div>
              );
            })}

            {/* Loose Todos (Tasks without parent project) */}
            {state.todos
              .filter((t) => !t.projectID)
              .map((todo) => {
                const isCurrent = todo.id === state.currentTodoID;
                return (
                  <div key={todo.id} className={`subtask-item loose-todo ${isCurrent ? 'active' : ''}`}>
                    <button className="todo-circle-btn" onClick={() => onToggleTodo(todo.id)}>
                      {todo.isCompleted ? (
                        <CheckCircle2 size={16} color={GardenTokens.red} />
                      ) : (
                        <Circle size={16} color={GardenTokens.muted} />
                      )}
                    </button>
                    <span className={`subtask-title ${todo.isCompleted ? 'line-through' : ''}`}>{todo.title}</span>
                    {todo.tags[0] && <span className="todo-subtag">#{todo.tags[0]}</span>}
                    <button
                      className="btn-play-todo"
                      onClick={() => onSelectTodoForFocus(todo)}
                      title="以此任务开启专注"
                    >
                      <Play size={12} fill="currentColor" />
                    </button>
                    <button className="btn-delete-todo" onClick={() => onDeleteTodo(todo.id)} title="删除">
                      <X size={12} />
                    </button>
                  </div>
                );
              })}
          </div>
        </div>

        {/* Card 4: 专注记录 */}
        <div className="garden-card records-card">
          <div className="records-card-top">
            <span className="card-title">专注记录</span>
            <span className="records-count">{summary.recordsInPeriod.length} 段</span>
            <span className="time-order-hint">按时间顺序</span>
          </div>

          <div className="records-timeline-list">
            {summary.recordsInPeriod.length === 0 ? (
              <div className="empty-records">今天还没有专注记录</div>
            ) : (
              summary.recordsInPeriod.map((record) => {
                const cat = getRecordCategory(record);
                const color = getCategoryColor(cat, state.categoryStyles);
                const totalSec = record.segments.reduce(
                  (acc, s) => acc + (new Date(s.end).getTime() - new Date(s.start).getTime()) / 1000,
                  0
                );

                return (
                  <div key={record.id} className="record-timeline-row">
                    <span className="record-circle-dot" style={{ backgroundColor: color }} />
                    <div className="record-center">
                      <div className="record-name-text">{record.name}</div>
                      <div className="record-meta-text">
                        <span>{formatTimeRange(record.startedAt, record.endedAt)}</span>
                        <span className="record-cat-label" style={{ color }}>
                          {cat}
                        </span>
                      </div>
                    </div>
                    <span className="record-duration-text">{formatDurationChinese(totalSec)}</span>
                    <button
                      className="record-more-action"
                      onClick={() => onEditRecord(record)}
                      title="编辑记录"
                    >
                      <MoreHorizontal size={15} color={GardenTokens.muted} />
                    </button>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      {/* 4. Sticky Bottom Flow Bar */}
      <div className="garden-bottom-flowbar">
        <div className="flowbar-left">
          <div className="flowbar-target-icon">
            <Target size={18} color={GardenTokens.red} />
          </div>
          <div className="flowbar-task-info">
            {currentTodo ? (
              <>
                <div className="flowbar-proj-line">
                  {currentProject && <span className="proj-sub">{currentProject.name}</span>}
                  <span className="current-badge">当前任务</span>
                  {currentTodo.tags[0] && <span className="tag-sub">#{currentTodo.tags[0]}</span>}
                </div>
                <div className="flowbar-main-title">{currentTodo.title}</div>
              </>
            ) : (
              <>
                <div className="flowbar-proj-line">
                  <span className="current-badge">自由专注</span>
                </div>
                <div className="flowbar-main-title">{state.name || '准备就绪，开启一段心流'}</div>
              </>
            )}
          </div>
        </div>

        <div className="flowbar-right">
          {(state.phase === 'work' || state.phase === 'rest') && (
            <div className="flowbar-countdown">
              {Math.floor(Math.max(0, state.remaining) / 60).toString().padStart(2, '0')}:
              {(Math.floor(Math.max(0, state.remaining)) % 60).toString().padStart(2, '0')}
            </div>
          )}
          {state.phase === 'rest' && (
            <button className="garden-btn-secondary" onClick={onSkipRest}>
              跳过休息
            </button>
          )}
          <button
            className="garden-btn-start-focus"
            onClick={
              state.phase === 'work' || state.phase === 'rest'
                ? state.paused
                  ? onResume
                  : onPause
                : onStartFocus
            }
          >
            {state.phase === 'work' || state.phase === 'rest'
              ? state.paused
                ? '继续'
                : '暂停'
              : '开始专注'}
          </button>
          <button className="garden-btn-expand" onClick={onOpenExpandedTimer} title="展开大计时器">
            <Maximize2 size={16} />
          </button>
        </div>
      </div>

      {/* Modal: New Project Dialog */}
      {showNewProjectDialog && (
        <div className="garden-modal-overlay">
          <div className="garden-dialog-card">
            <h3 className="dialog-title">新建大任务容器</h3>
            <form onSubmit={handleCreateProjectSubmit}>
              <div className="dialog-field">
                <label>大任务名称</label>
                <input
                  type="text"
                  className="garden-input"
                  placeholder="例如: TomatoBar 架构演进与体验迭代"
                  value={newProjectName}
                  onChange={(e) => setNewProjectName(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="dialog-field">
                <label>默认标签（子任务将自动继承）</label>
                <input
                  type="text"
                  className="garden-input"
                  placeholder="例如: 开发"
                  value={newProjectTags}
                  onChange={(e) => setNewProjectTags(e.target.value)}
                />
              </div>
              <div className="dialog-actions">
                <button type="button" className="garden-btn-secondary" onClick={() => setShowNewProjectDialog(false)}>
                  取消
                </button>
                <button type="submit" className="garden-btn-primary" disabled={!newProjectName.trim()}>
                  创建
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
