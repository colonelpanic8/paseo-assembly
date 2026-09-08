import type {
  LiveVoiceAvailability,
  LiveVoiceHostAvailability,
} from "@/live-voice/live-voice-availability-policy";

/**
 * `paseo://live-voice?host=<serverId>&assistant=<id or name>`
 *
 * Both parameters are optional. Without `host` the link uses the quick-launch
 * host from settings, then the only eligible host; without `assistant` it uses
 * the launcher's selection on that host. An earbud or automation shortcut can
 * therefore be one fixed URL and still follow whatever the user configured.
 */
export interface LiveVoiceLink {
  host: string | null;
  /** An assistant id (`ast_…`) or a display name; resolved on the chosen host. */
  assistant: string | null;
}

export type LiveVoiceLinkHostDecision =
  | { kind: "wait" }
  | { kind: "start"; serverId: string }
  | { kind: "show_launcher" };

export interface ResolveLiveVoiceLinkHostInput {
  link: LiveVoiceLink;
  /** The quick-launch host from settings; stands in for a link without `host`. */
  defaultHost?: string | null;
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
  const assistant = parsed.searchParams.get("assistant")?.trim() || null;
  return { host, assistant };
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
  const requestedHostId = input.link.host ?? input.defaultHost ?? null;
  const requestedHost = requestedHostId
    ? (input.hosts.find((host) => host.serverId === requestedHostId) ?? null)
    : null;
  if (requestedHost && isHostEligibilityPending(requestedHost)) {
    return { kind: "wait" };
  }

  if (input.availability.kind === "available") {
    const requestedAvailableHost = requestedHostId
      ? (input.availability.hosts.find((host) => host.serverId === requestedHostId) ?? null)
      : null;
    if (requestedAvailableHost) {
      return { kind: "start", serverId: requestedAvailableHost.serverId };
    }

    const isRequestedHostStillUnknown = requestedHostId !== null && requestedHost === null;
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
