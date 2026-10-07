import React, { useState } from 'react';
import type { FocusState, PetKind } from '../types';
import { DesktopPet } from './DesktopPet';
import { X, Play, Pause, Square, FastForward } from 'lucide-react';

interface ExpandedTimerModalProps {
  state: FocusState;
  petKind: PetKind;
  onStartWork: () => void;
  onPause: () => void;
  onResume: () => void;
  onStopEarly: () => void;
  onStartRest: (durationSec?: number) => void;
  onSkipRest: () => void;
  onClose: () => void;
}

export const ExpandedTimerModal: React.FC<ExpandedTimerModalProps> = ({
  state,
  petKind,
  onStartWork,
  onPause,
  onResume,
  onStopEarly,
  onStartRest,
  onSkipRest,
  onClose,
}) => {
  const [showCancelConfirm, setShowCancelConfirm] = useState(false);

  const { phase, paused, remaining, name, currentTodoID, todos, projects } = state;

  const currentTodo = todos.find((t) => t.id === currentTodoID);
  const currentProject = currentTodo?.projectID
    ? projects.find((p) => p.id === currentTodo.projectID)
    : null;

  const formatTime = (seconds: number) => {
    const mins = Math.floor(Math.max(0, seconds) / 60);
    const secs = Math.floor(Math.max(0, seconds) % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const getPhaseLabel = () => {
    if (paused) return '已暂停';
    switch (phase) {
      case 'work':
        return '专注中';
      case 'rest':
        return '休息中';
      case 'workFinished':
        return '专注达成';
      case 'restFinished':
        return '休息完毕';
      default:
        return '准备就绪';
    }
  };

  return (
    <div className="garden-modal-overlay">
      <div className="expanded-timer-card">
        {/* Top Header */}
        <div className="expanded-timer-top">
          <button className="expanded-close-btn" onClick={onClose} title="收起计时器">
            <X size={16} /> 收起
          </button>
        </div>

        {/* Pixel Pet in the Center */}
        <div className="expanded-pet-wrapper">
          <DesktopPet
            kind={petKind}
            phase={phase}
            paused={paused}
            size={110}
            floating={false}
          />
        </div>

        {/* Phase Label */}
        <div className="expanded-phase-label">{getPhaseLabel()}</div>

        {/* Task Title & Project Context */}
        <div className="expanded-task-row">
          {currentTodo ? (
            <div className="expanded-todo-badge">
              <span className="target-icon">🎯</span>
              {currentProject && <span className="proj-name">[{currentProject.name}] · </span>}
              <span className="task-title">{currentTodo.title}</span>
              {currentTodo.tags.length > 0 && (
                <span className="tag-group">
                  {currentTodo.tags.map((t) => (
                    <span key={t} className="tag-pill">
                      #{t}
                    </span>
                  ))}
                </span>
              )}
            </div>
          ) : (
            <div className="expanded-task-text">{name || '自由专注'}</div>
          )}
        </div>

        {/* Giant Countdown Digits (Garden Red) */}
        <div className="expanded-digits-wrapper">
          <div className="expanded-digits">
            {phase === 'workFinished' || phase === 'restFinished' ? '完成' : formatTime(remaining)}
          </div>
        </div>

        {/* Main Action Buttons */}
        <div className="expanded-actions-container">
          {phase === 'idle' && (
            <button className="garden-btn-primary" onClick={onStartWork}>
              <Play size={16} fill="currentColor" /> 开始专注
            </button>
          )}

          {phase === 'work' && (
            <div className="expanded-btn-stack">
              {!paused ? (
                <button className="garden-btn-primary" onClick={onPause}>
                  <Pause size={16} fill="currentColor" /> 暂停
                </button>
              ) : (
                <button className="garden-btn-primary" onClick={onResume}>
                  <Play size={16} fill="currentColor" /> 继续专注
                </button>
              )}

              <div className="expanded-sub-btn-row">
                <button className="garden-btn-secondary" onClick={onStopEarly}>
                  <Square size={14} /> 结束并记录
                </button>
                <button
                  className="garden-btn-secondary btn-muted"
                  onClick={() => setShowCancelConfirm(true)}
                  title="丢弃这段专注，不保存为记录"
                >
                  取消专注
                </button>
              </div>
            </div>
          )}

          {phase === 'rest' && (
            <div className="expanded-btn-stack">
              {!paused ? (
                <button className="garden-btn-primary" onClick={onPause}>
                  <Pause size={16} fill="currentColor" /> 暂停休息
                </button>
              ) : (
                <button className="garden-btn-primary" onClick={onResume}>
                  <Play size={16} fill="currentColor" /> 继续休息
                </button>
              )}

              <div className="expanded-sub-btn-row">
                <button className="garden-btn-secondary" onClick={onSkipRest}>
                  <FastForward size={14} /> 跳过休息
                </button>
                <button className="garden-btn-secondary btn-muted" onClick={onStopEarly}>
                  结束本组
                </button>
              </div>
            </div>
          )}

          {phase === 'workFinished' && (
            <div className="expanded-btn-stack">
              <button className="garden-btn-primary" onClick={() => onStartRest(5 * 60)}>
                开始短休 (5m)
              </button>
              <button className="garden-btn-secondary" onClick={onSkipRest}>
                跳过休息并开始下一轮
              </button>
            </div>
          )}

          {phase === 'restFinished' && (
            <button className="garden-btn-primary" onClick={onStartWork}>
              开启下一轮专注
            </button>
          )}
        </div>

        {/* Footer Hint */}
        <div className="expanded-footer-hint">
          收起或关闭主窗口后，任务栏会继续陪你专注。
        </div>

        {/* Cancel Confirmation Alert */}
        {showCancelConfirm && (
          <div className="garden-submodal-overlay">
            <div className="garden-submodal-card">
              <h4>取消这段专注？</h4>
              <p>取消后，当前进行中的时段将直接丢弃，不计入统计也不保存为记录。</p>
              <div className="submodal-actions">
                <button className="garden-btn-secondary" onClick={() => setShowCancelConfirm(false)}>
                  继续专注
                </button>
                <button
                  className="garden-btn-danger"
                  onClick={() => {
                    setShowCancelConfirm(false);
                    onStopEarly();
                  }}
                >
                  确认取消
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
