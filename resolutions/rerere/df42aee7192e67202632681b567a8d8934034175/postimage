import { useEffect } from "react";
import { useQueryClient, type QueryClient } from "@tanstack/react-query";
import { useShallow } from "zustand/shallow";
import { useFetchQueries } from "@/data/query";
import { getHostRuntimeStore, useHostRuntimeConnectionStatuses } from "@/runtime/host-runtime";
import { useSessionStore } from "@/stores/session-store";

// Recently-archived workspaces are an undo affordance, not an archive browser.
// The daemon caps its own response; this is the client-side ceiling on the merged
// cross-host list so a many-host sidebar can't grow an unbounded tail.
const ARCHIVED_WORKSPACE_LIMIT = 25;
const ARCHIVED_WORKSPACES_STALE_TIME = 30_000;

export interface ArchivedWorkspaceEntry {
  workspaceKey: string;
  serverId: string;
  workspaceId: string;
  projectName: string;
  name: string;
  archivedAt: Date;
  phase: "archiving" | "archived";
}

export interface ArchivedWorkspaceSource {
  isOnline: boolean;
  entries: ArchivedWorkspaceEntry[] | undefined;
}

export function archivedWorkspacesQueryKey(serverId: string): [string, string] {
  return ["archivedWorkspaces", serverId];
}

/**
 * Archived workspaces are deliberately kept out of the session store's workspace
 * map: everything that reads that map (project mode, switchers, counts) treats a
 * present descriptor as live. These rows live only here, and only status mode
 * renders them.
 */
export function useArchivedWorkspaces({
  serverIds,
}: {
  serverIds: readonly string[];
}): ArchivedWorkspaceEntry[] {
  const queryClient = useQueryClient();
  // COMPAT(archivedWorkspacesList): added in v0.2.0, drop the gate when floor >= v0.2.0.
  // Single capability-detection site; hosts without the RPC simply contribute nothing.
  const supportedServerIds = useSessionStore(
    useShallow((state) =>
      serverIds.filter(
        (serverId) =>
          state.sessions[serverId]?.serverInfo?.features?.archivedWorkspacesList === true,
      ),
    ),
  );
  // An offline host has no client to ask, so asking only burns retries. Its rows
  // reappear when the connection does.
  const connectionStatuses = useHostRuntimeConnectionStatuses(supportedServerIds);

  const queries = useFetchQueries(
    supportedServerIds.map((serverId) => ({
      queryKey: archivedWorkspacesQueryKey(serverId),
      queryFn: async (): Promise<ArchivedWorkspaceEntry[]> => {
        const client = getHostRuntimeStore().getClient(serverId);
        if (!client) {
          throw new Error("Host disconnected");
        }
        const entries = await client.listArchivedWorkspaces();
        return entries.map((entry) => ({
          workspaceKey: `${serverId}:${entry.id}`,
          serverId,
          workspaceId: entry.id,
          projectName: entry.projectDisplayName,
          name: entry.name,
          archivedAt: new Date(entry.archivedAt),
          phase: "archived" as const,
        }));
      },
      enabled: connectionStatuses.get(serverId) === "online",
      staleTimeMs: ARCHIVED_WORKSPACES_STALE_TIME,
      dataShape: "list" as const,
    })),
  );

  useEffect(() => {
    const unsubscribes = supportedServerIds.flatMap((serverId) => {
      if (connectionStatuses.get(serverId) !== "online") {
        return [];
      }
      const client = getHostRuntimeStore().getClient(serverId);
      if (!client) {
        return [];
      }
      return [
        client.on("workspace_update", (message) => {
          const queryKey = archivedWorkspacesQueryKey(serverId);
          const cached = queryClient.getQueryData<ArchivedWorkspaceEntry[]>(queryKey);
          const workspaceId =
            message.payload.kind === "remove" ? message.payload.id : message.payload.workspace.id;
          if (shouldRefreshArchivedWorkspaces(message.payload.kind, workspaceId, cached)) {
            void queryClient.invalidateQueries({ queryKey });
          }
        }),
      ];
    });
    return () => {
      for (const unsubscribe of unsubscribes) {
        unsubscribe();
      }
    };
  }, [connectionStatuses, queryClient, supportedServerIds]);

  const sources = supportedServerIds.map(
    (serverId, index): ArchivedWorkspaceSource => ({
      isOnline: connectionStatuses.get(serverId) === "online",
      entries: queries[index]?.data,
    }),
  );
  return mergeArchivedWorkspaces(sources);
}

export function shouldRefreshArchivedWorkspaces(
  kind: "remove" | "upsert",
  workspaceId: string,
  cached: readonly ArchivedWorkspaceEntry[] | undefined,
): boolean {
  if (kind === "remove") {
    return true;
  }
  return Boolean(cached?.some((entry) => entry.workspaceId === workspaceId));
}

export function mergeArchivedWorkspaces(
  sources: readonly ArchivedWorkspaceSource[],
): ArchivedWorkspaceEntry[] {
  const merged: ArchivedWorkspaceEntry[] = [];
  for (const source of sources) {
    if (source.isOnline && source.entries) {
      merged.push(...source.entries);
    }
  }
  return merged
    .sort((left, right) => compareArchivedWorkspaces(left, right))
    .slice(0, ARCHIVED_WORKSPACE_LIMIT);
}

export async function beginArchivedWorkspaceTransition(input: {
  queryClient: QueryClient;
  entry: ArchivedWorkspaceEntry;
}): Promise<void> {
  const queryKey = archivedWorkspacesQueryKey(input.entry.serverId);
  await input.queryClient.cancelQueries({ queryKey });
  input.queryClient.setQueryData<ArchivedWorkspaceEntry[]>(queryKey, (current = []) => [
    input.entry,
    ...current.filter((entry) => entry.workspaceKey !== input.entry.workspaceKey),
  ]);
}

export function settleArchivedWorkspaceTransition(input: {
  queryClient: QueryClient;
  serverId: string;
  workspaceKey: string;
  outcome: "archived" | "failed";
}): void {
  const queryKey = archivedWorkspacesQueryKey(input.serverId);
  input.queryClient.setQueryData<ArchivedWorkspaceEntry[]>(queryKey, (current = []) => {
    if (input.outcome === "failed") {
      return current.filter((entry) => entry.workspaceKey !== input.workspaceKey);
    }
    return current.map((entry) =>
      entry.workspaceKey === input.workspaceKey ? { ...entry, phase: "archived" } : entry,
    );
  });
}

// Newest archive first. Entries archived in the same millisecond (a cascade
// archive writes one timestamp across several workspaces) fall back to the key so
// the order stays stable across refetches.
function compareArchivedWorkspaces(
  left: ArchivedWorkspaceEntry,
  right: ArchivedWorkspaceEntry,
): number {
  const leftTime = left.archivedAt.getTime();
  const rightTime = right.archivedAt.getTime();
  if (leftTime !== rightTime) {
    return rightTime - leftTime;
  }
  return left.workspaceKey.localeCompare(right.workspaceKey);
}
