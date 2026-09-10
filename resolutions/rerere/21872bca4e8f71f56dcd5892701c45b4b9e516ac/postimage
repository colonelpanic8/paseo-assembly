import { useSyncExternalStore } from "react";
import type { LiveVoiceSnapshot } from "@/live-voice/live-voice-runtime";
import { LiveVoiceStartError } from "@/live-voice/live-voice-runtime";

let isLauncherRequested = false;
const launcherRequestListeners = new Set<() => void>();

function emitLauncherRequestChange(): void {
  for (const listener of launcherRequestListeners) {
    listener();
  }
}

function subscribeLauncherRequest(listener: () => void): () => void {
  launcherRequestListeners.add(listener);
  return () => {
    launcherRequestListeners.delete(listener);
  };
}

function getLauncherRequestSnapshot(): boolean {
  return isLauncherRequested;
}

export function requestLiveVoiceLauncher(): void {
  if (isLauncherRequested) {
    return;
  }
  isLauncherRequested = true;
  emitLauncherRequestChange();
}

export function consumeLiveVoiceLauncherRequest(): void {
  if (!isLauncherRequested) {
    return;
  }
  isLauncherRequested = false;
  emitLauncherRequestChange();
}

export function useLiveVoiceLauncherRequested(): boolean {
  return useSyncExternalStore(
    subscribeLauncherRequest,
    getLauncherRequestSnapshot,
    getLauncherRequestSnapshot,
  );
}

export function hasLiveVoiceCall(
  snapshot: Pick<LiveVoiceSnapshot, "phase" | "closedCause">,
): boolean {
  return snapshot.phase !== "idle" || snapshot.closedCause !== null;
}

export function isLiveVoiceCallActive(phase: LiveVoiceSnapshot["phase"]): boolean {
  return phase === "starting" || phase === "active" || phase === "stopping";
}

export function startLiveVoiceCall(
  start: (serverId: string) => Promise<void>,
  serverId: string,
): void {
  void start(serverId).catch((error: unknown) => {
    if (!(error instanceof LiveVoiceStartError)) {
      console.error("[LiveVoice] Failed to start session", error);
    }
  });
}
