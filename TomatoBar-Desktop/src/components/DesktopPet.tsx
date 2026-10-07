import React, { useEffect, useState, useRef } from 'react';
import type { FocusPhase, PetKind } from '../types';

interface PetAnimConfig {
  file: string;
  frameCount: number;
  durations: number[];
  loopMode: 'loop' | 'onceHold';
}

function getPetAnimation(kind: PetKind, phase: FocusPhase, paused: boolean): PetAnimConfig {
  if (kind === 'sprout') {
    if (paused) {
      if (phase === 'work') {
        return {
          file: '/sprites/pet_sprout_work_paused_v3.png',
          frameCount: 4,
          durations: [0.7, 0.7, 0.15, 0.7],
          loopMode: 'loop',
        };
      }
      return {
        file: '/sprites/pet_sprout_rest_paused_v3.png',
        frameCount: 4,
        durations: [0.6, 0.6, 0.6, 0.6],
        loopMode: 'loop',
      };
    }

    switch (phase) {
      case 'work':
        return {
          file: '/sprites/pet_sprout_work_v3.png',
          frameCount: 10,
          durations: [0.16, 0.14, 0.12, 0.16, 0.1, 0.12, 0.15, 0.14, 0.13, 0.16],
          loopMode: 'loop',
        };
      case 'rest':
        return {
          file: '/sprites/pet_sprout_rest_v3.png',
          frameCount: 8,
          durations: [0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32],
          loopMode: 'loop',
        };
      case 'workFinished':
        return {
          file: '/sprites/pet_sprout_work_finished_v3.png',
          frameCount: 8,
          durations: [0.16, 0.14, 0.13, 0.14, 0.16, 0.16, 0.2, 0.75],
          loopMode: 'onceHold',
        };
      case 'restFinished':
        return {
          file: '/sprites/pet_sprout_rest_finished_v3.png',
          frameCount: 8,
          durations: [0.28, 0.24, 0.2, 0.18, 0.16, 0.15, 0.16, 0.7],
          loopMode: 'onceHold',
        };
      case 'idle':
      default:
        return {
          file: '/sprites/pet_sprout_idle_v3.png',
          frameCount: 8,
          durations: [0.45, 0.45, 0.45, 0.08, 0.1, 0.08, 0.55, 0.55],
          loopMode: 'loop',
        };
    }
  }

  // Default: tomy
  if (paused) {
    return {
      file: '/sprites/pet_tomy_paused_v2.png',
      frameCount: 4,
      durations: [0.7, 0.7, 0.12, 0.7],
      loopMode: 'loop',
    };
  }

  switch (phase) {
    case 'work':
      return {
        file: '/sprites/pet_tomy_work_v2.png',
        frameCount: 10,
        durations: [0.11, 0.1, 0.12, 0.11, 0.06, 0.08, 0.12, 0.11, 0.12, 0.13],
        loopMode: 'loop',
      };
    case 'rest':
      return {
        file: '/sprites/pet_tomy_rest_v2.png',
        frameCount: 8,
        durations: [0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22],
        loopMode: 'loop',
      };
    case 'workFinished':
      return {
        file: '/sprites/pet_tomy_work_finished_v2.png',
        frameCount: 8,
        durations: [0.13, 0.11, 0.11, 0.18, 0.18, 0.14, 0.18, 0.7],
        loopMode: 'onceHold',
      };
    case 'restFinished':
      return {
        file: '/sprites/pet_tomy_rest_finished_v2.png',
        frameCount: 8,
        durations: [0.26, 0.22, 0.16, 0.15, 0.14, 0.12, 0.12, 0.65],
        loopMode: 'onceHold',
      };
    case 'idle':
    default:
      return {
        file: '/sprites/pet_tomy_idle_v2.png',
        frameCount: 8,
        durations: [0.42, 0.42, 0.42, 0.07, 0.1, 0.07, 0.52, 0.52],
        loopMode: 'loop',
      };
  }
}

interface DesktopPetProps {
  kind?: PetKind;
  phase: FocusPhase;
  paused: boolean;
  size?: number; // width/height in px, default 96
  floating?: boolean;
}

export const DesktopPet: React.FC<DesktopPetProps> = ({
  kind = 'tomy',
  phase,
  paused,
  size = 96,
  floating = false,
}) => {
  const [frameIndex, setFrameIndex] = useState(0);
  const anim = getPetAnimation(kind, phase, paused);
  const timerRef = useRef<number | null>(null);

  // Position state for floating drag
  const [pos, setPos] = useState({ x: 24, y: 24 });
  const [isDragging, setIsDragging] = useState(false);
  const dragStartRef = useRef({ mouseX: 0, mouseY: 0, startX: 0, startY: 0 });

  useEffect(() => {
    setFrameIndex(0);
  }, [anim.file]);

  useEffect(() => {
    const currentDuration = (anim.durations[frameIndex] || 0.15) * 1000;

    timerRef.current = window.setTimeout(() => {
      setFrameIndex((prev) => {
        if (prev >= anim.frameCount - 1) {
          if (anim.loopMode === 'onceHold') {
            return prev;
          }
          return 0;
        }
        return prev + 1;
      });
    }, currentDuration);

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [frameIndex, anim]);

  // Dragging handlers for floating widget mode
  const handleMouseDown = (e: React.MouseEvent) => {
    if (!floating) return;
    setIsDragging(true);
    dragStartRef.current = {
      mouseX: e.clientX,
      mouseY: e.clientY,
      startX: pos.x,
      startY: pos.y,
    };
  };

  useEffect(() => {
    if (!isDragging) return;

    const handleMouseMove = (e: MouseEvent) => {
      const dx = e.clientX - dragStartRef.current.mouseX;
      const dy = e.clientY - dragStartRef.current.mouseY;
      setPos({
        x: Math.max(10, Math.min(window.innerWidth - size - 10, dragStartRef.current.startX + dx)),
        y: Math.max(10, Math.min(window.innerHeight - size - 10, dragStartRef.current.startY + dy)),
      });
    };

    const handleMouseUp = () => {
      setIsDragging(false);
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, size]);

  const style: React.CSSProperties = floating
    ? {
        position: 'fixed',
        left: `${pos.x}px`,
        top: `${pos.y}px`,
        zIndex: 9999,
        cursor: isDragging ? 'grabbing' : 'grab',
      }
    : {
        position: 'relative',
      };

  const spriteWidth = size * anim.frameCount;
  const offsetX = -frameIndex * size;

  return (
    <div
      className={`desktop-pet-container ${floating ? 'floating-widget' : ''}`}
      style={style}
      onMouseDown={handleMouseDown}
      title={`${kind === 'tomy' ? '🍅 番茄仔' : '🌱 植小芽'} · 状态: ${
        paused ? '暂停中' : phase === 'work' ? '专注中' : phase === 'rest' ? '休息中' : '待机'
      } (可拖动挂件)`}
    >
      <div
        className="sprite-viewport"
        style={{
          width: `${size}px`,
          height: `${size}px`,
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'flex-start',
        }}
      >
        <img
          src={anim.file}
          alt="Desktop Pet Sprite"
          draggable={false}
          style={{
            width: `${spriteWidth}px`,
            height: `${size}px`,
            maxWidth: 'none',
            transform: `translateX(${offsetX}px)`,
            imageRendering: 'pixelated',
            pointerEvents: 'none',
            userSelect: 'none',
          }}
        />
      </div>
      {floating && (
        <div className="pet-status-pill">
          {paused ? '暂停' : phase === 'work' ? '专注' : phase === 'rest' ? '休息' : '待机'}
        </div>
      )}
    </div>
  );
};
