/**
 * The app-global Live Voice entry point: an icon button in the sidebar footer
 * that opens a menu. Idle, live voice occupies nothing but this icon — the strip
 * and the sidebar card only appear once a call exists. Diagnostics for why a
 * host can't take a call live in Settings → Diagnostics, not here.
 */

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { Text, View } from "react-native";
import { StyleSheet, withUnistyles } from "react-native-unistyles";
import { AudioLines } from "lucide-react-native";
import type { VoiceProfile, VoiceThread } from "@getpaseo/protocol/voice-profiles";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuHint,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
  useDropdownMenuClose,
  type MenuPageDefinition,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useLiveVoiceOptional } from "@/contexts/live-voice-context";
import { useAppVisible } from "@/hooks/use-app-visible";
import { useCompactTimeAgo } from "@/hooks/use-compact-time-ago";
import { useIsCompactFormFactor } from "@/constants/layout";
import { useLiveVoiceAvailability } from "@/live-voice/live-voice-availability";
import type { LiveVoiceHostAvailability } from "@/live-voice/live-voice-availability-policy";
import { resolveLiveVoiceStatusLabel } from "@/live-voice/live-voice-call-ui";
import { resolveLiveVoiceErrorMessage } from "@/live-voice/live-voice-error-message";
import { resolveLiveVoiceUnavailableMessage } from "@/live-voice/live-voice-unavailable-message";
import {
  LiveVoiceStartError,
  type LiveVoiceErrorInfo,
  type LiveVoicePhase,
} from "@/live-voice/live-voice-runtime";
import {
  consumeLiveVoiceLauncherRequest,
  hasLiveVoiceCall,
  useLiveVoiceLauncherRequested,
} from "@/live-voice/live-voice-launch";
import { usePanelStore } from "@/stores/panel-store";
import { ICON_SIZE, type Theme } from "@/styles/theme";
import { useVoiceProfiles, useVoiceThreads } from "@/voice-profiles/voice-profile-queries";
import { VoiceProfilesSheet } from "@/voice-profiles/voice-profiles-sheet";
import { useVoiceSelection, useVoiceSelectionStore } from "@/voice-profiles/voice-selection-store";
import { resolveVoiceThreadTitle } from "@/voice-profiles/voice-thread-title";

const ThemedAudioLines = withUnistyles(AudioLines);

const foregroundMapping = (theme: Theme) => ({ color: theme.colors.foreground });
const foregroundMutedMapping = (theme: Theme) => ({ color: theme.colors.foregroundMuted });
// `statusSuccess` rather than `primary`: primary is near-black in the light
// themes, and a live call indicator has to read as live in every scheme.
const liveMapping = (theme: Theme) => ({ color: theme.colors.statusSuccess });
const dangerMapping = (theme: Theme) => ({ color: theme.colors.statusDanger });

/** Resting and hovered icon tint. A call in progress overrides the hover tint. */
function resolveIconMappings(input: { phase: LiveVoicePhase; hasCall: boolean }): {
  resting: (theme: Theme) => { color: string };
  hovered: (theme: Theme) => { color: string };
} {
  const { phase, hasCall } = input;
  if (phase === "error") {
    return { resting: dangerMapping, hovered: dangerMapping };
  }
  if (hasCall) {
    return { resting: liveMapping, hovered: liveMapping };
  }
  return { resting: foregroundMutedMapping, hovered: foregroundMapping };
}

function LiveVoiceHostMenuItem({
  host,
  isSelected,
  onSelect,
}: {
  host: LiveVoiceHostAvailability;
  isSelected: boolean;
  onSelect: (serverId: string) => void;
}) {
  const handleSelect = useCallback(() => {
    onSelect(host.serverId);
  }, [host.serverId, onSelect]);

  return (
    <DropdownMenuItem
      selected={isSelected}
      showSelectedCheck
      closeOnSelect={false}
      onSelect={handleSelect}
      testID={`live-voice-menu-host-${host.serverId}`}
    >
      {host.label}
    </DropdownMenuItem>
  );
}

function reportUnexpectedStartError(error: unknown): void {
  if (!(error instanceof LiveVoiceStartError)) {
    console.error("[LiveVoice] Failed to start session", error);
  }
}

/** In-call menu body: call status, terminal recovery, and the action that ends it. */
function LiveVoiceCallMenuItems({
  phase,
  isAudioBlocked,
  serverId,
  error,
}: {
  phase: LiveVoicePhase;
  isAudioBlocked: boolean;
  serverId: string | null;
  error: LiveVoiceErrorInfo | null;
}) {
  const liveVoice = useLiveVoiceOptional();
  const { t } = useTranslation();
  const closeMenu = useDropdownMenuClose();

  const handleStop = useCallback(() => {
    void liveVoice?.stop().catch((stopError: unknown) => {
      console.error("[LiveVoice] Failed to stop", stopError);
    });
  }, [liveVoice]);

  const handleDismiss = useCallback(() => {
    liveVoice?.dismiss();
  }, [liveVoice]);

  const handleRetry = useCallback(() => {
    if (!liveVoice || !serverId) {
      return;
    }
    void liveVoice.start(serverId).then(closeMenu).catch(reportUnexpectedStartError);
  }, [closeMenu, liveVoice, serverId]);

  const isTerminal = phase === "idle" || phase === "error";
  const errorMessage = error ? resolveLiveVoiceErrorMessage(error, t) : undefined;

  return (
    <>
      <DropdownMenuLabel testID="live-voice-menu-status">
        {resolveLiveVoiceStatusLabel({ phase, isAudioBlocked, t })}
      </DropdownMenuLabel>
      {isTerminal ? (
        <>
          {phase === "error" && serverId ? (
            <DropdownMenuItem
              closeOnSelect={false}
              description={errorMessage}
              onSelect={handleRetry}
              testID="live-voice-menu-retry"
            >
              {t("common.actions.retry")}
            </DropdownMenuItem>
          ) : null}
          <DropdownMenuItem
            description={phase === "error" && !serverId ? errorMessage : undefined}
            onSelect={handleDismiss}
            testID="live-voice-menu-dismiss"
          >
            {t("liveVoice.actions.dismiss")}
          </DropdownMenuItem>
        </>
      ) : (
        <DropdownMenuItem
          destructive
          disabled={phase === "stopping"}
          onSelect={handleStop}
          testID="live-voice-menu-stop"
        >
          {t("liveVoice.actions.stop")}
        </DropdownMenuItem>
      )}
    </>
  );
}

const PROFILE_PAGE_ID = "live-voice-profile";
const THREAD_PAGE_ID = "live-voice-thread";
/** Enough recent threads to find the one you mean; the sheet lists them all. */
const RECENT_THREAD_LIMIT = 8;

/**
 * Which profile a new call on the host uses once the launcher's pick and the
 * daemon's default are both considered.
 */
function resolveEffectiveProfile(
  profiles: readonly VoiceProfile[],
  selectedProfileId: string | null,
  defaultProfileId: string | null,
): VoiceProfile | null {
  const id = selectedProfileId ?? defaultProfileId;
  return id ? (profiles.find((profile) => profile.id === id) ?? null) : null;
}

/** Threads a call under this profile could continue, most recent first. */
function resolveRecentThreads(
  threads: readonly VoiceThread[],
  profileId: string | null,
): VoiceThread[] {
  return threads.filter((thread) => thread.profileId === profileId).slice(0, RECENT_THREAD_LIMIT);
}

/**
 * The submenu page that picks which profile configures the call. Selecting a
 * row chooses and returns; the menu stays open so the next press is Start.
 */
function LiveVoiceProfilePage({ serverId }: { serverId: string }) {
  const { t } = useTranslation();
  const { profiles, defaultProfileId } = useVoiceProfiles(serverId);
  const { profileId: selectedProfileId } = useVoiceSelection(serverId);
  const selectProfile = useVoiceSelectionStore((state) => state.selectProfile);
  const defaultName = profiles.find((profile) => profile.id === defaultProfileId)?.name;

  const selectDefault = useCallback(() => selectProfile(serverId, null), [selectProfile, serverId]);

  return (
    <>
      <DropdownMenuItem
        selected={selectedProfileId === null}
        showSelectedCheck
        closeOnSelect={false}
        description={defaultName}
        onSelect={selectDefault}
        testID="live-voice-menu-profile-default"
      >
        {t("voiceProfiles.menu.defaultProfile")}
      </DropdownMenuItem>
      {profiles.map((profile) => (
        <LiveVoiceProfileMenuItem
          key={profile.id}
          serverId={serverId}
          profile={profile}
          selected={profile.id === selectedProfileId}
        />
      ))}
    </>
  );
}

function LiveVoiceProfileMenuItem({
  serverId,
  profile,
  selected,
}: {
  serverId: string;
  profile: VoiceProfile;
  selected: boolean;
}) {
  const selectProfile = useVoiceSelectionStore((state) => state.selectProfile);
  const handleSelect = useCallback(
    () => selectProfile(serverId, profile.id),
    [selectProfile, serverId, profile.id],
  );
  return (
    <DropdownMenuItem
      selected={selected}
      showSelectedCheck
      closeOnSelect={false}
      onSelect={handleSelect}
      testID={`live-voice-menu-profile-${profile.id}`}
    >
      {profile.name}
    </DropdownMenuItem>
  );
}

/**
 * The submenu page that picks what the call remembers: a fresh thread, or one
 * of the profile's recent threads to continue.
 */
function LiveVoiceThreadPage({ serverId }: { serverId: string }) {
  const { t } = useTranslation();
  const { profiles, defaultProfileId } = useVoiceProfiles(serverId);
  const { threads } = useVoiceThreads(serverId);
  const { profileId: selectedProfileId, threadId: selectedThreadId } = useVoiceSelection(serverId);
  const selectThread = useVoiceSelectionStore((state) => state.selectThread);
  const effectiveProfile = resolveEffectiveProfile(profiles, selectedProfileId, defaultProfileId);
  const recent = resolveRecentThreads(threads, effectiveProfile?.id ?? null);

  const selectNew = useCallback(() => selectThread(serverId, null), [selectThread, serverId]);

  return (
    <>
      <DropdownMenuItem
        selected={selectedThreadId === null}
        showSelectedCheck
        closeOnSelect={false}
        onSelect={selectNew}
        testID="live-voice-menu-thread-new"
      >
        {t("voiceProfiles.menu.newThread")}
      </DropdownMenuItem>
      {recent.map((thread) => (
        <LiveVoiceThreadMenuItem
          key={thread.id}
          serverId={serverId}
          thread={thread}
          selected={thread.id === selectedThreadId}
        />
      ))}
    </>
  );
}

function LiveVoiceThreadMenuItem({
  serverId,
  thread,
  selected,
}: {
  serverId: string;
  thread: VoiceThread;
  selected: boolean;
}) {
  const { t } = useTranslation();
  const selectThread = useVoiceSelectionStore((state) => state.selectThread);
  const timeAgo = useCompactTimeAgo(new Date(thread.updatedAt));
  const handleSelect = useCallback(
    () => selectThread(serverId, thread.id),
    [selectThread, serverId, thread.id],
  );
  return (
    <DropdownMenuItem
      selected={selected}
      showSelectedCheck
      closeOnSelect={false}
      description={timeAgo}
      onSelect={handleSelect}
      testID={`live-voice-menu-thread-${thread.id}`}
    >
      {resolveVoiceThreadTitle(thread, t)}
    </DropdownMenuItem>
  );
}

/** Idle menu body: pick a host when there is a choice, then start the call. */
function LiveVoiceStartMenuItems({
  hosts,
  selectedHost,
  onSelectHost,
  onManageProfiles,
}: {
  hosts: LiveVoiceHostAvailability[];
  selectedHost: LiveVoiceHostAvailability;
  onSelectHost: (serverId: string) => void;
  onManageProfiles: () => void;
}) {
  const liveVoice = useLiveVoiceOptional();
  const { t } = useTranslation();
  const closeMenu = useDropdownMenuClose();
  const { serverId } = selectedHost;
  const supportsProfiles = selectedHost.supportsVoiceProfiles === true;
  const { profiles, defaultProfileId } = useVoiceProfiles(supportsProfiles ? serverId : null);
  const { threads } = useVoiceThreads(supportsProfiles ? serverId : null);
  const { profileId: selectedProfileId, threadId: selectedThreadId } = useVoiceSelection(serverId);
  const effectiveProfile = resolveEffectiveProfile(profiles, selectedProfileId, defaultProfileId);
  const selectedThread = threads.find((thread) => thread.id === selectedThreadId) ?? null;
  const threadLabel = selectedThread
    ? resolveVoiceThreadTitle(selectedThread, t)
    : t("voiceProfiles.menu.newThread");
  const callDescription = [
    supportsProfiles ? (effectiveProfile?.name ?? null) : null,
    supportsProfiles ? threadLabel : null,
    selectedHost.label,
  ]
    .filter(Boolean)
    .join(" · ");

  const handleStart = useCallback(() => {
    if (!liveVoice) {
      return;
    }
    void liveVoice.start(serverId).then(closeMenu).catch(reportUnexpectedStartError);
  }, [closeMenu, liveVoice, serverId]);

  const hasHostChoice = hosts.length > 1;

  return (
    <>
      {supportsProfiles ? (
        <>
          <DropdownMenuSubTrigger
            id={PROFILE_PAGE_ID}
            value={
              selectedProfileId
                ? (effectiveProfile?.name ?? t("voiceProfiles.menu.defaultProfile"))
                : t("voiceProfiles.menu.defaultProfile")
            }
            testID="live-voice-menu-profile"
          >
            {t("voiceProfiles.menu.profileLabel")}
          </DropdownMenuSubTrigger>
          <DropdownMenuSubTrigger
            id={THREAD_PAGE_ID}
            value={threadLabel}
            testID="live-voice-menu-thread"
          >
            {t("voiceProfiles.menu.threadLabel")}
          </DropdownMenuSubTrigger>
          <DropdownMenuItem onSelect={onManageProfiles} testID="live-voice-menu-manage-profiles">
            {t("voiceProfiles.menu.manage")}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
        </>
      ) : null}
      {hasHostChoice ? (
        <>
          <DropdownMenuLabel>{t("liveVoice.menu.hosts")}</DropdownMenuLabel>
          {hosts.map((host) => (
            <LiveVoiceHostMenuItem
              key={host.serverId}
              host={host}
              isSelected={host.serverId === serverId}
              onSelect={onSelectHost}
            />
          ))}
          <DropdownMenuSeparator />
        </>
      ) : null}
      <DropdownMenuItem
        closeOnSelect={false}
        onSelect={handleStart}
        description={callDescription}
        testID="live-voice-menu-start"
      >
        {t("liveVoice.actions.start")}
      </DropdownMenuItem>
    </>
  );
}

export function LiveVoiceFooterButton({ active }: { active: boolean }) {
  const liveVoice = useLiveVoiceOptional();
  const availability = useLiveVoiceAvailability();
  const { t } = useTranslation();
  const [isOpen, setIsOpen] = useState(false);
  const [selectedServerId, setSelectedServerId] = useState<string | null>(null);
  const [isManagingProfiles, setIsManagingProfiles] = useState(false);
  const isCompactLayout = useIsCompactFormFactor();
  const isLauncherRequested = useLiveVoiceLauncherRequested();
  const isAppVisible = useAppVisible();
  const openAgentListForLayout = usePanelStore((state) => state.openAgentListForLayout);

  useEffect(() => {
    if (!isLauncherRequested || !isAppVisible) {
      return;
    }
    openAgentListForLayout({ isCompact: isCompactLayout });
    if (!active) {
      return;
    }
    setIsOpen(true);
    consumeLiveVoiceLauncherRequest();
  }, [active, isAppVisible, isCompactLayout, isLauncherRequested, openAgentListForLayout]);

  const availableHosts = availability.kind === "available" ? availability.hosts : [];
  const selectedHost =
    availableHosts.find((host) => host.serverId === selectedServerId) ?? availableHosts[0] ?? null;

  const handleManageProfiles = useCallback(() => {
    setIsOpen(false);
    setIsManagingProfiles(true);
  }, []);
  const handleCloseProfiles = useCallback(() => {
    setIsManagingProfiles(false);
  }, []);

  const memoryPages = useMemo<MenuPageDefinition[]>(
    () =>
      selectedHost?.supportsVoiceProfiles
        ? [
            {
              id: PROFILE_PAGE_ID,
              title: t("voiceProfiles.menu.profileLabel"),
              content: <LiveVoiceProfilePage serverId={selectedHost.serverId} />,
            },
            {
              id: THREAD_PAGE_ID,
              title: t("voiceProfiles.menu.threadLabel"),
              content: <LiveVoiceThreadPage serverId={selectedHost.serverId} />,
            },
          ]
        : [],
    [selectedHost?.serverId, selectedHost?.supportsVoiceProfiles, t],
  );

  if (!liveVoice) {
    return null;
  }

  const { phase, serverId, isAudioBlocked, error, closedCause } = liveVoice;
  const hasCall = hasLiveVoiceCall({ phase, closedCause });
  const iconMappings = resolveIconMappings({ phase, hasCall });

  return (
    <>
      <VoiceProfilesSheet
        visible={isManagingProfiles}
        onClose={handleCloseProfiles}
        initialServerId={selectedHost?.serverId ?? null}
      />
      <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
        <Tooltip delayDuration={300} enabledOnDesktop={!isOpen}>
          <TooltipTrigger asChild>
            <View>
              <DropdownMenuTrigger
                style={styles.trigger}
                testID="sidebar-live-voice-trigger"
                nativeID="sidebar-live-voice-trigger"
                accessibilityRole="button"
                accessibilityLabel={t("liveVoice.label")}
              >
                {({ hovered }) => (
                  <ThemedAudioLines
                    size={ICON_SIZE.md}
                    uniProps={hovered ? iconMappings.hovered : iconMappings.resting}
                  />
                )}
              </DropdownMenuTrigger>
            </View>
          </TooltipTrigger>
          <TooltipContent side="top" align="center" offset={8}>
            <Text style={styles.tooltipText}>{t("liveVoice.label")}</Text>
          </TooltipContent>
        </Tooltip>
        <DropdownMenuContent
          side="top"
          align="end"
          offset={8}
          width={280}
          pages={memoryPages}
          testID="live-voice-menu"
        >
          {hasCall ? (
            <LiveVoiceCallMenuItems
              phase={phase}
              isAudioBlocked={isAudioBlocked}
              serverId={serverId}
              error={error}
            />
          ) : null}
          {!hasCall && selectedHost ? (
            <LiveVoiceStartMenuItems
              hosts={availableHosts}
              selectedHost={selectedHost}
              onSelectHost={setSelectedServerId}
              onManageProfiles={handleManageProfiles}
            />
          ) : null}
          {!hasCall && !selectedHost ? (
            <DropdownMenuHint testID="live-voice-menu-unavailable">
              {availability.kind === "unavailable"
                ? resolveLiveVoiceUnavailableMessage(availability.reason, t)
                : t("liveVoice.actions.unavailable")}
            </DropdownMenuHint>
          ) : null}
        </DropdownMenuContent>
      </DropdownMenu>
    </>
  );
}

const styles = StyleSheet.create((theme) => ({
  trigger: {
    width: 28,
    height: 28,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: theme.spacing[1],
    paddingHorizontal: theme.spacing[1],
  },
  tooltipText: {
    fontSize: theme.fontSize.sm,
    color: theme.colors.popoverForeground,
  },
}));
