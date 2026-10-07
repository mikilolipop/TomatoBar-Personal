import React, { useState } from 'react';
import type { FocusRecord } from '../types';
import { formatDurationChinese, formatTimeRange } from '../core/analytics';
import { Edit3, Trash2, Calendar, CheckCircle, XCircle } from 'lucide-react';

interface HistoryListProps {
  records: FocusRecord[];
  onUpdateRecord: (id: string, updates: Partial<Pick<FocusRecord, 'name' | 'tags'>>) => void;
  onDeleteRecord: (id: string) => void;
}

export const HistoryList: React.FC<HistoryListProps> = ({
  records,
  onUpdateRecord,
  onDeleteRecord,
}) => {
  const [editingRecord, setEditingRecord] = useState<FocusRecord | null>(null);
  const [editName, setEditName] = useState('');
  const [editTagsRaw, setEditTagsRaw] = useState('');

  const handleStartEdit = (r: FocusRecord) => {
    setEditingRecord(r);
    setEditName(r.name);
    setEditTagsRaw(r.tags.join(', '));
  };

  const handleSaveEdit = () => {
    if (!editingRecord) return;
    const cleanTags = editTagsRaw
      .split(/[,，\s]+/)
      .map((t) => t.trim())
      .filter(Boolean);

    onUpdateRecord(editingRecord.id, {
      name: editName.trim() || '未命名专注',
      tags: cleanTags,
    });
    setEditingRecord(null);
  };

  if (records.length === 0) {
    return <div className="empty-history">暂无历史专注记录</div>;
  }

  return (
    <div className="history-container">
      <div className="history-header">
        <h3 className="section-title">历史专注记录 ({records.length} 条)</h3>
      </div>

      <div className="history-scroll-list">
        {records.map((record) => {
          const totalSec = record.segments.reduce(
            (acc, s) => acc + (new Date(s.end).getTime() - new Date(s.start).getTime()) / 1000,
            0
          );
          const d = new Date(record.startedAt);
          const dateStr = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d
            .getDate()
            .toString()
            .padStart(2, '0')}`;

          return (
            <div key={record.id} className="history-card">
              <div className="history-card-left">
                <div className="history-card-title-row">
                  <span className="history-name">{record.name}</span>
                  {record.completed ? (
                    <span className="status-badge-complete">
                      <CheckCircle size={12} /> 已完成
                    </span>
                  ) : (
                    <span className="status-badge-incomplete">
                      <XCircle size={12} /> 提前结束
                    </span>
                  )}
                </div>

                <div className="history-card-meta">
                  <span className="meta-time">
                    <Calendar size={12} /> {dateStr} {formatTimeRange(record.startedAt, record.endedAt)}
                  </span>
                  <span className="meta-duration">时长: {formatDurationChinese(totalSec)}</span>
                </div>

                {record.tags.length > 0 && (
                  <div className="history-tags-row">
                    {record.tags.map((tag, idx) => (
                      <span key={tag} className={`history-tag ${idx === 0 ? 'primary-category-tag' : ''}`}>
                        #{tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              <div className="history-card-actions">
                <button
                  type="button"
                  className="btn-icon-action"
                  onClick={() => handleStartEdit(record)}
                  title="编辑记录与标签"
                >
                  <Edit3 size={15} />
                </button>
                <button
                  type="button"
                  className="btn-icon-action btn-danger-action"
                  onClick={() => {
                    if (window.confirm(`确定删除记录「${record.name}」吗？`)) {
                      onDeleteRecord(record.id);
                    }
                  }}
                  title="删除记录"
                >
                  <Trash2 size={15} />
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Edit Modal Dialog */}
      {editingRecord && (
        <div className="modal-overlay">
          <div className="modal-card">
            <h3 className="modal-title">编辑专注记录</h3>
            <div className="modal-form-group">
              <label>任务名称</label>
              <input
                type="text"
                className="modal-input"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
              />
            </div>
            <div className="modal-form-group">
              <label>标签列表（首个标签将作为统计主分类，使用逗号或空格隔开）</label>
              <input
                type="text"
                className="modal-input"
                value={editTagsRaw}
                onChange={(e) => setEditTagsRaw(e.target.value)}
                placeholder="例如: 开发, 需求, 架构"
              />
            </div>
            <div className="modal-actions">
              <button className="btn btn-secondary" onClick={() => setEditingRecord(null)}>
                取消
              </button>
              <button className="btn btn-primary" onClick={handleSaveEdit}>
                保存修改
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
