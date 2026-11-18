export interface AppSettings {
  workMinutes: number;
  shortRestMinutes: number;
  longRestMinutes: number;
  longRestEvery: number;
}
export const defaultSettings: AppSettings = {
  workMinutes: 25,
  shortRestMinutes: 5,
  longRestMinutes: 15,
  longRestEvery: 4,
};
export function decodeSettings(raw: string): AppSettings {
  const o: unknown = JSON.parse(raw);
  if (!o || typeof o !== "object" || Array.isArray(o))
    throw new Error("偏好设置格式无效。");
  const s = { ...defaultSettings, ...o } as AppSettings;
  for (const key of [
    "workMinutes",
    "shortRestMinutes",
    "longRestMinutes",
    "longRestEvery",
  ] as const) {
    if (
      !Number.isInteger(s[key]) ||
      s[key] < 1 ||
      s[key] > (key === "longRestEvery" ? 12 : 180)
    )
      throw new Error("偏好设置时长超出范围。");
  }
  return {
    workMinutes: s.workMinutes,
    shortRestMinutes: s.shortRestMinutes,
    longRestMinutes: s.longRestMinutes,
    longRestEvery: s.longRestEvery,
  };
}
export function restSeconds(rounds: number, s: AppSettings): number {
  return (
    (rounds > 0 && rounds % s.longRestEvery === 0
      ? s.longRestMinutes
      : s.shortRestMinutes) * 60
  );
}
