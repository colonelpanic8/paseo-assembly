import type {
  LiveVoiceAvailability,
  LiveVoiceHostAvailability,
} from "@/live-voice/live-voice-availability-policy";

export interface LiveVoiceLink {
  host: string | null;
}

export type LiveVoiceLinkHostDecision =
  | { kind: "wait" }
  | { kind: "start"; serverId: string }
  | { kind: "show_launcher" };

export interface ResolveLiveVoiceLinkHostInput {
  link: LiveVoiceLink;
  isHostBootstrapReady: boolean;
  availability: LiveVoiceAvailability;
  hosts: LiveVoiceHostAvailability[];
}

export function parseLiveVoiceLink(url: string): LiveVoiceLink | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }

  const isLiveVoiceLink =
    parsed.protocol === "paseo:" &&
    parsed.hostname === "live-voice" &&
    (parsed.pathname === "" || parsed.pathname === "/");
  if (!isLiveVoiceLink) {
    return null;
  }

  const host = parsed.searchParams.get("host")?.trim() || null;
  return { host };
}

function isHostEligibilityPending(host: LiveVoiceHostAvailability): boolean {
  const isConnecting = host.connectionStatus === "connecting";
  const isWaitingForServerInfo =
    host.connectionStatus === "online" && host.supportsLiveVoice === null;
  return isConnecting || isWaitingForServerInfo;
}

export function resolveLiveVoiceLinkHost(
  input: ResolveLiveVoiceLinkHostInput,
): LiveVoiceLinkHostDecision {
  const requestedHost = input.link.host
    ? (input.hosts.find((host) => host.serverId === input.link.host) ?? null)
    : null;
  if (requestedHost && isHostEligibilityPending(requestedHost)) {
    return { kind: "wait" };
  }

  if (input.availability.kind === "available") {
    const requestedAvailableHost = input.link.host
      ? (input.availability.hosts.find((host) => host.serverId === input.link.host) ?? null)
      : null;
    if (requestedAvailableHost) {
      return { kind: "start", serverId: requestedAvailableHost.serverId };
    }

    const isRequestedHostStillUnknown = input.link.host !== null && requestedHost === null;
    if (isRequestedHostStillUnknown && !input.isHostBootstrapReady) {
      return { kind: "wait" };
    }

    if (input.availability.hosts.length === 1) {
      return { kind: "start", serverId: input.availability.hosts[0].serverId };
    }

    return { kind: "show_launcher" };
  }

  if (!input.isHostBootstrapReady || input.availability.reason === "hosts_connecting") {
    return { kind: "wait" };
  }
  return { kind: "show_launcher" };
}
