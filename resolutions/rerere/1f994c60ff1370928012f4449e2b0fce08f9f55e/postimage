import type { MutableRefObject, ReactNode } from "react";
import type { GestureType } from "react-native-gesture-handler";

export interface StatusRowSwipeContainerProps {
  /** Label for the revealed action; reuses `sidebar.workspace.actions.archive`. */
  archiveLabel: string;
  /** Same handler the row kebab and the keyboard shortcut call. Omitted = no swipe. */
  onArchive?: () => void;
  /** Archiving in flight: the swipe closes and stops accepting new gestures. */
  isArchiving: boolean;
  /** Label for the agent-tree action; `sidebar.workspace.agentTree.swipeAction`. */
  agentsLabel: string;
  /**
   * Toggles the row's agent tree. Omitted when the workspace has no agents, and
   * the underlay reveals Archive alone.
   */
  onToggleAgents?: () => void;
  /**
   * The compact sidebar's drawer-close pan. The row swipe blocks it so a
   * horizontal drag that starts on a row belongs to the row, not the drawer.
   */
  parentGestureRef?: MutableRefObject<GestureType | undefined>;
  children: ReactNode;
}
