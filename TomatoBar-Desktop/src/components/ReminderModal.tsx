import React from "react";
import { Modal } from "./Modal";
import type { FocusPhase } from "../types";
import { Coffee, Flame, X } from "lucide-react";

interface ReminderModalProps {
  phase: FocusPhase;
  rounds: number;
  taskName: string;
  onStartRest: (durationSec?: number) => void;
  onSkipRest: () => void;
  onStartWork: () => void;
  onDismiss: () => void;
  workMinutes: number;
  restMinutes: number;
  busy: boolean;
}

export const ReminderModal: React.FC<ReminderModalProps> = ({
  phase,
  rounds,
  taskName,
  onStartRest,
  onSkipRest,
  onStartWork,
  onDismiss,
  workMinutes,
  restMinutes,
  busy,
}) => {
  if (phase !== "workFinished" && phase !== "restFinished") {
    return null;
  }

  const isWorkDone = phase === "workFinished";

  return (
    <Modal
      title="计时完成提醒"
      className="reminder-overlay"
      onClose={onDismiss}
    >
      <div
        className={`reminder-card ${isWorkDone ? "reminder-work" : "reminder-rest"}`}
      >
        <button
          className="reminder-close-btn"
          onClick={onDismiss}
          title="关闭提醒"
        >
          <X size={18} />
        </button>

        <div className="reminder-icon-wrapper">
          {isWorkDone ? (
            <Flame size={40} className="pulse-icon" />
          ) : (
            <Coffee size={40} className="pulse-icon" />
          )}
        </div>

        <h2 className="reminder-title">
          {isWorkDone ? "🎉 专注时段达成！" : "🌿 休息时间结束！"}
        </h2>

        <p className="reminder-subtitle">
          {isWorkDone
            ? `已圆满完成第 ${rounds} 轮专注「${taskName || "专注任务"}」。让双眼和身体放松一下吧。`
            : "休息完毕，元气满满！准备好开启下一段心流了吗？"}
        </p>

        <fieldset className="reminder-actions" disabled={busy}>
          {isWorkDone ? (
            <>
              <button
                className="btn btn-success btn-large"
                onClick={() => {
                  onStartRest();
                }}
              >
                <Coffee size={18} /> 开始休息 ({restMinutes} 分钟)
              </button>
              <button className="btn btn-secondary" onClick={onSkipRest}>
                跳过休息，准备下一轮
              </button>
            </>
          ) : (
            <>
              <button
                className="btn btn-primary btn-large"
                onClick={onStartWork}
              >
                <Flame size={18} /> 开启下一轮专注 ({workMinutes} 分钟)
              </button>
              <button className="btn btn-secondary" onClick={onDismiss}>
                稍后再开始
              </button>
            </>
          )}
        </fieldset>
      </div>
    </Modal>
  );
};
