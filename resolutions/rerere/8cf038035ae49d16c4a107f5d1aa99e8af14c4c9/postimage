import * as Linking from "expo-linking";
import { useEffect, useState } from "react";
import { isNative } from "@/constants/platform";
import { useLiveVoiceOptional } from "@/contexts/live-voice-context";
import {
  useLiveVoiceAvailability,
  useLiveVoiceHostAvailability,
} from "@/live-voice/live-voice-availability";
import {
  hasLiveVoiceCall,
  isLiveVoiceCallActive,
  requestLiveVoiceLauncher,
  startLiveVoiceCall,
} from "@/live-voice/live-voice-launch";
import {
  parseLiveVoiceLink,
  resolveLiveVoiceLinkHost,
  type LiveVoiceLink,
} from "@/live-voice/live-voice-link";
import { getHostRuntimeStore } from "@/runtime/host-runtime";

export function LiveVoiceLinkListener() {
  const liveVoice = useLiveVoiceOptional();
  const availability = useLiveVoiceAvailability();
  const hosts = useLiveVoiceHostAvailability();
  const [pendingLink, setPendingLink] = useState<LiveVoiceLink | null>(null);
  const [isHostBootstrapReady, setIsHostBootstrapReady] = useState(false);

  useEffect(() => {
    if (!isNative) {
      return;
    }

    let cancelled = false;
    async function waitForHostBootstrap(): Promise<void> {
      try {
        await getHostRuntimeStore().boot();
      } catch (error) {
        console.warn("[Linking] Failed to wait for host bootstrap", error);
      }
      if (!cancelled) {
        setIsHostBootstrapReady(true);
      }
    }

    void waitForHostBootstrap();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!isNative) {
      return;
    }

    let cancelled = false;
    function handleUrl(url: string | null): void {
      if (cancelled || !url) {
        return;
      }
      const link = parseLiveVoiceLink(url);
      if (link) {
        setPendingLink(link);
      }
    }

    void Linking.getInitialURL()
      .then(handleUrl)
      .catch(() => undefined);
    const subscription = Linking.addEventListener("url", (event) => {
      handleUrl(event.url);
    });

    return () => {
      cancelled = true;
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    if (!pendingLink || !liveVoice) {
      return;
    }

    if (isLiveVoiceCallActive(liveVoice.phase)) {
      setPendingLink(null);
      return;
    }

    if (hasLiveVoiceCall(liveVoice)) {
      setPendingLink(null);
      requestLiveVoiceLauncher();
      return;
    }

    const decision = resolveLiveVoiceLinkHost({
      link: pendingLink,
      isHostBootstrapReady,
      availability,
      hosts,
    });
    if (decision.kind === "wait") {
      return;
    }

    setPendingLink(null);
    if (decision.kind === "show_launcher") {
      requestLiveVoiceLauncher();
      return;
    }
    startLiveVoiceCall(liveVoice.start, decision.serverId);
  }, [availability, hosts, isHostBootstrapReady, liveVoice, pendingLink]);

  return null;
}
