import type { FocusPhase, PetKind } from "../types";

export interface PetAnimConfig {
  file: string;
  frameCount: number;
  durations: number[];
  loopMode: "loop" | "onceHold";
}

export function getPetAnimation(
  kind: PetKind,
  phase: FocusPhase,
  paused: boolean,
): PetAnimConfig {
  if (kind === "sprout") {
    if (paused) {
      if (phase === "work") {
        return {
          file: "/sprites/pet_sprout_work_paused_v3.png",
          frameCount: 4,
          durations: [0.7, 0.7, 0.15, 0.7],
          loopMode: "loop",
        };
      }
      return {
        file: "/sprites/pet_sprout_rest_paused_v3.png",
        frameCount: 4,
        durations: [0.6, 0.6, 0.6, 0.6],
        loopMode: "loop",
      };
    }

    switch (phase) {
      case "work":
        return {
          file: "/sprites/pet_sprout_work_v3.png",
          frameCount: 10,
          durations: [
            0.16, 0.14, 0.12, 0.16, 0.1, 0.12, 0.15, 0.14, 0.13, 0.16,
          ],
          loopMode: "loop",
        };
      case "rest":
        return {
          file: "/sprites/pet_sprout_rest_v3.png",
          frameCount: 8,
          durations: [0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32],
          loopMode: "loop",
        };
      case "workFinished":
        return {
          file: "/sprites/pet_sprout_work_finished_v3.png",
          frameCount: 8,
          durations: [0.16, 0.14, 0.13, 0.14, 0.16, 0.16, 0.2, 0.75],
          loopMode: "onceHold",
        };
      case "restFinished":
        return {
          file: "/sprites/pet_sprout_rest_finished_v3.png",
          frameCount: 8,
          durations: [0.28, 0.24, 0.2, 0.18, 0.16, 0.15, 0.16, 0.7],
          loopMode: "onceHold",
        };
      case "idle":
      default:
        return {
          file: "/sprites/pet_sprout_idle_v3.png",
          frameCount: 8,
          durations: [0.45, 0.45, 0.45, 0.08, 0.1, 0.08, 0.55, 0.55],
          loopMode: "loop",
        };
    }
  }

  // Default: tomy
  if (paused) {
    return {
      file: "/sprites/pet_tomy_paused_v2.png",
      frameCount: 4,
      durations: [0.7, 0.7, 0.12, 0.7],
      loopMode: "loop",
    };
  }

  switch (phase) {
    case "work":
      return {
        file: "/sprites/pet_tomy_work_v2.png",
        frameCount: 10,
        durations: [0.11, 0.1, 0.12, 0.11, 0.06, 0.08, 0.12, 0.11, 0.12, 0.13],
        loopMode: "loop",
      };
    case "rest":
      return {
        file: "/sprites/pet_tomy_rest_v2.png",
        frameCount: 8,
        durations: [0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22],
        loopMode: "loop",
      };
    case "workFinished":
      return {
        file: "/sprites/pet_tomy_work_finished_v2.png",
        frameCount: 8,
        durations: [0.13, 0.11, 0.11, 0.18, 0.18, 0.14, 0.18, 0.7],
        loopMode: "onceHold",
      };
    case "restFinished":
      return {
        file: "/sprites/pet_tomy_rest_finished_v2.png",
        frameCount: 8,
        durations: [0.26, 0.22, 0.16, 0.15, 0.14, 0.12, 0.12, 0.65],
        loopMode: "onceHold",
      };
    case "idle":
    default:
      return {
        file: "/sprites/pet_tomy_idle_v2.png",
        frameCount: 8,
        durations: [0.42, 0.42, 0.42, 0.07, 0.1, 0.07, 0.52, 0.52],
        loopMode: "loop",
      };
  }
}
