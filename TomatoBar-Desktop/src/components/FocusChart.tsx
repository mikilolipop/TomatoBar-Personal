import type { FocusPeriod, computeFocusSummary } from "../core/analytics";
import { formatDurationChinese, getRecordCategory } from "../core/analytics";
import { getCategoryColor } from "../core/garden";
import type { FocusRecord } from "../types";
type Summary = ReturnType<typeof computeFocusSummary>;

export function FocusChart({
  summary,
  period,
  styles,
  onEdit,
}: {
  summary: Summary;
  period: FocusPeriod;
  styles?: Record<string, string>;
  onEdit: (record: FocusRecord) => void;
}) {
  const { start, end } = summary.interval;
  if (period === "day")
    return (
      <div className="focus-day-chart" aria-label="当天专注时间轴">
        <div className="focus-time-labels">
          <span>00:00</span>
          <span>12:00</span>
          <span>24:00</span>
        </div>
        <div className="focus-day-track">
          {summary.recordsInPeriod.flatMap((record) =>
            record.segments.map((segment, index) => {
              const left = Math.max(start.getTime(), Date.parse(segment.start));
              const right = Math.min(end.getTime(), Date.parse(segment.end));
              if (right <= left) return null;
              return (
                <button
                  key={`${record.id}-${index}`}
                  className="focus-day-segment"
                  style={{
                    left: `${((left - start.getTime()) / (end.getTime() - start.getTime())) * 100}%`,
                    width: `${((right - left) / (end.getTime() - start.getTime())) * 100}%`,
                    background: getCategoryColor(
                      getRecordCategory(record),
                      styles,
                    ),
                  }}
                  onClick={() => onEdit(record)}
                  title={`${record.name} · ${formatDurationChinese((right - left) / 1000)}`}
                  aria-label={`编辑${record.name}`}
                />
              );
            }),
          )}
        </div>
        <p className="chart-caption">色块只包含实际专注片段，暂停留下空隙。</p>
      </div>
    );
  if (period === "week") {
    const max = Math.max(1, ...summary.days.map((d) => d.seconds));
    return (
      <div className="focus-week-chart" aria-label="每周分类专注时长">
        {summary.days.map((day) => (
          <div key={day.date.toISOString()} className="focus-bar-column">
            <div className="focus-bar-track">
              <div
                className="focus-bar-stack"
                style={{ height: `${(day.seconds / max) * 100}%` }}
              >
                {day.categories.map((cat) => (
                  <div
                    key={cat.name}
                    style={{
                      height: `${(cat.seconds / day.seconds) * 100}%`,
                      background: getCategoryColor(cat.name, styles),
                    }}
                    title={`${day.date.toLocaleDateString("zh-CN")} · ${cat.name} · ${formatDurationChinese(cat.seconds)}`}
                  />
                ))}
              </div>
            </div>
            <span>
              {["日", "一", "二", "三", "四", "五", "六"][day.date.getDay()]}
            </span>
            <small>
              {day.seconds > 0 ? `${Math.round(day.seconds / 60)}分` : "—"}
            </small>
          </div>
        ))}
      </div>
    );
  }
  const offset = (start.getDay() + 6) % 7;
  return (
    <div className="focus-month-chart" aria-label="每月专注热力日历">
      {["一", "二", "三", "四", "五", "六", "日"].map((d) => (
        <span key={d} className="focus-month-heading">
          {d}
        </span>
      ))}
      {Array.from({ length: offset }, (_, i) => (
        <span key={`empty-${i}`} />
      ))}
      {summary.days.map((day) => (
        <span
          key={day.date.toISOString()}
          className={`focus-heat-cell heat-${day.seconds === 0 ? 0 : day.seconds < 1500 ? 1 : day.seconds < 3600 ? 2 : day.seconds < 7200 ? 3 : 4}`}
          title={`${day.date.toLocaleDateString("zh-CN")} · ${formatDurationChinese(day.seconds)}`}
        >
          {day.date.getDate()}
        </span>
      ))}
    </div>
  );
}
