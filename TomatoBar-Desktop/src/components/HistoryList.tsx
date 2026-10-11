import type { FocusRecord } from "../types";
import { recordSeconds } from "../types";
import { formatDurationChinese, formatTimeRange } from "../core/analytics";
import { Edit3, Trash2, Calendar, CheckCircle, XCircle } from "lucide-react";

export function HistoryList({
  records,
  onEditRecord,
  onDeleteRecord,
}: {
  records: FocusRecord[];
  onEditRecord: (record: FocusRecord) => void;
  onDeleteRecord: (id: string) => void;
}) {
  if (!records.length)
    return <div className="empty-history">暂无历史专注记录</div>;
  return (
    <section className="history-container">
      <div className="history-header">
        <h3>历史专注记录 ({records.length} 条)</h3>
      </div>
      <div className="history-scroll-list">
        {[...records]
          .sort((a, b) => Date.parse(b.startedAt) - Date.parse(a.startedAt))
          .map((record) => (
            <div key={record.id} className="history-card">
              <div className="history-card-left">
                <div className="history-card-title-row">
                  <span className="history-name">{record.name}</span>
                  {record.completed ? (
                    <span className="status-badge-complete">
                      <CheckCircle size={12} />
                      已完成
                    </span>
                  ) : (
                    <span className="status-badge-incomplete">
                      <XCircle size={12} />
                      提前结束
                    </span>
                  )}
                </div>
                <div className="history-card-meta">
                  <span>
                    <Calendar size={12} />
                    {new Date(record.startedAt).toLocaleDateString(
                      "zh-CN",
                    )}{" "}
                    {formatTimeRange(record.startedAt, record.endedAt)}
                  </span>
                  <span>
                    时长：{formatDurationChinese(recordSeconds(record))}
                  </span>
                </div>
                <div className="history-tags-row">
                  {record.tags.map((tag, i) => (
                    <span
                      key={tag}
                      className={`history-tag ${i === 0 ? "primary-category-tag" : ""}`}
                    >
                      #{tag}
                    </span>
                  ))}
                </div>
              </div>
              <div className="history-card-actions">
                <button
                  className="btn-icon-action"
                  onClick={() => onEditRecord(record)}
                  title="编辑记录与标签"
                  aria-label={`编辑${record.name}`}
                >
                  <Edit3 size={15} />
                </button>
                <button
                  className="btn-icon-action btn-danger-action"
                  onClick={() => {
                    if (window.confirm(`确定删除记录「${record.name}」吗？`))
                      onDeleteRecord(record.id);
                  }}
                  title="删除记录"
                  aria-label={`删除${record.name}`}
                >
                  <Trash2 size={15} />
                </button>
              </div>
            </div>
          ))}
      </div>
    </section>
  );
}
