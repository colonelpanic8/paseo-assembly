import { useEffect, useMemo } from "react";
import { usePendingArchiveAgentIds } from "@/hooks/use-archive-agent";
import equal from "fast-deep-equal";
import { useStoreWithEqualityFn } from "zustand/traditional";
import { useSessionStore, type Agent, type DaemonServerInfo } from "@/stores/session-store";
import { resolveAgentPurposeSummary } from "@/agents/purpose-summary";
import { refreshProviderSubagents, useProviderSubagentStore } from "./provider-store";
import type { ProviderSubagentDescriptorPayload } from "@getpaseo/protocol/messages";

/**
 * What a row needs to say which model and thinking level it is running. Provider
 * subagents carry no model data on the wire yet, so their fields are null today;
 * the shape exists so they light up the moment the descriptor grows them.
 */
export interface SubagentRowRuntime {
  /** Configured model id. */
  model: string | null;
  /** Runtime-reported model id. */
  runtimeModelId: string | null;
  thinkingOptionId: string | null;
  /** `undefined` when the daemon never sent it — see `Agent.effectiveThinkingOptionId`. */
  effectiveThinkingOptionId: string | null | undefined;
}

export interface PaseoSubagentRow extends SubagentRowRuntime {
  kind: "paseo";
  id: Agent["id"];
  provider: Agent["provider"];
  title: Agent["title"];
  summary: string | null;
  status: Agent["status"];
  requiresAttention: Agent["requiresAttention"];
  createdAt: Agent["createdAt"];
}

export interface ProviderSubagentRow extends SubagentRowRuntime {
  kind: "provider";
  id: string;
  parentAgentId: string;
  provider: ProviderSubagentDescriptorPayload["provider"];
  /** Provider-supplied name. Claude descriptors put the subagent *type* here. */
  title: string | null;
  /** Provider-supplied task summary. Preferred over `title` as the row label. */
  description: string | null;
  status: ProviderSubagentDescriptorPayload["status"];
  requiresAttention: boolean;
  createdAt: Date;
}

export type SubagentRow = PaseoSubagentRow | ProviderSubagentRow;

type SessionStoreSnapshot = ReturnType<typeof useSessionStore.getState>;
type ProviderSubagentStoreSnapshot = ReturnType<typeof useProviderSubagentStore.getState>;

interface SelectSubagentsParams {
  serverId: string;
  parentAgentId: string;
}

const EMPTY_SUBAGENT_ROWS: PaseoSubagentRow[] = [];
const EMPTY_PROVIDER_SUBAGENT_ROWS: ProviderSubagentRow[] = [];

function toSubagentRow(
  agent: Agent,
  serverInfo: DaemonServerInfo | null | undefined,
): PaseoSubagentRow {
  return {
    kind: "paseo",
    id: agent.id,
    provider: agent.provider,
    title: agent.title,
    summary: resolveAgentPurposeSummary({ summary: agent.summary, serverInfo }),
    status: agent.status,
    requiresAttention: agent.requiresAttention,
    createdAt: agent.createdAt,
    model: agent.model,
    runtimeModelId: agent.runtimeInfo?.model ?? null,
    thinkingOptionId: agent.thinkingOptionId ?? null,
    effectiveThinkingOptionId: agent.effectiveThinkingOptionId,
  };
}

export function selectSubagentsForParent(
  state: SessionStoreSnapshot,
  params: SelectSubagentsParams,
  pendingArchiveIds: ReadonlySet<string>,
): PaseoSubagentRow[] {
  const agents = state.sessions[params.serverId]?.agents;
  const serverInfo = state.sessions[params.serverId]?.serverInfo;
  if (!agents || agents.size === 0) {
    return EMPTY_SUBAGENT_ROWS;
  }

  const rows: PaseoSubagentRow[] = [];
  for (const agent of agents.values()) {
    if (
      agent.archivedAt ||
      pendingArchiveIds.has(agent.id) ||
      agent.parentAgentId !== params.parentAgentId
    ) {
      continue;
    }
    rows.push(toSubagentRow(agent, serverInfo));
  }

  if (rows.length === 0) {
    return EMPTY_SUBAGENT_ROWS;
  }

  rows.sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
  return rows;
}

export function selectProviderSubagentsForParent(
  state: ProviderSubagentStoreSnapshot,
  params: SelectSubagentsParams,
  supported: boolean,
): ProviderSubagentRow[] {
  if (!supported) return EMPTY_PROVIDER_SUBAGENT_ROWS;
  const rows: ProviderSubagentRow[] = [];
  const prefix = `${params.serverId}\0${params.parentAgentId}\0`;
  for (const [key, subagent] of state.descriptors) {
    if (!key.startsWith(prefix) || state.hiddenFromTrack.has(key)) continue;
    rows.push({
      kind: "provider",
      id: subagent.id,
      parentAgentId: subagent.parentAgentId,
      provider: subagent.provider,
      title: subagent.title,
      description: subagent.description,
      status: subagent.status,
      requiresAttention: subagent.status === "failed",
      createdAt: new Date(subagent.createdAt),
      model: null,
      runtimeModelId: null,
      thinkingOptionId: null,
      effectiveThinkingOptionId: undefined,
    });
  }
  rows.sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
  return rows;
}

export function useSubagentsForParent(params: SelectSubagentsParams): SubagentRow[] {
  const pendingArchiveIds = usePendingArchiveAgentIds(params.serverId);
  const paseoRows = useStoreWithEqualityFn(
    useSessionStore,
    (state) => selectSubagentsForParent(state, params, pendingArchiveIds),
    equal,
  );
  const supported = useSessionStore(
    (state) => state.sessions[params.serverId]?.serverInfo?.features?.providerSubagents === true,
  );
  const providerRows = useStoreWithEqualityFn(
    useProviderSubagentStore,
    (state) => selectProviderSubagentsForParent(state, params, supported),
    equal,
  );
  const client = useSessionStore((state) => state.sessions[params.serverId]?.client ?? null);

  useEffect(() => {
    if (!client || !supported) return;
    void refreshProviderSubagents(client, params.serverId, params.parentAgentId).catch(
      () => undefined,
    );
  }, [client, params.parentAgentId, params.serverId, supported]);

  return useMemo(() => {
    if (providerRows.length === 0) return paseoRows;
    const rows = [...paseoRows, ...providerRows];
    rows.sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
    return rows;
  }, [paseoRows, providerRows]);
}
