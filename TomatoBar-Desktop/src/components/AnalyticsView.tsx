import React, { useState } from 'react';
import type { FocusRecord } from '../types';
import type { FocusPeriod } from '../core/analytics';
import {
  computeFocusSummary,
  formatDurationChinese,
  formatTimeRange,
  getRecordCategory,
  recordSecondsInInterval,
} from '../core/analytics';
import { ChevronLeft, ChevronRight, Clock } from 'lucide-react';

interface AnalyticsViewProps {
  records: FocusRecord[];
}

const CATEGORY_COLORS = [
  '#FF6B6B', // Tomato Red
  '#4DABF7', // Ocean Blue
  '#51CF66', // Emerald Green
  '#FCC419', // Amber Yellow
  '#CC5DE8', // Purple
  '#FF922B', // Orange
  '#20C997', // Teal
  '#845EF7', // Indigo
];

function getCategoryColor(index: number): string {
  return CATEGORY_COLORS[index % CATEGORY_COLORS.length];
}

export const AnalyticsView: React.FC<AnalyticsViewProps> = ({ records }) => {
  const [period, setPeriod] = useState<FocusPeriod>('day');
  const [currentDate, setCurrentDate] = useState<Date>(new Date());
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const handlePrev = () => {
    const d = new Date(currentDate);
    if (period === 'day') d.setDate(d.getDate() - 1);
    else if (period === 'week') d.setDate(d.getDate() - 7);
    else d.setMonth(d.getMonth() - 1);
    setCurrentDate(d);
  };

  const handleNext = () => {
    const d = new Date(currentDate);
    if (period === 'day') d.setDate(d.getDate() + 1);
    else if (period === 'week') d.setDate(d.getDate() + 7);
    else d.setMonth(d.getMonth() + 1);
    setCurrentDate(d);
  };

  const handleToday = () => {
    setCurrentDate(new Date());
  };

  const summary = computeFocusSummary(records, period, currentDate, selectedCategory);

  const formatDateHeader = () => {
    const d = currentDate;
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const date = d.getDate();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

    if (period === 'day') {
      return `${year}年${month}月${date}日 · ${weekdays[d.getDay()]}`;
    }
    if (period === 'week') {
      const start = summary.interval.start;
      const end = new Date(summary.interval.end.getTime() - 1);
      return `${start.getMonth() + 1}月${start.getDate()}日 - ${end.getMonth() + 1}月${end.getDate()}日 (本周)`;
    }
    return `${year}年${month}月 (整月)`;
  };

  return (
    <div className="analytics-container">
      {/* Top Header & Period Selector */}
      <div className="analytics-header">
        <div className="period-tabs">
          <button
            className={`tab-btn ${period === 'day' ? 'tab-btn-active' : ''}`}
            onClick={() => setPeriod('day')}
          >
            日复盘
          </button>
          <button
            className={`tab-btn ${period === 'week' ? 'tab-btn-active' : ''}`}
            onClick={() => setPeriod('week')}
          >
            周堆叠
          </button>
          <button
            className={`tab-btn ${period === 'month' ? 'tab-btn-active' : ''}`}
            onClick={() => setPeriod('month')}
          >
            月热力
          </button>
        </div>

        <div className="date-nav">
          <button className="nav-arrow-btn" onClick={handlePrev} title="前一段时间">
            <ChevronLeft size={16} />
          </button>
          <span className="current-date-title">{formatDateHeader()}</span>
          <button className="nav-arrow-btn" onClick={handleNext} title="后一段时间">
            <ChevronRight size={16} />
          </button>
          <button className="btn-today" onClick={handleToday}>
            今天
          </button>
        </div>

        <div className="total-badge">
          <Clock size={15} />
          <span>累计专注: {formatDurationChinese(summary.totalSeconds)}</span>
        </div>
      </div>

      {/* Categories Summary Chips */}
      {summary.categories.length > 0 && (
        <div className="categories-legend-row">
          <button
            className={`category-legend-chip ${selectedCategory === null ? 'chip-selected' : ''}`}
            onClick={() => setSelectedCategory(null)}
          >
            全部分类 ({formatDurationChinese(summary.totalSeconds)})
          </button>
          {summary.categories.map((c, idx) => {
            const isSelected = selectedCategory?.toLowerCase() === c.name.toLowerCase();
            const color = getCategoryColor(idx);
            return (
              <button
                key={c.name}
                className={`category-legend-chip ${isSelected ? 'chip-selected' : ''}`}
                style={{ borderColor: isSelected ? color : 'transparent' }}
                onClick={() => setSelectedCategory(isSelected ? null : c.name)}
              >
                <span className="color-dot" style={{ backgroundColor: color }} />
                <span>{c.name}</span>
                <span className="cat-sec">{formatDurationChinese(c.seconds)}</span>
              </button>
            );
          })}
        </div>
      )}

      {/* Main Chart Body depending on period */}
      <div className="chart-body">
        {period === 'day' && <DayTimelineView summary={summary} categories={summary.categories} />}
        {period === 'week' && <WeekStackedBarView summary={summary} categories={summary.categories} />}
        {period === 'month' && <MonthHeatmapView currentDate={currentDate} records={records} />}
      </div>
    </div>
  );
};

// MARK: - Day Timeline View (色块流)
const DayTimelineView: React.FC<{ summary: any; categories: any[] }> = ({ summary, categories }) => {
  const records = summary.recordsInPeriod;

  // 24 hours: 0..23
  const hours = Array.from({ length: 24 }, (_, i) => i);

  if (records.length === 0) {
    return <div className="empty-chart">本日暂无专注记录，点击计时器开启今天的第一段专注吧！</div>;
  }

  const startOfDay = summary.interval.start.getTime();
  const dayMs = 24 * 60 * 60 * 1000;

  return (
    <div className="day-timeline-wrapper">
      <div className="timeline-labels">
        {hours
          .filter((h) => h % 3 === 0)
          .map((h) => (
            <span key={h} className="timeline-hour-mark" style={{ left: `${(h / 24) * 100}%` }}>
              {h}:00
            </span>
          ))}
      </div>

      <div className="timeline-track">
        {hours.map((h) => (
          <div key={h} className="timeline-hour-slot" style={{ left: `${(h / 24) * 100}%` }} />
        ))}

        {records.map((r: FocusRecord) => {
          const cat = getRecordCategory(r);
          const catIndex = categories.findIndex((c) => c.name.toLowerCase() === cat.toLowerCase());
          const color = getCategoryColor(catIndex >= 0 ? catIndex : 0);

          return r.segments.map((seg, sIdx) => {
            const segStart = new Date(seg.start).getTime();
            const segEnd = new Date(seg.end).getTime();

            const leftPct = Math.max(0, Math.min(100, ((segStart - startOfDay) / dayMs) * 100));
            const rightPct = Math.max(0, Math.min(100, ((segEnd - startOfDay) / dayMs) * 100));
            const widthPct = Math.max(0.5, rightPct - leftPct);

            return (
              <div
                key={`${r.id}-${sIdx}`}
                className="timeline-block"
                style={{
                  left: `${leftPct}%`,
                  width: `${widthPct}%`,
                  backgroundColor: color,
                }}
                title={`${r.name} (${cat})\n${formatTimeRange(seg.start, seg.end)}\n时长: ${formatDurationChinese(
                  (segEnd - segStart) / 1000
                )}`}
              />
            );
          });
        })}
      </div>

      {/* Record Details List */}
      <div className="day-records-table">
        <h4 className="table-heading">专注流水明细 ({records.length} 段)</h4>
        <div className="records-list">
          {records.map((r: FocusRecord) => {
            const cat = getRecordCategory(r);
            const catIndex = categories.findIndex((c) => c.name.toLowerCase() === cat.toLowerCase());
            const color = getCategoryColor(catIndex >= 0 ? catIndex : 0);

            return (
              <div key={r.id} className="record-row-item">
                <span className="record-color-indicator" style={{ backgroundColor: color }} />
                <div className="record-info-group">
                  <span className="record-name">{r.name}</span>
                  <div className="record-meta">
                    <span className="record-time">{formatTimeRange(r.startedAt, r.endedAt)}</span>
                    <span className="record-tag-badge">#{cat}</span>
                  </div>
                </div>
                <div className="record-duration-badge">
                  {formatDurationChinese(
                    r.segments.reduce(
                      (acc, s) => acc + (new Date(s.end).getTime() - new Date(s.start).getTime()) / 1000,
                      0
                    )
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

// MARK: - Week Stacked Bar View (周堆叠柱)
const WeekStackedBarView: React.FC<{ summary: any; categories: any[] }> = ({ summary, categories }) => {
  const days = summary.days; // 7 days (Mon..Sun)
  const dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  const maxDailySeconds = Math.max(1, ...days.map((d: any) => d.seconds));

  return (
    <div className="week-bars-container">
      <div className="bars-chart-canvas">
        {days.map((day: any, i: number) => {
          const heightPct = (day.seconds / maxDailySeconds) * 100;
          return (
            <div key={i} className="bar-column">
              <div className="bar-hover-label">
                {day.seconds > 0 ? formatDurationChinese(day.seconds) : ''}
              </div>
              <div className="bar-track">
                <div className="bar-fill-stack" style={{ height: `${heightPct}%` }}>
                  {day.categories.map((cat: any, cIdx: number) => {
                    const catTotalIdx = categories.findIndex((c) => c.name.toLowerCase() === cat.name.toLowerCase());
                    const color = getCategoryColor(catTotalIdx >= 0 ? catTotalIdx : cIdx);
                    const segHeightPct = (cat.seconds / (day.seconds || 1)) * 100;

                    return (
                      <div
                        key={cat.name}
                        className="bar-stack-segment"
                        style={{
                          height: `${segHeightPct}%`,
                          backgroundColor: color,
                        }}
                        title={`${dayNames[i]}: ${cat.name} · ${formatDurationChinese(cat.seconds)}`}
                      />
                    );
                  })}
                </div>
              </div>
              <span className="bar-x-label">{dayNames[i]}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// MARK: - Month Heatmap Calendar (月热力图)
const MonthHeatmapView: React.FC<{ currentDate: Date; records: FocusRecord[] }> = ({
  currentDate,
  records,
}) => {
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();

  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const totalDays = lastDay.getDate();

  // First day of week (Monday = 1)
  const startDayOfWeek = (firstDay.getDay() + 6) % 7;

  // Build grid
  const daysArray = Array.from({ length: totalDays }, (_, i) => i + 1);

  // Compute daily totals
  const dailyTotals = new Map<number, number>();
  for (let day = 1; day <= totalDays; day++) {
    const dayStart = new Date(year, month, day, 0, 0, 0, 0);
    const dayEnd = new Date(year, month, day + 1, 0, 0, 0, 0);

    let sec = 0;
    for (const r of records) {
      sec += recordSecondsInInterval(r, dayStart, dayEnd);
    }
    dailyTotals.set(day, sec);
  }

  const getIntensityClass = (sec: number) => {
    if (sec <= 0) return 'heat-0';
    if (sec < 25 * 60) return 'heat-1';
    if (sec < 60 * 60) return 'heat-2';
    if (sec < 120 * 60) return 'heat-3';
    return 'heat-4';
  };

  const weekHeaders = ['一', '二', '三', '四', '五', '六', '日'];

  return (
    <div className="month-heatmap-container">
      <div className="heatmap-week-header">
        {weekHeaders.map((h) => (
          <div key={h} className="heatmap-header-cell">
            {h}
          </div>
        ))}
      </div>

      <div className="heatmap-grid">
        {/* Empty placeholder cells for offset */}
        {Array.from({ length: startDayOfWeek }).map((_, i) => (
          <div key={`empty-${i}`} className="heatmap-cell empty-cell" />
        ))}

        {daysArray.map((day) => {
          const sec = dailyTotals.get(day) || 0;
          return (
            <div
              key={day}
              className={`heatmap-cell ${getIntensityClass(sec)}`}
              title={`${year}年${month + 1}月${day}日: 专注 ${formatDurationChinese(sec)}`}
            >
              <span className="heat-day-num">{day}</span>
              {sec > 0 && <span className="heat-time-hint">{Math.round(sec / 60)}分</span>}
            </div>
          );
        })}
      </div>

      <div className="heatmap-legend">
        <span>较少</span>
        <div className="heat-legend-cell heat-0" />
        <div className="heat-legend-cell heat-1" />
        <div className="heat-legend-cell heat-2" />
        <div className="heat-legend-cell heat-3" />
        <div className="heat-legend-cell heat-4" />
        <span>更多专注</span>
      </div>
    </div>
  );
};
