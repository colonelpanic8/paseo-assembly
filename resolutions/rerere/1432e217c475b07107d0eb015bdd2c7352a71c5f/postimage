import { Platform } from "react-native";
import { getIsElectronRuntimeMac } from "@/constants/layout";
import type { ShortcutOs } from "@/utils/format-shortcut";
import { isNative } from "@/constants/platform";
import { isMacUserAgent } from "@/utils/mac-user-agent";
import { getShortcutModPreference, useShortcutModStore } from "@/stores/shortcut-mod-store";

function getPlatformShortcutOs(): ShortcutOs {
  if (isNative) {
    return Platform.OS === "ios" ? "mac" : "non-mac";
  }
  if (getIsElectronRuntimeMac()) return "mac";
  return isMacUserAgent() ? "mac" : "non-mac";
}

export function getShortcutOs(): ShortcutOs {
  const preference = getShortcutModPreference();
  if (preference === "cmd") return "mac";
  if (preference === "ctrl") return "non-mac";
  return getPlatformShortcutOs();
}

/** Reactive getShortcutOs — re-renders when the mod-key preference changes. */
export function useShortcutOs(): ShortcutOs {
  const preference = useShortcutModStore((s) => s.preference);
  if (preference === "cmd") return "mac";
  if (preference === "ctrl") return "non-mac";
  return getPlatformShortcutOs();
}
