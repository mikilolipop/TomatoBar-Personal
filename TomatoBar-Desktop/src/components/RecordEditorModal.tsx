import React, { useState } from "react";
import { Modal } from "./Modal";
import { recordSeconds } from "../types";
import type { FocusRecord } from "../types";
import { formatDurationChinese, formatTimeRange } from "../core/analytics";
import { X, Trash2, Calendar, Clock } from "lucide-react";

interface RecordEditorModalProps {
  record: FocusRecord;
  onSave: (id: string, name: string, tags: string[]) => Promise<boolean>;
  onDelete: (id: string) => Promise<boolean>;
  onClose: () => void;
}

export const RecordEditorModal: React.FC<RecordEditorModalProps> = ({
  record,
  onSave,
  onDelete,
  onClose,
}) => {
  const [name, setName] = useState(record.name);
  const [tagsInput, setTagsInput] = useState(record.tags.join(", "));

  const totalSec = recordSeconds(record);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const handleSave = async () => {
    const cleanTags = tagsInput
      .split(/[,，\s]+/)
      .map((t) => t.trim())
      .filter(Boolean);

    setSaving(true);
    const saved = await onSave(record.id, name, cleanTags);
    setSaving(false);
    if (saved) onClose();
    else setError("修改未保存，请收起编辑器后重试保存。");
  };

  const handleSetPrimary = (primaryCategory: string) => {
    const clean = tagsInput
      .split(/[,，\s]+/)
      .map((t) => t.trim())
      .filter((t) => t && t.toLowerCase() !== primaryCategory.toLowerCase());
    setTagsInput([primaryCategory, ...clean].join(", "));
  };

  return (
    <Modal title="编辑专注记录" onClose={onClose}>
      <div className="garden-dialog-card record-editor-dialog">
        <div className="dialog-header-row">
          <h3>编辑专注记录</h3>
          <button
            className="dialog-close-icon"
            aria-label="关闭编辑器"
            onClick={onClose}
          >
            <X size={16} />
          </button>
        </div>

        <div className="record-editor-meta-strip">
          <span>
            <Calendar size={13} />{" "}
            {new Date(record.startedAt).toLocaleDateString()}
          </span>
          <span>
            <Clock size={13} />{" "}
            {formatTimeRange(record.startedAt, record.endedAt)} (
            {formatDurationChinese(totalSec)})
          </span>
        </div>

        <div className="dialog-field">
          <label>任务名称</label>
          <input
            type="text"
            className="garden-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        <div className="dialog-field">
          <label>标签列表（首个标签将作为统计分类）</label>
          <input
            type="text"
            className="garden-input"
            value={tagsInput}
            onChange={(e) => setTagsInput(e.target.value)}
            placeholder="例如: 开发, 需求, 架构"
          />
        </div>

        <div className="dialog-field">
          <label className="sub-label">快速设置主分类:</label>
          <div className="primary-cat-chips">
            {["开发", "设计", "阅读", "建模", "英语", "数学", "写作"].map(
              (cat) => (
                <button
                  key={cat}
                  type="button"
                  className="chip-btn"
                  onClick={() => handleSetPrimary(cat)}
                >
                  #{cat}
                </button>
              ),
            )}
          </div>
        </div>

        {error && <p role="alert">{error}</p>}
        <fieldset disabled={saving} className="dialog-actions-split">
          <button
            type="button"
            className="garden-btn-danger"
            onClick={async () => {
              if (window.confirm(`确定删除「${record.name}」这条记录吗？`)) {
                setSaving(true);
                const saved = await onDelete(record.id);
                setSaving(false);
                if (saved) onClose();
                else setError("删除未保存，请关闭编辑器后重试。");
              }
            }}
          >
            <Trash2 size={14} /> 删除记录
          </button>

          <div className="right-btns">
            <button
              type="button"
              className="garden-btn-secondary"
              onClick={onClose}
            >
              取消
            </button>
            <button
              type="button"
              className="garden-btn-primary"
              onClick={() => {
                void handleSave();
              }}
              disabled={!name.trim()}
            >
              保存更改
            </button>
          </div>
        </fieldset>
      </div>
    </Modal>
  );
};
