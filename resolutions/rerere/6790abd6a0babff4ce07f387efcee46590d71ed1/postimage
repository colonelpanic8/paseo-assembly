import { useCallback, useMemo } from "react";
import { useTranslation } from "react-i18next";
import { useToast } from "@/contexts/toast-context";
import { useHostFeature } from "@/runtime/host-features";
import { useMinuteNow } from "@/hooks/use-minute-tick";
import { formatDurationCoarse, formatFutureTimestamp } from "@/utils/time";
import { getHostRuntimeStore } from "@/runtime/host-runtime";
import {
  resolveWorkspaceSnoozePresets,
  type WorkspaceSnoozePreset,
  type WorkspaceSnoozePresetId,
} from "@/workspace-snooze/model";
import { useCustomSnoozeStore } from "@/workspace-snooze/custom-snooze-store";

const PRESET_LABEL_KEYS: Record<WorkspaceSnoozePresetId, string> = {
  hour: "sidebar.workspace.actions.snoozeHour",
  evening: "sidebar.workspace.actions.snoozeEvening",
  tomorrow: "sidebar.workspace.actions.snoozeTomorrow",
  "next-week": "sidebar.workspace.actions.snoozeNextWeek",
};

/**
 * Both snooze readouts, resolved against the current wall clock: the compact
 * chip pair and the full sentence for menu headers and screen readers. The
 * separator and word order live in the locale strings, since a countdown does
 * not follow the same order everywhere ("18:00・あと2h 15m").
 */
function deriveSnoozeLabels(
  snoozeWakeAtMs: number | null,
  t: (key: string, options: { time: string; duration: string }) => string,
  now: Date,
): { chip: string | null; sentence: string | null } {
  if (snoozeWakeAtMs === null) {
    return { chip: null, sentence: null };
  }
  const time = formatFutureTimestamp(new Date(snoozeWakeAtMs), now);
  const duration = formatDurationCoarse(snoozeWakeAtMs - now.getTime());
  return {
    chip: t("sidebar.workspace.actions.snoozedChip", { time, duration }),
    sentence: t("sidebar.workspace.actions.snoozedUntil", { time, duration }),
  };
}

export interface SidebarWorkspaceSnoozeActions {
  isSnoozed: boolean;
  /** Compact wake time and countdown ("6:00 PM · 2h 15m") for the inline chip. Null when not snoozed. */
  snoozeChipLabel: string | null;
  /** Full sentence ("Snoozed until 6:00 PM (2h 15m)") for menus and a11y. Null when not snoozed. */
  snoozedUntilLabel: string | null;
  presets: readonly (WorkspaceSnoozePreset & { label: string })[];
  customLabel: string;
  wakeLabel: string;
  onSnooze: (preset: WorkspaceSnoozePreset) => Promise<void> | void;
  onCustom: () => void;
  onWake: () => Promise<void> | void;
}

export function useWorkspaceSnoozeMenu(input: {
  serverId: string;
  workspaceId: string;
  // Effective sidebar state — decides between the preset list and "Wake".
  isSnoozed: boolean;
  // When the workspace wakes back up, from the snoozed bucket's derivation.
  // Null whenever the workspace is not snoozed.
  snoozeWakeAt: Date | null;
}): SidebarWorkspaceSnoozeActions | undefined {
  const { t } = useTranslation();
  const toast = useToast();
  const { serverId, workspaceId, isSnoozed } = input;
  // Keyed on the timestamp rather than the Date instance, which the view model
  // re-creates on every derivation.
  const snoozeWakeAtMs = input.snoozeWakeAt?.getTime() ?? null;
  // COMPAT(workspaceSnooze): added in v0.2.4, drop the gate when floor >= v0.2.4.
  // The single capability gate for the snooze UI — hosts without the feature
  // simply don't get the menu entries.
  const enabled = useHostFeature(serverId, "workspaceSnooze");

  // Preset times drift while the menu sits open, so onSnooze re-resolves by id
  // at click time; the labels rendered here are time-independent.
  const presets = useMemo(
    () =>
      resolveWorkspaceSnoozePresets(new Date()).map((preset) => ({
        id: preset.id,
        snoozedUntil: preset.snoozedUntil,
        label: t(PRESET_LABEL_KEYS[preset.id]),
      })),
    [t],
  );

  // The countdown has to move, and so does the wake time itself: "Wednesday
  // 9:00 AM" becomes plain "9:00 AM" once Wednesday arrives. Neither the row's
  // own minute tick nor the sidebar's wake clock reaches here — the chip is
  // passed to the memoized row as children, and the wake clock only fires at
  // the deadline — so the labels subscribe to the shared minute tick directly.
  // Deliberately unmemoized: two formats and an interpolation per render is
  // cheaper than reasoning about which key would keep them fresh, and a memo on
  // snoozeWakeAtMs is exactly what froze them before.
  const now = useMinuteNow();
  const snoozeLabels = deriveSnoozeLabels(snoozeWakeAtMs, t, now);

  const onSnooze = useCallback(
    async (preset: WorkspaceSnoozePreset) => {
      const client = getHostRuntimeStore().getClient(serverId);
      if (!client) {
        toast.error(t("sidebar.workspace.toasts.hostDisconnected"));
        return;
      }
      const currentPreset =
        resolveWorkspaceSnoozePresets(new Date()).find((candidate) => candidate.id === preset.id) ??
        preset;
      toast.show(t("sidebar.workspace.toasts.snoozingWorkspace"), { durationMs: null });
      try {
        await client.setWorkspaceSnooze(workspaceId, currentPreset.snoozedUntil);
        toast.show(t("sidebar.workspace.toasts.snoozedWorkspace"), { variant: "success" });
      } catch (error) {
        toast.error(
          error instanceof Error
            ? error.message
            : t("sidebar.workspace.toasts.failedToSnoozeWorkspace"),
        );
      }
    },
    [serverId, t, toast, workspaceId],
  );

  const onWake = useCallback(async () => {
    const client = getHostRuntimeStore().getClient(serverId);
    if (!client) {
      toast.error(t("sidebar.workspace.toasts.hostDisconnected"));
      return;
    }
    toast.show(t("sidebar.workspace.toasts.wakingWorkspace"), { durationMs: null });
    try {
      await client.setWorkspaceSnooze(workspaceId, null);
      toast.show(t("sidebar.workspace.toasts.wokeWorkspace"), { variant: "success" });
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : t("sidebar.workspace.toasts.failedToWakeWorkspace"),
      );
    }
  }, [serverId, t, toast, workspaceId]);

  const onCustom = useCallback(() => {
    useCustomSnoozeStore.getState().open(serverId, workspaceId);
  }, [serverId, workspaceId]);

  if (!enabled) {
    return undefined;
  }
  return {
    isSnoozed,
    snoozeChipLabel: snoozeLabels.chip,
    snoozedUntilLabel: snoozeLabels.sentence,
    presets,
    customLabel: t("sidebar.workspace.actions.snoozeCustom"),
    wakeLabel: t("sidebar.workspace.actions.wake"),
    onSnooze,
    onCustom,
    onWake,
  };
}
