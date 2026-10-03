import type pino from "pino";
import type {
  CodexBankedResetOutcome,
  ProviderUsage,
  UsageReportEntry,
} from "@getpaseo/protocol/messages";
import type { SessionInboundMessage, SessionOutboundMessage } from "../../messages.js";
import {
  UsageHistoryInvalidWindowError,
  type UsageHistoryService,
  validateUsageHistoryWindow,
} from "../../../services/usage-history/service.js";

export interface UsageSessionOptions {
  emit(message: SessionOutboundMessage): void;
  historyService?: UsageHistoryService;
  runtime?: {
    consumeCodexBankedReset?(input: {
      reportId?: string;
      creditId: string;
      idempotencyKey: string;
    }): Promise<CodexBankedResetOutcome>;
    listUsageReports(options: {
      forceRefresh?: boolean;
      reportIds?: string[];
    }): Promise<UsageReportEntry[]>;
    listLegacyUsage(): Promise<{ fetchedAt: string; providers: ProviderUsage[] }>;
  };
  logger: pino.Logger;
}

export class UsageSession {
  constructor(private readonly options: UsageSessionOptions) {}

  async handleListReports(
    msg: Extract<SessionInboundMessage, { type: "usage.list_reports.request" }>,
  ): Promise<void> {
    try {
      if (!this.options.runtime) throw new Error("Plugin runtime is unavailable");
      const reports = await this.options.runtime.listUsageReports({
        forceRefresh: msg.forceRefresh,
        reportIds: msg.reportIds,
      });
      this.options.emit({
        type: "usage.list_reports.response",
        payload: { requestId: msg.requestId, reports },
      });
    } catch (error) {
      this.emitError(msg, error, "usage_list_reports_failed");
    }
  }

  // COMPAT(providerUsageList): added in v0.9.3, remove after 2027-03-26.
  async handleLegacyList(
    msg: Extract<SessionInboundMessage, { type: "provider.usage.list.request" }>,
  ): Promise<void> {
    try {
      if (!this.options.runtime) throw new Error("Plugin runtime is unavailable");
      const usage = await this.options.runtime.listLegacyUsage();
      this.options.emit({
        type: "provider.usage.list.response",
        payload: {
          requestId: msg.requestId,
          fetchedAt: usage.fetchedAt,
          providers: usage.providers,
        },
      });
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      this.options.logger.error({ err }, "Failed to list provider usage");
      this.options.emit({
        type: "rpc_error",
        payload: {
          requestId: msg.requestId,
          requestType: msg.type,
          error: `Failed to list provider usage: ${err.message}`,
          code: "provider_usage_list_failed",
        },
      });
    }
  }

  async handleCodexBankedResetConsumeRequest(
    msg: Extract<SessionInboundMessage, { type: "provider.codex.consume_banked_reset.request" }>,
  ): Promise<void> {
    try {
      const runtime = this.options.runtime;
      if (!runtime?.consumeCodexBankedReset) throw new Error("Codex reset actions are unavailable");
      const outcome = await runtime.consumeCodexBankedReset({
        ...(msg.reportId ? { reportId: msg.reportId } : {}),
        creditId: msg.creditId,
        idempotencyKey: msg.idempotencyKey,
      });
      this.options.emit({
        type: "provider.codex.consume_banked_reset.response",
        payload: { requestId: msg.requestId, outcome },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.options.emit({
        type: "rpc_error",
        payload: {
          requestId: msg.requestId,
          requestType: msg.type,
          error: `Could not use banked reset: ${message}`,
          code: "codex_banked_reset_failed",
        },
      });
    }
  }

  async handleProviderUsageHistoryReadRequest(
    msg: Extract<SessionInboundMessage, { type: "provider.usage_history.read.request" }>,
  ): Promise<void> {
    try {
      validateUsageHistoryWindow(msg);
    } catch (error) {
      if (!(error instanceof UsageHistoryInvalidWindowError)) throw error;
      this.options.emit({
        type: "rpc_error",
        payload: {
          requestId: msg.requestId,
          requestType: msg.type,
          error: `Invalid usage history window: ${error.message}`,
          code: "provider_usage_history_invalid_window",
        },
      });
      return;
    }

    try {
      const historyService = this.options.historyService;
      if (!historyService) throw new Error("Usage history is unavailable");
      if (msg.refreshRates) await historyService.refreshRates();
      const summary = await historyService.readSummary(msg);
      this.options.emit({
        type: "provider.usage_history.read.response",
        payload: { requestId: msg.requestId, ...summary },
      });
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      this.options.logger.error({ err }, "Failed to read provider usage history");
      this.options.emit({
        type: "rpc_error",
        payload: {
          requestId: msg.requestId,
          requestType: msg.type,
          error: `Failed to read provider usage history: ${err.message}`,
          code: "provider_usage_history_read_failed",
        },
      });
    }
  }

  private emitError(
    msg: Extract<SessionInboundMessage, { type: "usage.list_reports.request" }>,
    error: unknown,
    code: string,
  ): void {
    this.options.emit({
      type: "rpc_error",
      payload: {
        requestId: msg.requestId,
        requestType: msg.type,
        error: error instanceof Error ? error.message : String(error),
        code,
      },
    });
  }
}
