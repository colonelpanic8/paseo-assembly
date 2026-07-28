/**
 * @vitest-environment jsdom
 */
import React from "react";
import { flushSync } from "react-dom";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { ArchivedWorkspaceEntry } from "@/hooks/use-archived-workspaces";

const { theme } = vi.hoisted(() => ({
  theme: {
    spacing: { 1: 4, 2: 8, 3: 12 },
    iconSize: { md: 18 },
    borderRadius: { lg: 8 },
    fontSize: { xs: 11, sm: 13 },
    colors: {
      foregroundMuted: "#aaa",
      surfaceSidebarHover: "#222",
      surface2: "#333",
    },
  },
}));

vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) =>
      (
        ({
          "sidebar.workspace.archived.groupTitle": "Recently archived",
          "sidebar.workspace.archived.unarchive": "Unarchive",
          "sidebar.workspace.archived.unarchiving": "Unarchiving…",
        }) as Record<string, string>
      )[key] ?? key,
  }),
}));

vi.mock("react-native-unistyles", () => ({
  StyleSheet: {
    create: (factory: unknown) =>
      typeof factory === "function"
        ? (factory as (value: typeof theme) => unknown)(theme)
        : factory,
  },
  withUnistyles: (component: unknown) => component,
}));

vi.mock("react-native-reanimated", () => {
  const animation = {
    duration: () => animation,
  };
  return {
    default: {
      View: ({
        children,
        entering: _entering,
        exiting: _exiting,
        layout: _layout,
        collapsable: _collapsable,
        ...props
      }: React.PropsWithChildren<Record<string, unknown>>) =>
        React.createElement("div", props, children),
    },
    FadeIn: animation,
    FadeInUp: animation,
    FadeOut: animation,
    LinearTransition: animation,
  };
});

vi.mock("lucide-react-native", () => {
  const createIcon = (name: string) => (props: Record<string, unknown>) =>
    React.createElement("span", { ...props, "data-icon": name });
  return {
    Archive: createIcon("Archive"),
    ArchiveRestore: createIcon("ArchiveRestore"),
    ChevronDown: createIcon("ChevronDown"),
    ChevronRight: createIcon("ChevronRight"),
  };
});

vi.mock("@tanstack/react-query", () => ({
  useMutation: () => ({
    isPending: false,
    mutate: vi.fn(),
  }),
}));

vi.mock("@/constants/platform", () => ({
  isNative: false,
  isWeb: true,
}));

vi.mock("@/constants/layout", () => ({
  useIsCompactFormFactor: () => false,
}));

vi.mock("@/contexts/toast-context", () => ({
  useToast: () => ({ error: vi.fn() }),
}));

vi.mock("@/runtime/host-runtime", () => ({
  getHostRuntimeStore: () => ({ getClient: () => null }),
}));

vi.mock("@/stores/sidebar-collapsed-sections-store", () => ({
  useSidebarCollapsedSectionsStore: (
    selector: (state: {
      collapsedStatusGroupKeys: Set<string>;
      toggleStatusGroupCollapsed: () => void;
    }) => unknown,
  ) =>
    selector({
      collapsedStatusGroupKeys: new Set(),
      toggleStatusGroupCollapsed: vi.fn(),
    }),
}));

vi.mock("@/components/sidebar/sidebar-group-toggle-row", () => ({
  SidebarGroupToggleRow: ({
    expanded,
    onPress,
    testID,
  }: {
    expanded: boolean;
    onPress: () => void;
    testID: string;
  }) =>
    React.createElement(
      "button",
      { "data-testid": testID, onClick: onPress, type: "button" },
      expanded ? "Show less" : "Show more",
    ),
}));

vi.stubGlobal("React", React);
vi.stubGlobal("IS_REACT_ACT_ENVIRONMENT", true);

import { SidebarArchivedGroup } from "./sidebar-archived-group";

function archivedEntry(index: number): ArchivedWorkspaceEntry {
  return {
    workspaceKey: `server:workspace-${index}`,
    serverId: "server",
    workspaceId: `workspace-${index}`,
    projectName: "Paseo",
    name: `Archived ${index}`,
    archivedAt: new Date(Date.UTC(2026, 6, index)),
    phase: "archived",
  };
}

describe("SidebarArchivedGroup", () => {
  let root: Root | null = null;
  let container: HTMLElement | null = null;

  beforeEach(() => {
    container = document.createElement("div");
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    if (root) {
      flushSync(() => root?.unmount());
    }
    root = null;
    container?.remove();
    container = null;
  });

  it("renders five recent rows before Show more expands the tail", () => {
    const entries = Array.from({ length: 7 }, (_, index) => archivedEntry(index + 1));
    flushSync(() => {
      root?.render(
        <SidebarArchivedGroup
          entries={entries}
          hostLabelByServerId={new Map([["server", "Local"]])}
          showHostLabels
        />,
      );
    });

    expect(container?.textContent).toContain("Recently archived");
    expect(container?.textContent).toContain("Archived 5");
    expect(container?.textContent).not.toContain("Archived 6");
    expect(container?.textContent).toContain("Paseo · Local");

    const toggle = container?.querySelector(
      '[data-testid="sidebar-archived-show-more"]',
    ) as HTMLButtonElement | null;
    expect(toggle?.textContent).toBe("Show more");

    flushSync(() => toggle?.click());

    expect(container?.textContent).toContain("Archived 6");
    expect(container?.textContent).toContain("Archived 7");
    expect(toggle?.textContent).toBe("Show less");
  });

  it("renders nothing when there are no archived workspaces", () => {
    flushSync(() => {
      root?.render(
        <SidebarArchivedGroup
          entries={[]}
          hostLabelByServerId={new Map()}
          showHostLabels={false}
        />,
      );
    });

    expect(container?.textContent).toBe("");
  });

  it("shows a pending indicator instead of unarchive while the workspace is moving", () => {
    const pending = { ...archivedEntry(1), phase: "archiving" as const };
    flushSync(() => {
      root?.render(
        <SidebarArchivedGroup
          entries={[pending]}
          hostLabelByServerId={new Map([["server", "Local"]])}
          showHostLabels
        />,
      );
    });

    expect(
      container?.querySelector(`[data-testid="sidebar-archived-pending-${pending.workspaceKey}"]`),
    ).not.toBeNull();
    expect(
      container?.querySelector(
        `[data-testid="sidebar-archived-unarchive-${pending.workspaceKey}"]`,
      ),
    ).toBeNull();
  });
});
