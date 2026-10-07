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
    <div className="garden-modal-overlay">
      <div className="garden-dialog-card settings-card" style={{ maxWidth: 560 }}>
        <div className="dialog-header-row">
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 16, fontWeight: 700 }}>
            <Sliders size={18} /> 偏好设置
          </h3>
          <button className="dialog-close-icon" onClick={onClose} title="关闭">
            <X size={16} />
          </button>
        </div>

        <div className="dialog-field">
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
            ⏱️ 专注时长配置
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 6 }}>
            <div>
              <span style={{ fontSize: 12, color: 'var(--garden-muted)' }}>工作专注时长</span>
              <select
                value={workMinutes}
                onChange={(e) => onUpdateDurations(Number(e.target.value), shortRestMinutes, longRestMinutes)}
                className="garden-input"
                style={{ marginTop: 4 }}
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

            <div>
              <span style={{ fontSize: 12, color: 'var(--garden-muted)' }}>短休息时长</span>
              <select
                value={shortRestMinutes}
                onChange={(e) => onUpdateDurations(workMinutes, Number(e.target.value), longRestMinutes)}
                className="garden-input"
                style={{ marginTop: 4 }}
              >
                <option value={3}>3 分钟</option>
                <option value={5}>5 分钟 (默认)</option>
                <option value={10}>10 分钟</option>
              </select>
            </div>
          </div>
        </div>

        <div className="dialog-field" style={{ marginTop: 14 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
            <Sparkles size={15} /> 桌面挂件 / 桌面宠物
          </label>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '10px 14px',
              background: 'rgba(239, 230, 214, 0.45)',
              borderRadius: 8,
              marginTop: 6,
            }}
          >
            <div>
              <div style={{ fontSize: 13, fontWeight: 600 }}>开启桌面宠物挂件</div>
              <div style={{ fontSize: 11, color: 'var(--garden-muted)' }}>
                在屏幕上悬浮显示随专注状态互动的像素小宠物（支持自由拖拽）
              </div>
            </div>
            <input
              type="checkbox"
              checked={showPet}
              onChange={(e) => onUpdatePet(petKind, e.target.checked)}
              style={{ width: 18, height: 18, accentColor: 'var(--garden-red)', cursor: 'pointer' }}
            />
          </div>

          {showPet && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 10 }}>
              <button
                type="button"
                className={`garden-btn-secondary ${petKind === 'tomy' ? 'active-pet' : ''}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 12px',
                  border: petKind === 'tomy' ? '2px solid var(--garden-red)' : '1px solid var(--garden-line)',
                  background: petKind === 'tomy' ? 'rgba(179, 77, 61, 0.08)' : 'var(--garden-surface)',
                  borderRadius: 8,
                  cursor: 'pointer',
                  textAlign: 'left',
                }}
                onClick={() => onUpdatePet('tomy', true)}
              >
                <span style={{ fontSize: 20 }}>🍅</span>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700 }}>番茄仔 · Tomy</div>
                  <div style={{ fontSize: 10, color: 'var(--garden-muted)' }}>敲键盘的番茄小极客</div>
                </div>
              </button>

              <button
                type="button"
                className={`garden-btn-secondary ${petKind === 'sprout' ? 'active-pet' : ''}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 12px',
                  border: petKind === 'sprout' ? '2px solid var(--garden-red)' : '1px solid var(--garden-line)',
                  background: petKind === 'sprout' ? 'rgba(179, 77, 61, 0.08)' : 'var(--garden-surface)',
                  borderRadius: 8,
                  cursor: 'pointer',
                  textAlign: 'left',
                }}
                onClick={() => onUpdatePet('sprout', true)}
              >
                <span style={{ fontSize: 20 }}>🌱</span>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700 }}>植小芽 · Sprout</div>
                  <div style={{ fontSize: 10, color: 'var(--garden-muted)' }}>抱书静心翻阅的小芽</div>
                </div>
              </button>
            </div>
          )}
        </div>

        <div className="dialog-field" style={{ marginTop: 14 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
            <Database size={15} /> 本地数据与跨端互通
          </label>
          <div style={{ fontSize: 12, color: 'var(--garden-muted)', marginTop: 4 }}>
            当前包含 <strong>{state.records.length}</strong> 条历史记录与 <strong>{state.todos.length}</strong> 个待办任务。
            数据格式与 macOS 原生版本 100% 互通。
          </div>

          <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
            <button
              type="button"
              className="garden-btn-secondary"
              style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
              onClick={onExportData}
            >
              <Download size={14} /> 导出 sessions.json
            </button>
            <button
              type="button"
              className="garden-btn-secondary"
              style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
              onClick={() => fileInputRef.current?.click()}
            >
              <Upload size={14} /> 导入 sessions.json
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

        <div className="dialog-actions" style={{ marginTop: 18 }}>
          <button type="button" className="garden-btn-primary" onClick={onClose} style={{ minWidth: 100 }}>
            完成
          </button>
        </div>
      </div>
    </div>
  );
};
