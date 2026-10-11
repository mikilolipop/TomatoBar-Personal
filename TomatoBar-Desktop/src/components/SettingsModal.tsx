import { useRef, useState } from "react";
import type { FocusState } from "../types";
import type { AppSettings } from "../core/settings";
import { decodeSessions } from "../core/sessionsCodec";
import { Modal } from "./Modal";
import { X, Download, Upload, Sliders, Sparkles, Database } from "lucide-react";

export function SettingsModal({
  settings,
  state,
  canExport,
  busy,
  error,
  onUpdateSettings,
  onExportData,
  onImportData,
  onClose,
  onRestoreDefaults,
}: {
  settings: AppSettings;
  state: FocusState;
  canExport: boolean;
  busy: boolean;
  error: string | null;
  onUpdateSettings: (changes: Partial<AppSettings>) => Promise<boolean>;
  onExportData: () => void;
  onImportData: (json: string) => Promise<boolean>;
  onClose: () => void;
  onRestoreDefaults: () => Promise<boolean>;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [message, setMessage] = useState("");
  const [importing, setImporting] = useState(false);
  const changeFile = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setImporting(true);
    setMessage("");
    try {
      if (file.size > 20 * 1024 * 1024)
        throw new Error("文件超过 20 MB，请选择较小的记录备份。");
      const json = await file.text();
      const imported = decodeSessions(json);
      if (
        !window.confirm(
          `将用备份中的 ${imported.records.length} 条记录和 ${imported.todos.length} 个待办替换当前数据。当前数据会保留为备份。继续导入？`,
        )
      )
        return;
      const saved = await onImportData(json);
      setMessage(saved ? "数据已校验并保存。" : "数据未能保存，请重试。");
    } catch (e) {
      setMessage(e instanceof Error ? e.message : String(e));
    } finally {
      setImporting(false);
    }
  };
  const disabled = busy || importing || !!error;
  return (
    <Modal title="偏好设置" onClose={onClose}>
      <div className="garden-dialog-card settings-card">
        <div className="dialog-header-row">
          <h3>
            <Sliders size={18} />
            偏好设置
          </h3>
          <button
            className="dialog-close-icon"
            aria-label="关闭设置"
            onClick={onClose}
          >
            <X size={16} />
          </button>
        </div>
        <fieldset disabled={disabled} className="settings-fields">
          <div className="settings-duration-grid">
            {(
              [
                ["workMinutes", "专注时长", [15, 20, 25, 30, 45, 50, 60]],
                ["shortRestMinutes", "短休息时长", [3, 5, 10]],
                ["longRestMinutes", "长休息时长", [10, 15, 20, 30]],
                ["longRestEvery", "长休息间隔", [2, 3, 4, 5, 6]],
              ] as const
            ).map(([key, label, values]) => (
              <label key={key}>
                {label}
                <select
                  aria-label={label}
                  className="garden-input"
                  value={settings[key]}
                  onChange={(e) => {
                    void onUpdateSettings({ [key]: Number(e.target.value) });
                  }}
                >
                  {Array.from(new Set([...values, settings[key]]))
                    .sort((a, b) => a - b)
                    .map((n) => (
                      <option key={n} value={n}>
                        {n} {key === "longRestEvery" ? "轮" : "分钟"}
                      </option>
                    ))}
                </select>
              </label>
            ))}
          </div>
          <div className="dialog-field">
            <h4>
              <Sparkles size={15} />
              窗口宠物
            </h4>
            <label className="pet-toggle">
              <span>在应用窗口中显示可拖动宠物</span>
              <input
                type="checkbox"
                checked={settings.showPet}
                onChange={(e) => {
                  void onUpdateSettings({ showPet: e.target.checked });
                }}
              />
            </label>
            {settings.showPet && (
              <div className="pet-choices">
                {(["tomy", "sprout"] as const).map((kind) => (
                  <button
                    key={kind}
                    className="garden-btn-secondary"
                    aria-pressed={settings.petKind === kind}
                    onClick={() => {
                      void onUpdateSettings({ petKind: kind });
                    }}
                  >
                    {kind === "tomy"
                      ? "🍅 番茄仔 · Tomy"
                      : "🌱 植小芽 · Sprout"}
                  </button>
                ))}
              </div>
            )}
          </div>
        </fieldset>
        <div className="dialog-field">
          <h4>
            <Database size={15} />
            本地数据与备份
          </h4>
          <p className="settings-hint">
            {canExport
              ? `${state.records.length} 条历史记录 · ${state.todos.length} 个待办`
              : "当前记录读取失败，请重试读取或导入有效备份。"}
            <br />
            支持旧版 Windows 与 macOS 的 sessions.json。导入会替换当前数据。
          </p>
          <div className="settings-data-actions">
            <button
              className="garden-btn-secondary"
              disabled={!canExport || importing}
              onClick={onExportData}
            >
              <Download size={14} />
              导出备份
            </button>
            <button
              className="garden-btn-secondary"
              disabled={busy || importing}
              onClick={() => input.current?.click()}
            >
              <Upload size={14} />
              {importing ? "正在导入…" : "导入备份"}
            </button>
            <input
              ref={input}
              type="file"
              accept=".json,application/json"
              hidden
              onChange={(e) => {
                void changeFile(e);
              }}
            />
          </div>
          {!canExport && (
            <button
              className="garden-btn-secondary"
              disabled={busy || importing}
              onClick={async () => {
                if (
                  window.confirm(
                    "恢复默认时长和宠物偏好？原设置会保留备份，专注记录不修改。",
                  )
                ) {
                  const restored = await onRestoreDefaults();
                  setMessage(
                    restored
                      ? "默认设置已保存。记录仍有错误时，可继续导入记录备份。"
                      : "设置未能恢复，请重试。",
                  );
                }
              }}
            >
              恢复默认设置
            </button>
          )}
          {(message || error) && (
            <p className="settings-message" role="status">
              {message || error}
            </p>
          )}
        </div>
        <div className="dialog-actions">
          <button className="garden-btn-primary" onClick={onClose}>
            完成
          </button>
        </div>
      </div>
    </Modal>
  );
}
