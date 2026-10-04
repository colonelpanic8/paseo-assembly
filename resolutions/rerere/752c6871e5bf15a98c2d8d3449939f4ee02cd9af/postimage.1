import pino from "pino";
import { describe, expect, it, test, vi } from "vitest";
import type { UsageHistoryService } from "../../../services/usage-history/service.js";
import type { SessionOutboundMessage } from "../../messages.js";
import { UsageSession } from "./usage-session.js";

test("lists reports from usage sources", async () => {
  const emitted: SessionOutboundMessage[] = [];
  const requested: Array<{ forceRefresh?: boolean; reportIds?: string[] }> = [];
  const entry = {
    id: "fixture:one",
    account: {},
    fetchedAt: "2026-01-01T00:00:00.000Z",
    sourceId: "fixture",
    sourceLabel: "Fixture",
    report: { status: "available" as const, windows: [] },
  };
  const usage = new UsageSession({
    emit: (message) => emitted.push(message),
    runtime: {
      async listUsageReports(options) {
        requested.push({ forceRefresh: options.forceRefresh, reportIds: options.reportIds });
        options.onReport?.(entry);
        return [entry];
      },
      async listLegacyUsage() {
        return { fetchedAt: "2026-01-01T00:00:00.000Z", providers: [] };
      },
    },
    logger: pino({ level: "silent" }),
  });

  await usage.handleListReports({ type: "usage.list_reports.request", requestId: "list" });
  expect(requested).toEqual([{ forceRefresh: undefined, reportIds: undefined }]);
  expect(emitted).toEqual([
    { type: "usage.list_reports.update", payload: { requestId: "list", report: entry } },
    { type: "usage.list_reports.response", payload: { requestId: "list", error: null } },
  ]);
});

test("surfaces a legacy usage-list failure as an rpc_error envelope", async () => {
  const emitted: SessionOutboundMessage[] = [];
  const usage = new UsageSession({
    emit: (message) => emitted.push(message),
    runtime: {
      async listUsageReports() {
        return [];
      },
      async listLegacyUsage(): Promise<never> {
        throw new Error("quota service down");
      },
    },
    logger: pino({ level: "silent" }),
  });
  await usage.handleLegacyList({ type: "provider.usage.list.request", requestId: "u1" });
  expect(emitted[0]).toMatchObject({
    type: "rpc_error",
    payload: { requestId: "u1", code: "provider_usage_list_failed" },
  });
});

test("request failures terminate with an error response and no updates", async () => {
  const emitted: SessionOutboundMessage[] = [];
  const usage = new UsageSession({
    emit: (message) => emitted.push(message),
    logger: pino({ level: "silent" }),
  });
  await usage.handleListReports({ type: "usage.list_reports.request", requestId: "failed" });
  expect(emitted).toEqual([
    {
      type: "usage.list_reports.response",
      payload: { requestId: "failed", error: "Plugin runtime is unavailable" },
    },
  ]);
});

function makeResetSession(
  consumeCodexBankedReset: NonNullable<
    NonNullable<ConstructorParameters<typeof UsageSession>[0]["runtime"]>["consumeCodexBankedReset"]
  >,
) {
  const emitted: SessionOutboundMessage[] = [];
  const usage = new UsageSession({
    emit: (message) => emitted.push(message),
    runtime: {
      listUsageReports: async () => [],
      listLegacyUsage: async () => ({ fetchedAt: "now", providers: [] }),
      consumeCodexBankedReset,
    },
    logger: pino({ level: "silent" }),
  });
  return { emitted, usage };
}

test("returns a correlated error when banked reset redemption fails", async () => {
  const { usage, emitted } = makeResetSession(async () => {
    throw new Error("Request timed out");
  });
  await usage.handleCodexBankedResetConsumeRequest({
    type: "provider.codex.consume_banked_reset.request",
    requestId: "request-1",
    creditId: "reset-1",
    idempotencyKey: "attempt-1",
  });
  expect(emitted).toEqual([
    {
      type: "rpc_error",
      payload: {
        requestId: "request-1",
        requestType: "provider.codex.consume_banked_reset.request",
        error: "Could not use banked reset: Request timed out",
        code: "codex_banked_reset_failed",
      },
    },
  ]);
});

test("forwards banked reset redemption and correlates the outcome", async () => {
  const consume = vi.fn(async () => "nothing_to_reset" as const);
  const { usage, emitted } = makeResetSession(consume);
  await usage.handleCodexBankedResetConsumeRequest({
    type: "provider.codex.consume_banked_reset.request",
    requestId: "request-1",
    reportId: "codex:work",
    creditId: "reset-1",
    idempotencyKey: "attempt-1",
  });
  expect(consume).toHaveBeenCalledWith({
    reportId: "codex:work",
    creditId: "reset-1",
    idempotencyKey: "attempt-1",
  });
  expect(emitted).toEqual([
    {
      type: "provider.codex.consume_banked_reset.response",
      payload: { requestId: "request-1", outcome: "nothing_to_reset" },
    },
  ]);
});

function makeHistorySubsystem(options: { usageHistory: Partial<UsageHistoryService> }) {
  const emitted: SessionOutboundMessage[] = [];
  return {
    emitted,
    subsystem: new UsageSession({
      emit: (message) => emitted.push(message),
      historyService: options.usageHistory as UsageHistoryService,
      logger: pino({ level: "silent" }),
    }),
  };
}

function findByType<T extends SessionOutboundMessage["type"]>(
  emitted: SessionOutboundMessage[],
  type: T,
) {
  return emitted.find((message) => message.type === type) as
    | Extract<SessionOutboundMessage, { type: T }>
    | undefined;
}

describe("usage history", () => {
  it("emits a usage-history response with the request id", async () => {
    const refreshRates = vi.fn(async () => ({
      status: "fresh" as const,
      source: "https://example.test/rates.json",
      fetchedAt: "2026-08-03T00:00:00.000Z",
      knownModels: 1,
    }));
    const readSummary = vi.fn(async () => ({
      readAt: "2026-08-03T00:00:00.000Z",
      timeZone: "UTC",
      sinceDay: "2026-08-01",
      untilDay: "2026-08-02",
      buckets: [],
      sources: [],
      pricing: {
        status: "unavailable" as const,
        source: "https://example.test/rates.json",
        fetchedAt: null,
        knownModels: 0,
      },
      scanDurationMs: 12,
    }));
    const { subsystem, emitted } = makeHistorySubsystem({
      usageHistory: { readSummary, refreshRates },
    });

    await subsystem.handleProviderUsageHistoryReadRequest({
      type: "provider.usage_history.read.request",
      requestId: "history-1",
      sinceDay: "2026-08-01",
      untilDay: "2026-08-02",
      timeZone: "UTC",
      refreshRates: true,
    });

    expect(refreshRates).toHaveBeenCalledOnce();
    expect(findByType(emitted, "provider.usage_history.read.response")?.payload).toEqual({
      requestId: "history-1",
      ...(await readSummary.mock.results[0]?.value),
    });
  });

  it("surfaces a usage-history failure as an rpc_error envelope", async () => {
    const { subsystem, emitted } = makeHistorySubsystem({
      usageHistory: {
        readSummary: async () => {
          throw new Error("transcript scan failed");
        },
      },
    });

    await subsystem.handleProviderUsageHistoryReadRequest({
      type: "provider.usage_history.read.request",
      requestId: "history-2",
      sinceDay: "2026-08-01",
      untilDay: "2026-08-02",
      timeZone: "UTC",
    });

    const error = findByType(emitted, "rpc_error");
    expect(error?.payload.code).toBe("provider_usage_history_read_failed");
    expect(error?.payload.requestId).toBe("history-2");
  });

  it("rejects invalid usage-history windows without calling the service", async () => {
    const readSummary = vi.fn();
    const { subsystem, emitted } = makeHistorySubsystem({ usageHistory: { readSummary } });

    await subsystem.handleProviderUsageHistoryReadRequest({
      type: "provider.usage_history.read.request",
      requestId: "history-3",
      sinceDay: "2026-02-30",
      untilDay: "2026-03-01",
      timeZone: "UTC",
    });

    expect(readSummary).not.toHaveBeenCalled();
    const error = findByType(emitted, "rpc_error");
    expect(error?.payload.code).toBe("provider_usage_history_invalid_window");
    expect(error?.payload.requestId).toBe("history-3");
  });
});
