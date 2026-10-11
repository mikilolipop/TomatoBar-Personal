import React, { useMemo } from "react";
import type { FocusRecord, FocusState, FocusTodo } from "../types";
import { recordSeconds } from "../types";
import { canStartWork } from "../core/stateMachine";
import { shiftPeriodDate } from "../core/analytics";
import { TodoPanel } from "./TodoPanel";
import { FocusChart } from "./FocusChart";
import type { FocusPeriod } from "../core/analytics";
import {
  computeFocusSummary,
  formatDurationChinese,
  formatTimeRange,
  getRecordCategory,
} from "../core/analytics";
import { getCategoryColor, GardenTokens } from "../core/garden";
import {
  ChevronLeft,
  ChevronRight,
  MoreHorizontal,
  Maximize2,
  BookOpen,
  Hammer,
  Paintbrush,
  Headphones,
  FileText,
  Tag as TagIcon,
  Target,
} from "lucide-react";

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
  onStartRest: () => void;
  restMinutes: number;
  onFreeFocus: () => void;
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
  onStartRest,
  restMinutes,
  onFreeFocus,
  onAddTodo,
  onToggleTodo,
  onDeleteTodo,
  onSelectTodoForFocus,
  onAddProject,
  onDeleteProject,
  onEditRecord,
}) => {
  const summary = useMemo(
    () => computeFocusSummary(state.records, period, currentDate),
    [state.records, period, currentDate],
  );

  const currentTodo = state.todos.find((t) => t.id === state.currentTodoID);
  const currentProject = currentTodo?.projectID
    ? state.projects.find((p) => p.id === currentTodo.projectID)
    : null;

  const handlePrevDate = () =>
    onSetDate(shiftPeriodDate(currentDate, period, -1));
  const handleNextDate = () =>
    onSetDate(shiftPeriodDate(currentDate, period, 1));

  const formatDateHeader = () => {
    const d = currentDate;
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const date = d.getDate();
    if (period === "month") return `${year}年 ${month}月`;
    if (period === "week") {
      const a = summary.interval.start;
      const b = new Date(summary.interval.end.getTime() - 1);
      return `${a.getMonth() + 1}月${a.getDate()}日 — ${b.getMonth() + 1}月${b.getDate()}日`;
    }
    const weekdays = [
      "星期日",
      "星期一",
      "星期二",
      "星期三",
      "星期四",
      "星期五",
      "星期六",
    ];
    return `${year}年 ${month}月${date}日 ${weekdays[d.getDay()]}`;
  };

  // Icon selector based on category
  const renderCategoryIcon = (cat: string) => {
    switch (cat) {
      case "开发":
      case "编程":
        return <Hammer size={24} color="#FFF" />;
      case "设计":
      case "建模":
        return <Paintbrush size={24} color="#FFF" />;
      case "阅读":
      case "材料力学":
        return <BookOpen size={24} color="#FFF" />;
      case "英语":
        return <Headphones size={24} color="#FFF" />;
      case "数学":
      case "写作":
        return <FileText size={24} color="#FFF" />;
      default:
        return <TagIcon size={24} color="#FFF" />;
    }
  };

  return (
    <div className="garden-overview">
      {/* 2. Hero Section */}
      <div className="garden-hero-section">
        <div className="hero-left">
          <h2 className="hero-heading">今天，把时间留给了什么？</h2>
          <div className="hero-date-nav">
            <button
              className="date-arrow"
              onClick={handlePrevDate}
              aria-label="上一期间"
            >
              <ChevronLeft size={16} />
            </button>
            <span className="date-label">{formatDateHeader()}</span>
            <button
              className="garden-btn-secondary"
              onClick={() => onSetDate(new Date())}
            >
              今天
            </button>
            <button
              className="date-arrow"
              onClick={handleNextDate}
              aria-label="下一期间"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>

        <div className="hero-right">
          <div className="period-pill-group">
            <button
              className={`period-pill ${period === "day" ? "active" : ""}`}
              onClick={() => onSetPeriod("day")}
            >
              日
            </button>
            <button
              className={`period-pill ${period === "week" ? "active" : ""}`}
              onClick={() => onSetPeriod("week")}
            >
              周
            </button>
            <button
              className={`period-pill ${period === "month" ? "active" : ""}`}
              onClick={() => onSetPeriod("month")}
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
          <div className="card-header-label">
            {period === "day" ? "当日" : period === "week" ? "本周" : "本月"}
            累计专注（不含进行中）
          </div>
          <div className="big-duration-stat">
            {formatDurationChinese(summary.totalSeconds)}
          </div>

          <div className="category-stats-list">
            {summary.categories.length === 0 ? (
              <div className="empty-hint">所选期间暂无专注记录</div>
            ) : (
              summary.categories.map((cat) => {
                const color = getCategoryColor(cat.name, state.categoryStyles);
                return (
                  <div key={cat.name} className="cat-stat-row">
                    <div className="cat-name-group">
                      <span
                        className="cat-color-chip"
                        style={{ backgroundColor: color }}
                      />
                      <span className="cat-name">{cat.name}</span>
                    </div>
                    <span className="cat-duration">
                      {formatDurationChinese(cat.seconds)}
                    </span>
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
            <span className="footprint-count">
              {summary.recordsInPeriod.length} 段
            </span>
          </div>

          <FocusChart
            summary={summary}
            period={period}
            styles={state.categoryStyles}
            onEdit={onEditRecord}
          />
          {period === "day" && (
            <div className="footprints-canvas">
              {summary.recordsInPeriod.length === 0 ? (
                <div className="empty-footprints">
                  还没有足迹。完成一段专注后，它会留在这里。
                </div>
              ) : (
                <div className="footprints-tiles-row">
                  {summary.recordsInPeriod.map((record) => {
                    const cat = getRecordCategory(record);
                    const color = getCategoryColor(cat, state.categoryStyles);
                    const totalSec = recordSeconds(record);

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
          )}

          <div className="card-bottom-caption">
            {period === "day"
              ? "点击色块，编辑名称、分类和标签。"
              : period === "week"
                ? "每列代表一天，颜色表示专注分类。"
                : "每格代表一天，颜色深浅表示投入时长。"}
          </div>
        </div>

        <TodoPanel
          state={state}
          onAddTodo={onAddTodo}
          onToggleTodo={onToggleTodo}
          onDeleteTodo={onDeleteTodo}
          onSelectTodoForFocus={onSelectTodoForFocus}
          onAddProject={onAddProject}
          onDeleteProject={onDeleteProject}
        />

        {/* Card 4: 专注记录 */}
        <div className="garden-card records-card">
          <div className="records-card-top">
            <span className="card-title">专注记录</span>
            <span className="records-count">
              {summary.recordsInPeriod.length} 段
            </span>
            <span className="time-order-hint">按时间顺序</span>
          </div>

          <div className="records-timeline-list">
            {summary.recordsInPeriod.length === 0 ? (
              <div className="empty-records">所选期间还没有专注记录</div>
            ) : (
              summary.recordsInPeriod.map((record) => {
                const cat = getRecordCategory(record);
                const color = getCategoryColor(cat, state.categoryStyles);
                const totalSec = recordSeconds(record);

                return (
                  <div key={record.id} className="record-timeline-row">
                    <span
                      className="record-circle-dot"
                      style={{ backgroundColor: color }}
                    />
                    <div className="record-center">
                      <div className="record-name-text">{record.name}</div>
                      <div className="record-meta-text">
                        <span>
                          {formatTimeRange(record.startedAt, record.endedAt)}
                        </span>
                        <span className="record-cat-label" style={{ color }}>
                          {cat}
                        </span>
                      </div>
                    </div>
                    <span className="record-duration-text">
                      {formatDurationChinese(totalSec)}
                    </span>
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
                  {currentProject && (
                    <span className="proj-sub">{currentProject.name}</span>
                  )}
                  <span className="current-badge">当前任务</span>
                  {currentTodo.tags[0] && (
                    <span className="tag-sub">#{currentTodo.tags[0]}</span>
                  )}
                </div>
                <div className="flowbar-main-title">{currentTodo.title}</div>
              </>
            ) : (
              <>
                <div className="flowbar-proj-line">
                  <span className="current-badge">自由专注</span>
                </div>
                <div className="flowbar-main-title">
                  {state.name || "准备就绪，开启一段心流"}
                </div>
              </>
            )}
          </div>
        </div>

        <div className="flowbar-right">
          {currentTodo && canStartWork(state) && (
            <button className="garden-btn-secondary" onClick={onFreeFocus}>
              自由专注
            </button>
          )}
          {(state.phase === "work" || state.phase === "rest") && (
            <div className="flowbar-countdown">
              {Math.floor(Math.max(0, state.remaining) / 60)
                .toString()
                .padStart(2, "0")}
              :
              {(Math.floor(Math.max(0, state.remaining)) % 60)
                .toString()
                .padStart(2, "0")}
            </div>
          )}
          {state.phase === "rest" && (
            <button className="garden-btn-secondary" onClick={onSkipRest}>
              跳过休息
            </button>
          )}
          <button
            className="garden-btn-start-focus"
            onClick={
              state.phase === "work" || state.phase === "rest"
                ? state.paused
                  ? onResume
                  : onPause
                : state.phase === "workFinished"
                  ? onStartRest
                  : onStartFocus
            }
          >
            {state.phase === "work" || state.phase === "rest"
              ? state.paused
                ? "继续"
                : "暂停"
              : state.phase === "workFinished"
                ? `开始休息 (${restMinutes} 分钟)`
                : state.phase === "restFinished"
                  ? "开始下一轮"
                  : "开始专注"}
          </button>
          <button
            className="garden-btn-expand"
            onClick={onOpenExpandedTimer}
            title="展开大计时器"
          >
            <Maximize2 size={16} />
          </button>
        </div>
      </div>
    </div>
  );
};
