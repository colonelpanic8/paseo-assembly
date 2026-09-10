import { parseLiveVoiceLink } from "@/live-voice/live-voice-link";

export function redirectSystemPath({ path, initial }: { path: string; initial: boolean }): string {
  if (parseLiveVoiceLink(path)) {
    // The Live Voice listener consumes the original URL; only cold starts need a route.
    return initial ? "/" : "";
  }
  return path;
}
