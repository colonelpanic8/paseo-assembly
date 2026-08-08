import { memo, useCallback, useMemo, useState, type MutableRefObject, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { View, Text, Pressable, ScrollView, type PressableStateCallbackType } from "react-native";
import { NestableScrollContainer } from "react-native-draggable-flatlist";
import Animated, { LayoutAnimationConfig } from "react-native-reanimated";
import { navigateToWorkspace } from "@/stores/navigation-active-workspace-store";
import { useActiveWorkspaceSelection } from "@/stores/navigation-active-workspace-store";
import { type SidebarWorkspaceEntry } from "@/hooks/use-sidebar-workspaces-list";
import type { StatusGroup } from "@/hooks/sidebar-status-view-model";
import type { HostBadgeModel } from "@/hosts/appearance";
import { isWeb as platformIsWeb, isNative as platformIsNative } from "@/constants/platform";
import { StyleSheet } from "react-native-unistyles";
import type { Theme } from "@/styles/theme";
import { withUnistyles } from "react-native-unistyles";
import {
  ChevronDown,
  ChevronRight,
  CircleAlert,
  CircleCheck,
  CircleDot,
  CircleX,
  Moon,
} from "lucide-react-native";
import { useToast } from "@/contexts/toast-context";
import { useMutation } from "@tanstack/react-query";
import { getHostRuntimeStore } from "@/runtime/host-runtime";
import { AdaptiveRenameModal } from "@/components/rename-modal";
import { requireWorkspaceDirectory } from "@/utils/workspace-directory";
import { redirectIfArchivingActiveWorkspace } from "@/utils/sidebar-workspace-archive-redirect";
import { useWorkspaceArchive } from "@/workspace/use-workspace-archive";
import { toWorktreeArchiveRisk } from "@/git/worktree-archive-warning";
import * as Clipboard from "expo-clipboard";
import type { ShortcutKey } from "@/utils/format-shortcut";
import { useShortcutKeys } from "@/hooks/use-shortcut-keys";
import { useKeyboardActionHandler } from "@/hooks/use-keyboard-action-handler";
import { useClearWorkspaceAttention } from "@/hooks/use-clear-workspace-attention";
import {
  SidebarWorkspaceRowFrame,
  SidebarWorkspaceAgentTreeToggle,
  type SidebarWorkspaceRowDisclosure,
} from "@/components/sidebar/sidebar-workspace-row-content";
import { useOpenKebabMenuVisibility } from "@/components/sidebar/use-open-kebab-menu-visibility";
import { getStatusDotColor } from "@/utils/status-dot-color";
import { selectWorkspaceServiceSummary } from "@/components/sidebar/workspace-meta-row";
import {
  SidebarStatusRowArchiveAction,
  SidebarStatusRowContent,
  STATUS_ROW_AGENT_TREE_INDENT,
} from "@/components/sidebar/sidebar-status-row-content";
import {
  useWorkspaceHasAgents,
  WorkspaceAgentTree,
} from "@/components/sidebar/sidebar-workspace-agent-tree";
import { useSidebarCollapsedSectionsStore } from "@/stores/sidebar-collapsed-sections-store";
import {
  SidebarWorkspaceContextMenu,
  SidebarWorkspaceMenu,
} from "@/components/sidebar/sidebar-workspace-menu";
import { isStatusGroupCollapsed } from "@/stores/sidebar-collapsed-sections-store/state";
import { SidebarStatusRowSnoozeAction } from "@/components/sidebar/sidebar-status-row-snooze-action";
import { useWorkspaceSnoozeMenu } from "@/workspace-snooze/use-workspace-snooze-menu";
import { PinnedSectionHeader } from "@/components/sidebar/pinned-section-header";
import { SidebarGroupToggleRow } from "@/components/sidebar/sidebar-group-toggle-row";
import { useLimitedSidebarGroup } from "@/components/sidebar/use-limited-sidebar-group";
import {
  buildStatusLayoutSignature,
  useLimitedStatusGroups,
  type LimitedStatusGroup,
} from "@/components/sidebar/sidebar-status-layout";
import { SidebarArchivedGroup } from "@/components/sidebar/sidebar-archived-group";
import {
  SidebarListSettleContext,
  sidebarRowEnter,
  useArchiveCollapse,
  useSidebarListSettle,
  useSidebarListSettleValue,
} from "@/components/sidebar/sidebar-motion";
import type { ArchivedWorkspaceEntry } from "@/hooks/use-archived-workspaces";
import type { ToggleSidebarWorkspacePin } from "@/hooks/use-sidebar-workspace-pin";
import type { GestureType } from "react-native-gesture-handler";
import { StatusRowSwipeContainer } from "@/components/sidebar/status-row-swipe-container";
import { useMinuteNow } from "@/hooks/use-minute-tick";

// Themed icon wrappers
const foregroundMutedColorMapping = (theme: Theme) => ({
  color: theme.colors.foregroundMuted,
});
// One mapping per bucket, resolved through the status-dot producer so a group header and
// the rows under it cannot disagree about what "failed" looks like.
const needsInputColorMapping = (theme: Theme) => ({
  color: getStatusDotColor({ theme, bucket: "needs_input" }) ?? undefined,
});
const failedColorMapping = (theme: Theme) => ({
  color: getStatusDotColor({ theme, bucket: "failed" }) ?? undefined,
});
const attentionColorMapping = (theme: Theme) => ({
  color: getStatusDotColor({ theme, bucket: "attention" }) ?? undefined,
});
const runningColorMapping = (theme: Theme) => ({
  color: getStatusDotColor({ theme, bucket: "running" }) ?? undefined,
});
// Snoozed is not a status-dot bucket -- it is a sidebar state, not an agent one -- so it
// takes the palette directly rather than going through the producer.
const blueColorMapping = (theme: Theme) => ({ color: theme.colors.palette.blue[500] });
const STATUS_ROW_ENTERING = sidebarRowEnter;

const ThemedChevronDown = withUnistyles(ChevronDown);
const ThemedChevronRight = withUnistyles(ChevronRight);
const ThemedCircleAlert = withUnistyles(CircleAlert);
const ThemedCircleCheck = withUnistyles(CircleCheck);
const ThemedCircleDot = withUnistyles(CircleDot);
const ThemedCircleX = withUnistyles(CircleX);
const ThemedMoon = withUnistyles(Moon);
interface StatusWorkspaceListProps {
  groups: StatusGroup[];
  archivedWorkspaces: ArchivedWorkspaceEntry[];
  pinnedWorkspaces: SidebarWorkspaceEntry[];
  /** Project icon data URIs keyed by project view key; null when the project has no icon. */
  projectIconByProjectViewKey: ReadonlyMap<string, string | null>;
  shortcutIndexByWorkspaceKey: Map<string, number>;
  showShortcutBadges: boolean;
  onWorkspacePress?: () => void;
  hostBadgeByServerId: ReadonlyMap<string, HostBadgeModel>;
  supportsPinningByServerId: ReadonlyMap<string, boolean>;
  onToggleWorkspacePin: ToggleSidebarWorkspacePin;
  /** Compact sidebar drawer-close pan; shared with the scroll and row gestures. */
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
  listHeaderComponent?: ReactNode;
}

export function SidebarStatusWorkspaceList({
  groups,
  archivedWorkspaces,
  pinnedWorkspaces,
  projectIconByProjectViewKey,
  shortcutIndexByWorkspaceKey,
  showShortcutBadges,
  onWorkspacePress,
  hostBadgeByServerId,
  supportsPinningByServerId,
  onToggleWorkspacePin,
  parentGestureRef,
  listHeaderComponent,
}: StatusWorkspaceListProps) {
  // One clock invalidates every visible status row together. Rows receive the
  // minute explicitly so memoization cannot retain a stale relative label.
  const activityNow = useMinuteNow();
  const collapsedStatusGroupKeys = useSidebarCollapsedSectionsStore(
    (state) => state.collapsedStatusGroupKeys,
  );
  const pinnedCollapsed = useSidebarCollapsedSectionsStore((state) => state.collapsedPinned);
  const togglePinnedCollapsed = useSidebarCollapsedSectionsStore(
    (state) => state.togglePinnedCollapsed,
  );
  const {
    visibleItems: visiblePinnedWorkspaces,
    expanded: pinnedWorkspacesExpanded,
    canToggle: canTogglePinnedWorkspaces,
    toggleExpanded: togglePinnedWorkspacesExpanded,
  } = useLimitedSidebarGroup(pinnedWorkspaces);
  // Owned here rather than per group so the signature below can describe every
  // row the list is about to render.
  const { limitedGroups, toggleGroupExpanded } = useLimitedStatusGroups(
    groups,
    collapsedStatusGroupKeys,
  );
  const listSettle = useSidebarListSettleValue(
    buildStatusLayoutSignature({
      hasListHeader: listHeaderComponent != null,
      pinnedCollapsed,
      visiblePinnedWorkspaces,
      canTogglePinnedWorkspaces,
      limitedGroups,
      archivedWorkspaces,
    }),
  );

  // NestableScrollContainer forwards props to RNGH's ScrollView but does not
  // type them. Keeping vertical scroll simultaneous with the drawer-close pan
  // lets a clear vertical drag scroll immediately while a clear horizontal drag
  // can still close the sidebar. Mirrors project mode.
  const nativeScrollGestureProps = useMemo(
    () => (parentGestureRef ? { simultaneousHandlers: parentGestureRef } : undefined),
    [parentGestureRef],
  );

  const statusShortcutIndex = showShortcutBadges ? shortcutIndexByWorkspaceKey : new Map();
  // skipEntering silences row entrances for everything mounting with the list
  // itself (startup, grouping-mode switch); only rows added later animate in.
  const content = (
    <SidebarListSettleContext value={listSettle}>
      <LayoutAnimationConfig skipEntering>
        {pinnedWorkspaces.length > 0 ? (
          <View style={styles.pinnedSection} testID="sidebar-pinned-section">
            <PinnedSectionHeader collapsed={pinnedCollapsed} onToggle={togglePinnedCollapsed} />
            {pinnedCollapsed ? null : (
              <>
                {visiblePinnedWorkspaces.map((workspace) => (
                  <StatusWorkspaceRow
                    key={workspace.workspaceKey}
                    activityNow={activityNow}
                    workspace={workspace}
                    iconDataUri={projectIconByProjectViewKey.get(workspace.projectViewKey) ?? null}
                    hostBadge={hostBadgeByServerId.get(workspace.serverId) ?? null}
                    shortcutNumber={statusShortcutIndex.get(workspace.workspaceKey) ?? null}
                    showShortcutBadge={showShortcutBadges}
                    canPin={supportsPinningByServerId.get(workspace.serverId) === true}
                    onToggleWorkspacePin={onToggleWorkspacePin}
                    onWorkspacePress={onWorkspacePress}
                    parentGestureRef={parentGestureRef}
                  />
                ))}
                {canTogglePinnedWorkspaces ? (
                  <Animated.View layout={listSettle} collapsable={false}>
                    <SidebarGroupToggleRow
                      expanded={pinnedWorkspacesExpanded}
                      onPress={togglePinnedWorkspacesExpanded}
                      testID="sidebar-pinned-show-more"
                    />
                  </Animated.View>
                ) : null}
              </>
            )}
          </View>
        ) : null}
        {listHeaderComponent ? (
          <Animated.View layout={listSettle} collapsable={false}>
            {listHeaderComponent}
          </Animated.View>
        ) : null}
        <StatusGroupList
          activityNow={activityNow}
          limitedGroups={limitedGroups}
          onToggleGroupExpanded={toggleGroupExpanded}
          projectIconByProjectViewKey={projectIconByProjectViewKey}
          shortcutIndex={statusShortcutIndex}
          showShortcutBadges={showShortcutBadges}
          onWorkspacePress={onWorkspacePress}
          hostBadgeByServerId={hostBadgeByServerId}
          supportsPinningByServerId={supportsPinningByServerId}
          onToggleWorkspacePin={onToggleWorkspacePin}
          parentGestureRef={parentGestureRef}
        />
        <SidebarArchivedGroup
          entries={archivedWorkspaces}
          hostBadgeByServerId={hostBadgeByServerId}
        />
      </LayoutAnimationConfig>
    </SidebarListSettleContext>
  );

  return (
    <View style={styles.container}>
      {platformIsNative ? (
        <NestableScrollContainer
          style={styles.list}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          {...nativeScrollGestureProps}
          testID="sidebar-status-list-scroll"
        >
          {content}
        </NestableScrollContainer>
      ) : (
        <ScrollView
          style={styles.list}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          testID="sidebar-status-list-scroll"
        >
          {content}
        </ScrollView>
      )}
    </View>
  );
}

function StatusGroupList({
  activityNow,
  limitedGroups,
  onToggleGroupExpanded,
  projectIconByProjectViewKey,
  shortcutIndex,
  showShortcutBadges,
  onWorkspacePress,
  hostBadgeByServerId,
  supportsPinningByServerId,
  onToggleWorkspacePin,
  parentGestureRef,
}: {
  activityNow: Date;
  limitedGroups: LimitedStatusGroup[];
  onToggleGroupExpanded: (bucket: string) => void;
  projectIconByProjectViewKey: ReadonlyMap<string, string | null>;
  shortcutIndex: Map<string, number>;
  showShortcutBadges: boolean;
  onWorkspacePress?: () => void;
  hostBadgeByServerId: ReadonlyMap<string, HostBadgeModel>;
  supportsPinningByServerId: ReadonlyMap<string, boolean>;
  onToggleWorkspacePin: ToggleSidebarWorkspacePin;
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
}) {
  return (
    <>
      {limitedGroups.map((limited) => (
        <StatusGroupRows
          key={limited.group.bucket}
          activityNow={activityNow}
          limited={limited}
          onToggleGroupExpanded={onToggleGroupExpanded}
          projectIconByProjectViewKey={projectIconByProjectViewKey}
          shortcutIndex={shortcutIndex}
          showShortcutBadges={showShortcutBadges}
          onWorkspacePress={onWorkspacePress}
          hostBadgeByServerId={hostBadgeByServerId}
          supportsPinningByServerId={supportsPinningByServerId}
          onToggleWorkspacePin={onToggleWorkspacePin}
          parentGestureRef={parentGestureRef}
        />
      ))}
    </>
  );
}

function StatusGroupRows({
  activityNow,
  limited,
  onToggleGroupExpanded,
  projectIconByProjectViewKey,
  shortcutIndex,
  showShortcutBadges,
  onWorkspacePress,
  hostBadgeByServerId,
  supportsPinningByServerId,
  onToggleWorkspacePin,
  parentGestureRef,
}: {
  activityNow: Date;
  limited: LimitedStatusGroup;
  onToggleGroupExpanded: (bucket: string) => void;
  projectIconByProjectViewKey: ReadonlyMap<string, string | null>;
  shortcutIndex: Map<string, number>;
  showShortcutBadges: boolean;
  onWorkspacePress?: () => void;
  hostBadgeByServerId: ReadonlyMap<string, HostBadgeModel>;
  supportsPinningByServerId: ReadonlyMap<string, boolean>;
  onToggleWorkspacePin: ToggleSidebarWorkspacePin;
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
}) {
  const { group, collapsed, visibleRows, expanded, canToggle } = limited;
  const listSettle = useSidebarListSettle();
  const handleToggleExpanded = useCallback(() => {
    onToggleGroupExpanded(group.bucket);
  }, [group.bucket, onToggleGroupExpanded]);

  // Flat siblings, not a group container: an animated wrapper around the whole
  // group would resize when its own rows change, and the web backend animates
  // that as a scale that drags the heading along (see sidebar-motion.ts). Each
  // fixed-size element animates its own translation instead; the trailing
  // spacer is invisible, so it can snap.
  return (
    <>
      <Animated.View entering={STATUS_ROW_ENTERING} layout={listSettle} collapsable={false}>
        <StatusGroupHeader group={group} collapsed={collapsed} />
      </Animated.View>
      {!collapsed
        ? visibleRows.map((workspace) => (
            <StatusWorkspaceRow
              key={workspace.workspaceKey}
              activityNow={activityNow}
              workspace={workspace}
              iconDataUri={projectIconByProjectViewKey.get(workspace.projectViewKey) ?? null}
              hostBadge={hostBadgeByServerId.get(workspace.serverId) ?? null}
              shortcutNumber={shortcutIndex.get(workspace.workspaceKey) ?? null}
              showShortcutBadge={showShortcutBadges}
              canPin={supportsPinningByServerId.get(workspace.serverId) === true}
              onToggleWorkspacePin={onToggleWorkspacePin}
              onWorkspacePress={onWorkspacePress}
              parentGestureRef={parentGestureRef}
              containerTestID={`sidebar-status-row-${group.bucket}`}
            />
          ))
        : null}
      {!collapsed && canToggle ? (
        <Animated.View entering={STATUS_ROW_ENTERING} layout={listSettle} collapsable={false}>
          <SidebarGroupToggleRow
            expanded={expanded}
            onPress={handleToggleExpanded}
            indented
            testID={`sidebar-status-show-more-${group.bucket}`}
          />
        </Animated.View>
      ) : null}
      <View style={styles.groupSpacer} />
    </>
  );
}

function StatusGroupHeader({ group, collapsed }: { group: StatusGroup; collapsed: boolean }) {
  const [isHovered, setIsHovered] = useState(false);
  const toggleStatusGroupCollapsed = useSidebarCollapsedSectionsStore(
    (state) => state.toggleStatusGroupCollapsed,
  );
  const handlePress = useCallback(() => {
    toggleStatusGroupCollapsed(group.bucket);
  }, [group.bucket, toggleStatusGroupCollapsed]);
  const handleHoverIn = useCallback(() => setIsHovered(true), []);
  const handleHoverOut = useCallback(() => setIsHovered(false), []);
  const rowStyle = useCallback(
    ({ pressed }: PressableStateCallbackType) => [
      styles.statusGroupRow,
      isHovered && styles.statusGroupRowHovered,
      pressed && styles.statusGroupRowPressed,
    ],
    [isHovered],
  );
  const accessibilityState = useMemo(() => ({ expanded: !collapsed }), [collapsed]);

  return (
    <View onPointerEnter={handleHoverIn} onPointerLeave={handleHoverOut}>
      <Pressable
        accessibilityRole={platformIsWeb ? undefined : "button"}
        accessibilityLabel={`${group.label} status group`}
        accessibilityState={accessibilityState}
        style={rowStyle}
        onPress={handlePress}
        testID={`sidebar-status-group-${group.bucket}`}
      >
        <View style={styles.statusGroupRowLeft}>
          <View style={styles.statusGroupLeadingVisualSlot}>
            <StatusGroupLeadingVisual
              bucket={group.bucket}
              collapsed={collapsed}
              showChevron={isHovered}
            />
          </View>
          <View style={styles.statusGroupTitleGroup}>
            <Text style={styles.statusGroupTitle} numberOfLines={1}>
              {group.label}
            </Text>
          </View>
        </View>
      </Pressable>
    </View>
  );
}

function StatusGroupLeadingVisual({
  bucket,
  collapsed,
  showChevron,
}: {
  bucket: StatusGroup["bucket"];
  collapsed: boolean;
  showChevron: boolean;
}) {
  if (!showChevron) {
    return <StatusGroupIcon bucket={bucket} />;
  }
  if (collapsed) {
    return <ThemedChevronRight size={14} uniProps={foregroundMutedColorMapping} />;
  }
  return <ThemedChevronDown size={14} uniProps={foregroundMutedColorMapping} />;
}

function StatusGroupIcon({ bucket }: { bucket: StatusGroup["bucket"] }) {
  switch (bucket) {
    case "needs_input":
      return <ThemedCircleAlert size={14} uniProps={needsInputColorMapping} />;
    case "failed":
      return <ThemedCircleX size={14} uniProps={failedColorMapping} />;
    case "attention":
      return <ThemedCircleCheck size={14} uniProps={attentionColorMapping} />;
    case "running":
      return <ThemedCircleDot size={14} uniProps={runningColorMapping} />;
    case "done":
      return <ThemedCircleCheck size={14} uniProps={foregroundMutedColorMapping} />;
    case "snoozed":
      return <ThemedMoon size={14} uniProps={blueColorMapping} />;
  }
}

const StatusWorkspaceRow = memo(function StatusWorkspaceRow({
  activityNow,
  workspace,
  iconDataUri,
  hostBadge,
  shortcutNumber,
  showShortcutBadge,
  canPin,
  onToggleWorkspacePin,
  onWorkspacePress,
  parentGestureRef,
  containerTestID,
}: {
  activityNow: Date;
  workspace: SidebarWorkspaceEntry;
  iconDataUri: string | null;
  hostBadge: HostBadgeModel | null;
  shortcutNumber: number | null;
  showShortcutBadge: boolean;
  canPin: boolean;
  onToggleWorkspacePin: ToggleSidebarWorkspacePin;
  onWorkspacePress?: () => void;
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
  /** Stamped on the row's outer animated view so tests can scope rows to a status bucket. */
  containerTestID?: string;
}) {
  const activeWorkspaceSelection = useActiveWorkspaceSelection();
  const selected =
    activeWorkspaceSelection?.serverId === workspace.serverId &&
    activeWorkspaceSelection?.workspaceId === workspace.workspaceId;

  const handlePress = useCallback(() => {
    if (!workspace.serverId) return;
    onWorkspacePress?.();
    navigateToWorkspace({ serverId: workspace.serverId, workspaceId: workspace.workspaceId });
  }, [onWorkspacePress, workspace.serverId, workspace.workspaceId]);

  return (
    <StatusWorkspaceRowWithMenu
      activityNow={activityNow}
      workspace={workspace}
      iconDataUri={iconDataUri}
      hostBadge={hostBadge}
      selected={selected}
      shortcutNumber={shortcutNumber}
      showShortcutBadge={showShortcutBadge}
      canPin={canPin}
      onToggleWorkspacePin={onToggleWorkspacePin}
      parentGestureRef={parentGestureRef}
      onPress={handlePress}
      containerTestID={containerTestID}
    />
  );
});

function StatusWorkspaceRowWithMenu({
  activityNow,
  workspace,
  iconDataUri,
  hostBadge,
  selected,
  shortcutNumber,
  showShortcutBadge,
  canPin,
  onToggleWorkspacePin,
  parentGestureRef,
  onPress,
  containerTestID,
}: {
  activityNow: Date;
  workspace: SidebarWorkspaceEntry;
  iconDataUri: string | null;
  hostBadge: HostBadgeModel | null;
  selected: boolean;
  shortcutNumber: number | null;
  showShortcutBadge: boolean;
  canPin: boolean;
  onToggleWorkspacePin: ToggleSidebarWorkspacePin;
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
  onPress: () => void;
  containerTestID?: string;
}) {
  const { t } = useTranslation();
  const toast = useToast();
  const [isHidingWorkspace, setIsHidingWorkspace] = useState(false);
  const [isRenameOpen, setIsRenameOpen] = useState(false);
  const isArchiving = workspace.archivingAt !== null || isHidingWorkspace;

  const redirectAfterArchive = useCallback(() => {
    redirectIfArchivingActiveWorkspace({
      serverId: workspace.serverId,
      workspaceId: workspace.workspaceId,
      activeWorkspaceSelection: selected
        ? { serverId: workspace.serverId, workspaceId: workspace.workspaceId }
        : null,
    });
  }, [selected, workspace]);

  const archiveController = useWorkspaceArchive({
    serverId: workspace.serverId,
    workspaceId: workspace.workspaceId,
    workspaceKind: workspace.workspaceKind,
    name: workspace.name,
    projectName: workspace.projectName,
    ...toWorktreeArchiveRisk(workspace),
    onArchiveStarted: redirectAfterArchive,
    onSetHiding: setIsHidingWorkspace,
  });

  const handleArchive = useCallback(() => {
    if (isArchiving) return;
    archiveController.archive();
  }, [archiveController, isArchiving]);

  const handleCopyPath = useCallback(() => {
    let copyTargetDirectory: string;
    try {
      copyTargetDirectory = requireWorkspaceDirectory({
        workspaceId: workspace.workspaceId,
        workspaceDirectory: workspace.workspaceDirectory,
      });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Workspace path not available");
      return;
    }
    void Clipboard.setStringAsync(copyTargetDirectory);
    toast.copied("Path copied");
  }, [toast, workspace.workspaceDirectory, workspace.workspaceId]);

  const handleCopyBranchName = useCallback(() => {
    void Clipboard.setStringAsync(workspace.name);
    toast.copied("Branch name copied");
  }, [toast, workspace.name]);

  const renameMutation = useMutation({
    mutationFn: async (title: string) => {
      const client = getHostRuntimeStore().getClient(workspace.serverId);
      if (!client) throw new Error(t("workspace.terminal.hostDisconnected"));
      await client.setWorkspaceTitle(workspace.workspaceId, title.length === 0 ? null : title);
    },
  });

  const handleOpenRename = useCallback(() => setIsRenameOpen(true), []);
  const handleCloseRename = useCallback(() => setIsRenameOpen(false), []);
  const handleSubmitRename = useCallback(
    async (value: string) => {
      await renameMutation.mutateAsync(value.trim());
    },
    [renameMutation],
  );
  const isPinned = workspace.pinnedAt != null;
  const handleTogglePin = useCallback(() => {
    onToggleWorkspacePin(workspace);
  }, [onToggleWorkspacePin, workspace]);
  const onTogglePin = canPin ? handleTogglePin : undefined;

  const archiveShortcutKeys = useShortcutKeys("archive-workspace");
  const { hasClearableAttention, clearAttention } = useClearWorkspaceAttention({
    serverId: workspace.serverId,
    workspaceId: workspace.workspaceId,
  });
  const handleMarkAsRead = useCallback(() => {
    void clearAttention().catch((error) => {
      toast.error(error instanceof Error ? error.message : "Failed to mark workspace as read");
    });
  }, [clearAttention, toast]);

  // Subscribed here rather than threaded through the memoized row above, and
  // keyed by workspaceKey so an expansion carries across grouping modes.
  const workspaceKey = workspace.workspaceKey;
  const agentTreeExpanded = useSidebarCollapsedSectionsStore((state) =>
    state.expandedAgentTreeWorkspaceKeys.has(workspaceKey),
  );
  const toggleAgentTreeExpanded = useSidebarCollapsedSectionsStore(
    (state) => state.toggleAgentTreeExpanded,
  );
  const hasAgents = useWorkspaceHasAgents({
    serverId: workspace.serverId,
    workspaceId: workspace.workspaceId,
  });
  const handleToggleAgentTree = useCallback(() => {
    toggleAgentTreeExpanded(workspaceKey);
  }, [toggleAgentTreeExpanded, workspaceKey]);
  const disclosure = useMemo(
    () => (hasAgents ? { expanded: agentTreeExpanded, onToggle: handleToggleAgentTree } : null),
    [agentTreeExpanded, handleToggleAgentTree, hasAgents],
  );

  useKeyboardActionHandler({
    handlerId: `workspace-archive-${workspace.workspaceKey}`,
    actions: ["workspace.archive"],
    enabled: selected && !isArchiving,
    priority: 0,
    handle: () => {
      handleArchive();
      return true;
    },
  });

  return (
    <>
      <StatusWorkspaceRowInner
        activityNow={activityNow}
        workspace={workspace}
        iconDataUri={iconDataUri}
        hostBadge={hostBadge}
        selected={selected}
        shortcutNumber={shortcutNumber}
        showShortcutBadge={showShortcutBadge}
        onPress={onPress}
        isArchiving={isArchiving}
        archiveLabel={t("sidebar.workspace.actions.archive")}
        archiveStatus={isArchiving ? "pending" : "idle"}
        archivePendingLabel={t("sidebar.workspace.actions.archiving")}
        onArchive={handleArchive}
        onCopyBranchName={workspace.projectKind === "git" ? handleCopyBranchName : undefined}
        onCopyPath={handleCopyPath}
        onRename={handleOpenRename}
        onSubmitRename={handleSubmitRename}
        onMarkAsRead={hasClearableAttention ? handleMarkAsRead : undefined}
        archiveShortcutKeys={selected ? archiveShortcutKeys : null}
        isPinned={isPinned}
        onTogglePin={onTogglePin}
        parentGestureRef={parentGestureRef}
        containerTestID={containerTestID}
        disclosure={disclosure}
      />
      {/*
        A flat sibling of the row, not a child of it: the row's animated wrapper
        carries a layout transition, and the web backend animates a resize as a
        scale keyframe that would squash the row and its tree (see
        sidebar-motion.ts). Growing the list by adding a sibling keeps every
        layout transition a pure translation. An archiving row drops its tree
        first so the collapse animates alone.
      */}
      {disclosure?.expanded && !isArchiving ? (
        <WorkspaceAgentTree
          serverId={workspace.serverId}
          workspaceId={workspace.workspaceId}
          baseIndent={STATUS_ROW_AGENT_TREE_INDENT}
        />
      ) : null}
      <AdaptiveRenameModal
        visible={isRenameOpen}
        title="Rename workspace"
        initialValue={workspace.title ?? workspace.name}
        placeholder={workspace.name}
        submitLabel="Rename"
        onClose={handleCloseRename}
        onSubmit={handleSubmitRename}
        testID={`sidebar-workspace-rename-modal-${workspace.workspaceKey}`}
      />
    </>
  );
}

function StatusWorkspaceRowInner({
  activityNow,
  workspace,
  iconDataUri,
  hostBadge,
  selected,
  shortcutNumber,
  showShortcutBadge,
  onPress,
  isArchiving,
  archiveLabel,
  archiveStatus = "idle",
  archivePendingLabel,
  onArchive,
  onCopyBranchName,
  onCopyPath,
  onRename,
  onSubmitRename,
  onMarkAsRead,
  archiveShortcutKeys,
  isPinned,
  onTogglePin,
  parentGestureRef,
  containerTestID,
  disclosure,
}: {
  activityNow: Date;
  workspace: SidebarWorkspaceEntry;
  iconDataUri: string | null;
  hostBadge: HostBadgeModel | null;
  selected: boolean;
  shortcutNumber: number | null;
  showShortcutBadge: boolean;
  onPress: () => void;
  isArchiving: boolean;
  archiveLabel: string;
  archiveStatus?: "idle" | "pending" | "success";
  archivePendingLabel?: string;
  onArchive?: () => void;
  onCopyBranchName?: () => void;
  onCopyPath?: () => void;
  onRename?: () => void;
  onSubmitRename?: (value: string) => Promise<void>;
  onMarkAsRead?: () => void;
  archiveShortcutKeys?: ShortcutKey[][] | null;
  isPinned?: boolean;
  onTogglePin?: () => void;
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
  containerTestID?: string;
  disclosure: SidebarWorkspaceRowDisclosure | null;
}) {
  const { t } = useTranslation();
  const agentsLabel = t("sidebar.workspace.agentTree.swipeAction");
  const isTouchPlatform = platformIsNative;
  const archiveCollapse = useArchiveCollapse(isArchiving);
  const listSettle = useSidebarListSettle();
  const kebab = useOpenKebabMenuVisibility(false);
  // The snoozed bucket already ticks via the sidebar's wake clock, so the row
  // needs no timer of its own: it pops out of the bucket when the snooze ends.
  const isSnoozed = workspace.statusBucket === "snoozed";

  const isDesktop = !isTouchPlatform;
  const serviceSummary = isDesktop ? selectWorkspaceServiceSummary(workspace.scripts) : null;

  const accessibilityState = useMemo(() => ({ selected }), [selected]);

  return (
    <Animated.View
      entering={STATUS_ROW_ENTERING}
      layout={listSettle}
      onLayout={archiveCollapse.onLayout}
      style={archiveCollapse.style}
      collapsable={false}
      testID={containerTestID}
    >
      <SidebarWorkspaceRowFrame workspace={workspace}>
        {({ isHovered, contextMenuOpen, onContextMenuOpenChange, hoverHandlers }) => {
          // Touch platforms have no hover, so the kebab is permanent there and the
          // inline archive text button never appears.
          const showActions = Boolean(
            onArchive && (isHovered || isTouchPlatform || kebab.showKebab),
          );
          // The full cluster already contains the snooze chip, so the standalone
          // one only fills the gap when the cluster is hidden.
          const showSnoozeChipOnly = !showActions && isSnoozed;
          // Web-only: the chevron is hover-revealed and stays on while the tree
          // is open. Native has no hover and reaches the tree by swiping instead.
          const showAgentTreeToggle = Boolean(
            disclosure && platformIsWeb && (isHovered || disclosure.expanded),
          );
          const workspaceRowStyle = getStatusWorkspaceRowStyle({ selected, isHovered });
          return (
            <View style={styles.workspaceRowContainer} {...hoverHandlers}>
              <StatusRowSwipeContainer
                archiveLabel={archiveLabel}
                onArchive={onArchive}
                isArchiving={isArchiving}
                agentsLabel={agentsLabel}
                onToggleAgents={disclosure?.onToggle}
                parentGestureRef={parentGestureRef}
              >
                <SidebarWorkspaceContextMenu
                  contextMenuOpen={contextMenuOpen}
                  onContextMenuOpenChange={onContextMenuOpenChange}
                  workspace={workspace}
                  leadingProjectName={workspace.projectName}
                  hostBadgeLabel={hostBadge?.label}
                  serviceSummary={serviceSummary}
                  workspaceKey={workspace.workspaceKey}
                  onCopyPath={onCopyPath}
                  onCopyBranchName={onCopyBranchName}
                  onRename={onRename}
                  onMarkAsRead={onMarkAsRead}
                  onArchive={onArchive}
                  archiveLabel={archiveLabel}
                  archiveStatus={archiveStatus}
                  archivePendingLabel={archivePendingLabel}
                  archiveShortcutKeys={archiveShortcutKeys}
                  isPinned={isPinned}
                  onTogglePin={onTogglePin}
                  agentTree={disclosure ?? undefined}
                  openInFileManagerPath={workspace.workspaceDirectory}
                  disabled={isArchiving}
                  accessibilityRole="button"
                  accessibilityState={accessibilityState}
                  style={workspaceRowStyle}
                  highlightStyle={styles.workspaceRowHovered}
                  onPress={onPress}
                  testID={`sidebar-workspace-row-${workspace.workspaceKey}`}
                >
                  <SidebarStatusRowContent
                    activityNow={activityNow}
                    workspace={workspace}
                    iconDataUri={iconDataUri}
                    hostBadge={hostBadge}
                    serviceSummary={serviceSummary}
                    isArchiving={isArchiving}
                    shortcutNumber={shortcutNumber}
                    showShortcutBadge={showShortcutBadge}
                    showActions={showActions}
                    showSnoozedChip={showSnoozeChipOnly}
                    showAgentTreeToggle={showAgentTreeToggle}
                    onSubmitRename={onSubmitRename}
                  >
                    {showSnoozeChipOnly ? (
                      <StatusWorkspaceSnoozeChip workspace={workspace} />
                    ) : null}
                    {showActions && onArchive ? (
                      <StatusWorkspaceQuickActions
                        {...kebab.menuProps}
                        workspace={workspace}
                        showInlineArchive={!isTouchPlatform}
                        isPinned={isPinned}
                        onTogglePin={onTogglePin}
                        onCopyPath={onCopyPath}
                        onCopyBranchName={onCopyBranchName}
                        onRename={onRename}
                        onMarkAsRead={onMarkAsRead}
                        onArchive={onArchive}
                        archiveLabel={archiveLabel}
                        archiveStatus={archiveStatus}
                        archivePendingLabel={archivePendingLabel}
                        archiveShortcutKeys={archiveShortcutKeys}
                      />
                    ) : null}
                    {showAgentTreeToggle && disclosure ? (
                      <SidebarWorkspaceAgentTreeToggle
                        expanded={disclosure.expanded}
                        onToggle={disclosure.onToggle}
                        testID={`sidebar-workspace-agent-tree-toggle-${workspace.workspaceKey}`}
                      />
                    ) : null}
                  </SidebarStatusRowContent>
                </SidebarWorkspaceContextMenu>
              </StatusRowSwipeContainer>
            </View>
          );
        }}
      </SidebarWorkspaceRowFrame>
    </Animated.View>
  );
}

/**
 * The snooze trigger, which renders both inside the hover cluster and on its
 * own for a snoozed row that is not hovered. The menu hook is deliberately
 * mounted here rather than in the row: it is per-render work the row should
 * only pay when the trigger is actually on screen.
 */
function StatusWorkspaceSnoozeChip({ workspace }: { workspace: SidebarWorkspaceEntry }) {
  const snooze = useWorkspaceSnoozeMenu({
    serverId: workspace.serverId,
    workspaceId: workspace.workspaceId,
    isSnoozed: workspace.statusBucket === "snoozed",
    snoozeWakeAt: workspace.snoozeWakeAt,
  });
  if (!snooze) {
    return null;
  }
  return <SidebarStatusRowSnoozeAction workspaceKey={workspace.workspaceKey} snooze={snooze} />;
}

/** Hover-revealed cluster: snooze, inline archive (web), plus the row kebab. */
function StatusWorkspaceQuickActions({
  workspace,
  showInlineArchive,
  isPinned,
  onTogglePin,
  onCopyPath,
  onCopyBranchName,
  onRename,
  onMarkAsRead,
  onArchive,
  open,
  onOpenChange,
  archiveLabel,
  archiveStatus,
  archivePendingLabel,
  archiveShortcutKeys,
}: {
  workspace: SidebarWorkspaceEntry;
  showInlineArchive: boolean;
  isPinned?: boolean;
  onTogglePin?: () => void;
  onCopyPath?: () => void;
  onCopyBranchName?: () => void;
  onRename?: () => void;
  onMarkAsRead?: () => void;
  onArchive: () => void;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  archiveLabel: string;
  archiveStatus?: "idle" | "pending" | "success";
  archivePendingLabel?: string;
  archiveShortcutKeys?: ShortcutKey[][] | null;
}) {
  const snooze = useWorkspaceSnoozeMenu({
    serverId: workspace.serverId,
    workspaceId: workspace.workspaceId,
    isSnoozed: workspace.statusBucket === "snoozed",
    snoozeWakeAt: workspace.snoozeWakeAt,
  });
  return (
    <View style={styles.workspaceQuickActions}>
      {snooze ? (
        <SidebarStatusRowSnoozeAction workspaceKey={workspace.workspaceKey} snooze={snooze} />
      ) : null}
      {showInlineArchive ? (
        <SidebarStatusRowArchiveAction label={archiveLabel} onArchive={onArchive} />
      ) : null}
      <SidebarWorkspaceMenu
        open={open}
        onOpenChange={onOpenChange}
        workspaceKey={workspace.workspaceKey}
        onCopyPath={onCopyPath}
        onCopyBranchName={onCopyBranchName}
        onRename={onRename}
        onMarkAsRead={onMarkAsRead}
        onArchive={onArchive}
        archiveLabel={archiveLabel}
        archiveStatus={archiveStatus}
        archivePendingLabel={archivePendingLabel}
        archiveShortcutKeys={archiveShortcutKeys}
        isPinned={isPinned}
        onTogglePin={onTogglePin}
        snooze={snooze}
      />
    </View>
  );
}

function getStatusWorkspaceRowStyle({
  selected,
  isHovered,
}: {
  selected: boolean;
  isHovered: boolean;
}) {
  return [
    styles.workspaceRow,
    selected && styles.sidebarRowSelected,
    isHovered && styles.workspaceRowHovered,
  ];
}

const styles = StyleSheet.create((theme) => ({
  container: {
    flex: 1,
  },
  list: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: theme.spacing[2],
    // Keep status mode's Pinned/Workspaces boundary identical to project mode.
    paddingTop: 2,
    paddingBottom: theme.spacing[4],
  },
  pinnedSection: {
    marginBottom: theme.spacing[1],
  },
  // Trailing gap of a status group; a plain view because it is invisible and
  // may snap while the animated siblings around it slide.
  groupSpacer: {
    height: theme.spacing[1],
  },
  statusGroupRow: {
    minHeight: 36,
    paddingVertical: theme.spacing[2],
    paddingHorizontal: theme.spacing[2],
    borderRadius: theme.borderRadius.lg,
    marginBottom: theme.spacing[2],
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: theme.spacing[2],
    userSelect: "none",
  },
  statusGroupRowHovered: {
    backgroundColor: theme.colors.surfaceSidebarHover,
  },
  statusGroupRowPressed: {
    backgroundColor: theme.colors.surface2,
  },
  statusGroupRowLeft: {
    flexDirection: "row",
    alignItems: "center",
    gap: theme.spacing[2],
    flex: 1,
    minWidth: 0,
  },
  statusGroupLeadingVisualSlot: {
    position: "relative",
    width: theme.iconSize.md,
    height: theme.iconSize.md,
    flexShrink: 0,
    alignItems: "center",
    justifyContent: "center",
  },
  statusGroupTitleGroup: {
    flexDirection: "row",
    alignItems: "center",
    gap: theme.spacing[1],
    flex: 1,
    minWidth: 0,
  },
  statusGroupTitle: {
    color: theme.colors.foregroundMuted,
    fontSize: theme.fontSize.sm,
    fontWeight: "400",
    minWidth: 0,
    flexShrink: 1,
  },
  workspaceRowContainer: {
    position: "relative",
    // The gap lives on the hover/swipe container, not the row itself, so the
    // native swipe underlay stops at the row box instead of filling the gap.
    marginBottom: theme.spacing[1],
  },
  workspaceQuickActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: theme.spacing[1],
  },
  workspaceRow: {
    // The 40px icon block plus the full-width meta line; fixed so the hover swap
    // between the time-ago text and the quick actions never reflows the row.
    minHeight: 72,
    paddingVertical: theme.spacing[2],
    paddingLeft: theme.spacing[2],
    paddingRight: theme.spacing[3],
    borderRadius: theme.borderRadius.lg,
    flexDirection: "column",
    alignItems: "stretch",
    justifyContent: "flex-start",
    gap: theme.spacing[1],
    userSelect: "none",
  },
  workspaceRowHovered: {
    backgroundColor: theme.colors.surfaceSidebarHover,
  },
  workspaceRowPressed: {
    backgroundColor: theme.colors.surface2,
  },
  sidebarRowSelected: {
    backgroundColor: theme.colors.surfaceSidebarHover,
  },
}));
