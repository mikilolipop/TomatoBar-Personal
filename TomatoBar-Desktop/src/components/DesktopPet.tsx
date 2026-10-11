import { useEffect, useMemo, useRef, useState } from "react";
import type { FocusPhase, PetKind } from "../types";
import { getPetAnimation } from "../core/petAnimations";
import type { PetAnimConfig } from "../core/petAnimations";

function PetSprite({
  animation,
  size,
  stopped,
}: {
  animation: PetAnimConfig;
  size: number;
  stopped: boolean;
}) {
  const [frame, setFrame] = useState(0);
  useEffect(() => {
    if (
      stopped ||
      (animation.loopMode === "onceHold" && frame === animation.frameCount - 1)
    )
      return;
    const timeout = window.setTimeout(
      () => setFrame((old) => (old + 1) % animation.frameCount),
      animation.durations[frame] * 1000,
    );
    return () => window.clearTimeout(timeout);
  }, [animation, frame, stopped]);
  return (
    <div
      className="sprite-viewport"
      style={{ width: size, height: size, overflow: "hidden" }}
    >
      <img
        src={animation.file}
        alt=""
        draggable={false}
        style={{
          width: size * animation.frameCount,
          height: size,
          maxWidth: "none",
          transform: `translateX(${-frame * size}px)`,
          imageRendering: "pixelated",
          pointerEvents: "none",
        }}
      />
    </div>
  );
}
export function DesktopPet({
  kind = "tomy",
  phase,
  paused,
  size = 96,
  floating = false,
}: {
  kind?: PetKind;
  phase: FocusPhase;
  paused: boolean;
  size?: number;
  floating?: boolean;
}) {
  const animation = useMemo(
    () => getPetAnimation(kind, phase, paused),
    [kind, phase, paused],
  );
  const [reducedMotion, setReducedMotion] = useState(
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  const [position, setPosition] = useState(() => ({
    x: Math.max(10, window.innerWidth - size - 20),
    y: Math.max(10, window.innerHeight - size - 100),
  }));
  const [dragging, setDragging] = useState(false);
  const drag = useRef({ x: 0, y: 0, startX: 0, startY: 0 });
  const clamp = (x: number, y: number) => ({
    x: Math.max(10, Math.min(Math.max(10, window.innerWidth - size - 10), x)),
    y: Math.max(10, Math.min(Math.max(10, window.innerHeight - size - 10), y)),
  });
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReducedMotion(media.matches);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);
  useEffect(() => {
    const resized = () =>
      setPosition((old) => ({
        x: Math.max(
          10,
          Math.min(Math.max(10, window.innerWidth - size - 10), old.x),
        ),
        y: Math.max(
          10,
          Math.min(Math.max(10, window.innerHeight - size - 10), old.y),
        ),
      }));
    window.addEventListener("resize", resized);
    return () => window.removeEventListener("resize", resized);
  }, [size]);
  const label = paused
    ? "已暂停"
    : phase === "work"
      ? "专注中"
      : phase === "rest"
        ? "休息中"
        : phase === "workFinished"
          ? "专注达成"
          : phase === "restFinished"
            ? "休息完毕"
            : "准备就绪";
  return (
    <div
      className={`desktop-pet-container ${floating ? "floating-widget" : ""}`}
      aria-label={`${kind === "tomy" ? "番茄仔" : "植小芽"} · ${label}`}
      title={floating ? `${label} · 可拖动（方向键移动）` : label}
      tabIndex={floating ? 0 : undefined}
      style={
        floating
          ? {
              position: "fixed",
              left: position.x,
              top: position.y,
              zIndex: 10,
              cursor: dragging ? "grabbing" : "grab",
              touchAction: "none",
            }
          : undefined
      }
      onPointerDown={(e) => {
        if (!floating || e.button !== 0) return;
        e.currentTarget.setPointerCapture(e.pointerId);
        drag.current = {
          x: e.clientX,
          y: e.clientY,
          startX: position.x,
          startY: position.y,
        };
        setDragging(true);
      }}
      onPointerMove={(e) => {
        if (dragging)
          setPosition(
            clamp(
              drag.current.startX + e.clientX - drag.current.x,
              drag.current.startY + e.clientY - drag.current.y,
            ),
          );
      }}
      onPointerUp={() => setDragging(false)}
      onPointerCancel={() => setDragging(false)}
      onLostPointerCapture={() => setDragging(false)}
      onKeyDown={(e) => {
        const delta: Record<string, [number, number]> = {
          ArrowLeft: [-10, 0],
          ArrowRight: [10, 0],
          ArrowUp: [0, -10],
          ArrowDown: [0, 10],
        };
        if (floating && delta[e.key]) {
          e.preventDefault();
          const [x, y] = delta[e.key];
          setPosition((old) => clamp(old.x + x, old.y + y));
        }
      }}
    >
      <PetSprite
        key={animation.file}
        animation={animation}
        size={size}
        stopped={reducedMotion || dragging}
      />
      {floating && <div className="pet-status-pill">{label}</div>}
    </div>
  );
}
