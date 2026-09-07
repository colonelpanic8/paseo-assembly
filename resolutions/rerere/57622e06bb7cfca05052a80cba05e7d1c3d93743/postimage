export type LiveVoiceBackgroundCallAction = "toggleMute" | "end";
export type LiveVoiceAudioRouteKind = "watch" | "earbuds" | "wired" | "speaker" | "other";

export interface LiveVoiceAudioRoute {
  id: string;
  label: string;
  kind: LiveVoiceAudioRouteKind;
}

export interface LiveVoiceAudioRouteState {
  active: LiveVoiceAudioRoute | null;
  candidates: LiveVoiceAudioRoute[];
}

export function isLiveVoiceBackgroundCallSupported(): boolean {
  return false;
}

export function beginLiveVoiceBackgroundCall(): Promise<void> {
  return Promise.resolve();
}

export function updateLiveVoiceBackgroundCall(_params: { isMuted: boolean }): Promise<void> {
  return Promise.resolve();
}

export function endLiveVoiceBackgroundCall(): Promise<void> {
  return Promise.resolve();
}

export function getLiveVoiceAudioRoutes(): Promise<LiveVoiceAudioRouteState | null> {
  return Promise.resolve(null);
}

export function setLiveVoiceAudioRoute(_routeId: string): Promise<boolean> {
  return Promise.resolve(false);
}

export function setLiveVoiceWearNodeNames(_names: string[]): Promise<void> {
  return Promise.resolve();
}

export function subscribeLiveVoiceAudioRoutes(
  _listener: (state: LiveVoiceAudioRouteState) => void,
): () => void {
  return () => undefined;
}

export function subscribeLiveVoiceBackgroundCallActions(
  _listener: (action: LiveVoiceBackgroundCallAction) => void,
): () => void {
  return () => undefined;
}
