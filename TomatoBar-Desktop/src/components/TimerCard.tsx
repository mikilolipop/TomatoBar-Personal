import React from 'react';
import type { FocusState } from '../types';
import { Play, Pause, Square, FastForward, CheckCircle2 } from 'lucide-react';

interface TimerCardProps {
  state: FocusState;
  onStartWork: () => void;
  onPause: () => void;
  onResume: () => void;
  onStopEarly: () => void;
  onStartRest: (durationSec?: number) => void;
  onSkipRest: () => void;
}

export const TimerCard: React.FC<TimerCardProps> = ({
  state,
  onStartWork,
  onPause,
  onResume,
  onStopEarly,
  onStartRest,
  onSkipRest,
}) => {
  const { phase, paused, remaining, rounds, name, activeTags, currentTodoID, todos } = state;

  const currentTodo = todos.find((t) => t.id === currentTodoID);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(Math.max(0, seconds) / 60);
    const secs = Math.floor(Math.max(0, seconds) % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const getPhaseBadge = () => {
    if (paused) return { text: '已暂停', className: 'badge-paused' };
    switch (phase) {
      case 'work':
        return { text: '专注中', className: 'badge-work' };
      case 'rest':
        return { text: '休息中', className: 'badge-rest' };
      case 'workFinished':
        return { text: '专注完成', className: 'badge-finished' };
      case 'restFinished':
        return { text: '休息完毕', className: 'badge-finished' };
      default:
        return { text: '待机准备', className: 'badge-idle' };
    }
  };

  const badge = getPhaseBadge();

  return (
    <div className={`timer-card ${phase}`}>
      <div className="timer-header">
        <div className="badge-group">
          <span className={`phase-badge ${badge.className}`}>{badge.text}</span>
          {rounds > 0 && <span className="rounds-pill">第 {rounds} 轮</span>}
        </div>
        {currentTodo && (
          <div className="current-task-pill" title="当前关联的待办事项">
            <CheckCircle2 size={13} className="text-accent" />
            <span className="task-title-truncate">{currentTodo.title}</span>
          </div>
        )}
      </div>

      <div className="countdown-display">
        <h1 className="countdown-digits">{formatTime(remaining)}</h1>
      </div>

      <div className="task-context-bar">
        <span className="current-task-name">{name || '🍅 准备就绪，开启一段心流'}</span>
        {activeTags.length > 0 && (
          <div className="tag-pills">
            {activeTags.map((t) => (
              <span key={t} className="tag-pill">
                #{t}
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="timer-actions">
        {phase === 'idle' && (
          <button className="btn btn-primary btn-large" onClick={onStartWork}>
            <Play size={18} /> 开始专注 (25m)
          </button>
        )}

        {phase === 'work' && !paused && (
          <div className="btn-group">
            <button className="btn btn-secondary" onClick={onPause}>
              <Pause size={17} /> 暂停
            </button>
            <button className="btn btn-danger-outline" onClick={onStopEarly}>
              <Square size={16} /> 提前结束
            </button>
          </div>
        )}

        {phase === 'work' && paused && (
          <div className="btn-group">
            <button className="btn btn-primary" onClick={onResume}>
              <Play size={17} /> 继续专注
            </button>
            <button className="btn btn-danger-outline" onClick={onStopEarly}>
              <Square size={16} /> 放弃本轮
            </button>
          </div>
        )}

        {phase === 'rest' && (
          <div className="btn-group">
            {!paused ? (
              <button className="btn btn-secondary" onClick={onPause}>
                <Pause size={17} /> 暂停休息
              </button>
            ) : (
              <button className="btn btn-primary" onClick={onResume}>
                <Play size={17} /> 继续休息
              </button>
            )}
            <button className="btn btn-secondary" onClick={onSkipRest}>
              <FastForward size={16} /> 跳过休息
            </button>
          </div>
        )}

        {phase === 'workFinished' && (
          <div className="btn-group">
            <button className="btn btn-success" onClick={() => onStartRest(5 * 60)}>
              <Play size={17} /> 开始短休 (5m)
            </button>
            <button className="btn btn-secondary" onClick={onSkipRest}>
              <FastForward size={16} /> 跳过并下一轮
            </button>
          </div>
        )}

        {phase === 'restFinished' && (
          <div className="btn-group">
            <button className="btn btn-primary btn-large" onClick={onStartWork}>
              <Play size={18} /> 开启下一轮专注
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
