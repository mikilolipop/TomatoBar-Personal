/**
 * TomatoBar Personal - Analytics & Retrospective Calculations
 * 1:1 aligned with Analytics.swift logic
 */

import type { FocusRecord } from '../types';

export type FocusPeriod = 'day' | 'week' | 'month';

export interface CategoryTotal {
  name: string;
  seconds: number;
}

export interface FocusDay {
  date: Date;
  categories: CategoryTotal[];
  seconds: number;
}

export function formatDurationChinese(seconds: number): string {
  const sec = Math.max(0, Math.round(seconds));
  if (sec < 60) return `${sec}秒`;
  const minutes = Math.floor(sec / 60);
  if (minutes < 60) return `${minutes}分钟`;
  const hours = Math.floor(minutes / 60);
  const remainingMins = minutes % 60;
  return remainingMins === 0 ? `${hours}小时` : `${hours}小时${remainingMins}分`;
}

export function formatTimeRange(startIso: string, endIso: string): string {
  const dStart = new Date(startIso);
  const dEnd = new Date(endIso);
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${pad(dStart.getHours())}:${pad(dStart.getMinutes())} - ${pad(dEnd.getHours())}:${pad(dEnd.getMinutes())}`;
}

export function getRecordCategory(record: FocusRecord): string {
  return record.tags[0] || '未分类';
}

export function recordSecondsInInterval(record: FocusRecord, start: Date, end: Date): number {
  const startMs = start.getTime();
  const endMs = end.getTime();

  return record.segments.reduce((acc, seg) => {
    const segStart = new Date(seg.start).getTime();
    const segEnd = new Date(seg.end).getTime();
    const overlapStart = Math.max(segStart, startMs);
    const overlapEnd = Math.min(segEnd, endMs);
    if (overlapEnd > overlapStart) {
      return acc + (overlapEnd - overlapStart) / 1000;
    }
    return acc;
  }, 0);
}

export function getPeriodInterval(period: FocusPeriod, targetDate: Date = new Date()): { start: Date; end: Date } {
  const date = new Date(targetDate);

  if (period === 'day') {
    const start = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
    const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1, 0, 0, 0, 0);
    return { start, end };
  }

  if (period === 'week') {
    // Week starts on Monday
    const day = date.getDay();
    const diff = (day === 0 ? -6 : 1) - day; // day 0 is Sunday -> -6 to get Monday
    const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate() + diff, 0, 0, 0, 0);
    const nextMonday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 7, 0, 0, 0, 0);
    return { start: monday, end: nextMonday };
  }

  // month
  const start = new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
  const end = new Date(date.getFullYear(), date.getMonth() + 1, 1, 0, 0, 0, 0);
  return { start, end };
}

export function computeFocusSummary(
  records: FocusRecord[],
  period: FocusPeriod,
  date: Date = new Date(),
  selectedCategory?: string | null
): {
  interval: { start: Date; end: Date };
  totalSeconds: number;
  categories: CategoryTotal[];
  recordsInPeriod: FocusRecord[];
  days: FocusDay[];
} {
  const interval = getPeriodInterval(period, date);

  // Filter records in interval
  const recordsInPeriod = records
    .filter((r) => {
      const matchCat = !selectedCategory || getRecordCategory(r).toLowerCase() === selectedCategory.toLowerCase();
      const inInt = recordSecondsInInterval(r, interval.start, interval.end) > 0;
      return matchCat && inInt;
    })
    .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime());

  // Category totals
  const catMap = new Map<string, { name: string; seconds: number }>();
  for (const r of recordsInPeriod) {
    const sec = recordSecondsInInterval(r, interval.start, interval.end);
    if (sec <= 0) continue;
    const cat = getRecordCategory(r);
    const key = cat.toLowerCase();
    const cur = catMap.get(key) || { name: cat, seconds: 0 };
    catMap.set(key, { name: cur.name, seconds: cur.seconds + sec });
  }

  const categories: CategoryTotal[] = Array.from(catMap.values()).sort((a, b) => b.seconds - a.seconds);
  const totalSeconds = categories.reduce((sum, c) => sum + c.seconds, 0);

  // Daily breakdown
  const days: FocusDay[] = [];
  let cursor = new Date(interval.start);
  while (cursor < interval.end) {
    const nextDay = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1, 0, 0, 0, 0);
    const dayEnd = nextDay < interval.end ? nextDay : interval.end;

    const dayCatMap = new Map<string, { name: string; seconds: number }>();
    for (const r of recordsInPeriod) {
      const sec = recordSecondsInInterval(r, cursor, dayEnd);
      if (sec <= 0) continue;
      const cat = getRecordCategory(r);
      const key = cat.toLowerCase();
      const cur = dayCatMap.get(key) || { name: cat, seconds: 0 };
      dayCatMap.set(key, { name: cur.name, seconds: cur.seconds + sec });
    }

    const dayCats = Array.from(dayCatMap.values()).sort((a, b) => b.seconds - a.seconds);
    const daySec = dayCats.reduce((s, c) => s + c.seconds, 0);

    days.push({
      date: new Date(cursor),
      categories: dayCats,
      seconds: daySec,
    });

    cursor = nextDay;
  }

  return {
    interval,
    totalSeconds,
    categories,
    recordsInPeriod,
    days,
  };
}
