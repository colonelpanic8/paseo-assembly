/**
 * @vitest-environment jsdom
 */
import React, { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { formatCompactTimeAgo } from "@/utils/time";

vi.stubGlobal("IS_REACT_ACT_ENVIRONMENT", true);

const MINUTE = 60_000;

// Every case re-imports the module so the shared interval and cached minute
// start clean; the tick state is module-level by design.
async function loadHook(): Promise<() => Date> {
  vi.resetModules();
  const module = await import("./use-minute-tick");
  return module.useMinuteNow;
}

interface Probe {
  mount(): void;
  unmount(): void;
  readonly renders: number;
  readonly minute: number | null;
  readonly relativeLabel: string | null;
}

function createProbe(useMinuteNow: () => Date, activityAt?: Date): Probe {
  const container = document.createElement("div");
  document.body.appendChild(container);
  let root: Root | null = null;
  let renders = 0;
  let minute: number | null = null;
  let relativeLabel: string | null = null;

  function Probe() {
    renders += 1;
    const now = useMinuteNow();
    minute = Math.floor(now.getTime() / MINUTE);
    relativeLabel = activityAt ? formatCompactTimeAgo(activityAt, now) : null;
    return null;
  }

  return {
    mount() {
      root = createRoot(container);
      act(() => root?.render(<Probe />));
    },
    unmount() {
      act(() => root?.unmount());
      root = null;
      container.remove();
    },
    get renders() {
      return renders;
    },
    get minute() {
      return minute;
    },
    get relativeLabel() {
      return relativeLabel;
    },
  };
}

describe("useMinuteNow", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-16T12:00:00.000Z"));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("re-renders once the wall-clock minute changes", async () => {
    const useMinuteNow = await loadHook();
    const probe = createProbe(useMinuteNow);
    probe.mount();
    const initialRenders = probe.renders;

    // Poll fires well before the boundary, so nothing should change yet.
    act(() => void vi.advanceTimersByTime(20_000));
    expect(probe.renders).toBe(initialRenders);

    act(() => void vi.advanceTimersByTime(MINUTE));
    expect(probe.renders).toBe(initialRenders + 1);

    probe.unmount();
  });

  it("ages a relative label after its initial now minute", async () => {
    const useMinuteNow = await loadHook();
    const activityAt = new Date("2026-07-16T12:00:00.000Z");
    const probe = createProbe(useMinuteNow, activityAt);
    probe.mount();
    expect(probe.relativeLabel).toBe("now");

    act(() => void vi.advanceTimersByTime(5 * MINUTE));
    expect(probe.relativeLabel).toBe("5m");

    probe.unmount();
  });

  it("keeps one interval for many subscribers and stops it when the last unmounts", async () => {
    const useMinuteNow = await loadHook();
    const first = createProbe(useMinuteNow);
    const second = createProbe(useMinuteNow);

    first.mount();
    const withOne = vi.getTimerCount();
    second.mount();
    expect(vi.getTimerCount()).toBe(withOne);

    first.unmount();
    expect(vi.getTimerCount()).toBe(withOne);

    second.unmount();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("serves a fresh minute to a subscriber that arrives after the ticker stopped", async () => {
    const useMinuteNow = await loadHook();
    const first = createProbe(useMinuteNow);
    first.mount();
    const startMinute = first.minute;
    first.unmount();

    // Nothing is subscribed here, so the cached minute goes stale.
    act(() => void vi.advanceTimersByTime(5 * MINUTE));

    const second = createProbe(useMinuteNow);
    second.mount();
    expect(second.minute).toBe((startMinute ?? 0) + 5);

    second.unmount();
  });
});
