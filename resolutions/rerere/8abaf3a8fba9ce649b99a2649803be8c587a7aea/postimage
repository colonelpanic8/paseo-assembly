import { useCallback, useEffect, useMemo, useState } from "react";
import { Pressable, Text, View, useWindowDimensions } from "react-native";
import Svg, { Circle } from "react-native-svg";
import { StyleSheet, withUnistyles } from "react-native-unistyles";
import type { TFunction } from "i18next";
import { useTranslation } from "react-i18next";
import type { AgentPromptCacheStatus } from "@getpaseo/protocol/agent-types";
import { Button } from "@/components/ui/button";
import { HoverCard, HoverCardContent, HoverCardTrigger } from "@/components/ui/hover-card";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useIsCompactFormFactor } from "@/constants/layout";
import { isNative } from "@/constants/platform";
import { useHostReportsUsage } from "@/usage";
import type { Theme } from "@/styles/theme";
import { ContextWindowDetails } from "./context-window-details";
import { ContextWindowSheet } from "./context-window-sheet";
import { formatTokenCount } from "./context-window-meter.utils";
import { derivePromptCacheView, type PromptCacheLifetime } from "./prompt-cache-view";

interface ContextWindowMeterProps {
  serverId: string;
  agentId: string;
  maxTokens: number | null;
  usedTokens: number | null;
  totalCostUsd?: number | null;
  showPercentage?: boolean;
  /** Model the agent is actually running; omitted when unknown. */
  modelLabel?: string | null;
  /** Thinking level the agent is actually running; omitted when unknown. */
  thinkingLabel?: string | null;
  /** Optional glyph envelope for icon-toolbar alignment. */
  glyphSize?: number;
  /** Absent on daemons that do not report prompt cache figures. */
  promptCache?: AgentPromptCacheStatus | null;
  /** Sends a short message to the agent to re-warm its prompt cache. */
  onPingPromptCache?: () => Promise<void>;
  /** The agent is busy, so a ping would only queue behind its turn. */
  pingDisabled?: boolean;
}

type PingState = "idle" | "pending" | "failed";

const SVG_SIZE = 14;
const USAGE_POPOVER_WIDTH = 300;
const COMPACT_SVG_SIZE = 12;
const COMPACT_RADIUS = 5;
const STROKE_WIDTH = 2;
const COMPACT_STROKE_WIDTH = 1.75;

function isValidMaxTokens(value: number): boolean {
  return Number.isFinite(value) && value > 0;
}

function isValidUsedTokens(value: number): boolean {
  return Number.isFinite(value) && value >= 0;
}

function getUsagePercentage(maxTokens: number, usedTokens: number): number | null {
  if (!isValidMaxTokens(maxTokens) || !isValidUsedTokens(usedTokens)) {
    return null;
  }
  return (usedTokens / maxTokens) * 100;
}

function clampPercentage(value: number): number {
  return Math.max(0, Math.min(100, value));
}

function formatSessionCost(value: number): string | null {
  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }
  if (value < 0.01) {
    return `$${value.toFixed(4)}`;
  }
  return `$${value.toFixed(2)}`;
}

function getProgressColor(percentage: number, theme: Theme): string {
  if (percentage > 90) {
    return theme.colors.destructive;
  }
  if (percentage >= 70) {
    return theme.colors.palette.amber[500];
  }
  return theme.colors.foregroundMuted;
}

function getMeterGeometry(showPercentage: boolean, glyphSize?: number) {
  if (showPercentage) {
    return {
      svgSize: COMPACT_SVG_SIZE,
      radius: COMPACT_RADIUS,
      strokeWidth: COMPACT_STROKE_WIDTH,
      containerStyle: styles.containerWithLabel,
    };
  }
  const resolvedSize = glyphSize ?? SVG_SIZE;
  const resolvedStrokeWidth = glyphSize ? 2 : STROKE_WIDTH;
  return {
    svgSize: resolvedSize,
    radius: (resolvedSize - resolvedStrokeWidth) / 2,
    strokeWidth: resolvedStrokeWidth,
    containerStyle: styles.container,
  };
}

// Wrap the whole SVG: withUnistyles adds a div on web, which cannot sit inside an SVG.
const ContextWindowRing = withUnistyles(function ContextWindowRing({
  size,
  radius,
  strokeWidth,
  percentage,
  trackColor,
  progressColor,
}: {
  size: number;
  radius: number;
  strokeWidth: number;
  percentage: number | null;
  trackColor: string;
  progressColor: string;
}) {
  const center = size / 2;
  const circumference = 2 * Math.PI * radius;
  return (
    <Svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Circle
        cx={center}
        cy={center}
        r={radius}
        fill="none"
        stroke={trackColor}
        strokeWidth={strokeWidth}
      />
      {percentage !== null ? (
        <Circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          stroke={progressColor}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference - (clampPercentage(percentage) / 100) * circumference}
          // SVG strokes start at three o'clock; the ring reads clockwise from twelve.
          transform={`rotate(-90 ${center} ${center})`}
        />
      ) : null}
    </Svg>
  );
});

function promptCacheDotStyle(lifetime: PromptCacheLifetime) {
  if (lifetime === "warm") return styles.promptCacheDotWarm;
  if (lifetime === "expiring") return styles.promptCacheDotExpiring;
  if (lifetime === "expired") return styles.promptCacheDotExpired;
  return styles.promptCacheDotUnknown;
}

function promptCacheStatusLabel(t: TFunction, lifetime: PromptCacheLifetime): string {
  if (lifetime === "warm") return t("contextWindow.promptCache.statusWarm");
  if (lifetime === "expiring") return t("contextWindow.promptCache.statusExpiring");
  if (lifetime === "expired") return t("contextWindow.promptCache.statusExpired");
  return t("contextWindow.promptCache.statusUnknown");
}

function formatCacheDuration(t: TFunction, seconds: number): string {
  const safeSeconds = Math.max(0, Math.round(seconds));
  if (safeSeconds < 60) {
    return t("contextWindow.promptCache.durationSeconds", { value: safeSeconds });
  }
  return t("contextWindow.promptCache.durationMinutes", { value: Math.round(safeSeconds / 60) });
}

function promptCacheTiming(t: TFunction, view: ReturnType<typeof derivePromptCacheView>): string {
  if (view.lifetime === "expired") {
    return t("contextWindow.promptCache.expiredAgo", {
      duration: formatCacheDuration(t, view.expiredForSeconds ?? 0),
    });
  }
  if (view.remainingSeconds === null) {
    return t("contextWindow.promptCache.lastRequestAgo", {
      duration: formatCacheDuration(t, view.elapsedSeconds),
    });
  }
  return t("contextWindow.promptCache.warmFor", {
    duration: formatCacheDuration(t, view.remainingSeconds),
  });
}

function promptCacheSplit(
  t: TFunction,
  split: ReturnType<typeof derivePromptCacheView>["lastRequest"],
): string {
  const cached = formatTokenCount(split.cachedTokens);
  const fresh = formatTokenCount(split.freshTokens);
  if (split.writtenTokens === null) {
    return t("contextWindow.promptCache.split", { cached, fresh });
  }
  return t("contextWindow.promptCache.splitWithWrite", {
    cached,
    fresh,
    written: formatTokenCount(split.writtenTokens),
  });
}

interface PromptCacheTooltipSectionProps {
  status: AgentPromptCacheStatus;
  pingState: PingState;
  onPing: (() => void) | null;
  pingDisabled: boolean;
}

// Rendered only while the tooltip is open, so the once-a-second countdown starts and
// stops with the surface the user is reading.
function PromptCacheTooltipSection({
  status,
  pingState,
  onPing,
  pingDisabled,
}: PromptCacheTooltipSectionProps) {
  const { t } = useTranslation();
  const [nowMs, setNowMs] = useState(() => Date.now());

  useEffect(() => {
    const interval = setInterval(() => setNowMs(Date.now()), 1000);
    return () => clearInterval(interval);
  }, []);

  const view = useMemo(() => derivePromptCacheView(status, nowMs), [status, nowMs]);

  return (
    <>
      <View style={styles.tooltipDivider} />
      <Text style={styles.tooltipTitle}>{t("contextWindow.promptCache.title")}</Text>
      <View style={styles.promptCacheStatusRow}>
        <View style={[styles.promptCacheDot, promptCacheDotStyle(view.lifetime)]} />
        <Text style={styles.tooltipText}>{promptCacheStatusLabel(t, view.lifetime)}</Text>
        <Text style={styles.tooltipDetail} numberOfLines={1}>
          {promptCacheTiming(t, view)}
        </Text>
      </View>
      <Text style={styles.tooltipDetail}>
        {t("contextWindow.promptCache.lastRequest", {
          percent: view.lastRequest.hitPercent,
          split: promptCacheSplit(t, view.lastRequest),
        })}
      </Text>
      <Text style={styles.tooltipDetail}>
        {t(
          view.session.requestCount === 1
            ? "contextWindow.promptCache.sessionSingular"
            : "contextWindow.promptCache.sessionPlural",
          { percent: view.session.hitPercent, count: view.session.requestCount },
        )}
      </Text>
      {onPing ? (
        <>
          <View style={styles.promptCachePingRow}>
            <Button
              variant="outline"
              size="sm"
              onPress={onPing}
              disabled={pingDisabled || pingState === "pending"}
            >
              {pingState === "pending"
                ? t("contextWindow.promptCache.pinging")
                : t("contextWindow.promptCache.ping")}
            </Button>
          </View>
          {/* The hint slot doubles as the failure slot so the section keeps its height. */}
          <Text
            style={
              pingState === "failed" ? styles.promptCachePingError : styles.promptCachePingHint
            }
            numberOfLines={2}
          >
            {pingState === "failed"
              ? t("contextWindow.promptCache.pingError")
              : t("contextWindow.promptCache.pingHint")}
          </Text>
        </>
      ) : null}
    </>
  );
}

export function ContextWindowMeter({
  serverId,
  agentId,
  maxTokens,
  usedTokens,
  totalCostUsd,
  showPercentage = false,
  modelLabel,
  thinkingLabel,
  glyphSize,
  promptCache,
  onPingPromptCache,
  pingDisabled = false,
}: ContextWindowMeterProps) {
  const { t } = useTranslation();
  const { width } = useWindowDimensions();
  // Usage cards need a wider popover; without them it keeps the plain tooltip shape.
  const showsUsage = useHostReportsUsage(serverId);
  const popoverWidth = Math.min(USAGE_POPOVER_WIDTH, width - 24);
  // Compact screens open the details in a sheet, which can hold a pressable Refresh.
  const isCompact = useIsCompactFormFactor();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const openSheet = useCallback(() => setIsSheetOpen(true), []);
  const closeSheet = useCallback(() => setIsSheetOpen(false), []);
  // Ping state lives here, not in the section: the section unmounts every time the
  // tooltip closes, and a failure has to survive until the user tries again.
  const [pingState, setPingState] = useState<PingState>("idle");
  const percentage =
    maxTokens !== null && usedTokens !== null ? getUsagePercentage(maxTokens, usedTokens) : null;
  const handlePing = useCallback(() => {
    if (!onPingPromptCache) return;
    setPingState("pending");
    void onPingPromptCache().then(
      () => setPingState("idle"),
      () => setPingState("failed"),
    );
  }, [onPingPromptCache]);

  const geometry = getMeterGeometry(showPercentage, glyphSize);

  const context = useMemo(
    () =>
      percentage !== null && maxTokens !== null && usedTokens !== null
        ? { percentage: Math.round(percentage), maxTokens, usedTokens }
        : null,
    [percentage, maxTokens, usedTokens],
  );
  const meterColors = useCallback(
    (theme: Theme) => ({
      progressColor: getProgressColor(percentage ?? 0, theme),
      trackColor: theme.colors.surface3,
    }),
    [percentage],
  );
  const formattedSessionCost =
    typeof totalCostUsd === "number" ? formatSessionCost(totalCostUsd) : null;
  const containerStyle = geometry.containerStyle;
  const ring = (
    <ContextWindowRing
      size={geometry.svgSize}
      radius={geometry.radius}
      strokeWidth={geometry.strokeWidth}
      percentage={percentage}
      uniProps={meterColors}
    />
  );
  const percentageLabel =
    showPercentage && context ? (
      <Text style={styles.percentageLabel}>{`${context.percentage}%`}</Text>
    ) : null;
  const accessibilityLabel = context
    ? t("contextWindow.accessibility", { percentage: context.percentage })
    : t("contextWindow.accessibilityNoData");
  const runtimeDetails = (
    <>
      {modelLabel ? (
        <Text style={styles.runtimeDetail} testID="context-window-meter-model">
          {t("contextWindow.model", { model: modelLabel })}
        </Text>
      ) : null}
      {thinkingLabel ? (
        <Text style={styles.runtimeDetail} testID="context-window-meter-thinking">
          {t("contextWindow.thinking", { thinking: thinkingLabel })}
        </Text>
      ) : null}
    </>
  );

  const cacheDetails = promptCache ? (
    <PromptCacheTooltipSection
      status={promptCache}
      pingState={pingState}
      onPing={onPingPromptCache ? handlePing : null}
      pingDisabled={pingDisabled}
    />
  ) : null;

  if (isCompact) {
    return (
      <>
        <Pressable
          style={containerStyle}
          testID="context-window-meter"
          accessibilityRole="button"
          accessibilityLabel={accessibilityLabel}
          onPress={openSheet}
        >
          {ring}
          {percentageLabel}
        </Pressable>
        <ContextWindowSheet open={isSheetOpen} onClose={closeSheet}>
          <ContextWindowDetails
            serverId={serverId}
            agentId={agentId}
            context={context}
            sessionCost={formattedSessionCost}
            showTitle={false}
            refreshable
          />
          {runtimeDetails}
          {cacheDetails}
        </ContextWindowSheet>
      </>
    );
  }

  const popoverStyle = showsUsage
    ? [styles.usagePopover, { width: popoverWidth }]
    : styles.plainPopover;

  // Native wide screens have no hover, so the details open in a tooltip on press. The tooltip
  // takes no presses, so its usage cards have no Refresh.
  if (isNative) {
    return (
      <Tooltip
        delayDuration={0}
        enabledOnDesktop
        enabledOnMobile
        interactive={Boolean(promptCache && onPingPromptCache)}
      >
        <TooltipTrigger asChild triggerRefProp="ref">
          <Pressable
            style={containerStyle}
            testID="context-window-meter"
            accessibilityRole="image"
            accessibilityLabel={accessibilityLabel}
          >
            {ring}
            {percentageLabel}
          </Pressable>
        </TooltipTrigger>
        <TooltipContent
          side="top"
          align="center"
          offset={8}
          maxWidth={showsUsage ? popoverWidth : undefined}
          style={popoverStyle}
          testID="context-window-meter-tooltip"
        >
          <ContextWindowDetails
            serverId={serverId}
            agentId={agentId}
            context={context}
            sessionCost={formattedSessionCost}
            showTitle
            refreshable={false}
          />
          {runtimeDetails}
          {cacheDetails}
        </TooltipContent>
      </Tooltip>
    );
  }

  return (
    <HoverCard>
      <HoverCardTrigger focusable accessibilityLabel={accessibilityLabel}>
        <View
          style={containerStyle}
          testID="context-window-meter"
          accessibilityRole="image"
          accessibilityLabel={accessibilityLabel}
        >
          {ring}
          {percentageLabel}
        </View>
      </HoverCardTrigger>
      <HoverCardContent
        placement="top"
        offset={8}
        role="dialog"
        accessibilityLabel={t("contextWindow.title")}
        testID="context-window-details"
        style={popoverStyle}
      >
        <ContextWindowDetails
          serverId={serverId}
          agentId={agentId}
          context={context}
          sessionCost={formattedSessionCost}
          showTitle
          refreshable
        />
        {runtimeDetails}
        {cacheDetails}
      </HoverCardContent>
    </HoverCard>
  );
}

const styles = StyleSheet.create((theme) => ({
  container: {
    width: 28,
    height: 28,
    borderRadius: theme.borderRadius.full,
    alignItems: "center",
    justifyContent: "center",
  },
  containerWithLabel: {
    height: 28,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: theme.spacing[1],
    borderRadius: theme.borderRadius.full,
  },
  percentageLabel: {
    color: theme.colors.foregroundMuted,
    fontSize: theme.fontSize.base,
    fontWeight: theme.fontWeight.normal,
  },
  runtimeDetail: {
    color: theme.colors.foregroundMuted,
    fontSize: theme.fontSize.sm,
    lineHeight: theme.fontSize.sm * 1.4,
  },
  // Plain details use a small inset; account usage cards have their own content density.
  plainPopover: { paddingVertical: theme.spacing[1], paddingHorizontal: theme.spacing[2] },
  usagePopover: { padding: theme.spacing[3], gap: theme.spacing[3] },
  tooltipContent: {
    gap: theme.spacing[1.5],
    minWidth: 200,
  },
  tooltipTitle: {
    color: theme.colors.foreground,
    fontSize: theme.fontSize.base,
  },
  tooltipText: {
    color: theme.colors.foreground,
    fontSize: theme.fontSize.base,
    lineHeight: theme.fontSize.base * 1.4,
  },
  tooltipDetail: {
    color: theme.colors.foregroundMuted,
    fontSize: theme.fontSize.sm,
    lineHeight: theme.fontSize.sm * 1.4,
  },
  tooltipDivider: {
    height: 1,
    backgroundColor: theme.colors.borderAccent,
    marginVertical: theme.spacing[1],
    // Cancel the tooltip content's horizontal padding so the rule spans edge to edge.
    marginHorizontal: -theme.spacing[2],
  },
  promptCacheStatusRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: theme.spacing[1.5],
    // Pin the row so swapping Warm for Likely expired cannot move the lines below it.
    minHeight: theme.fontSize.base * 1.4,
  },
  promptCacheDot: {
    width: theme.spacing[1.5],
    height: theme.spacing[1.5],
    borderRadius: theme.borderRadius.full,
  },
  promptCacheDotWarm: {
    backgroundColor: theme.colors.statusSuccess,
  },
  promptCacheDotExpiring: {
    backgroundColor: theme.colors.statusWarning,
  },
  promptCacheDotExpired: {
    backgroundColor: theme.colors.statusDanger,
  },
  promptCacheDotUnknown: {
    backgroundColor: theme.colors.foregroundMuted,
  },
  promptCachePingRow: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: theme.spacing[0.5],
  },
  promptCachePingHint: {
    color: theme.colors.foregroundMuted,
    fontSize: theme.fontSize.sm,
    lineHeight: theme.fontSize.sm * 1.4,
    // Two lines either way, so swapping the hint for the failure keeps the height.
    minHeight: theme.fontSize.sm * 1.4 * 2,
  },
  promptCachePingError: {
    color: theme.colors.palette.red[300],
    fontSize: theme.fontSize.sm,
    lineHeight: theme.fontSize.sm * 1.4,
    minHeight: theme.fontSize.sm * 1.4 * 2,
  },
}));
