import type { Agent, WorkspaceDescriptor } from "@/stores/session-store";
import { isWorkspaceRootAgent } from "@/subagents/policies";
import { deriveSidebarStateBucket } from "./sidebar-agent-state";

export const EMPTY_WORKSPACE_PROVIDERS: readonly string[] = [];

export interface WorkspaceAgentActivity {
  agentId: string;
  status: WorkspaceDescriptor["status"];
  enteredAt: Date | null;
  lastUserMessageAt: Date | null;
  /**
   * Distinct providers with a live root agent in the workspace, ordered by each
   * provider's most recent activity, descending. `providers[0]` is the provider
   * of the agent that won the recency contest for `agentId`.
   */
  providers: readonly string[];
  readyToReview: boolean;
}

function collectReadyToReviewWorkspaceIds(agents: ReadonlyMap<string, Agent>): Set<string> {
  const workspaceIds = new Set<string>();
  for (const agent of agents.values()) {
    const parentAgent = agent.parentAgentId ? agents.get(agent.parentAgentId) : undefined;
    const isRoot = isWorkspaceRootAgent(agent, parentAgent);
    const isReady = agent.requiresAttention === true && agent.attentionReason === "finished";
    if (!agent.archivedAt && agent.workspaceId && isRoot && isReady) {
      workspaceIds.add(agent.workspaceId);
    }
  }
  return workspaceIds;
}

export function buildWorkspaceAgentActivityIndex(
  agents: ReadonlyMap<string, Agent>,
  previous?: ReadonlyMap<string, WorkspaceAgentActivity>,
): Map<string, WorkspaceAgentActivity> {
  const activityByWorkspaceId = new Map<string, WorkspaceAgentActivity>();
  const latestActivityAtByWorkspaceId = new Map<string, Date>();
  const lastUserMessageAtByWorkspaceId = new Map<string, Date>();
  // Providers are collected for every live root agent, not just the recency
  // winner, so the row can show one icon per provider working in the workspace.
  const providerActivityByWorkspaceId = new Map<string, Map<string, number>>();
  const readyToReviewWorkspaceIds = collectReadyToReviewWorkspaceIds(agents);

  for (const agent of agents.values()) {
    const parentAgent = agent.parentAgentId ? agents.get(agent.parentAgentId) : undefined;
    if (agent.archivedAt || !agent.workspaceId || !isWorkspaceRootAgent(agent, parentAgent)) {
      continue;
    }

    recordLastUserMessageAt({
      lastUserMessageAtByWorkspaceId,
      workspaceId: agent.workspaceId,
      lastUserMessageAt: agent.lastUserMessageAt,
    });

    const enteredAt = agent.attentionTimestamp ?? agent.updatedAt;
    recordProviderActivity({
      providerActivityByWorkspaceId,
      workspaceId: agent.workspaceId,
      provider: agent.provider,
      status: agent.status,
      enteredAt,
    });

    const latestActivityAt = latestActivityAtByWorkspaceId.get(agent.workspaceId);
    if (latestActivityAt && enteredAt <= latestActivityAt) {
      continue;
    }
    latestActivityAtByWorkspaceId.set(agent.workspaceId, enteredAt);

    const status = deriveSidebarStateBucket({
      status: agent.status,
      pendingPermissionCount: agent.pendingPermissions.length,
      requiresAttention: agent.requiresAttention,
      attentionReason: agent.attentionReason,
    });
    activityByWorkspaceId.set(agent.workspaceId, {
      agentId: agent.id,
      status,
      enteredAt,
      lastUserMessageAt: null,
      providers: EMPTY_WORKSPACE_PROVIDERS,
      readyToReview: readyToReviewWorkspaceIds.has(agent.workspaceId),
    });
  }

  for (const [workspaceId, activity] of activityByWorkspaceId) {
    const previousActivity = previous?.get(workspaceId);
    const orderedProviders = orderProvidersByRecency(
      providerActivityByWorkspaceId.get(workspaceId),
    );
    // Sidebar entries compare provider lists by reference, so hold on to the
    // previous array whenever its contents still match.
    const providers =
      previousActivity && areProviderListsEqual(previousActivity.providers, orderedProviders)
        ? previousActivity.providers
        : orderedProviders;
    const lastUserMessageAt = lastUserMessageAtByWorkspaceId.get(workspaceId) ?? null;
    const nextActivity = { ...activity, lastUserMessageAt, providers };
    if (previousActivity && areWorkspaceAgentActivitiesEqual(previousActivity, nextActivity)) {
      activityByWorkspaceId.set(workspaceId, previousActivity);
      continue;
    }
    activityByWorkspaceId.set(workspaceId, nextActivity);
  }

  if (previous && areWorkspaceAgentActivityIndexesIdentical(previous, activityByWorkspaceId)) {
    return previous instanceof Map ? previous : new Map(previous);
  }
  return activityByWorkspaceId;
}

interface LastUserMessageInput {
  lastUserMessageAtByWorkspaceId: Map<string, Date>;
  workspaceId: string;
  lastUserMessageAt: Date | null;
}

function recordLastUserMessageAt(input: LastUserMessageInput): void {
  if (!input.lastUserMessageAt) {
    return;
  }
  const latestUserMessageAt = input.lastUserMessageAtByWorkspaceId.get(input.workspaceId);
  if (!latestUserMessageAt || input.lastUserMessageAt > latestUserMessageAt) {
    input.lastUserMessageAtByWorkspaceId.set(input.workspaceId, input.lastUserMessageAt);
  }
}

function areWorkspaceAgentActivitiesEqual(
  left: WorkspaceAgentActivity,
  right: WorkspaceAgentActivity,
): boolean {
  return (
    left.agentId === right.agentId &&
    left.status === right.status &&
    left.lastUserMessageAt?.getTime() === right.lastUserMessageAt?.getTime() &&
    left.providers === right.providers &&
    left.readyToReview === right.readyToReview
  );
}

function recordProviderActivity(input: {
  providerActivityByWorkspaceId: Map<string, Map<string, number>>;
  workspaceId: string;
  provider: string | undefined;
  status: Agent["status"];
  enteredAt: Date;
}): void {
  if (!input.provider || input.status === "closed" || input.status === "error") {
    return;
  }
  let byProvider = input.providerActivityByWorkspaceId.get(input.workspaceId);
  if (!byProvider) {
    byProvider = new Map<string, number>();
    input.providerActivityByWorkspaceId.set(input.workspaceId, byProvider);
  }
  const enteredAtMs = input.enteredAt.getTime();
  const latestMs = byProvider.get(input.provider);
  if (latestMs === undefined || enteredAtMs > latestMs) {
    byProvider.set(input.provider, enteredAtMs);
  }
}

function orderProvidersByRecency(
  providerActivity: ReadonlyMap<string, number> | undefined,
): readonly string[] {
  if (!providerActivity || providerActivity.size === 0) {
    return EMPTY_WORKSPACE_PROVIDERS;
  }
  return Array.from(providerActivity.entries())
    .sort(([, leftMs], [, rightMs]) => rightMs - leftMs)
    .map(([provider]) => provider);
}

function areProviderListsEqual(left: readonly string[], right: readonly string[]): boolean {
  if (left === right) {
    return true;
  }
  return left.length === right.length && left.every((provider, index) => provider === right[index]);
}

function areWorkspaceAgentActivityIndexesIdentical(
  previous: ReadonlyMap<string, WorkspaceAgentActivity>,
  next: ReadonlyMap<string, WorkspaceAgentActivity>,
): boolean {
  if (previous.size !== next.size) {
    return false;
  }
  for (const [workspaceId, activity] of next) {
    if (previous.get(workspaceId) !== activity) {
      return false;
    }
  }
  return true;
}
