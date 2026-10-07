import React, { useRef } from 'react';
import type { PetKind, FocusState } from '../types';
import { X, Download, Upload, Sliders, Sparkles, Database } from 'lucide-react';

interface SettingsModalProps {
  workMinutes: number;
  shortRestMinutes: number;
  longRestMinutes: number;
  petKind: PetKind;
  showPet: boolean;
  state: FocusState;
  onUpdateDurations: (work: number, shortRest: number, longRest: number) => void;
  onUpdatePet: (kind: PetKind, show: boolean) => void;
  onExportData: () => void;
  onImportData: (importedState: FocusState) => void;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  workMinutes,
  shortRestMinutes,
  longRestMinutes,
  petKind,
  showPet,
  state,
  onUpdateDurations,
  onUpdatePet,
  onExportData,
  onImportData,
  onClose,
}) => {
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const text = event.target?.result as string;
        const parsed = JSON.parse(text);
        if (window.confirm('导入数据将合并/替换当前数据，是否确认继续？')) {
          onImportData(parsed);
          alert('数据导入成功！');
          onClose();
        }
      } catch (err) {
        alert('文件解析失败，请确保选择的是有效的 sessions.json 格式文件。');
      }
    };
    reader.readAsText(file);
  };

  return (
    <div className="modal-overlay">
      <div className="modal-card settings-card">
        <div className="modal-header">
          <h3 className="modal-title">
            <Sliders size={18} /> 偏好设置
          </h3>
          <button className="modal-close-btn" onClick={onClose} title="关闭">
            <X size={18} />
          </button>
        </div>

        <div className="settings-section">
          <h4 className="settings-section-title">⏱️ 专注时长配置</h4>
          <div className="settings-grid">
            <div className="setting-item">
              <label>专注时长（分钟）</label>
              <select
                value={workMinutes}
                onChange={(e) => onUpdateDurations(Number(e.target.value), shortRestMinutes, longRestMinutes)}
                className="setting-select"
              >
                <option value={15}>15 分钟</option>
                <option value={20}>20 分钟</option>
                <option value={25}>25 分钟 (经典番茄)</option>
                <option value={30}>30 分钟</option>
                <option value={45}>45 分钟</option>
                <option value={50}>50 分钟</option>
                <option value={60}>60 分钟</option>
              </select>
            </div>

            <div className="setting-item">
              <label>短休息时长（分钟）</label>
              <select
                value={shortRestMinutes}
                onChange={(e) => onUpdateDurations(workMinutes, Number(e.target.value), longRestMinutes)}
                className="setting-select"
              >
                <option value={3}>3 分钟</option>
                <option value={5}>5 分钟 (默认)</option>
                <option value={10}>10 分钟</option>
              </select>
            </div>
          </div>
        </div>

        <div className="settings-section">
          <h4 className="settings-section-title">
            <Sparkles size={16} /> 桌面挂件 / 桌面宠物
          </h4>
          <div className="setting-toggle-row">
            <div>
              <div className="toggle-label">开启桌面宠物挂件</div>
              <div className="toggle-hint">在屏幕上悬浮显示随专注状态互动的像素小宠物（支持自由拖拽）</div>
            </div>
            <input
              type="checkbox"
              checked={showPet}
              onChange={(e) => onUpdatePet(petKind, e.target.checked)}
              className="setting-checkbox"
            />
          </div>

          {showPet && (
            <div className="pet-selector-row">
              <button
                type="button"
                className={`pet-select-card ${petKind === 'tomy' ? 'active' : ''}`}
                onClick={() => onUpdatePet('tomy', true)}
              >
                <span className="pet-emoji">🍅</span>
                <span className="pet-name">番茄仔 · Tomy</span>
                <span className="pet-sub">敲击键盘的番茄小极客</span>
              </button>

              <button
                type="button"
                className={`pet-select-card ${petKind === 'sprout' ? 'active' : ''}`}
                onClick={() => onUpdatePet('sprout', true)}
              >
                <span className="pet-emoji">🌱</span>
                <span className="pet-name">植小芽 · Sprout</span>
                <span className="pet-sub">抱书静心翻阅的盆栽小芽</span>
              </button>
            </div>
          )}
        </div>

        <div className="settings-section">
          <h4 className="settings-section-title">
            <Database size={16} /> 本地数据与跨端互通
          </h4>
          <p className="setting-hint-text">
            当前包含 <strong>{state.records.length}</strong> 条历史记录与 <strong>{state.todos.length}</strong> 个待办任务。
            数据格式与 macOS 原生版本 100% 互通。
          </p>

          <div className="backup-btn-row">
            <button className="btn btn-secondary" onClick={onExportData}>
              <Download size={15} /> 导出 sessions.json 备份
            </button>
            <button className="btn btn-secondary" onClick={() => fileInputRef.current?.click()}>
              <Upload size={15} /> 从文件导入 sessions.json
            </button>
            <input
              type="file"
              ref={fileInputRef}
              style={{ display: 'none' }}
              accept=".json"
              onChange={handleFileChange}
            />
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn btn-primary" onClick={onClose}>
            完成
          </button>
        </div>
      </div>
    </div>
  );
};
